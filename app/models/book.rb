class Book < ApplicationRecord
  belongs_to :book_series

  enum :book_status, { owned: 1, wishlist: 2, ignored: 3, sold: 4 }, default: :owned
  validates :volume_num, presence: true, allow_nil: true

end
