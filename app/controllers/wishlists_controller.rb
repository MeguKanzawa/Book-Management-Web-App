class WishlistsController < ApplicationController
  def index
    @wishlist_series = BookSeries.wishlist.order(wishlist_priority: :desc)
  end

  def create_from_search
    series = BookSeries.find_or_initialize_by(title: params[:title], author: params[:author])
    
    series.assign_attributes(
      publication: params[:publisher],
      cover_image_url: params[:cover_image_url],
      in_wishlist: true,
      wishlist_priority: :medium
    )

    if series.save
      redirect_back fallback_location: root_path, notice: "Added #{series.title} to Wishlist!"
    else
      redirect_back fallback_location: root_path, alert: "Could not add to wishlist."
    end
  end
end
