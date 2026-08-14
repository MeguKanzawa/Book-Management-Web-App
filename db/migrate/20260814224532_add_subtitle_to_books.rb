class AddSubtitleToBooks < ActiveRecord::Migration[8.1]
  def change
    add_column :books, :subtitle, :string
  end
end
