json.extract! book_series, :id, :title, :author, :publication, :series_status, :series_type, :series_genre, :tracking_status, :created_at, :updated_at
json.url book_series_url(book_series, format: :json)
