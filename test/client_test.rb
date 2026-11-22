# frozen_string_literal: true

require_relative "test_helper"

class ClientTest < Minitest::Test
  include ClientHelpers

  def test_default_base_url_and_api_prefix
    client = Shortn::SDK::Client.new(api_key: "k", transport: MockTransport.new([200, {}]))
    assert_equal "https://app.shortn.link", client.base_url
  end

  def test_base_url_trailing_slash_and_api_suffix_are_normalized
    transport = MockTransport.new([200, {}], [200, {}])
    Shortn::SDK::Client.new(api_key: "k", base_url: "https://dev.example.test/", transport: transport).workspaces.list
    Shortn::SDK::Client.new(api_key: "k", base_url: "https://dev.example.test/api/v1", transport: transport).workspaces.list
    assert_equal ["https://dev.example.test/api/v1/workspaces"] * 2, transport.requests.map(&:url)
  end

  def test_sends_auth_user_agent_and_accept_headers
    client = build_client([200, { "data" => [] }])
    client.workspaces.list
    headers = transport.last.headers
    assert_equal "Bearer sk_live_test", headers["Authorization"]
    assert_equal "shortn-sdk-ruby/#{Shortn::SDK::VERSION}", headers["User-Agent"]
    assert_equal "application/json", headers["Accept"]
    refute headers.key?("Content-Type"), "a request without a body has no Content-Type"
  end

  def test_user_agent_suffix
    client = build_client([200, {}], user_agent: "my-app/2.0")
    client.workspaces.list
    assert_equal "shortn-sdk-ruby/0.1.0 my-app/2.0", transport.last.headers["User-Agent"]
  end

  def test_json_body_sets_content_type
    client = build_client([201, { "public_id" => "l1" }])
    client.links.create(url: "https://example.com", title: "T")
    assert_equal "application/json", transport.last.headers["Content-Type"]
    assert_equal({ "url" => "https://example.com", "title" => "T" }, transport.last.json)
  end

  def test_timeout_is_passed_to_transport
    client = build_client([200, {}], timeout: 7)
    client.workspaces.list
    assert_equal 7, transport.last.timeout
  end

  def test_authenticated_call_without_key_raises_before_sending
    client = build_client(api_key: nil)
    assert_raises(Shortn::SDK::ConfigurationError) { client.links.list }
    assert_empty transport.requests
  end

  def test_public_helpers_work_without_key_and_never_send_one
    client = build_client([200, { "valid" => true }], [200, { "plans" => {} }], api_key: "sk_live_secret")
    client.public.validate_url("example.com")
    client.public.plans
    transport.requests.each { |request| refute request.headers.key?("Authorization") }

    keyless = build_client([200, { "plans" => {} }], api_key: nil)
    assert_equal({ "plans" => {} }, keyless.public.plans)
  end

  def test_unknown_response_fields_stay_reachable
    client = build_client([200, { "data" => { "public_id" => "w1", "brand_new_field" => { "x" => 1 } } }])
    result = client.workspaces.get("w1")
    assert_equal({ "x" => 1 }, result["data"]["brand_new_field"])
  end

  def test_empty_body_returns_empty_hash
    client = build_client([204, ""])
    assert_equal({}, client.reports.delete_rule("r1"))
  end

  def test_query_leaves_out_nil_and_joins_arrays
    client = build_client([200, {}])
    client.reports.list_rules(workspace_public_id: nil, schedule_types: %w[every_x event], team_public_ids: [])
    assert_equal "/api/v1/reports/rules", transport.last.path
    assert_equal({ "schedule_types" => "every_x,event", "team_public_ids" => "" }, transport.last.query)
  end

  def test_no_query_string_when_nothing_is_set
    client = build_client([200, {}])
    client.links.list(limit: nil, offset: nil)
    assert_equal "#{ClientHelpers::BASE}/api/v1/links", transport.last.url
  end

  def test_path_segments_are_escaped
    client = build_client([200, {}], [200, {}], [200, {}])
    client.links.get("a b/c?d#e")
    client.teams.get("ü-team")
    client.tags.get("x+y%z")
    assert_equal "/api/v1/links/a%20b%2Fc%3Fd%23e", transport.requests[0].raw_path
    assert_equal "/api/v1/teams/%C3%BC-team", transport.requests[1].raw_path
    assert_equal "/api/v1/tags/x%2By%25z", transport.requests[2].raw_path
  end

  def test_blank_path_segment_is_refused
    client = build_client
    assert_raises(ArgumentError) { client.links.get("") }
    assert_raises(ArgumentError) { client.destinations.delete("ws", nil) }
    assert_empty transport.requests
  end

  def test_params_must_be_a_hash
    client = build_client
    assert_raises(ArgumentError) { client.tags.create("ws", "name") }
  end

  def test_structured_error_mapping
    body = {
      "code" => "conversion_identity_required",
      "error" => "idempotency_key is required",
      "hint" => "Send a stable key.",
      "details" => { "field" => "idempotency_key" },
      "request_id" => "req_123"
    }
    client = build_client([400, body])
    error = assert_raises(Shortn::SDK::APIError) { client.conversions.track_lead(click_id: "clk") }
    assert_equal 400, error.status
    assert_equal "conversion_identity_required", error.code
    assert_equal "idempotency_key is required", error.message
    assert_equal "Send a stable key.", error.hint
    assert_equal "idempotency_key", error.field
    assert_equal({ "field" => "idempotency_key" }, error.details)
    assert_equal "req_123", error.request_id
    assert_equal JSON.generate(body), error.body
    assert_equal body, error.data
    assert_kind_of Shortn::SDK::Error, error
  end

  def test_plan_limit_fields_are_reachable_through_data
    body = { "code" => "plan_limit_exceeded", "error" => "Limit", "feature" => "utm_templates", "limit" => 3,
             "current" => 3, "required_plan" => nil }
    client = build_client([403, body])
    error = assert_raises(Shortn::SDK::APIError) { client.utm_templates.create("ws", name: "N") }
    assert_equal "plan_limit_exceeded", error.code
    assert_equal "utm_templates", error.data["feature"]
    assert_nil error.field
    assert_nil error.hint
  end

  def test_error_with_only_error_message
    client = build_client([404, { "error" => "team not found" }])
    error = assert_raises(Shortn::SDK::APIError) { client.teams.get("missing") }
    assert_equal "team not found", error.message
    assert_nil error.code
    assert_nil error.details
  end

  def test_non_json_error_body
    client = build_client([502, "<html>Bad gateway</html>", { "Content-Type" => "text/html" }])
    error = assert_raises(Shortn::SDK::APIError) { client.links.create(url: "https://e.com", title: "t") }
    assert_equal 502, error.status
    assert_equal "<html>Bad gateway</html>", error.body
    assert_nil error.data
    assert_equal "text/html", error.headers["content-type"]
    assert_match(/HTTP 502/, error.message)
  end

  def test_request_id_header_fallback
    client = build_client([409, { "code" => "c", "error" => "e" }, { "Shortn-Request-Id" => "hdr_1" }])
    error = assert_raises(Shortn::SDK::APIError) { client.conversions.track_sale(invoice_id: "i") }
    assert_equal "hdr_1", error.request_id
  end

  # --- retries -------------------------------------------------------------

  def test_get_retries_on_429_honouring_retry_after
    client = build_client([429, { "code" => "api_rate_limit_exceeded", "error" => "slow down" }, { "Retry-After" => "3" }],
                          [200, { "data" => [] }])
    assert_equal({ "data" => [] }, client.links.list)
    assert_equal 2, transport.requests.length
    assert_equal [3.0], sleeps
  end

  def test_get_retries_on_503_with_backoff
    client = build_client([503, { "error" => "unavailable" }], [503, { "error" => "unavailable" }], [200, { "ok" => 1 }])
    assert_equal({ "ok" => 1 }, client.analytics.link("l1"))
    assert_equal 3, transport.requests.length
    assert_equal [0.1, 0.2], sleeps
  end

  def test_retries_are_bounded
    client = build_client([503, {}], [503, {}], [503, {}], [200, {}])
    error = assert_raises(Shortn::SDK::APIError) { client.workspaces.list }
    assert_equal 503, error.status
    assert_equal 3, transport.requests.length
  end

  def test_no_retry_on_500_or_4xx
    client = build_client([500, { "error" => "boom" }], [200, {}])
    assert_raises(Shortn::SDK::APIError) { client.workspaces.list }
    client = build_client([409, { "error" => "conflict" }], [200, {}])
    assert_raises(Shortn::SDK::APIError) { client.tags.update("t", name: "x") }
    assert_equal 1, transport.requests.length
  end

  def test_put_and_delete_are_retried
    client = build_client([503, {}], [200, { "success" => true }], [429, {}], [200, { "success" => true }])
    client.destinations.update("ws", "d1", name: "n", type: "email")
    client.destinations.delete("ws", "d1")
    assert_equal %w[PUT PUT DELETE DELETE], transport.requests.map(&:method)
  end

  def test_post_and_patch_without_idempotency_key_are_not_retried
    client = build_client([503, {}], [200, {}])
    assert_raises(Shortn::SDK::APIError) { client.links.create(url: "https://e.com", title: "t") }
    client = build_client([429, {}], [200, {}])
    assert_raises(Shortn::SDK::APIError) { client.links.update("l1", title: "t") }
    client = build_client([503, {}], [200, {}])
    assert_raises(Shortn::SDK::APIError) { client.conversions.track_refund(invoice_id: "i", refund_id: "r", amount_cents: 1) }
    assert_equal 1, transport.requests.length
  end

  def test_conversion_post_with_idempotency_key_is_retried
    client = build_client([503, {}], [200, { "type" => "lead" }])
    assert_equal({ "type" => "lead" }, client.conversions.track_lead("click_id" => "clk", "idempotency_key" => "k1"))
    assert_equal 2, transport.requests.length
    assert_equal transport.requests[0].body, transport.requests[1].body
  end

  def test_network_errors_are_retried_then_wrapped
    client = build_client(Errno::ECONNRESET.new, [200, { "ok" => true }])
    assert_equal({ "ok" => true }, client.workspaces.list)

    client = build_client(Errno::ECONNREFUSED.new, Errno::ECONNREFUSED.new, Errno::ECONNREFUSED.new)
    error = assert_raises(Shortn::SDK::NetworkError) { client.workspaces.list }
    assert_kind_of Errno::ECONNREFUSED, error.cause
    assert_equal 3, transport.requests.length
  end

  def test_network_error_on_unsafe_post_is_not_retried
    client = build_client(Net::ReadTimeout.new, [200, {}])
    assert_raises(Shortn::SDK::NetworkError) { client.links.enable("l1") }
    assert_equal 1, transport.requests.length
  end

  def test_retries_can_be_switched_off
    client = build_client([503, {}], [200, {}], retry_options: Shortn::SDK::RetryOptions.none)
    assert_raises(Shortn::SDK::APIError) { client.workspaces.list }
    assert_equal 1, transport.requests.length

    transport = MockTransport.new([503, {}], [200, {}])
    client = Shortn::SDK::Client.new(api_key: "k", transport: transport, retry_options: false)
    assert_raises(Shortn::SDK::APIError) { client.workspaces.list }
    assert_equal 1, transport.requests.length
  end

  def test_retry_options_from_hash
    client = build_client([503, {}], [503, {}], [200, {}], retry_options: { max_retries: 1, initial_delay: 0 })
    assert_raises(Shortn::SDK::APIError) { client.workspaces.list }
    assert_equal 2, transport.requests.length
    assert_empty sleeps
  end

  def test_too_long_retry_after_raises_instead_of_waiting
    client = build_client([429, { "error" => "limit" }, { "Retry-After" => "120" }], [200, {}])
    error = assert_raises(Shortn::SDK::APIError) { client.workspaces.list }
    assert_equal 120.0, error.retry_after
    assert_equal 1, transport.requests.length
    assert_empty sleeps
  end

  def test_backoff_is_capped
    options = Shortn::SDK::RetryOptions.new(initial_delay: 1, max_delay: 3, jitter: false)
    assert_equal [1.0, 2.0, 3.0, 3.0], (0..3).map { |attempt| options.backoff(attempt) }
  end

  def test_retry_after_http_date
    seconds = Shortn::SDK.parse_retry_after((Time.now + 30).httpdate)
    assert_in_delta 30, seconds, 2
    assert_nil Shortn::SDK.parse_retry_after("soon")
    assert_nil Shortn::SDK.parse_retry_after(nil)
  end

  def test_inspect_hides_the_key
    client = build_client
    refute_includes client.inspect, "sk_live_test"
  end

  # --- base URL ------------------------------------------------------------

  def test_invalid_base_url_raises_configuration_error
    ["ftp://files.example.test", "app.shortn.link", "https://", "http://exa mple.test", "mailto:ops@example.test"].each do |url|
      assert_raises(Shortn::SDK::ConfigurationError, url) { Shortn::SDK::Client.new(api_key: "k", base_url: url) }
    end
    assert_equal "http://localhost:8080", Shortn::SDK::Client.new(base_url: "http://localhost:8080/").base_url
    assert_equal "HTTPS://Example.test", Shortn::SDK::Client.new(base_url: "HTTPS://Example.test").base_url
  end

  # --- encoding --------------------------------------------------------------

  def test_frozen_time_in_query_is_not_mutated
    time = Time.new(2026, 1, 1, 10, 30, 0, "+02:00").freeze
    client = build_client([200, {}])
    client.conversions.events(from: time)
    assert_equal({ "from" => "2026-01-01T08:30:00Z" }, transport.last.query)
    assert_equal 7200, time.utc_offset, "the caller's Time keeps its zone"
  end

  def test_query_booleans_are_one_and_zero
    client = build_client([200, {}], [200, {}])
    client.conversions.events(include_total: true, limit: 5)
    assert_equal({ "include_total" => "1", "limit" => "5" }, transport.last.query)
    client.tags.list("ws", report_scope: true, team_public_ids: [], workspace_wide: false)
    assert_equal({ "report_scope" => "1", "team_public_ids" => "", "workspace_wide" => "0" }, transport.last.query)
  end

  def test_qr_code_booleans_stay_true_and_false
    client = build_client([200, "png"])
    client.public.qr_code(url: "https://e.com", centerLogo: true, "frameTextFollowsBackground" => false)
    assert_equal({ "url" => "https://e.com", "centerLogo" => "true", "frameTextFollowsBackground" => "false" },
                 transport.last.query)
  end

  def test_body_times_and_dates_are_rfc3339_utc
    occurred = Time.new(2026, 1, 1, 0, 0, 0, "+01:00").freeze
    client = build_client([200, {}], [201, {}])
    client.conversions.track_lead(click_id: "clk", idempotency_key: "k", occurred_at: occurred,
                                  metadata: { "seen" => [DateTime.new(2026, 2, 3, 4, 5, 6, "-05:00")] })
    assert_equal "2025-12-31T23:00:00Z", transport.last.json["occurred_at"]
    assert_equal ["2026-02-03T09:05:06Z"], transport.last.json["metadata"]["seen"]
    assert_equal 3600, occurred.utc_offset

    client.links.create(url: "https://e.com", title: "t", starts_at: Date.new(2026, 3, 1), expires_at: Time.utc(2026, 4, 1, 12))
    assert_equal "2026-03-01T00:00:00Z", transport.last.json["starts_at"]
    assert_equal "2026-04-01T12:00:00Z", transport.last.json["expires_at"]
  end

  def test_numeric_amounts_are_sent_as_decimal_strings
    cases = { 19.99 => "19.99", 0.00001 => "0.00001", 1e20 => "100000000000000000000", 20 => "20", 20.0 => "20",
              Rational(1999, 100) => "19.99", 0.1 + 0.2 => "0.30000000000000004", "19.99" => "19.99" }
    cases.each do |amount, expected|
      client = build_client([200, {}])
      client.conversions.track_sale(click_id: "clk", amount: amount, currency: "EUR", invoice_id: "inv")
      assert_equal expected, transport.last.json["amount"], "amount #{amount.inspect}"
    end

    client = build_client([200, {}])
    client.conversions.track_sale("click_id" => "clk", "amount" => 0.5, "settlement_amount_cents" => 1200,
                                  "currency" => "EUR", "invoice_id" => "inv",
                                  "metadata" => { "amount" => 2.5, "score" => 1.5, "ratio" => Rational(1, 4) })
    body = transport.last.json
    assert_equal "0.5", body["amount"]
    assert_equal 1200, body["settlement_amount_cents"], "other numeric fields stay numbers"
    assert_equal({ "amount" => 2.5, "score" => 1.5, "ratio" => "0.25" }, body["metadata"])
  end

  def test_big_decimal_amounts_are_plain_decimal_strings
    begin
      verbose, $VERBOSE = $VERBOSE, nil # no "bundled gem" warning on Ruby 3.4+
      require "bigdecimal"
    rescue LoadError
      skip "bigdecimal is not in the bundle (a bundled gem since Ruby 3.4)"
    ensure
      $VERBOSE = verbose
    end
    { "19.99" => "19.99", "1e-8" => "0.00000001", "100.0" => "100", "0.1999e2" => "19.99" }.each do |text, expected|
      client = build_client([200, {}])
      client.conversions.track_sale(click_id: "clk", amount: BigDecimal(text), currency: "BTC", invoice_id: "inv",
                                    metadata: { "fee" => BigDecimal("0.5") })
      assert_equal expected, transport.last.json["amount"]
      assert_equal "0.5", transport.last.json["metadata"]["fee"]
    end
  end

  def test_amount_without_exact_decimal_form_is_refused_before_sending
    client = build_client([200, {}])
    assert_raises(ArgumentError) { client.conversions.track_sale(click_id: "clk", amount: Rational(1, 3), currency: "EUR") }
    assert_raises(ArgumentError) { client.conversions.track_sale(click_id: "clk", amount: Float::NAN, currency: "EUR") }
    assert_raises(ArgumentError) { client.conversions.track_sale(click_id: "clk", amount: Float::INFINITY, currency: "EUR") }
    assert_empty transport.requests
  end

  # --- network errors ------------------------------------------------------

  def test_transient_network_errors_are_retried
    [Net::OpenTimeout.new, Net::ReadTimeout.new, Net::WriteTimeout.new, Errno::EPIPE.new, Errno::ETIMEDOUT.new,
     Errno::EHOSTUNREACH.new, EOFError.new, IOError.new, SocketError.new("getaddrinfo"),
     OpenSSL::SSL::SSLError.new("SSL_read: unexpected eof while reading")].each do |error|
      client = build_client(error, [200, { "ok" => true }])
      assert_equal({ "ok" => true }, client.workspaces.list, error.class.name)
      assert_equal 2, transport.requests.length
    end
  end

  def test_certificate_failures_raise_without_retry
    ["SSL_connect returned=1 errno=0 peeraddr=1.2.3.4:443 state=error: certificate verify failed (unable to get local issuer certificate)",
     'hostname "api.example.test" does not match the server certificate'].each do |message|
      client = build_client(OpenSSL::SSL::SSLError.new(message), [200, {}])
      error = assert_raises(Shortn::SDK::NetworkError) { client.workspaces.list }
      assert_kind_of OpenSSL::SSL::SSLError, error.cause
      assert_equal 1, transport.requests.length
      assert_empty sleeps
    end
  end

  def test_other_exceptions_propagate_unchanged_without_retry
    [ArgumentError.new("bad header"), NoMethodError.new("undefined method"), Timeout::Error.new("custom")].each do |raised|
      client = build_client(raised, [200, {}])
      error = assert_raises(raised.class) { client.workspaces.list }
      assert_same raised, error
      assert_equal 1, transport.requests.length
    end
  end

  def test_net_http_transport_turns_off_net_http_retries
    fake = Class.new do
      attr_accessor :use_ssl, :open_timeout, :read_timeout, :write_timeout, :max_retries
      attr_reader :sent

      def start
        yield self
      end

      def request(request)
        @sent = request
        response = Net::HTTPOK.new("1.1", "200", "OK")
        response.instance_variable_set(:@read, true)
        response.instance_variable_set(:@body, "{}")
        response
      end
    end.new
    transport = Shortn::SDK::NetHTTPTransport.new
    transport.define_singleton_method(:build_http) { |_uri| fake }
    status, _headers, body = transport.call("PUT", "https://api.example.test/api/v1/x", {}, "{}", 5)
    assert_equal [200, "{}"], [status, body]
    assert_equal 0, fake.max_retries
    assert_equal true, fake.use_ssl
    assert_equal [5, 5, 5], [fake.open_timeout, fake.read_timeout, fake.write_timeout]
    assert_equal "PUT", fake.sent.method
  end

  # --- test-mode conversions -------------------------------------------------

  def test_test_mode_conversions_are_never_retried
    [{ click_id: "clk", idempotency_key: "k1", test_mode: true },
     { "click_id" => "clk", "idempotency_key" => "k1", "test_mode" => true }].each do |params|
      client = build_client([503, {}], [200, { "type" => "lead" }])
      assert_raises(Shortn::SDK::APIError) { client.conversions.track_lead(params) }
      client = build_client(Errno::ECONNRESET.new, [200, { "type" => "lead" }])
      assert_raises(Shortn::SDK::NetworkError) { client.conversions.track_lead(params) }
      assert_equal 1, transport.requests.length
    end

    client = build_client([503, {}], [200, { "type" => "lead" }])
    client.conversions.track_lead(click_id: "clk", idempotency_key: "k1", test_mode: false)
    assert_equal 2, transport.requests.length, "a live event with a key is still retried"
  end
end
