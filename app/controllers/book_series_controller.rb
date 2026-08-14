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
    if params[:id].present? && params[:id] != "0"
      @series = BookSeries.find_by(id: params[:id])
    end

    @series ||= BookSeries.find_or_create_by!(title: params[:title]) do |s|
      s.author = params[:author]
      s.publication = params[:publisher]
      s.rakuten_genre_id = params[:rakuten_genre_id]
    end

    added_count = 0

    # Process only the posted selected_volumes array
    if params[:selected_volumes].is_a?(Array)
      params[:selected_volumes].each do |vol_params|
        next if vol_params[:title].blank? && vol_params[:isbn].blank?

        # Uniquely match existing books by ISBN (preferable) or title
        book = if vol_params[:isbn].present?
               @series.books.find_or_initialize_by(isbn: vol_params[:isbn])
             elsif vol_params[:title].present?
               @series.books.find_or_initialize_by(volume_title: vol_params[:title])
             elsif vol_num.present?
               @series.books.find_or_initialize_by(volume_num: vol_num)
             else
               @series.books.build
             end

        vol_num = vol_params[:volume_number].presence
        # Set to nil if allowed by model validation, or fallback to 0
        book.volume_num   = vol_num ? vol_num.to_i : nil
        book.volume_title = vol_params[:title]
        book.subtitle     = vol_params[:subtitle] if vol_params[:subtitle].present?
        book.image_url    = vol_params[:image_url]
        book.release_date = vol_params[:release_date]
        book.book_status  = params[:book_status] || :owned

        if book.save
          added_count += 1
        end
      end
    end

    respond_to do |format|
      format.html { 
        redirect_to search_series_path(
        series_id: @series.id,  
        title:            @series.title,
          author:           params[:author] || @series.author,
          publisher:        params[:publisher] || @series.publication,
          rakuten_genre_id: params[:rakuten_genre_id] || @series.rakuten_genre_id,
          query:            params[:query]
        ), 
        notice: "Added #{added_count} volume(s) to Bookshelf!", 
        status: :see_other 
      }
      format.json { render json: { status: "success", count: added_count } }
    end
  end

  def set_book_series
    @book_series = BookSeries.find(params[:id])
  end

  def update_metadata
    series = BookSeries.find(params[:id])
    if series.update(book_series_params)
      redirect_back fallback_location: root_path, notice: "Series updated!", status: :see_other
    else
      redirect_back fallback_location: root_path, alert: "Failed to update series."
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