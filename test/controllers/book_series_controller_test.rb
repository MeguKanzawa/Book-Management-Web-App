require "test_helper"

class BookSeriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @book_series = book_series(:one)
  end

  test "should get index" do
    get book_series_index_url
    assert_response :success
  end

  test "should get new" do
    get new_book_series_url
    assert_response :success
  end

  test "should create book_series" do
    assert_difference("BookSeries.count") do
      post book_series_index_url, params: { book_series: { author: @book_series.author, publication: @book_series.publication, series_genre: @book_series.series_genre, series_status: @book_series.series_status, series_type: @book_series.series_type, title: @book_series.title, tracking_status: @book_series.tracking_status } }
    end

    assert_redirected_to book_series_url(BookSeries.last)
  end

  test "should show book_series" do
    get book_series_url(@book_series)
    assert_response :success
  end

  test "should get edit" do
    get edit_book_series_url(@book_series)
    assert_response :success
  end

  test "should update book_series" do
    patch book_series_url(@book_series), params: { book_series: { author: @book_series.author, publication: @book_series.publication, series_genre: @book_series.series_genre, series_status: @book_series.series_status, series_type: @book_series.series_type, title: @book_series.title, tracking_status: @book_series.tracking_status } }
    assert_redirected_to book_series_url(@book_series)
  end

  test "should destroy book_series" do
    assert_difference("BookSeries.count", -1) do
      delete book_series_url(@book_series)
    end

    assert_redirected_to book_series_index_url
  end
end
