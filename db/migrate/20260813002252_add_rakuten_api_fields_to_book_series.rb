class AddRakutenApiFieldsToBookSeries < ActiveRecord::Migration[8.1]
  def change
    add_column :book_series, :rakuten_genre_id, :string unless column_exists?(:book_series, :rakuten_genre_id)
  end
end
