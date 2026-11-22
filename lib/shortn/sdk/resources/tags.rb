# frozen_string_literal: true

module Shortn
  module SDK
    # Tags: `/workspaces/{public_id}/tags` and `/tags/{public_id}`.
    # These endpoints answer without a `data` wrapper.
    class TagsResource < Resource
      # GET /workspaces/{workspace_id}/tags. Query: `team_public_ids`
      # (Array or comma-separated), `team` ("none"), `report_scope` ("1").
      # The tags are under `tags` (null when there are none).
      def list(workspace_id, query = {})
        get_request("/workspaces/#{segment(workspace_id, 'workspace_id')}/tags", hash_param(query, "query"))
      end

      # POST /workspaces/{workspace_id}/tags. Params: `name`, `color`,
      # optional `team_public_ids`.
      def create(workspace_id, params)
        post_request("/workspaces/#{segment(workspace_id, 'workspace_id')}/tags", hash_param(params, "params"))
      end

      # GET /tags/{id}
      def get(id)
        get_request("/tags/#{segment(id, 'id')}")
      end

      # PUT /tags/{id}. Either `name`/`color`, or `team_public_ids`, per request.
      def update(id, params)
        put_request("/tags/#{segment(id, 'id')}", hash_param(params, "params"))
      end

      # DELETE /tags/{id}: removes the tag from every link.
      def delete(id)
        delete_request("/tags/#{segment(id, 'id')}")
      end
    end
  end
end
