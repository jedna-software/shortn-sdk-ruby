# frozen_string_literal: true

# Record a test lead and sale for a click, then read the test events back.
#
#   SHORTN_API_KEY=sk_live_... SHORTN_CLICK_ID=clk_... ruby examples/track_conversions.rb

require "securerandom"
require "shortn/sdk"

shortn = Shortn::SDK::Client.new(api_key: ENV.fetch("SHORTN_API_KEY"))
click_id = ENV.fetch("SHORTN_CLICK_ID")
order = "order_#{SecureRandom.hex(4)}"

begin
  shortn.conversions.track_lead(
    click_id: click_id,
    event_name: "Sign up",
    lead_category: "signup",
    idempotency_key: "signup_#{order}",
    test_mode: true
  )
  sale = shortn.conversions.track_sale(
    click_id: click_id,
    amount_cents: 4900,
    currency: "EUR",
    invoice_id: order,
    test_mode: true
  )
  puts "sale #{sale.dig('event', 'public_id')}"
rescue Shortn::SDK::APIError => e
  warn "#{e.status} #{e.code}: #{e.message} #{e.hint}"
  exit 1
end

shortn.conversions.events(environment: "test", limit: 5).fetch("data").each do |event|
  puts "#{event['event_type']} #{event['event_name']} #{event['occurred_at']}"
end
