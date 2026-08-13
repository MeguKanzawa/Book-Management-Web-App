
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
    @query = session[:query]
    @title = params[:title]
    @series_name = params[:series_name]
    @rakuten_genre_id    = params[:rakuten_genre_id]
    @author      = params[:author]
    @publisher   = params[:publisher]
  
    @volumes = RakutenBooksService.fetch_series_volumes(
      @title,
      @series_name,
      @rakuten_genre_id,
      @author,
      @publisher,
    )

    @existing_series = BookSeries.find_by(title: @title, author: @author)
    
    if @existing_series
      # Map collected/owned volume numbers (or titles)
      owned_volume_numbers = @existing_series.books.pluck(:volume_num).compact.map(&:to_i)

      # 3. Mark each fetched volume with an :owned status
      @volumes.each do |vol|
        vol[:owned] = owned_volume_numbers.include?(vol[:volume_number].to_i)
      end
    end

  end
end