class WishlistsController < ApplicationController
  def index
    @wishlist_series = BookSeries.wishlist.order(wishlist_priority: :desc)
  end

  def create_from_search
    @series = BookSeries.find_or_create_from_rakuten(params, in_wishlist: true)

    if @series.persisted?
      redirect_back fallback_location: root_path, notice: "Added #{@series.title} to Wishlist!"
    else
      redirect_back fallback_location: root_path, alert: "Could not add to Wishlist: #{@series.errors.full_messages.join(', ')}"
    end
  end
end
