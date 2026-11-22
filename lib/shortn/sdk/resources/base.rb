# frozen_string_literal: true

module Shortn
  module SDK
    # Shared helpers for the resource groups.
    class Resource
      def initialize(client)
        @client = client
      end

      def inspect
        "#<#{self.class.name}>"
      end

      private

      def get_request(path, query = nil, auth: true)
        @client.request("GET", path, query: query, auth: auth)
      end

      def post_request(path, body = nil, idempotent: false)
        @client.request("POST", path, body: body, idempotent: idempotent)
      end

      def put_request(path, body, query = nil)
        @client.request("PUT", path, body: body, query: query)
      end

      def patch_request(path, body)
        @client.request("PATCH", path, body: body)
      end

      def delete_request(path, query = nil)
        @client.request("DELETE", path, query: query)
      end

      # Escapes one path segment and refuses an empty one, so a missing id
      # can't turn `GET /links/{code}` into `GET /links/`.
      def segment(value, name)
        text = value.to_s
        raise ArgumentError, "#{name} is required" if text.strip.empty?

        Client.escape_path(text)
      end

      def hash_param(value, name)
        return {} if value.nil?
        raise ArgumentError, "#{name} must be a Hash" unless value.is_a?(Hash)

        value
      end
    end
  end
end
