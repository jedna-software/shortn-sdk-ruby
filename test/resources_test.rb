# frozen_string_literal: true

require_relative "test_helper"

# One case per SDK method: the HTTP method, the escaped path, the query and
# the JSON body it sends.
class ResourcesTest < Minitest::Test
  include ClientHelpers

  WS = "ws/1"   # needs escaping on purpose
  WS_ESC = "ws%2F1"

  CASES = [
    # links
    ["links.list", ->(c) { c.links.list(limit: 10, offset: 20) }, "GET", "/links", { "limit" => "10", "offset" => "20" }, nil],
    ["links.list (no query)", ->(c) { c.links.list }, "GET", "/links", {}, nil],
    ["links.get", ->(c) { c.links.get("l 1") }, "GET", "/links/l%201", {}, nil],
    ["links.create", ->(c) { c.links.create(url: "https://example.com", title: "T", workspace_public_id: "w", tag_public_ids: ["t1"]) },
     "POST", "/links", {}, { "url" => "https://example.com", "title" => "T", "workspace_public_id" => "w", "tag_public_ids" => ["t1"] }],
    ["links.update", ->(c) { c.links.update("l1", title: "New", team_public_ids: []) }, "PATCH", "/links/l1", {}, { "title" => "New", "team_public_ids" => [] }],
    ["links.delete", ->(c) { c.links.delete("l1") }, "DELETE", "/links/l1", {}, nil],
    ["links.enable", ->(c) { c.links.enable("l1") }, "POST", "/links/l1/enable", {}, nil],
    ["links.set_ab_winner", ->(c) { c.links.set_ab_winner("l1", variant: "B") }, "POST", "/links/l1/ab/winner", {}, { "variant" => "B" }],
    ["links.set_ab_winner (string)", ->(c) { c.links.set_ab_winner("l1", "C") }, "POST", "/links/l1/ab/winner", {}, { "variant" => "C" }],
    # analytics
    ["analytics.link", ->(c) { c.analytics.link("l1") }, "GET", "/analytics/links/l1", {}, nil],
    # workspaces
    ["workspaces.list", ->(c) { c.workspaces.list }, "GET", "/workspaces", {}, nil],
    ["workspaces.get", ->(c) { c.workspaces.get(WS) }, "GET", "/workspaces/#{WS_ESC}", {}, nil],
    # tags
    ["tags.list", ->(c) { c.tags.list(WS, team: "none") }, "GET", "/workspaces/#{WS_ESC}/tags", { "team" => "none" }, nil],
    ["tags.create", ->(c) { c.tags.create(WS, name: "Spring", color: "#3b82f6") }, "POST", "/workspaces/#{WS_ESC}/tags", {},
     { "name" => "Spring", "color" => "#3b82f6" }],
    ["tags.get", ->(c) { c.tags.get("t1") }, "GET", "/tags/t1", {}, nil],
    ["tags.update", ->(c) { c.tags.update("t1", name: "Summer") }, "PUT", "/tags/t1", {}, { "name" => "Summer" }],
    ["tags.delete", ->(c) { c.tags.delete("t1") }, "DELETE", "/tags/t1", {}, nil],
    # utm templates
    ["utm_templates.list", ->(c) { c.utm_templates.list(WS, include_team_scoped: true) }, "GET", "/workspaces/#{WS_ESC}/utm-templates",
     { "include_team_scoped" => "1" }, nil],
    ["utm_templates.create", ->(c) { c.utm_templates.create(WS, name: "N", utm_source: "news") }, "POST", "/workspaces/#{WS_ESC}/utm-templates", {},
     { "name" => "N", "utm_source" => "news" }],
    ["utm_templates.update", ->(c) { c.utm_templates.update("u1", name: "N2", lost_access_action: "copy") }, "PUT", "/utm-templates/u1", {},
     { "name" => "N2", "lost_access_action" => "copy" }],
    ["utm_templates.delete", ->(c) { c.utm_templates.delete("u1", links: "clear") }, "DELETE", "/utm-templates/u1", { "links" => "clear" }, nil],
    ["utm_templates.delete (no query)", ->(c) { c.utm_templates.delete("u1") }, "DELETE", "/utm-templates/u1", {}, nil],
    # destinations
    ["destinations.list", ->(c) { c.destinations.list(WS) }, "GET", "/workspaces/#{WS_ESC}/destinations", {}, nil],
    ["destinations.create", ->(c) { c.destinations.create(WS, name: "Hook", type: "webhook", config: { webhook_url: "https://example.com/h" }) },
     "POST", "/workspaces/#{WS_ESC}/destinations", {}, { "name" => "Hook", "type" => "webhook", "config" => { "webhook_url" => "https://example.com/h" } }],
    ["destinations.update", ->(c) { c.destinations.update(WS, "d 1", name: "Hook 2", type: "webhook") }, "PUT", "/workspaces/#{WS_ESC}/destinations/d%201", {},
     { "name" => "Hook 2", "type" => "webhook" }],
    ["destinations.delete", ->(c) { c.destinations.delete(WS, "d1") }, "DELETE", "/workspaces/#{WS_ESC}/destinations/d1", {}, nil],
    # teams
    ["teams.list", ->(c) { c.teams.list(WS) }, "GET", "/workspaces/#{WS_ESC}/teams", {}, nil],
    ["teams.create", ->(c) { c.teams.create(WS, name: "Paid", description: "d") }, "POST", "/workspaces/#{WS_ESC}/teams", {},
     { "name" => "Paid", "description" => "d" }],
    ["teams.get", ->(c) { c.teams.get("paid-social", workspace: "w1") }, "GET", "/teams/paid-social", { "workspace" => "w1" }, nil],
    ["teams.update", ->(c) { c.teams.update("paid-social", { name: "EU" }, workspace: "w1") }, "PUT", "/teams/paid-social", { "workspace" => "w1" },
     { "name" => "EU" }],
    ["teams.delete", ->(c) { c.teams.delete("paid-social") }, "DELETE", "/teams/paid-social", {}, nil],
    # domains
    ["domains.list", ->(c) { c.domains.list }, "GET", "/domains", {}, nil],
    ["domains.create", ->(c) { c.domains.create(domain: "go.example.com") }, "POST", "/domains", {}, { "domain" => "go.example.com" }],
    ["domains.create (string)", ->(c) { c.domains.create("go.example.com") }, "POST", "/domains", {}, { "domain" => "go.example.com" }],
    ["domains.verify", ->(c) { c.domains.verify(14) }, "POST", "/domains/14/verify", {}, nil],
    ["domains.delete", ->(c) { c.domains.delete(14) }, "DELETE", "/domains/14", {}, nil],
    # reports
    ["reports.list_rules", ->(c) { c.reports.list_rules(workspace_public_id: "w1", schedule_types: ["every_x"]) }, "GET", "/reports/rules",
     { "workspace_public_id" => "w1", "schedule_types" => "every_x" }, nil],
    ["reports.get_rule", ->(c) { c.reports.get_rule("r1") }, "GET", "/reports/rules/r1", {}, nil],
    ["reports.create_rule", ->(c) { c.reports.create_rule(report_type: "custom_builder_v1", interval_seconds: 604_800, enabled: false) },
     "POST", "/reports/rules", {}, { "report_type" => "custom_builder_v1", "interval_seconds" => 604_800, "enabled" => false }],
    ["reports.update_rule", ->(c) { c.reports.update_rule("r1", enabled: true) }, "PATCH", "/reports/rules/r1", {}, { "enabled" => true }],
    ["reports.delete_rule", ->(c) { c.reports.delete_rule("r1") }, "DELETE", "/reports/rules/r1", {}, nil],
    # conversions
    ["conversions.track_lead", ->(c) { c.conversions.track_lead(click_id: "clk", idempotency_key: "k", lead_category: "signup", test_mode: true) },
     "POST", "/conversions/leads", {}, { "click_id" => "clk", "idempotency_key" => "k", "lead_category" => "signup", "test_mode" => true }],
    ["conversions.validate_lead", ->(c) { c.conversions.validate_lead(click_id: "clk", idempotency_key: "k") }, "POST", "/conversions/leads/validations", {},
     { "click_id" => "clk", "idempotency_key" => "k" }],
    ["conversions.track_sale", ->(c) { c.conversions.track_sale(click_id: "clk", amount_cents: 4900, currency: "EUR", invoice_id: "inv") },
     "POST", "/conversions/sales", {}, { "click_id" => "clk", "amount_cents" => 4900, "currency" => "EUR", "invoice_id" => "inv" }],
    ["conversions.validate_sale", ->(c) { c.conversions.validate_sale(click_id: "clk", amount: "49.00", currency: "EUR", invoice_id: "inv") },
     "POST", "/conversions/sales/validations", {}, { "click_id" => "clk", "amount" => "49.00", "currency" => "EUR", "invoice_id" => "inv" }],
    ["conversions.track_refund", ->(c) { c.conversions.track_refund(invoice_id: "inv", refund_id: "re", amount_cents: 1900) },
     "POST", "/conversions/refunds", {}, { "invoice_id" => "inv", "refund_id" => "re", "amount_cents" => 1900 }],
    ["conversions.validate_refund", ->(c) { c.conversions.validate_refund(invoice_id: "inv", refund_id: "re", amount_cents: 1900) },
     "POST", "/conversions/refunds/validations", {}, { "invoice_id" => "inv", "refund_id" => "re", "amount_cents" => 1900 }],
    ["conversions.summary", ->(c) { c.conversions.summary }, "GET", "/conversions/summary", {}, nil],
    ["conversions.attribution", ->(c) { c.conversions.attribution(environment: "test", limit: 5, from: "2026-11-01") }, "GET", "/conversions/attribution",
     { "environment" => "test", "limit" => "5", "from" => "2026-11-01" }, nil],
    ["conversions.timeline", ->(c) { c.conversions.timeline(interval: "week", to: nil) }, "GET", "/conversions/timeline", { "interval" => "week" }, nil],
    ["conversions.events", ->(c) { c.conversions.events(event_type: "sale", q: "a&b", offset: 0) }, "GET", "/conversions/events",
     { "event_type" => "sale", "q" => "a&b", "offset" => "0" }, nil],
    # public
    ["public.validate_url", ->(c) { c.public.validate_url("example.com/a b") }, "GET", "/validate", { "url" => "example.com/a b" }, nil],
    ["public.plans", ->(c) { c.public.plans }, "GET", "/plans", {}, nil]
  ].freeze

  CASES.each_with_index do |(name, call, method, path, query, body), index|
    define_method("test_#{index.to_s.rjust(2, '0')}_#{name.gsub(/[^a-z0-9]+/i, '_')}") do
      client = build_client([200, { "ok" => true }])
      result = call.call(client)
      request = transport.last
      assert_equal 1, transport.requests.length
      assert_equal method, request.method
      assert_equal "/api/v1#{path}", request.raw_path
      assert_equal query, request.query
      if body.nil?
        assert_nil request.body
      else
        assert_equal body, request.json
      end
      assert_equal({ "ok" => true }, result)
    end
  end

  def test_every_public_method_has_a_case
    client = build_client
    groups = %i[links analytics workspaces tags utm_templates destinations teams domains reports conversions public]
    methods = groups.flat_map do |group|
      resource = client.public_send(group)
      (resource.class.public_instance_methods(false) - [:inspect]).map { |m| "#{group}.#{m}" }
    end
    # public.qr_code returns bytes, so it has its own tests below.
    covered = CASES.map { |name, *| name.split(" ").first }.uniq + ["public.qr_code"]
    assert_equal 50, methods.length, "the SDK wraps 50 routes"
    assert_equal methods.sort, (covered & methods).sort
    assert_equal [], methods - covered
  end

  def test_qr_code_returns_bytes_without_auth
    png = "\x89PNG\r\n\x1A\n\x00\x01binary".b
    client = build_client([200, png, { "Content-Type" => "image/png" }])
    bytes = client.public.qr_code(url: "https://shtnl.ink/abc", format: "png", size: "download")
    request = transport.last
    assert_equal "GET", request.method
    assert_equal "/api/v1/qr", request.raw_path
    assert_equal({ "url" => "https://shtnl.ink/abc", "format" => "png", "size" => "download" }, request.query)
    refute request.headers.key?("Authorization")
    assert_equal "image/png, */*", request.headers["Accept"]
    assert_equal Encoding::BINARY, bytes.encoding
    assert_equal png, bytes
  end

  def test_qr_code_svg_accept_header_and_string_shortcut
    client = build_client([200, "<svg/>"], [200, "x"])
    assert_equal "<svg/>", client.public.qr_code(url: "https://e.com", format: "svg")
    assert_equal "image/svg+xml, */*", transport.last.headers["Accept"]
    client.public.qr_code("https://e.com")
    assert_equal({ "url" => "https://e.com" }, transport.last.query)
  end

  def test_qr_code_error_is_an_api_error
    client = build_client([403, { "code" => "plan_limit_exceeded", "error" => "QR customization", "feature" => "qr_customization" }])
    error = assert_raises(Shortn::SDK::APIError) { client.public.qr_code(url: "https://e.com", qrShape: "liquid") }
    assert_equal "plan_limit_exceeded", error.code
  end

  def test_validate_url_requires_a_url
    client = build_client
    assert_raises(ArgumentError) { client.public.validate_url(" ") }
  end

  def test_string_keys_are_accepted
    client = build_client([200, {}])
    client.tags.create("w", "name" => "x", "color" => "#000000")
    assert_equal({ "name" => "x", "color" => "#000000" }, transport.last.json)
  end
end
