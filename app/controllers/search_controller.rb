# # app/controllers/search_controller.rb
# class SearchController < ApplicationController
#   def index
#     if params[:query].present?
#       @found_series = GoogleBooksService.search(params[:query])
#     else
#       @found_series = []
#     end
#   end

#   def show_series
#     @series_name = params[:name]
#     @series_id = params[:series_id]
    
#     # Always pull strict volume entries by searching the validated text name
#     @volumes = GoogleBooksService.fetch_series_volumes_by_title(@series_name, @series_id)    
#   end
# end
# 
## app/controllers/search_controller.rb
class SearchController < ApplicationController
  def index
    if params[:query].present?
      @found_series_by_genre = RakutenBooksService.search_parent_series(params[:query])
    else
      @found_series_by_genre = {}
    end
  end

  def show_series
    @title = params[:title]
    @series_name = params[:series_name]
    @genre_id    = params[:genre_id]
    @author      = params[:author]
    @publisher   = params[:publisher]
  
    @volumes = RakutenBooksService.fetch_series_volumes(
      @title,
      @series_name,
      @genre_id,
      @author,
      @publisher,
    )

  end
end