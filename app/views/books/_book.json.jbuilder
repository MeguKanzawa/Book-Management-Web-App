json.extract! book, :id, :book_series_id, :volume_num, :volume_title, :isbn, :cost, :book_status, :image_url, :created_at, :updated_at
json.url book_url(book, format: :json)
