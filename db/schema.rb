# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_14_224532) do
  create_table "book_series", force: :cascade do |t|
    t.string "author"
    t.string "cover_image_url"
    t.datetime "created_at", null: false
    t.integer "genre"
    t.boolean "in_wishlist", default: false, null: false
    t.string "publication"
    t.string "rakuten_genre_id"
    t.integer "series_genre"
    t.integer "series_status"
    t.integer "series_type"
    t.string "title"
    t.integer "tracking_status"
    t.datetime "updated_at", null: false
    t.integer "wishlist_priority", default: 1
  end

  create_table "books", force: :cascade do |t|
    t.integer "book_series_id", null: false
    t.integer "book_status"
    t.decimal "cost"
    t.datetime "created_at", null: false
    t.string "image_url"
    t.string "isbn"
    t.string "release_date"
    t.string "subtitle"
    t.datetime "updated_at", null: false
    t.integer "volume_num"
    t.string "volume_title"
    t.index ["book_series_id"], name: "index_books_on_book_series_id"
  end

  add_foreign_key "books", "book_series"
end
