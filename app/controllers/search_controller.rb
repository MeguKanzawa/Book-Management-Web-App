class SearchController < ApplicationController
  def index
    if params[:query].present?
      @found_series_by_genre = RakutenBooksService.search_parent_series(params[:query])

      found_titles = @found_series_by_genre.values.map { |s| s[:title] || s["title"] }.compact.uniq

      # Fetch existing series
      existing_records = BookSeries.includes(:books).where(title: found_titles)

      # Build a strict composite key: [title, normalized_author, genre_id]
      @existing_series_map = existing_records.index_by do |s|
        norm_author = s.author.to_s.gsub(/\s+/, "").strip
        [s.title.to_s.strip, norm_author, s.rakuten_genre_id.to_s.strip]
      end
    else
      @found_series_by_genre = {}
      @existing_series_map = {}
    end

    session[:query] = params[:query]
    @query = session[:query]
  end

  def show_series
    @query            = session[:query] || params[:query]
    @title            = params[:title]
    @series_name      = params[:series_name]
    @rakuten_genre_id = params[:rakuten_genre_id]
    @author           = params[:author]
    @publisher        = params[:publisher]

    # 1. Scoped lookup: Find by ID first, or strictly match Title + Genre ID + Author
    if params[:series_id].present? && params[:series_id] != "0"
      @series_record = BookSeries.includes(:books).find_by(id: params[:series_id])
    end

    if @series_record.nil? && @title.present?
      # Fallback match MUST be strict to avoid cross-series collision
      scoped_query = BookSeries.includes(:books).where(title: @title)
      scoped_query = scoped_query.where(rakuten_genre_id: @rakuten_genre_id) if @rakuten_genre_id.present?
      
      if @author.present?
        norm_author = @author.to_s.gsub(/\s+/, "").strip
        @series_record = scoped_query.find { |s| s.author.to_s.gsub(/\s+/, "").strip == norm_author }
      else
        @series_record = scoped_query.first
      end
    end
    
    @series_id = @series_record&.id || 0

    # 2. Fetch volume listings from Rakuten API
    @volumes = RakutenBooksService.fetch_series_volumes(
      @title,
      @series_name,
      @rakuten_genre_id,
      @author,
      @publisher
    )

    # 3. Match DB books with STRICT guard conditions
    if @series_record
      # Index books strictly by populated values
      books_by_isbn    = @series_record.books.select { |b| b.isbn.present? }.index_by { |b| b.isbn.to_s.strip }
      books_by_title   = @series_record.books.select { |b| b.volume_title.present? }.index_by { |b| b.volume_title.to_s.strip.downcase }
      books_by_vol_num = @series_record.books.select { |b| b.volume_num.to_i > 0 }.index_by { |b| b.volume_num.to_i }

      @volumes.each do |vol|
        v_isbn  = (vol[:isbn] || vol["isbn"]).to_s.strip
        v_title = (vol[:title] || vol["title"]).to_s.strip.downcase
        v_num   = (vol[:volume_number] || vol["volume_number"]).presence
        v_num_i = v_num ? v_num.to_i : nil

        db_book = nil
        # 1. Match by ISBN
        db_book ||= books_by_isbn[v_isbn] if v_isbn.present?
        # 2. Match by Volume Number (ONLY if > 0)
        db_book ||= books_by_vol_num[v_num_i] if v_num_i.present? && v_num_i > 0
        # 3. Match by Volume Title
        db_book ||= books_by_title[v_title] if v_title.present?

        # Attach database details ONLY if an explicit match belongs to this exact series
        if db_book
          vol[:book_status] = db_book.book_status
          vol[:id]          = db_book.id
        end
      end
    end
  end
end