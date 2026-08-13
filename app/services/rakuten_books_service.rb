# app/services/rakuten_books_service.rb
require 'net/http'
require 'json'

class RakutenBooksService
  BASE_URL = "https://openapi.rakuten.co.jp/services/api/BooksBook/Search/20170404"

  # PHASE 1: Fetch items by title, group unique series by booksGenreId
  # app/services/rakuten_books_service.rb

def self.search_parent_series(query)
  return {} if query.blank?

  app_id = ENV['RAKUTEN_APP_ID']
  access_key = ENV['RAKUTEN_ACCESS_KEY']
  return {} if app_id.blank? || access_key.blank?

  params = {
    format: "json",  
    title: query,    
    applicationId: app_id,
    accessKey: access_key,   
    carrier: 0,
    referer: "https://my-bookshelf-app.com/",
    hits: 30,
    formatVersion: 2
  }

  query_string = params.map { |k, v| "#{k}=#{ERB::Util.url_encode(v.to_s)}" }.join("&")
  uri = URI("#{BASE_URL}?#{query_string}")

  p uri

  response_body = make_api_request(uri)

  p "came to here" 
  return {} if response_body.blank?

  series_map = {}

  begin
    p "got into begin loop"
    data = JSON.parse(response_body)

    return {} if data["Items"].blank?

    data["Items"].each do |raw_item|

      item = raw_item["Item"] || raw_item
      next if digital_item?(item)

      raw_title = item["title"] || "Untitled"
      rakuten_genre_id  = item["booksGenreId"] || "unknown"

      p rakuten_genre_id

      title = raw_title.gsub(/(?:[\s(（・:：]*(?:Vol\.|巻|第|#)?\s*\d+.*$)|[\s(（・:：]*(?:全巻)?セット.*$/i, '').strip
      series_name = item["seriesName"].presence || (title.present? ? title : raw_title)

      author    = item["author"] || "Unknown Author"
      publisher = item["publisherName"] || "Unknown Publisher"
      
      normalized_author    = author.downcase.gsub(/[\s ]/, '')
      normalized_publisher = publisher.downcase.gsub(/[\s ]/, '')
      # normalized_series    = normalize_text(series_name)
      
      # Grouping key ensures unique series per genre + author + publisher
      group_key = "#{normalized_author}_#{normalized_publisher}_#{rakuten_genre_id}_#{title}"
      
      image_url = item["largeImageUrl"] || item["mediumImageUrl"]
      image_url = nil if image_url&.include?("nowprinting")

      if series_map[group_key]
        # Populate image if missing
        if series_map[group_key][:image_url].blank? && image_url.present?
          series_map[group_key][:image_url] = image_url
        end
      else
        series_map[group_key] = {
          title: title,
          series_id: group_key,
          series_name: series_name,
          author: author,
          publisher: publisher,
          image_url: image_url,
          rakuten_genre_id: rakuten_genre_id 
        }.with_indifferent_access
      end
    end
  rescue StandardError => e
    Rails.logger.error "🛑 RakutenBooksService Parsing Exception: #{e.message}"
    return {}
  end

  return series_map
  
end

  # PHASE 2: Fetch up to 100 volumes scoped by rakuten_genre_id, author, publisher, and series_name
  def self.fetch_series_volumes(title, series_name, rakuten_genre_id, author, publisher)
    # return [] if series_name.blank?

    app_id = ENV['RAKUTEN_APP_ID']
    access_key = ENV['RAKUTEN_ACCESS_KEY']
    return [] if app_id.blank? || access_key.blank?

    all_volumes = []
    page = 1
    max_pages = 10 # 4 pages * 28 hits = up to 112 potential raw items
    target_base = normalize_text(series_name)

    loop do
      # p if page > max_pages || all_volumes.size >= 100
      # break if page > max_pages || all_volumes.size >= 100
      # 
      break if page > max_pages || all_volumes.size >= 100

      first_author = first_author(author)

      params = {
        format: "json",
        title: title,
        author: first_author,
        publisherName: publisher,
        booksGenreId: rakuten_genre_id,
        page: page,
        sort: "+releaseDate",     
        applicationId: app_id,
        accessKey: access_key,
        hits: 30,                
        referer: "https://my-bookshelf-app.com/",
        formatVersion: 2         
      }

      query_string = params.map { |k, v| "#{k}=#{ERB::Util.url_encode(v.to_s)}" }.join("&")
      uri = URI("#{BASE_URL}?#{query_string}")

      response_body = make_api_request(uri)
      
      begin
        data = JSON.parse(response_body)
        break if data["error"] || data["Items"].blank?

        items = data["Items"]
        break if items.empty?

        items.each do |item|
          vol_title = item["title"].to_s
          # p vol_title
          
          next if vol_title.match?(/セット|公式ファンブック|BOX|画集|ガイドブック/i)
          # p "passed string match test"
          
          normalized_volume = normalize_volume(vol_title, title)

          # normalized_vol = normalize_text(vol_title)
          # next unless normalized_vol.include?(target_base)
          # p "passed normalized volume string check"
          # 
          
          p title
          p vol_title
          p "/n"

          vol_num = extract_volume_number(vol_title, title) || 0
          next if vol_num < 0 || vol_num > 500
          # p "passed volume number check"

        
          image_url = item["largeImageUrl"] || item["mediumImageUrl"]
          image_url = nil if image_url&.include?("nowprinting")

          all_volumes << {
            id: "#{item['isbn'] || SecureRandom.hex(4)}",
            title: normalized_volume,
            volume_number: vol_num,
            image_url: image_url,
            release_date: item["releaseDate"]
          }.with_indifferent_access
        end

        total_pages = data["pageCount"].to_i
        break if total_pages > 0 && page >= total_pages

        page += 1
        sleep 0.25
      rescue StandardError => e
        Rails.logger.warn "⚠️ RakutenBooksService page parsing issue at page #{page}: #{e.message}"
        break
      end
    end

    # all_volumes.uniq { |v| v[:title] }.sort_by { |v| v[:volume_number] }
    

    p all_volumes.size
    p "finished fetch_volumes"
  

    return all_volumes
  end

  private

  def self.make_api_request(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')

    request = Net::HTTP::Get.new(uri.request_uri)

    # Mandatory headers for Rakuten OpenAPI Gateway
    request['Accept'] = 'application/json'
    request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
    request['Referer']    = 'https://my-bookshelf-app.com/'
    request['Referrer']   = 'https://my-bookshelf-app.com/'
    request['Origin']     = 'https://my-bookshelf-app.com'

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      response.body
    else
      puts "🛑 API Request Failed!"
      puts "   HTTP Status : #{response.code} #{response.message}"
      puts "   Response Body: #{response.body}"
      nil
    end
  rescue StandardError => e
    puts "🛑 Net::HTTP Exception: #{e.message}"
    nil
  end

  def self.normalize_text(text)
    text.to_s.downcase.gsub(/[\s:：巻話Vol\d・【】（）()\/\#\ ]/i, '')
  end

  def self.normalize_volume(text, series_title)
    vol_num = extract_volume_number(text, series_title)
    cleaned_text = normalize_text(text)

    vol_num ? "#{cleaned_text}#{vol_num}" : cleaned_text
  end

  def self.extract_volume_number(title, series_title)
    if (match = title.match(/(?:Vol\.|巻|第|#)\s*(\d+)/i))
      return match[1].to_i
    end

    if (match = title.match(/(?:\[|\(|［|（)(\d+)(?:\]|\)|］|）)/))
      return match[1].to_i
    end

    if (title == series_title)
      return 1
    end

    numbers = title.scan(/\d+/)
    clean_numbers = numbers.reject { |n| n.to_i >= 1950 && n.to_i <= 2030 }
    
    clean_numbers.last ? clean_numbers.last.to_i : nil
  end

  def self.digital_item?(item)
    rakuten_genre_id = item["booksGenreId"].to_s
    title    = item["title"].to_s
    isbn     = item["isbn"].to_s

    # 1. Filter out Rakuten's E-Book genre tree (001025...)
    return true if rakuten_genre_id.start_with?("001025")

    # 2. Filter out titles containing explicit digital tags
    return true if title.match?(/（電子版）|【電子限定】|【電子書籍】|電子限定特典付き/i)

    # 3. If an ISBN is present, ensure it is a valid physical ISBN (starts with 978 or 979)
    if isbn.present?
      return true unless isbn.start_with?("978", "979")
    end

    false

  end

  def self.first_author(author_str)
    return author_str.split('/').first
  end
end
