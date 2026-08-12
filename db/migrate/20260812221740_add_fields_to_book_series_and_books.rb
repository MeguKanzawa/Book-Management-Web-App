class AddFieldsToBookSeriesAndBooks < ActiveRecord::Migration[8.1]
  def change
    add_column :book_series, :in_wishlist, :boolean, default: false, null: false
    add_column :book_series, :wishlist_priority, :integer, default: 1 # 1: Low, 2: Medium, 3: High
    add_column :book_series, :cover_image_url, :string
    add_column :book_series, :genre, :integer # Maps to genre enum

    # Add release_date to books for volume metadata
    add_column :books, :release_date, :string
  end
end
