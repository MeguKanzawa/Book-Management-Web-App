# app/controllers/search_controller.rb
class SearchController < ApplicationController
  def index
    if params[:query].present?
      @found_series = GoogleBooksService.search(params[:query])
    else
      @found_series = []
    end
  end

  def show_series
    @series_name = params[:name]
    @series_id = params[:series_id]
    
    # Always pull strict volume entries by searching the validated text name
    @volumes = GoogleBooksService.fetch_series_volumes_by_title(@series_name, @series_id)    
  end
end