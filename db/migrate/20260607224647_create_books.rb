class CreateBooks < ActiveRecord::Migration[8.1]
  def change
    create_table :books do |t|
      t.references :book_series, null: false, foreign_key: true
      t.integer :volume_num
      t.string :volume_title
      t.string :isbn
      t.decimal :cost
      t.integer :book_status
      t.string :image_url

      t.timestamps
    end
  end
end
