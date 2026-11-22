# frozen_string_literal: true

module Shortn
  module SDK
    # Link analytics: `/analytics/links/{public_id}`.
    class AnalyticsResource < Resource
      # GET /analytics/links/{public_id}: `total_clicks`, `unique_clicks`,
      # `clicks_by_country`. Counts toward the analytics rate limit.
      # The endpoint reads no query parameters today; `query` is sent as given
      # for forward compatibility and has no effect.
      def link(id, query = {})
        get_request("/analytics/links/#{segment(id, 'id')}", hash_param(query, "query"))
      end
    end
  end
end
