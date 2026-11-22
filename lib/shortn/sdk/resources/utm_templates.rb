# frozen_string_literal: true

module Shortn
  module SDK
    # UTM templates: `/workspaces/{public_id}/utm-templates` and
    # `/utm-templates/{public_id}`.
    class UTMTemplatesResource < Resource
      # GET /workspaces/{workspace_id}/utm-templates. Query:
      # `include_team_scoped` ("1"/true), `team_public_ids`.
      def list(workspace_id, query = {})
        get_request("/workspaces/#{segment(workspace_id, 'workspace_id')}/utm-templates", hash_param(query, "query"))
      end

      # POST /workspaces/{workspace_id}/utm-templates. Params: `name`,
      # `utm_source`..`utm_id`, `team_public_ids`. The template is under `data`.
      def create(workspace_id, params)
        post_request("/workspaces/#{segment(workspace_id, 'workspace_id')}/utm-templates", hash_param(params, "params"))
      end

      # PUT /utm-templates/{template_id}. Replaces the template: send every
      # value to keep. Optional `workspace_public_id`, `lost_access_action`.
      def update(template_id, params)
        put_request("/utm-templates/#{segment(template_id, 'template_id')}", hash_param(params, "params"))
      end

      # DELETE /utm-templates/{template_id}. Query: `links` ("keep" or "clear").
      def delete(template_id, query = {})
        delete_request("/utm-templates/#{segment(template_id, 'template_id')}", hash_param(query, "query"))
      end
    end
  end
end
