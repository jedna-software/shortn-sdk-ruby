# frozen_string_literal: true

# Live smoke test against a Shortn instance. Opt-in: skipped unless
# SHORTN_API_KEY and SHORTN_BASE_URL are set. Never run it against
# production with a test key.
#
#   SHORTN_API_KEY=...                 key with every scope, account-wide
#   SHORTN_BASE_URL=https://staging.example.com
#   SHORTN_SMOKE_WORKSPACE=<workspace public id to create things in>
#   SHORTN_SMOKE_CLICK_ID=<a click on a conversion-enabled link>
#
#   bundle exec rake smoke
#
# Everything it creates has a random suffix and is removed again, also when
# a step fails. Links can't be deleted through the API, so the smoke link is
# suspended instead.

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "securerandom"
require "time"
require "minitest/autorun"
require "shortn/sdk"

class SmokeTest < Minitest::Test
  PRODUCTION_HOSTS = %w[app.shortn.link].freeze

  def setup
    @api_key = ENV.fetch("SHORTN_API_KEY", "")
    @base_url = ENV.fetch("SHORTN_BASE_URL", "")
    skip "set SHORTN_API_KEY and SHORTN_BASE_URL to run the smoke test" if @api_key.empty? || @base_url.empty?
    host = URI.parse(@base_url).host.to_s.downcase
    flunk "refusing to run the smoke test against production (#{host})" if PRODUCTION_HOSTS.include?(host)

    @workspace = ENV.fetch("SHORTN_SMOKE_WORKSPACE", "")
    skip "set SHORTN_SMOKE_WORKSPACE" if @workspace.empty?
    @suffix = SecureRandom.hex(3)
    @client = Shortn::SDK::Client.new(
      api_key: @api_key,
      base_url: @base_url,
      user_agent: "smoke-test",
      retry_options: Shortn::SDK::RetryOptions.new(max_retries: 4, initial_delay: 1)
    )
  end

  attr_reader :client

  def test_workspaces_and_public_helpers
    workspaces = client.workspaces.list.fetch("data")
    assert(workspaces.any? { |w| w["public_id"] == @workspace }, "the smoke workspace is listed")
    assert_equal @workspace, client.workspaces.get(@workspace).fetch("data").fetch("public_id")

    keyless = Shortn::SDK::Client.new(base_url: @base_url)
    validation = keyless.public.validate_url("example.com/sdk-smoke-ruby")
    assert_equal true, validation["valid"]
    assert_equal "https://example.com/sdk-smoke-ruby", validation["normalized"]
    refute keyless.public.validate_url("not a url")["valid"]

    plans = keyless.public.plans.fetch("plans")
    assert plans.key?("free"), "the plan catalog lists free"

    png = keyless.public.qr_code(url: "https://example.com/sdk-smoke-ruby", format: "png")
    refute_empty png
    assert png.start_with?("\x89PNG".b), "QR code is a PNG"
  end

  def test_links_lifecycle
    link_id = nil
    created = client.links.create(
      url: "https://example.com/sdk-smoke-ruby",
      title: "SDK smoke ruby #{@suffix}",
      workspace_public_id: @workspace
    )
    link_id = created.fetch("public_id")
    refute_empty created.fetch("short_code")

    link = client.links.get(link_id).fetch("data")
    assert_equal link_id, link["public_id"]
    assert_equal @workspace, link["workspace_public_id"]

    client.links.update(link_id, title: "SDK smoke ruby #{@suffix} renamed")
    assert_equal "SDK smoke ruby #{@suffix} renamed", client.links.get(link_id).fetch("data").fetch("title")

    listed = client.links.list(limit: 100).fetch("data")
    assert(listed.any? { |l| l["public_id"] == link_id }, "the new link is listed")

    analytics = client.analytics.link(link_id)
    assert_equal 0, analytics.fetch("total_clicks")
  ensure
    client.links.delete(link_id) if link_id
  end

  def test_tags_lifecycle
    tag_id = nil
    tag = client.tags.create(@workspace, name: "sdk-rb-#{@suffix}", color: "#3b82f6")
    tag_id = tag.fetch("public_id")
    assert_equal "sdk-rb-#{@suffix}", client.tags.get(tag_id).fetch("name")
    assert_equal "sdk-rb2-#{@suffix}", client.tags.update(tag_id, name: "sdk-rb2-#{@suffix}").fetch("name")
    tags = client.tags.list(@workspace).fetch("tags") || []
    assert(tags.any? { |t| t["public_id"] == tag_id }, "the new tag is listed")
    client.tags.delete(tag_id)
    tag_id = nil
  ensure
    client.tags.delete(tag_id) if tag_id
  end

  def test_utm_templates_lifecycle
    template_id = nil
    created = client.utm_templates.create(@workspace, name: "SDK smoke ruby #{@suffix}", utm_source: "sdk", utm_medium: "smoke")
    template_id = created.fetch("data").fetch("public_id")
    updated = client.utm_templates.update(template_id, name: "SDK smoke ruby #{@suffix} v2", utm_source: "sdk", utm_medium: "smoke-2")
    assert_equal "smoke-2", updated.fetch("data").fetch("utm_medium")
    templates = client.utm_templates.list(@workspace).fetch("data")
    assert(templates.any? { |t| t["public_id"] == template_id }, "the new template is listed")
    deleted = client.utm_templates.delete(template_id, links: "keep")
    template_id = nil
    assert_equal true, deleted.fetch("data").fetch("deleted")
  ensure
    client.utm_templates.delete(template_id) if template_id
  end

  def test_teams_lifecycle
    slug = nil
    created = client.teams.create(@workspace, name: "SDK smoke ruby #{@suffix}", description: "temporary")
    slug = created.fetch("slug")
    team = client.teams.get(slug, workspace: @workspace)
    assert_equal created.fetch("public_id"), team.fetch("public_id")
    updated = client.teams.update(slug, { description: "temporary, renamed" }, workspace: @workspace)
    assert_equal "temporary, renamed", updated.fetch("description")
    teams = client.teams.list(@workspace).fetch("teams") || []
    assert(teams.any? { |t| t["slug"] == slug }, "the new team is listed")
    assert_equal true, client.teams.delete(slug, workspace: @workspace).fetch("success")
    slug = nil
  ensure
    client.teams.delete(slug, workspace: @workspace) if slug
  end

  def test_destinations_lifecycle
    destination_id = nil
    created = client.destinations.create(
      @workspace,
      name: "SDK smoke ruby #{@suffix}",
      type: "webhook",
      config: { webhook_url: "https://example.com/hooks/sdk-smoke" }
    )
    destination_id = created.fetch("public_id")
    updated = client.destinations.update(@workspace, destination_id, name: "SDK smoke ruby #{@suffix} v2", type: "webhook")
    assert_equal true, updated.fetch("success")
    listed = client.destinations.list(@workspace)
    match = listed.find { |d| d["public_id"] == destination_id }
    assert match, "the new destination is listed"
    assert_equal "SDK smoke ruby #{@suffix} v2", match["name"]
    assert_equal true, client.destinations.delete(@workspace, destination_id).fetch("success")
    destination_id = nil
  ensure
    client.destinations.delete(@workspace, destination_id) if destination_id
  end

  # A weekly report with no destinations, first run months away, paused right
  # after creation: it can't send anything. The create endpoint ignores
  # `enabled`, so pausing is a separate update.
  def test_report_rules_lifecycle
    rule_id = nil
    created = client.reports.create_rule(
      workspace_public_id: @workspace,
      report_type: "custom_builder_v1",
      schedule_type: "every_x",
      interval_seconds: 604_800,
      initial_run_at: (Time.now.utc + (300 * 86_400)).strftime("%Y-%m-%dT%H:%M:%SZ"),
      report_name: "SDK smoke ruby #{@suffix}",
      destination_public_ids: [],
      definition_json: {
        version: "custom_builder.v1",
        trigger: "scheduled",
        sections: [{ id: "total_clicks", order: 1, settings: { window: "7d" } }],
        options: { locale: "en-US" }
      }
    ).fetch("data")
    rule_id = created.fetch("public_id")

    paused = client.reports.update_rule(rule_id, enabled: false).fetch("data")
    assert_equal false, paused.fetch("enabled")

    rule = client.reports.get_rule(rule_id).fetch("data")
    assert_equal @workspace, rule.fetch("workspace_public_id")
    assert_equal [], rule.fetch("destinations") || []

    renamed = client.reports.update_rule(rule_id, report_name: "SDK smoke ruby #{@suffix} v2").fetch("data")
    assert_equal false, renamed.fetch("enabled")

    rules = client.reports.list_rules(workspace_public_id: @workspace, schedule_types: ["every_x"]).fetch("data")
    assert(rules.any? { |r| r["public_id"] == rule_id }, "the new rule is listed")

    client.reports.delete_rule(rule_id)
    rule_id = nil
  ensure
    client.reports.delete_rule(rule_id) if rule_id
  end

  def test_domains_list
    assert_kind_of Array, client.domains.list.fetch("data")
  end

  def test_conversions_in_test_mode
    click_id = ENV.fetch("SHORTN_SMOKE_CLICK_ID", "")
    skip "set SHORTN_SMOKE_CLICK_ID" if click_id.empty?
    run = "sdk-smoke-ruby-#{SecureRandom.hex(6)}"
    invoice = "#{run}-inv"

    lead = { click_id: click_id, idempotency_key: "#{run}-lead", event_name: "SDK smoke lead", lead_category: "signup", test_mode: true }
    sale = { click_id: click_id, idempotency_key: "#{run}-sale", invoice_id: invoice, amount_cents: 1000, currency: "EUR", test_mode: true }
    refund = { invoice_id: invoice, refund_id: "#{run}-refund", idempotency_key: "#{run}-refund", amount_cents: 400, test_mode: true }

    assert_equal true, client.conversions.validate_lead(lead).fetch("valid")
    assert_equal true, client.conversions.validate_sale(sale).fetch("valid")

    tracked_lead = client.conversions.track_lead(lead)
    assert_equal "lead", tracked_lead.fetch("type")
    assert_equal true, tracked_lead.fetch("event").fetch("is_test")

    tracked_sale = client.conversions.track_sale(sale)
    assert_equal "sale", tracked_sale.fetch("type")
    assert_equal 1000, tracked_sale.fetch("event").fetch("amount_cents")

    # By design, a refund only finds live sales, so a test-mode refund of a
    # test-mode sale answers 404 conversion_sale_not_found. Accept that answer
    # (the request and the error mapping are still exercised).
    expected_test_refund = lambda do |error|
      raise error unless error.status == 404 && error.code == "conversion_sale_not_found" && error.field == "invoice_id"

      warn "smoke: expected (by design): a test-mode refund finds only live sales (#{error.code})"
    end
    begin
      assert_equal true, client.conversions.validate_refund(refund).fetch("valid")
      assert_equal "refund", client.conversions.track_refund(refund).fetch("type")
    rescue Shortn::SDK::APIError => e
      expected_test_refund.call(e)
      e2 = assert_raises(Shortn::SDK::APIError) { client.conversions.track_refund(refund) }
      expected_test_refund.call(e2)
    end

    # By design, test-mode events are never deduplicated ("public API test
    # requests remain repeatable"), so a repeat records a second test event
    # instead of answering duplicate: true as live events do. That is also
    # why the SDK never retries a test-mode conversion.
    repeat = client.conversions.track_lead(lead).fetch("event")
    unless repeat.fetch("duplicate")
      refute_equal tracked_lead.fetch("event").fetch("public_id"), repeat.fetch("public_id")
      warn "smoke: expected (by design): a test-mode lead with a repeated idempotency_key is recorded again"
    end

    assert client.conversions.summary.fetch("data").key?("leads")
    assert_kind_of Array, client.conversions.attribution(environment: "test", limit: 5).fetch("data")
    assert_kind_of Array, client.conversions.timeline(environment: "test", interval: "day").fetch("data")
    events = client.conversions.events(environment: "test", limit: 20).fetch("data")
    assert(events.any? { |e| e["public_id"] == tracked_sale.fetch("event").fetch("public_id") }, "the test sale is listed")
  end
end
