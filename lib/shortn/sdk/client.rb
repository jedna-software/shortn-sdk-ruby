# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "time"
require "uri"

require_relative "errors"
require_relative "retry_options"
require_relative "version"
require_relative "transport"
require_relative "resources/base"
require_relative "resources/links"
require_relative "resources/analytics"
require_relative "resources/workspaces"
require_relative "resources/tags"
require_relative "resources/utm_templates"
require_relative "resources/destinations"
require_relative "resources/teams"
require_relative "resources/domains"
require_relative "resources/reports"
require_relative "resources/conversions"
require_relative "resources/public"

module Shortn
  module SDK
    # Client for the Shortn Link public API (`<base_url>/api/v1`).
    #
    #   shortn = Shortn::SDK::Client.new(api_key: ENV.fetch("SHORTN_API_KEY"))
    #   shortn.links.list(limit: 10)
    #
    # Every method returns the decoded JSON response as plain Hashes and Arrays
    # with string keys, so fields the API adds later are always reachable.
    class Client
      DEFAULT_BASE_URL = "https://app.shortn.link"
      DEFAULT_TIMEOUT = 30
      API_PREFIX = "/api/v1"

      # Failures before a response that are worth retrying. Anything else a
      # transport raises (ArgumentError, NoMethodError, ...) propagates as is.
      TRANSIENT_NETWORK_ERRORS = [
        Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout,
        Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::EPIPE, Errno::ETIMEDOUT, Errno::EHOSTUNREACH,
        EOFError, IOError, SocketError, OpenSSL::SSL::SSLError
      ].freeze

      # Top-level body keys whose numeric value is sent as a decimal String.
      AMOUNT_KEYS = %w[amount].freeze

      attr_reader :base_url, :timeout, :retry_options, :user_agent,
                  :links, :analytics, :workspaces, :tags, :utm_templates, :destinations,
                  :teams, :domains, :reports, :conversions, :public

      # @param api_key [String, nil] secret API key (`sk_live_...`). Only the
      #   public helpers (`client.public`) work without one.
      # @param base_url [String] app origin; `/api/v1` is appended. Must be
      #   an http or https URL with a host (ConfigurationError otherwise).
      # @param timeout [Numeric] open/read/write timeout in seconds.
      # @param retry_options [RetryOptions, Hash, false] retry policy;
      #   `false` turns retries off.
      # @param user_agent [String, nil] appended to `shortn-sdk-ruby/<version>`.
      # @param transport [#call, nil] HTTP transport, called as
      #   `call(method, url, headers, body, timeout)` and returning
      #   `[status, headers, body]`. Defaults to Net::HTTP.
      # @param sleeper [#call, nil] called with the seconds to wait between
      #   retries. Defaults to Kernel#sleep.
      def initialize(api_key: nil, base_url: DEFAULT_BASE_URL, timeout: DEFAULT_TIMEOUT, retry_options: nil,
                     user_agent: nil, transport: nil, sleeper: nil)
        @api_key = api_key.to_s.strip
        @api_key = nil if @api_key.empty?
        @base_url = normalize_base_url(base_url)
        @timeout = timeout
        @retry_options = build_retry_options(retry_options)
        @user_agent = ["shortn-sdk-ruby/#{VERSION}", user_agent].compact.map(&:to_s).reject(&:empty?).join(" ")
        @transport = transport || NetHTTPTransport.new
        @sleeper = sleeper || ->(seconds) { sleep(seconds) }

        @links = LinksResource.new(self)
        @analytics = AnalyticsResource.new(self)
        @workspaces = WorkspacesResource.new(self)
        @tags = TagsResource.new(self)
        @utm_templates = UTMTemplatesResource.new(self)
        @destinations = DestinationsResource.new(self)
        @teams = TeamsResource.new(self)
        @domains = DomainsResource.new(self)
        @reports = ReportsResource.new(self)
        @conversions = ConversionsResource.new(self)
        @public = PublicResource.new(self)
      end

      def inspect
        "#<#{self.class.name} base_url=#{@base_url.inspect} api_key=#{@api_key ? '[set]' : 'nil'}>"
      end

      # Sends a request and returns the decoded JSON body (`{}` for an empty
      # body). Resource methods call this; use it directly for endpoints the
      # SDK does not wrap yet.
      #
      # @param method [String] HTTP method
      # @param path [String] path below `/api/v1`, already escaped
      # @param query [Hash, nil] query parameters; nil values are left out
      # @param body [Hash, Array, nil] JSON body. Time and DateTime values are
      #   sent as UTC RFC 3339 ("2026-01-01T00:00:00Z"), Date as midnight UTC,
      #   BigDecimal and Rational as plain decimal Strings, and an Integer or
      #   Float under a top-level `amount` key as a
      #   decimal String too (the API's `amount` is a String such as "19.99").
      # @param auth [Boolean] send the API key (raises ConfigurationError when
      #   none is configured)
      # @param idempotent [Boolean, nil] whether a retry is safe; defaults to
      #   true for GET, PUT and DELETE
      def request(method, path, query: nil, body: nil, auth: true, idempotent: nil)
        response = perform(method, path, query: query, body: body, auth: auth, idempotent: idempotent,
                                         accept: "application/json")
        decode_json(response[:body])
      end

      # Like #request, but returns the raw response:
      # `{status:, headers:, body:}` with lower-case header names.
      def request_raw(method, path, query: nil, body: nil, auth: true, idempotent: nil, accept: "*/*")
        perform(method, path, query: query, body: body, auth: auth, idempotent: idempotent, accept: accept)
      end

      # Percent-encodes one path segment (RFC 3986 unreserved characters stay).
      def self.escape_path(value)
        value.to_s.b.gsub(/[^A-Za-z0-9\-._~]/n) { |char| format("%%%02X", char.ord) }
      end

      private

      def perform(method, path, query:, body:, auth:, idempotent:, accept:)
        method = method.to_s.upcase
        idempotent = %w[GET HEAD PUT DELETE].include?(method) if idempotent.nil?
        url = build_url(path, query)
        headers = build_headers(auth, accept)
        payload = nil
        unless body.nil?
          payload = JSON.generate(json_body(body))
          headers["Content-Type"] = "application/json"
        end

        attempt = 0
        loop do
          begin
            status, response_headers, response_body = @transport.call(method, url, headers, payload, @timeout)
          rescue *TRANSIENT_NETWORK_ERRORS => e
            message = "Shortn request failed before a response arrived: #{e.class}: #{e.message}"
            raise NetworkError, message if certificate_failure?(e) || !retry_allowed?(idempotent, attempt)

            wait(@retry_options.backoff(attempt))
            attempt += 1
            next
          end

          status = status.to_i
          response_headers = normalize_headers(response_headers)
          response_body = response_body.to_s
          if status.between?(200, 299)
            return { status: status, headers: response_headers, body: response_body }
          end

          error = api_error(status, response_headers, response_body)
          raise error unless [429, 503].include?(status) && retry_allowed?(idempotent, attempt)

          delay = error.retry_after
          raise error if delay && delay > @retry_options.max_retry_after.to_f

          wait(delay || @retry_options.backoff(attempt))
          attempt += 1
        end
      end

      # A TLS certificate the client refuses won't verify on a retry either.
      def certificate_failure?(error)
        error.is_a?(OpenSSL::SSL::SSLError) &&
          error.message.match?(/certificate verify failed|does not match the server certificate/i)
      end

      def retry_allowed?(idempotent, attempt)
        idempotent && @retry_options.enabled? && attempt < @retry_options.max_retries.to_i
      end

      def wait(seconds)
        @sleeper.call(seconds) if seconds.positive?
      end

      def build_url(path, query)
        url = "#{@base_url}#{API_PREFIX}#{path}"
        encoded = encode_query(query)
        encoded.empty? ? url : "#{url}?#{encoded}"
      end

      def encode_query(query)
        return "" if query.nil? || query.empty?

        pairs = query.each_with_object([]) do |(key, value), list|
          next if value.nil?

          list << [key.to_s, query_value(value)]
        end
        URI.encode_www_form(pairs)
      end

      # Booleans go as "1"/"0", the form the API's flags (report_scope,
      # include_total, ...) accept.
      def query_value(value)
        case value
        when Array then value.map(&:to_s).join(",")
        when true then "1"
        when false then "0"
        when Time then value.getutc.iso8601
        when DateTime then value.to_time.getutc.iso8601
        else value.to_s
        end
      end

      # Copies the body with every value in a form the API parses; see #request.
      def json_body(body)
        return json_value(body) unless body.is_a?(Hash)

        body.each_with_object({}) do |(key, value), result|
          result[key] = AMOUNT_KEYS.include?(key.to_s) && value.is_a?(Numeric) ? decimal_string(value) : json_value(value)
        end
      end

      def json_value(value)
        case value
        when Hash then value.each_with_object({}) { |(key, item), result| result[key] = json_value(item) }
        when Array then value.map { |item| json_value(item) }
        when Time then value.getutc.iso8601
        when DateTime then value.to_time.getutc.iso8601
        when Date then value.strftime("%Y-%m-%dT00:00:00Z")
        when Rational then decimal_string(value)
        else
          defined?(::BigDecimal) && value.is_a?(::BigDecimal) ? decimal_string(value) : value
        end
      end

      # A plain decimal String with no exponent and no trailing zeros:
      # 19.99 => "19.99", 1.0e-05 => "0.00001", 20 => "20". A Float goes
      # through its shortest decimal form, so 19.99 isn't sent as
      # 19.989999999999998.
      def decimal_string(number)
        if number.is_a?(Float) || (defined?(::BigDecimal) && number.is_a?(::BigDecimal))
          raise ArgumentError, "#{number} has no decimal form" unless number.finite?
        end
        rational = number.is_a?(Float) ? Rational(number.to_s) : number.to_r
        scale = decimal_places(rational.denominator)
        raise ArgumentError, "#{number} has no exact decimal form" if scale.nil?

        digits = (rational.abs * (10**scale)).to_i.to_s.rjust(scale + 1, "0")
        text = scale.zero? ? digits : "#{digits[0...-scale]}.#{digits[-scale..]}"
        rational.negative? ? "-#{text}" : text
      end

      # Decimals needed to write 1/denominator exactly, or nil when it repeats.
      def decimal_places(denominator)
        twos = fives = 0
        while (denominator % 2).zero?
          denominator /= 2
          twos += 1
        end
        while (denominator % 5).zero?
          denominator /= 5
          fives += 1
        end
        denominator == 1 ? [twos, fives].max : nil
      end

      def build_headers(auth, accept)
        headers = { "Accept" => accept, "User-Agent" => @user_agent }
        if auth
          raise ConfigurationError, "This endpoint needs an API key: pass api_key: to Shortn::SDK::Client.new." if @api_key.nil?

          headers["Authorization"] = "Bearer #{@api_key}"
        end
        headers
      end

      def normalize_headers(headers)
        (headers || {}).each_with_object({}) do |(name, value), result|
          result[name.to_s.downcase] = value.is_a?(Array) ? value.join(", ") : value.to_s
        end
      end

      def decode_json(body)
        return {} if body.nil? || body.strip.empty?

        JSON.parse(body)
      rescue JSON::ParserError
        body
      end

      def api_error(status, headers, body)
        data = nil
        begin
          data = JSON.parse(body) unless body.strip.empty?
        rescue JSON::ParserError
          data = nil
        end
        message = data.is_a?(Hash) ? (data["error"] || data["message"]).to_s.strip : ""
        message = "Shortn API request failed with HTTP #{status}." if message.empty?
        APIError.new(message, status: status, body: body, data: data, headers: headers)
      end

      def normalize_base_url(value)
        url = value.to_s.strip
        url = DEFAULT_BASE_URL if url.empty?
        url = url.sub(%r{/+\z}, "").sub(%r{/api/v1\z}, "")
        uri = begin
          URI.parse(url)
        rescue URI::InvalidURIError
          nil
        end
        unless uri && %w[http https].include?(uri.scheme.to_s.downcase) && !uri.host.to_s.empty?
          raise ConfigurationError, "base_url must be an http or https URL with a host, such as #{DEFAULT_BASE_URL}"
        end

        url
      end

      def build_retry_options(value)
        case value
        when nil then RetryOptions.new
        when false then RetryOptions.none
        when RetryOptions then value
        when Hash then RetryOptions.new(**value.transform_keys(&:to_sym))
        else raise ArgumentError, "retry_options must be a Shortn::SDK::RetryOptions, a Hash or false"
        end
      end
    end
  end
end
