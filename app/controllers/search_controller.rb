
## app/controllers/search_controller.rb
class SearchController < ApplicationController
  def index
    if params[:query].present?
      @found_series_by_genre = RakutenBooksService.search_parent_series(params[:query])
    else
      @found_series_by_genre = {}
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

  end
end