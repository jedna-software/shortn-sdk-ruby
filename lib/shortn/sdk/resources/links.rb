# frozen_string_literal: true

module Shortn
  module SDK
    # Links: `/links`. Refer to a link by its `public_id`.
    class LinksResource < Resource
      # GET /links. Query: `limit` (1-100), `offset`.
      def list(query = {})
        get_request("/links", hash_param(query, "query"))
      end

      # GET /links/{public_id}. The link is under `data`.
      def get(public_id)
        get_request("/links/#{segment(public_id, 'public_id')}")
      end

      # POST /links with the API key. `url` and `title` are required; see the
      # API docs for every optional field (tags, UTM, schedule, targeting...).
      def create(params)
        post_request("/links", hash_param(params, "params"))
      end

      # PATCH /links/{public_id}. Fields: `title`, `description`, `url`,
      # `short_code`, `domain`, `status`, `active`, `team_public_ids`.
      def update(public_id, params)
        patch_request("/links/#{segment(public_id, 'public_id')}", hash_param(params, "params"))
      end

      # DELETE /links/{public_id}: suspends the link (history is kept).
      def delete(public_id)
        delete_request("/links/#{segment(public_id, 'public_id')}")
      end

      # POST /links/{public_id}/enable: makes a suspended link active again.
      def enable(public_id)
        post_request("/links/#{segment(public_id, 'public_id')}/enable")
      end

      # POST /links/{public_id}/ab/winner. Params: `variant` (such as "B").
      # A String is taken as the variant.
      def set_ab_winner(public_id, params)
        params = { variant: params } if params.is_a?(String)
        post_request("/links/#{segment(public_id, 'public_id')}/ab/winner", hash_param(params, "params"))
      end
    end
  end
end
