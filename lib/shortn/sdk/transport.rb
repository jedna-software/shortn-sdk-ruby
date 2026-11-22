# frozen_string_literal: true

require "net/http"
require "uri"

module Shortn
  module SDK
    # Default transport: one Net::HTTP request per call.
    #
    # Any object responding to `call(method, url, headers, body, timeout)` and
    # returning `[status, headers, body]` can replace it (see Client.new).
    class NetHTTPTransport
      REQUEST_CLASSES = {
        "GET" => Net::HTTP::Get,
        "POST" => Net::HTTP::Post,
        "PUT" => Net::HTTP::Put,
        "PATCH" => Net::HTTP::Patch,
        "DELETE" => Net::HTTP::Delete,
        "HEAD" => Net::HTTP::Head
      }.freeze

      def call(method, url, headers, body, timeout)
        uri = URI.parse(url)
        request_class = REQUEST_CLASSES.fetch(method) { raise ArgumentError, "unsupported HTTP method #{method}" }
        request = request_class.new(uri, headers)
        request.body = body unless body.nil?

        http = build_http(uri)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = timeout
        http.read_timeout = timeout
        http.write_timeout = timeout if http.respond_to?(:write_timeout=)
        # Net::HTTP would otherwise repeat an idempotent request once on its
        # own; the client's retry policy decides about retries.
        http.max_retries = 0
        response = http.start { |connection| connection.request(request) }
        [response.code.to_i, response.each_header.to_h, response.body.to_s]
      end

      private

      def build_http(uri)
        Net::HTTP.new(uri.host, uri.port)
      end
    end
  end
end
