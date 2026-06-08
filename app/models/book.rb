class Book < ApplicationRecord
  belongs_to :book_series

  enum :status, {owned: 1, wishlist: 2, ignored: 3}
  validates :volume_num, presence: true

end
