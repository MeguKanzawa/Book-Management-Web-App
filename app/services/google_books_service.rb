# app/services/google_books_service.rb
require 'net/http'
require 'json'
require 'set'

class GoogleBooksService
  BASE_URL = "https://www.googleapis.com/books/v1/volumes"

  # Step 1: Broad search to find parent series options grouped simply by primary author + clean title
  def self.search(query, lang = 'ja')
    return [] if query.blank?
    api_key = ENV['API_KEY']
    
    encoded_query = ERB::Util.url_encode(query)
    url_string = "#{BASE_URL}?q=#{encoded_query}&langRestrict=#{lang}&maxResults=40"
    url_string += "&key=#{api_key}" if api_key.present?
    
    uri = URI(url_string)
    response = Net::HTTP.get(uri)
    data = JSON.parse(response)

    return [] unless data["items"]

    series_map = {}

    data["items"].each do |item|
      info = item["volumeInfo"] || {}
      
      publisher = info['publisher']
      next if publisher.blank? || publisher.downcase.include?("unknown")

      raw_title = info['title'] || 'Untitled'
      
      # Extract base series title characters by dropping ending digits and brackets
      series_name = raw_title.gsub(/[:：巻話Vol\d・]+.*$/, '').strip
      series_name = raw_title if series_name.blank?

      authors = info['authors'] || []
      primary_author = authors.first.present? ? authors.first.strip : 'Unknown Author'
      
      group_key = "#{primary_author.downcase.gsub(/[\s ]/, '')}_#{series_name.downcase.gsub(/[\s ]/, '')}"

      image_links = info['imageLinks'] || {}
      raw_thumbnail = image_links['thumbnail'] || image_links['smallThumbnail']
      image = raw_thumbnail.present? ? raw_thumbnail.gsub("http://", "https://") : nil

      if series_map[group_key]
        if series_map[group_key][:image_url].blank? && image.present?
          series_map[group_key][:image_url] = image
        end
      else
        series_map[group_key] = {
          series_id: group_key,
          series_name: series_name,
          author: primary_author, 
          publication: publisher,
          image_url: image
        }.with_indifferent_access
      end
    end

    series_map.values
  rescue StandardError => e
    Rails.logger.error "GoogleBooksService Search Error: #{e.message}"
    []
  end

  # Step 2: Fetch volumes up to 200+ linked STRICTLY to the exact Title and Author
  def self.fetch_series_volumes_by_title(series_name, author = nil, lang = 'ja')
    return [] if series_name.blank?
    api_key = ENV['API_KEY']
    
    all_volumes = []
    seen_ids = Set.new 
    start_index = 0
    max_results = 40

    target_base_title = series_name.downcase.gsub(/[\s :：巻話Vol\d・【】（）()\-ー\/+\#]/i, '')

    35.times do
      encoded_query = ERB::Util.url_encode(series_name)
      url_string = "#{BASE_URL}?q=#{encoded_query}&langRestrict=#{lang}&startIndex=#{start_index}&maxResults=#{max_results}"
      url_string += "&key=#{api_key}" if api_key.present?
      
      uri = URI(url_string)
      response = Net::HTTP.get(uri)
      data = JSON.parse(response)
      
      items = data["items"]
      break if items.blank? || items.empty?

      items.each do |item|
        next if seen_ids.include?(item['id'])
        seen_ids.add(item['id'])

        info = item["volumeInfo"] || {}
        title = info['title'] || 'Untitled'

        item_base_title = title.downcase.gsub(/[\s :：巻話Vol\d・【】（）()\-ー\/+\#]/i, '')
        next unless item_base_title == target_base_title

        item_authors = info['authors'] || []
        if author.present? && item_authors.present?
          clean_target_author = author.downcase.gsub(/[\s ]/, '')
          author_matched = item_authors.any? do |a|
            clean_item_auth = a.downcase.gsub(/[\s ]/, '')
            clean_item_auth.include?(clean_target_author) || clean_target_author.include?(clean_item_auth)
          end
          next unless author_matched
        end

        display_num = info.dig('seriesInfo', 'bookDisplayNumber')
        order_num = info.dig('seriesInfo', 'volumeSeries', 0, 'orderNumber')
        
        extracted_num = nil
        if display_num.present?
          extracted_num = display_num
        elsif order_num.present?
          extracted_num = order_num
        else
          if title slice_match = title.match(/(?:Vol\.|巻|第|#)\s*(\d+)/i)
            extracted_num = slice_match[1]
          else
            numbers = title.scan(/\d+/)
            clean_numbers = numbers.reject { |n| n.to_i >= 1950 && n.to_i <= 2030 }
            extracted_num = clean_numbers.last || numbers.last
          end
        end
        
        next if extracted_num.blank? || extracted_num.to_i == 0

        vol_integer = extracted_num.to_i
        next if vol_integer <= 0 || vol_integer > 500

        image_links = info['imageLinks'] || {}
        raw_thumbnail = image_links['thumbnail'] || image_links['smallThumbnail']
        image = raw_thumbnail.present? ? raw_thumbnail.gsub("http://", "https://") : nil

        all_volumes << {
          id: item['id'],
          title: title,
          volume_number: vol_integer,
          image_url: image
        }.with_indifferent_access
      end

      start_index += max_results
    end

    existing_volumes = all_volumes.group_by { |v| v[:volume_number] }.transform_values do |editions|
      editions.sort_by { |e| e[:image_url].present? ? 0 : 1 }.first
    end

    max_discovered_volume = existing_volumes.keys.max || 12

    (1..max_discovered_volume).map do |vol_num|
      existing_volumes[vol_num] || {
        id: "placeholder-#{series_name.parameterize rescue 'vol'}-#{vol_num}",
        title: "#{series_name} Vol. #{vol_num}",
        volume_number: vol_num,
        image_url: nil
      }.with_indifferent_access
    end
  rescue StandardError => e
    Rails.logger.error "GoogleBooksService Fetch Volumes Error: #{e.message}"
    []
  end
end