# frozen_string_literal: true

module Shortn
  module SDK
    # Retry policy.
    #
    # Retries happen on 429 and 503 responses and on transient network errors
    # (timeouts, refused or reset connections, DNS, TLS other than a failed
    # certificate check), and only for requests that are safe to repeat: GET,
    # PUT and DELETE, and live conversion POSTs that carry an idempotency_key.
    # Test-mode conversions (`test_mode: true`) are never retried: the API does
    # not deduplicate test events.
    #
    # max_retries     - retries after the first attempt (0 disables retries)
    # initial_delay   - seconds before the first retry
    # max_delay       - cap for the exponential backoff, in seconds
    # backoff_factor  - multiplier per retry
    # jitter          - randomise each backoff delay by +/-20%
    # max_retry_after - longest Retry-After (seconds) the client waits for;
    #                   a longer one raises the error instead of sleeping
    # disabled        - turn retries off entirely
    RetryOptions = Struct.new(
      :max_retries,
      :initial_delay,
      :max_delay,
      :backoff_factor,
      :jitter,
      :max_retry_after,
      :disabled,
      keyword_init: true
    ) do
      def initialize(max_retries: 2, initial_delay: 0.5, max_delay: 8.0, backoff_factor: 2.0, jitter: true,
                     max_retry_after: 60.0, disabled: false)
        super
      end

      # A policy that never retries.
      def self.none
        new(disabled: true)
      end

      def enabled?
        !disabled && max_retries.to_i.positive?
      end

      # Backoff delay in seconds before retry number +attempt+ (0-based).
      def backoff(attempt)
        delay = [initial_delay.to_f * (backoff_factor.to_f**attempt), max_delay.to_f].min
        delay *= 0.8 + (rand * 0.4) if jitter && delay.positive?
        delay
      end
    end
  end
end
