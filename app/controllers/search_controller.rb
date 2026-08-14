
## app/controllers/search_controller.rb
class SearchController < ApplicationController
  def index
    if params[:query].present?
      @found_series_by_genre = RakutenBooksService.search_parent_series(params[:query])

      found_titles = @found_series_by_genre.values.map { |s| s[:title] || s["title"] }

      @existing_series_map = BookSeries.where(title: found_titles).index_by(&:title)
    else
      @found_series_by_genre = {}
      @existing_series_map = {}
    end
    session[:query] = params[:query]
    @query = session[:query]
  end

  def show_series
    @query = session[:query] || params[:query]
    @title = params[:title]
    @series_name = params[:series_name]
    @rakuten_genre_id    = params[:rakuten_genre_id]
    @author      = params[:author]
    @publisher   = params[:publisher]

    @existing_series = BookSeries.find_by(title: @title, author: @author)
    @series_id       = @existing_series&.id || 0
  
    @volumes = RakutenBooksService.fetch_series_volumes(
      @title,
      @series_name,
      @rakuten_genre_id,
      @author,
      @publisher,
    )

    if @existing_series
      # Map collected/owned volume numbers (or titles)
      existing_books_map = @existing_series.books.index_by(&:volume_num)

      @volumes.each do |vol|
        vol_num = (vol[:volume_number] || vol["volume_number"]).to_i
        if (db_book = existing_books_map[vol_num])
          vol[:book_status] = db_book.book_status
          vol[:id] = db_book.id
        end
      end
    end

  end
end