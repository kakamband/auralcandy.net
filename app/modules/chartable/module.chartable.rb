module Chartable

  # Verify the existance of required environmental variables
  def verify_env

    # List of required environmental variables
    env_list = ["CHARTABLE_PODCAST_ID", "CHARTABLE_ACCESS_TOKEN"]

    # Verify environmental variables are set
    env_list.each { |env| abort("Environmental variable #{env} not set.") if ENV[env].nil? }

  end

  # Send GET request to Chartable API (returns 10 episodes per page)
  def get_chartable_api_page(page)

    begin

      response = Faraday.new.get do |request|

        # Build Chartable API URL
        chartable_api_url = "https://chartable.com/api/episodes"
        chartable_api_url += "?podcast_id=#{ENV["CHARTABLE_PODCAST_ID"]}"
        chartable_api_url += "&team_id=#{ENV["CHARTABLE_PODCAST_ID"]}"
        chartable_api_url += "&page=#{page.to_s}"

        # Set request target URL
        request.url(chartable_api_url)

        # Set access token as Cookie header
        request.headers = {"Cookie" => "remember_token=#{ENV["CHARTABLE_ACCESS_TOKEN"]};"}

        # Set request timeout
        request.options.timeout = 10

      end

      # Parse JSON response to hash
      return JSON.parse(response.body)

    rescue StandardError => error
      abort(error.message)
    end

  end

  # Fetch downloads from Chartable API
  def get_chartable_data

    downloads = Hash.new
    total     = $management.entries.all(:content_type => "episode").total.to_i
    pages     = (total/10)+1

    # Fetch data in multiple passes
    (1..pages).each do |page|

      data = get_chartable_api_page(page)

      # Populate hash with episode titles and downloads counts
      data.each do |episode|
        downloads[episode["title"].split(" - ")[1]] = episode["total_downloads"]
      end

    end

    return downloads

  end

  # Update Contentful entries via Management API
  def update_episode_downloads

    # Get episode downloads from Chartable API
    chartable_data = get_chartable_data

    # Query options
    options = {
      :content_type => "episode",
      :limit        => 999,
      :order        => "-fields.releaseDate"
    }

    # Query and update episode entries
    $management.entries.all(options).each do |episode|

      # Update download count to episode entry if found in Chartable data
      if episode.published? && chartable_data.key?(episode.fields[:title])
        episode.update(downloads: chartable_data[episode.fields[:title]])
        episode.publish

      # Set download count to zero if not found in Chartable
      elsif episode.published? && !chartable_data.key?(episode.fields[:title])
        episode.update(downloads: 0)
        episode.publish
      end

    end

  end

end