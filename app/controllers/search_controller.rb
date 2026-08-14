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

    # 1. Fallback lookup: try finding by ID first, then fallback to title search
    if params[:series_id].present? && params[:series_id] != "0"
      @existing_series = BookSeries.includes(:books).find_by(id: params[:series_id])
    end
    @existing_series ||= BookSeries.includes(:books).find_by(title: @title)
    
    @series_id = @existing_series&.id || 0

    # 2. Fetch volume listings from Rakuten API
    @volumes = RakutenBooksService.fetch_series_volumes(
      @title,
      @series_name,
      @rakuten_genre_id,
      @author,
      @publisher
    )

    # 3. Match DB books using ISBN -> Title -> Volume Number
    if @existing_series
      # Build multi-index maps for fast, flexible lookup
      books_by_isbn   = @existing_series.books.select { |b| b.isbn.present? }.index_by(&:isbn)
      books_by_title  = @existing_series.books.select { |b| b.volume_title.present? }.index_by(&:volume_title)
      books_by_vol_num = @existing_series.books.select { |b| b.volume_num.present? }.index_by(&:volume_num)

      @volumes.each do |vol|
        v_isbn  = vol[:isbn] || vol["isbn"]
        v_title = vol[:title] || vol["title"]
        v_num   = (vol[:volume_number] || vol["volume_number"]).presence
        v_num_i = v_num ? v_num.to_i : nil

        # Multi-criteria match: ISBN first, then volume title, then volume number
        db_book = nil
        if v_isbn.present?
          db_book = books_by_isbn[v_isbn]
        end
        if db_book.nil? && v_title.present?
          db_book = books_by_title[v_title]
        end
        if db_book.nil? && v_num_i.present?
          db_book = books_by_vol_num[v_num_i]
        end

        # Attach database details if match is found
        if db_book
          vol[:book_status] = db_book.book_status
          vol[:id]          = db_book.id
        end
      end
    end
  end
end