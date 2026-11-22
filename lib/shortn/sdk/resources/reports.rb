# frozen_string_literal: true

module Shortn
  module SDK
    # Report and alert rules: `/reports/rules`.
    class ReportsResource < Resource
      # GET /reports/rules. Query: `workspace_public_id`, `schedule_types`,
      # `link_public_ids`, `team_public_ids` (Arrays are sent comma-separated).
      def list_rules(query = {})
        get_request("/reports/rules", hash_param(query, "query"))
      end

      # GET /reports/rules/{id}. The rule is under `data`.
      def get_rule(id)
        get_request("/reports/rules/#{segment(id, 'id')}")
      end

      # POST /reports/rules. Params: `workspace_public_id`, `report_type`
      # ("custom_builder_v1"), `schedule_type`, `interval_seconds`,
      # `initial_run_at`, `report_name`, `definition_json`,
      # `destination_public_ids`, `team_public_ids`, `include_unassigned_links`,
      # `link_public_ids`. A new rule is always enabled: the API ignores
      # `enabled` on create, so pause a rule with update_rule(id, enabled: false).
      def create_rule(params)
        post_request("/reports/rules", hash_param(params, "params"))
      end

      # PATCH /reports/rules/{id}: changes the fields sent, such as
      # `{ enabled: false }`.
      def update_rule(id, params)
        patch_request("/reports/rules/#{segment(id, 'id')}", hash_param(params, "params"))
      end

      # DELETE /reports/rules/{id}. Answers 204, returned as `{}`.
      def delete_rule(id)
        delete_request("/reports/rules/#{segment(id, 'id')}")
      end
    end
  end
end
