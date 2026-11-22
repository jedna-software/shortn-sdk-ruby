# frozen_string_literal: true

module Shortn
  module SDK
    # Report destinations: `/workspaces/{public_id}/destinations`.
    # These endpoints answer without a `data` wrapper; the list is an Array.
    class DestinationsResource < Resource
      # GET /workspaces/{workspace_id}/destinations
      def list(workspace_id)
        get_request(collection(workspace_id))
      end

      # POST /workspaces/{workspace_id}/destinations. Params: `name`, `type`
      # (email, webhook, slack, discord, msteams), `config`, `team_public_ids`.
      def create(workspace_id, params)
        post_request(collection(workspace_id), hash_param(params, "params"))
      end

      # PUT /workspaces/{workspace_id}/destinations/{destination_id}.
      # `name` and `type` are required every time.
      def update(workspace_id, destination_id, params)
        put_request("#{collection(workspace_id)}/#{segment(destination_id, 'destination_id')}", hash_param(params, "params"))
      end

      # DELETE /workspaces/{workspace_id}/destinations/{destination_id}
      def delete(workspace_id, destination_id)
        delete_request("#{collection(workspace_id)}/#{segment(destination_id, 'destination_id')}")
      end

      private

      def collection(workspace_id)
        "/workspaces/#{segment(workspace_id, 'workspace_id')}/destinations"
      end
    end
  end
end
