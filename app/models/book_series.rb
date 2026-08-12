class BookSeries < ApplicationRecord
  has_many :books, dependent: :destroy
  enum :series_status, { ongoing: 1, completed: 2, unknown: 3 }
  enum :series_type, { book: 1, manga: 2, art_book: 3, magazine: 4, other: 5 }
  enum :genre, { shojo: 1, shonen: 2, bl: 3, light_novel: 4, bunko: 5, other: 6 }
  enum :tracking_status, { actively_hunting: 1, passive_watch: 2, on_standby: 3, someday: 4, complete: 5 }
  enum :wishlist_priority, { low: 1, medium: 2, high: 3 }

  scope :in_bookshelf, -> { where(in_wishlist: false) }
  scope :wishlist, -> { where(in_wishlist: true) }

  def volume_progress
    total = books.count
    owned = books.where(book_status: :owned).count
    "#{owned} / #{total}"
  end
end
