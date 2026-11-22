# frozen_string_literal: true

module Shortn
  module SDK
    # Conversions: send leads, sales and refunds, validate them without
    # recording, and read conversion reporting.
    #
    # Bodies are passed through as snake_case JSON; the API refuses unknown
    # fields. `amount` is a String such as "19.99"; an Integer, Float or
    # BigDecimal is converted to one. `occurred_at` may be a Time.
    #
    # A live write that carries `idempotency_key` is retried on 429, 503 and
    # network errors, since the API records a live event once per key. A
    # `test_mode: true` write is never retried: the API does not deduplicate
    # test events, so a retry would record a second one.
    class ConversionsResource < Resource
      # POST /conversions/leads. Needs `click_id` and `idempotency_key`.
      def track_lead(params)
        intake("/conversions/leads", params)
      end

      # POST /conversions/leads/validations: same checks, records nothing.
      def validate_lead(params)
        intake("/conversions/leads/validations", params)
      end

      # POST /conversions/sales. Needs `click_id`, `currency`, and `invoice_id`
      # or `idempotency_key`; amount as `amount_cents` or `amount`.
      def track_sale(params)
        intake("/conversions/sales", params)
      end

      # POST /conversions/sales/validations
      def validate_sale(params)
        intake("/conversions/sales/validations", params)
      end

      # POST /conversions/refunds. Needs `invoice_id`, `refund_id` and an
      # amount (`amount_cents` or `amount`).
      def track_refund(params)
        intake("/conversions/refunds", params)
      end

      # POST /conversions/refunds/validations
      def validate_refund(params)
        intake("/conversions/refunds/validations", params)
      end

      # GET /conversions/summary: all-time live totals under `data`.
      def summary(query = {})
        get_request("/conversions/summary", hash_param(query, "query"))
      end

      # GET /conversions/attribution. Query: `from`, `to`, `environment`
      # ("live"/"test"), `limit`.
      def attribution(query = {})
        get_request("/conversions/attribution", hash_param(query, "query"))
      end

      # GET /conversions/timeline. Query: `from`, `to`, `environment`,
      # `interval` ("day", "week", "month").
      def timeline(query = {})
        get_request("/conversions/timeline", hash_param(query, "query"))
      end

      # GET /conversions/events. Query: `from`, `to`, `environment`, `limit`,
      # `offset`, `event_type`, `lead_category`, `event_origin`, `link`,
      # `event`, `q`.
      def events(query = {})
        get_request("/conversions/events", hash_param(query, "query"))
      end

      private

      def intake(path, params)
        body = hash_param(params, "params")
        key = body[:idempotency_key] || body["idempotency_key"]
        test_mode = body.key?(:test_mode) ? body[:test_mode] : body["test_mode"]
        post_request(path, body, idempotent: !key.to_s.strip.empty? && !test_mode)
      end
    end
  end
end
