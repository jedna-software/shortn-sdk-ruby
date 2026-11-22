# frozen_string_literal: true

module Shortn
  module SDK
    # Base class for every error the SDK raises.
    class Error < StandardError; end

    # The client is missing something it needs, such as an API key.
    class ConfigurationError < Error; end

    # The request failed before an HTTP response arrived (DNS, connection,
    # TLS, timeout). The original exception is available as #cause.
    class NetworkError < Error; end

    # The API answered with a non-2xx status.
    #
    # Shortn errors look like:
    #   {"code": "...", "error": "...", "hint": "...", "details": {"field": "..."}}
    # Plan-limit errors add top-level fields such as "feature" and
    # "required_plan"; read them from #data. #code is nil only for an answer
    # that didn't come from the API, such as a proxy's 502 page.
    class APIError < Error
      # @return [Integer] HTTP status code
      attr_reader :status
      # @return [String, nil] stable machine-readable code, when the API sends one
      attr_reader :code
      # @return [String, nil] the hint the API sends with some errors
      attr_reader :hint
      # @return [String, nil] the request field at fault (details.field)
      attr_reader :field
      # @return [Hash, nil] the details object
      attr_reader :details
      # @return [String, nil] request id sent by the conversion intake endpoints
      attr_reader :request_id
      # @return [Hash, Array, nil] the parsed JSON body, when the body is JSON
      attr_reader :data
      # @return [String] the raw response body
      attr_reader :body
      # @return [Hash{String => String}] response headers, lower-case names
      attr_reader :headers

      def initialize(message, status:, body: "", data: nil, headers: {})
        super(message)
        @status = status
        @body = body.to_s
        @data = data
        @headers = headers || {}
        envelope = data.is_a?(Hash) ? data : {}
        @code = string_or_nil(envelope["code"])
        @hint = string_or_nil(envelope["hint"])
        @details = envelope["details"].is_a?(Hash) ? envelope["details"] : nil
        @field = string_or_nil(@details && @details["field"]) || string_or_nil(envelope["field"])
        @request_id = string_or_nil(envelope["request_id"]) || string_or_nil(@headers["shortn-request-id"])
      end

      # Seconds from the Retry-After header, when present.
      def retry_after
        Shortn::SDK.parse_retry_after(@headers["retry-after"])
      end

      private

      def string_or_nil(value)
        return nil if value.nil?

        text = value.to_s
        text.empty? ? nil : text
      end
    end

    # Parses a Retry-After header value (delta seconds or an HTTP date) into
    # seconds. Returns nil when the value is missing or unreadable.
    def self.parse_retry_after(value)
      text = value.to_s.strip
      return nil if text.empty?
      return [Float(text), 0.0].max if text.match?(/\A\d+(\.\d+)?\z/)

      require "time"
      [Time.httpdate(text) - Time.now, 0.0].max
    rescue ArgumentError
      nil
    end
  end
end
