# frozen_string_literal: true

module Shortn
  module SDK
    # Custom domains: `/domains`. Domains use a numeric `id`. Creating,
    # verifying and deleting need an account-wide key.
    class DomainsResource < Resource
      # GET /domains. The domains are under `data`.
      def list
        get_request("/domains")
      end

      # POST /domains. Params: `domain`. The new domain is under `domain`.
      def create(params)
        params = { domain: params } if params.is_a?(String)
        post_request("/domains", hash_param(params, "params"))
      end

      # POST /domains/{id}/verify: checks DNS now.
      def verify(id)
        post_request("/domains/#{segment(id, 'id')}/verify")
      end

      # DELETE /domains/{id}
      def delete(id)
        delete_request("/domains/#{segment(id, 'id')}")
      end
    end
  end
end
