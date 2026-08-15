class BookshelvesController < ApplicationController
  def manga
    @type = :manga
    @series_list = BookSeries.in_bookshelf.where(series_type: :manga).includes(:books)
    render :show_bookshelf
  end

  def books
    @type = :book
    @series_list = BookSeries.in_bookshelf.where(series_type: [:book, :light_novel]).includes(:books)
    render :show_bookshelf
  end

  def other
    @type = :other
    @series_list = BookSeries.in_bookshelf.where(series_type: [:art_book, :magazine, :other]).includes(:books)
    render :show_bookshelf
  end

  private
  def format_series_payload(scope)
    scope.as_json(
      include: :books,
      methods: [:series_status] # Explicitly call the ActiveRecord enum/getter method
    ).to_json
  end
end
