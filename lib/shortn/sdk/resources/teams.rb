# frozen_string_literal: true

module Shortn
  module SDK
    # Teams: `/workspaces/{public_id}/teams` and `/teams/{slug}`.
    # These endpoints answer without a `data` wrapper.
    #
    # A slug is unique only within a workspace: pass
    # `{ workspace: "<workspace public id>" }` as the query of get, update and
    # delete when the key reaches several workspaces.
    class TeamsResource < Resource
      # GET /workspaces/{workspace_id}/teams. The teams are under `teams`.
      def list(workspace_id)
        get_request("/workspaces/#{segment(workspace_id, 'workspace_id')}/teams")
      end

      # POST /workspaces/{workspace_id}/teams. Params: `name`, `description`.
      # Answers `id`, `slug` and `public_id`.
      def create(workspace_id, params)
        post_request("/workspaces/#{segment(workspace_id, 'workspace_id')}/teams", hash_param(params, "params"))
      end

      # GET /teams/{slug}. Query: `workspace`.
      def get(slug, query = {})
        get_request("/teams/#{segment(slug, 'slug')}", hash_param(query, "query"))
      end

      # PUT /teams/{slug}. Params: `name`, `description`. Query: `workspace`.
      def update(slug, params, query = {})
        put_request("/teams/#{segment(slug, 'slug')}", hash_param(params, "params"), hash_param(query, "query"))
      end

      # DELETE /teams/{slug}: archives the team. Query: `workspace`.
      def delete(slug, query = {})
        delete_request("/teams/#{segment(slug, 'slug')}", hash_param(query, "query"))
      end
    end
  end
end
