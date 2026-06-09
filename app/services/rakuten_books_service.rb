# app/services/rakuten_books_service.rb
require 'net/http'
require 'json'

class RakutenBooksService
  # ⚡ CRITICAL: Using the active 2026 API gateway endpoint
  BASE_URL = "https://openapi.rakuten.co.jp/services/api/BooksBook/Search/20170404"

  def self.search_parent_series(query)
    return [] if query.blank?

    app_id = ENV['RAKUTEN_APP_ID']
    access_key = ENV['RAKUTEN_ACCESS_KEY']
    
    if app_id.blank? || access_key.blank?
      Rails.logger.error "🛑 Rakuten API Error: Credentials missing from .env! Did you restart your server?"
      return []
    end

    series_map = {}

    params = {
      format: "json",          
      applicationId: app_id,
      accessKey: access_key,   
      title: query,
      booksGenreId: "001",     
      hits: 30,
      formatVersion: 2
    }

    query_string = params.map { |k, v| "#{k}=#{ERB::Util.url_encode(v.to_s)}" }.join("&")
    uri = URI("#{BASE_URL}?#{query_string}")

    response_body = make_api_request(uri)
    return [] if response_body.blank?

    begin
      data = JSON.parse(response_body)
      return [] if data["Items"].blank?

      data["Items"].each do |item|
        raw_title = item["title"] || "Untitled"
        
        # ⚡ FIX 1: Enhanced regex to match naked volume numbers and trailing Japanese set qualifiers
        series_name = raw_title.gsub(/(?:[\s(（・:：]*(?:Vol\.|巻|第|#)?\s*\d+.*$)|[\s(（・:：]*(?:全巻)?セット.*$/i, '').strip
        series_name = raw_title if series_name.blank?

        author = item["author"] || "Unknown Author"
        publisher = item["publisherName"] || "Unknown Publisher"
        
        # ⚡ FIX 2: Strip both half-width spaces and Japanese full-width spaces ( ) from author/publisher
        normalized_author = author.downcase.gsub(/[\s ]/, '')
        normalized_publisher = publisher.downcase.gsub(/[\s ]/, '')
        normalized_series = normalize_text(series_name)
        
        # Build the final tight grouping fingerprint
        group_key = "#{normalized_author}_#{normalized_publisher}_#{normalized_series}"
        
        image_url = item["largeImageUrl"] || item["mediumImageUrl"]
        image_url = nil if image_url&.include?("nowprinting")

        if series_map[group_key]
          # If the current saved title contains an unwanted artifact but the new incoming item is clean, favor the cleaner series name
          if series_map[group_key][:series_name].include?("巻") || series_map[group_key][:series_name].match?(/\d+$/)
            series_map[group_key][:series_name] = series_name
          end
          
          if series_map[group_key][:image_url].blank? && image_url.present?
            series_map[group_key][:image_url] = image_url
          end
        else
          series_map[group_key] = {
            series_id: group_key,
            series_name: series_name,
            author: author,
            publication: publisher,
            image_url: image_url
          }.with_indifferent_access
        end
      end
    rescue StandardError => e
      Rails.logger.error "🛑 RakutenBooksService Parsing Exception: #{e.message}"
      return []
    end

    series_map.values
  end
  
  # Update this method inside app/services/rakuten_books_service.rb
  def self.fetch_series_volumes(series_name, author = nil, publisher = nil)
    return [] if series_name.blank?

    app_id = ENV['RAKUTEN_APP_ID']
    access_key = ENV['RAKUTEN_ACCESS_KEY']
    return [] if app_id.blank? || access_key.blank?

    all_volumes = []
    page = 1
    max_pages = 6
    target_base = normalize_text(series_name)

    loop do
      break if page > max_pages

      params = {
        format: "json",
        applicationId: app_id,
        accessKey: access_key,
        title: series_name,
        booksGenreId: "001",
        sort: "+releaseDate",     
        hits: 30,                
        page: page,
        formatVersion: 2         
      }

      params[:author] = author if author.present?
      # ⚡ NEW: Scope the query to the chosen publisher variant to prevent mismatched formats
      params[:publisherName] = publisher if publisher.present?

      query_string = params.map { |k, v| "#{k}=#{ERB::Util.url_encode(v.to_s)}" }.join("&")
      uri = URI("#{BASE_URL}?#{query_string}")

      response_body = make_api_request(uri)
      break if response_body.blank?

      begin
        data = JSON.parse(response_body)
        break if data["error"] || data["Items"].blank?

        items = data["Items"]
        break if items.empty?

        items.each do |item|
          title = item["title"] || ""
          
          next if title.include?("セット") || title.include?("公式ファンブック") || title.include?("BOX")
          next unless normalize_text(title).start_with?(target_base)

          has_serial_marker = title.match?(/(?:Vol\.|巻|第|#)\s*\d+/i)
          vol_num = extract_volume_number(title)

          if vol_num.nil?
            vol_num = 0
          elsif !has_serial_marker && vol_num > 150
            vol_num = 0
          end

          next if vol_num < 0 || vol_num > 500

          image_url = item["largeImageUrl"] || item["mediumImageUrl"]
          image_url = nil if image_url&.include?("nowprinting")

          all_volumes << {
            id: "rakuten-#{item['isbn'] || SecureRandom.hex(4)}",
            title: title,
            volume_number: vol_num,
            image_url: image_url,
            release_date: item["releaseDate"]
          }.with_indifferent_access
        end

        total_pages = data["pageCount"] ? data["pageCount"].to_i : 1
        break if page >= total_pages

        page += 1
        sleep 0.25 
      rescue StandardError => e
        Rails.logger.warn "⚠️ RakutenBooksService parsing obstacle at page #{page}: #{e.message}"
        break
      end
    end

    return [] if all_volumes.empty?

    if all_volumes.any? { |v| v[:volume_number] == 0 }
      explicit_vols = all_volumes.select { |v| v[:volume_number] > 0 }
      standalone_vols = all_volumes.select { |v| v[:volume_number] == 0 }.sort_by { |v| v[:release_date] || "9999-12-31" }
      
      if explicit_vols.empty?
        standalone_vols.each_with_index { |v, i| v[:volume_number] = i + 1 }
        all_volumes = standalone_vols
      else
        max_explicit = explicit_vols.map { |v| v[:volume_number] }.max || 0
        standalone_vols.each_with_index { |v, i| v[:volume_number] = max_explicit + i + 1 }
        all_volumes = explicit_vols + standalone_vols
      end
    end

    existing_volumes = all_volumes.group_by { |v| v[:volume_number] }.transform_values do |editions|
      editions.sort_by { |e| e[:image_url].present? ? 0 : 1 }.first
    end

    return [] if existing_volumes.empty?
    max_discovered_volume = existing_volumes.keys.max

    (1..max_discovered_volume).map do |vol_num|
      existing_volumes[vol_num] || {
        id: "placeholder-#{series_name.parameterize rescue 'vol'}-#{vol_num}",
        title: "#{series_name} Vol. #{vol_num}",
        volume_number: vol_num,
        image_url: nil,
        release_date: nil
      }.with_indifferent_access
    end
  end

  private

  def self.make_api_request(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri)
    
    request['Referer']    = 'https://my-bookshelf-app.com/'
    request['Referrer']   = 'https://my-bookshelf-app.com/'
    request['Origin']     = 'https://my-bookshelf-app.com'
    request['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'

    response = http.request(request)
    
    if response.is_a?(Net::HTTPSuccess)
      response.body
    else
      Rails.logger.error "🛑 Rakuten API Gateway Error: Status #{response.code} - Body: #{response.body}"
      nil
    end
  end

  def self.normalize_text(text)
    text.to_s.downcase.gsub(/[\s :：巻話Vol\d・【】（）()\-ー\/+\#\!！ ]/i, '')
  end

  def self.extract_volume_number(title)
    if (match = title.match(/(?:Vol\.|巻|第|#)\s*(\d+)/i))
      return match[1].to_i
    end

    numbers = title.scan(/\d+/)
    clean_numbers = numbers.reject { |n| n.to_i >= 1950 && n.to_i <= 2030 }
    
    return clean_numbers.last.to_i if clean_numbers.any?
    numbers.last ? numbers.last.to_i : nil
  end
end