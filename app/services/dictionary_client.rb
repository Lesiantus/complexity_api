require "net/http"
require "json"

class DictionaryClient
  BASE_URL = "https://api.dictionaryapi.dev/api/v2/entries/en"

  # Fetch definitions, synonyms, and antonyms for a given word.
  # Returns a hash with counts or a rate-limited indicator if the API responds with 429.
  def self.fetch_definitions(word)
    return nil unless word.is_a?(String) && word.strip.present?

    url = URI("#{BASE_URL}/#{URI.encode_www_form_component(word)}")
    response = Net::HTTP.get_response(url)

    case response
    when Net::HTTPSuccess
      json = JSON.parse(response.body)
      parse_response(json)
    when Net::HTTPNotFound
      Rails.logger.warn("DictionaryClient: #{word} not found (404)")
      nil
    when Net::HTTPTooManyRequests
      retry_after = response["Retry-After"]&.to_i || 5
      {
        rate_limited: true,
        retry_after:
      }
    else
      raise "HTTP #{response.code}"
    end
  rescue JSON::ParserError => e
    Rails.logger.error("DictionaryClient JSON parse error (#{word}): #{e.message}")
    nil
  end

  # Parse the JSON response from the dictionary API.
  # Returns a hash with counts of definitions, synonyms, and antonyms.
  def self.parse_response(data)
    return nil unless data.is_a?(Array) && data.first.is_a?(Hash)

    definitions = 0
    synonyms = []
    antonyms = []

    data.each do |entry|
      meanings = entry["meanings"] || []
      meanings.each do |meaning|
        defs = meaning["definitions"] || []
        definitions += defs.size

        synonyms.concat(meaning["synonyms"] || [])
        antonyms.concat(meaning["antonyms"] || [])

        defs.each do |def_item|
          synonyms.concat(def_item["synonyms"] || [])
          antonyms.concat(def_item["antonyms"] || [])
        end
      end
    end

    {
      definitions_count: definitions,
      synonyms_count: synonyms.uniq.size,
      antonyms_count: antonyms.uniq.size
    }
  end
end
