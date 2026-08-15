class BookSeries < ApplicationRecord
  has_many :books, dependent: :destroy
  enum :series_status, { ongoing: 1, completed: 2, unknown: 3 }, default: :ongoing
  enum :series_type, { book: 1, manga: 2, art_book: 3, magazine: 4, other: 5 }, prefix: true
  enum :genre, { shojo: 1, shonen: 2, bl: 3, light_novel: 4, bunko: 5, other: 6 }, prefix: true
  enum :tracking_status, { actively_hunting: 1, passive_watch: 2, on_standby: 3, someday: 4, complete: 5 }
  enum :wishlist_priority, { low: 1, medium: 2, high: 3 }

  scope :in_bookshelf, -> { where(in_wishlist: false) }
  scope :wishlist, -> { where(in_wishlist: true) }

  def volume_progress
    total = books.count
    owned = books.where(book_status: :owned).count
    "#{owned} / #{total}"
  end

  def self.determine_series_type(rakuten_genre_id)
    gid = rakuten_genre_id.to_s

    p gid

    if gid.start_with?("001001")
      :manga
    elsif gid.start_with?("001019")
      :art_book
    elsif gid.start_with?("001008")
      :magazine
    elsif gid.start_with?("001002", "001003", "001004", "001017", "00102")
      :book
    else
      :other
    end
  end

  def self.find_or_create_from_rakuten(params, in_wishlist:)
    series = find_or_initialize_by(
      title: params[:title], 
      author: params[:author]
    )

    detected_type = determine_series_type(params[:rakuten_genre_id])

    series.assign_attributes(
      publication: params[:publisher].presence || params[:publication],
      cover_image_url: params[:cover_image_url] || params[:image_url],
      rakuten_genre_id: params[:rakuten_genre_id],
      series_type: detected_type,
      in_wishlist: in_wishlist

    )

    # Set default wishlist priority if adding to wishlist for the first time
    series.wishlist_priority ||= :medium if in_wishlist
    series.in_wishlist = in_wishlist

    series.save
    series
  end
end
