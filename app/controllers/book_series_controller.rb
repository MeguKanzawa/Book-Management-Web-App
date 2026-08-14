class BookSeriesController < ApplicationController
  before_action :set_book_series, only: %i[ show edit update destroy ]

  # GET /book_series or /book_series.json
  def index
    @book_series = BookSeries.all
  end

  # GET /book_series/1 or /book_series/1.json
  def show
  end

  # GET /book_series/new
  def new
    @book_series = BookSeries.new
  end

  # GET /book_series/1/edit
  def edit
  end

  # POST /book_series or /book_series.json
  def create
    @book_series = BookSeries.new(book_series_params)

    respond_to do |format|
      if @book_series.save
        format.html { redirect_to @book_series, notice: "Book series was successfully created." }
        format.json { render :show, status: :created, location: @book_series }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @book_series.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /book_series/1 or /book_series/1.json
  def update
    if @book_series.update(book_series_params)
      notice_msg = @book_series.in_wishlist? ? "Wishlist updated!" : "Moved to Bookshelf!"
      redirect_back fallback_location: root_path, notice: notice_msg
    else
      redirect_back fallback_location: root_path, alert: "Update failed."
    end
  end

  # DELETE /book_series/1 or /book_series/1.json
  def destroy
    title = @book_series.title
    @book_series.destroy!

    respond_to do |format|
      format.html { redirect_to book_series_index_path, notice: "Book series was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  def create_from_search
    @series = BookSeries.find_or_create_from_rakuten(params, in_wishlist: false)

    if @series.persisted?
      redirect_back fallback_location: root_path, notice: "Added #{@series.title} to Bookshelf!"
    else
      redirect_back fallback_location: root_path, alert: "Could not add to Bookshelf."
    end
  end

  def add_volumes
    series = BookSeries.find(params[:id])

    if params[:selected_volumes].present?
      params[:selected_volumes].each do |vol_params|
        series.books.find_or_create_by(
          volume_num: vol_params[:volume_num],
          volume_title: vol_params[:title],
          image_url: vol_params[:image_url],
        )
      end
    end

    volumes_data = params[:selected_volumes] || []
    target_status = params[:book_status].presence || :owned

    volumes_data.each do |vol|
      series.books.find_or_create_by(volume_num: vol[:volume_number]) do |b|
        b.volume_title = vol[:title]
        b.image_url = vol[:image_url]
        b.book_status = target_status
        b.isbn = vol[:isbn]
        book.save!
      end
    end

    

    respond_to do |format|
      format.html { redirect_to search_series_path(
                      title:            series.title,
                      author:           params[:author] || series.author,
                      publisher:        params[:publisher] || series.publication,
                      rakuten_genre_id: params[:rakuten_genre_id] || series.rakuten_genre_id,
                      query:            params[:query]
                    ), 
                    notice: "Added #{volumes_data.size} volumes to Bookshelf!", 
                    status: :see_other 
                  }
      format.json { render json: { status: "success", count: volumes_data.size } }
    end
  end

  def set_book_series
    @book_series = BookSeries.find(params[:id])
  end

  def update_metadata
    series = BookSeries.find(params[:id])
    if series.update(series_params)
      redirect_back fallback_location: root_path, notice: "Series updated!"
    end
  end

  def book_series_params
    params.require(:book_series).permit(
      :title, 
      :author, 
      :publication, 
      :series_status, 
      :series_type, 
      :genre, 
      :tracking_status, 
      :wishlist_priority, 
      :in_wishlist, 
      :cover_image_url, 
      :rakuten_genre_id
    )
  end

end
