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
    respond_to do |format|
      if @book_series.update(book_series_params)
        format.html { redirect_to @book_series, notice: "Book series was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @book_series }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @book_series.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /book_series/1 or /book_series/1.json
  def destroy
    @book_series.destroy!

    respond_to do |format|
      format.html { redirect_to book_series_index_path, notice: "Book series was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  def create_from_search
    series = BookSeries.find_or_initialize_by(title: params[:title], author: params[:author])
    
    series.assign_attributes(
      publication: params[:publisher],
      cover_image_url: params[:cover_image_url],
      series_type: params[:series_type] || :manga,
      in_wishlist: false
    )

    if series.save
      redirect_back fallback_location: root_path, notice: "Added #{series.title} to Bookshelf!"
    else
      redirect_back fallback_location: root_path, alert: "Could not add series."
    end
  end

  def add_volumes
    series = BookSeries.find(params[:id])
    volumes_data = params[:selected_volumes] || []

    volumes_data.each do |vol|
      series.books.find_or_create_by(volume_num: vol[:volume_number]) do |b|
        b.volume_title = vol[:title]
        b.image_url = vol[:image_url]
        b.release_date = vol[:release_date]
        b.book_status = :owned
      end
    end

    respond_to do |format|
      format.html { redirect_to show_series_path(title: series.title), notice: "Added #{volumes_data.size} volumes to Bookshelf!" }
      format.json { render json: { status: "success", count: volumes_data.size } }
    end
  end

  def update_metadata
    series = BookSeries.find(params[:id])
    if series.update(series_params)
      redirect_back fallback_location: root_path, notice: "Series updated!"
    end
  end

  private

  def series_params
    params.require(:book_series).permit(:series_status, :genre, :tracking_status, :wishlist_priority)
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_book_series
      @book_series = BookSeries.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def book_series_params
      params.expect(book_series: [ :title, :author, :publication, :series_status, :series_type, :series_genre, :tracking_status ])
    end
end
