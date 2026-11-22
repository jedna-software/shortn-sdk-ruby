# frozen_string_literal: true

module Shortn
  module SDK
    # Endpoints that need no API key. The key, when configured, is not sent.
    #
    # Key-less link creation and the anonymous link preview are left out on
    # purpose: they need a browser human check. Use links.create and
    # analytics.link with an API key instead.
    class PublicResource < Resource
      # GET /validate?url=... Answers `valid`, plus `normalized` or
      # `code`/`error`.
      def validate_url(url)
        raise ArgumentError, "url is required" if url.to_s.strip.empty?

        get_request("/validate", { url: url.to_s }, auth: false)
      end

      # GET /qr. Params: `url` (required), `format` (png, svg, jpg), `size`,
      # `fg`, `bg`, `qrShape`, `frameTemplate`, `centerLogo`... Returns the
      # image bytes as a binary String. Boolean flags such as `centerLogo` go
      # as "true"/"false", the form this endpoint reads.
      def qr_code(params)
        params = { url: params } if params.is_a?(String)
        query = hash_param(params, "params").transform_values do |value|
          [true, false].include?(value) ? value.to_s : value
        end
        format = (query[:format] || query["format"]).to_s
        accept = { "svg" => "image/svg+xml", "jpg" => "image/jpeg", "jpeg" => "image/jpeg" }.fetch(format, "image/png")
        response = @client.request_raw("GET", "/qr", query: query, auth: false, accept: "#{accept}, */*")
        response[:body].b
      end

      # GET /plans: the plan catalog under `plans`, keyed by plan id.
      def plans
        get_request("/plans", auth: false)
      end
    end
  end
end
