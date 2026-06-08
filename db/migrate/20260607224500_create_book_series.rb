class CreateBookSeries < ActiveRecord::Migration[8.1]
  def change
    create_table :book_series do |t|
      t.string :title
      t.string :author
      t.string :publication
      t.integer :series_status
      t.integer :series_type
      t.integer :series_genre
      t.integer :tracking_status

      t.timestamps
    end
  end
end
