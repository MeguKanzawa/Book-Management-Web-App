Rails.application.routes.draw do
  root "search#index"

  # Search & Series Route
  get "/", to: 'search#index', as: 'search'
  get "search/series", to: 'search#show_series', as: 'search_series'
  
  # Bookshelf Category Routes
  get "bookshelf/manga", to: "bookshelves#manga", as: :manga_bookshelf
  get "bookshelf/books", to: "bookshelves#books", as: :books_bookshelf
  get "bookshelf/other", to: "bookshelves#other", as: :other_bookshelf

  # Wishlist Route
  get "wishlist", to: "wishlists#index", as: :wishlist

  # Action Routes (Adding to Bookshelf / Wishlist)
  resources :book_series, only: [:create, :update, :destroy] do
    post :add_volumes, on: :member
    patch :update_metadata, on: :member
  end

  post "add_series_to_bookshelf", to: "book_series#create_from_search"
  post "add_series_to_wishlist", to: "wishlists#create_from_search"

end
