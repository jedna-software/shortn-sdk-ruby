# frozen_string_literal: true

module Shortn
  module SDK
    # Workspaces: `/workspaces`.
    class WorkspacesResource < Resource
      # GET /workspaces. The workspaces are under `data`.
      def list
        get_request("/workspaces")
      end

      # GET /workspaces/{public_id}. The workspace is under `data`.
      def get(public_id)
        get_request("/workspaces/#{segment(public_id, 'public_id')}")
      end
    end
  end
end
