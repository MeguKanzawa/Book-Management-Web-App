class BookSeries < ApplicationRecord
  has_many :books, dependent: :destroy
  enum :series_status, {ongoing: 1, completed: 2, unknown: 3}
  enum :series_type, { book: 1, manga: 2, art_book: 3, magazine: 4, other: 5}
  enum :genre, { shojo: 1, shonen: 2, bl: 3, other: 4}
  enum :tracking_status, {actively_hunting: 1, passive_watch: 2, on_standby: 3, someday: 4, complete: 5}
end
