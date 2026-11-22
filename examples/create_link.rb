# frozen_string_literal: true

# Create a link in your first workspace, read it back and print its clicks.
#
#   SHORTN_API_KEY=sk_live_... ruby examples/create_link.rb

require "shortn/sdk"

shortn = Shortn::SDK::Client.new(api_key: ENV.fetch("SHORTN_API_KEY"))

workspace = shortn.workspaces.list.fetch("data").first
link = shortn.links.create(
  url: "https://example.com/pricing",
  title: "Pricing",
  workspace_public_id: workspace.fetch("public_id"),
  utm_source: "newsletter",
  utm_medium: "email",
  utm_campaign: "spring_launch"
)

details = shortn.links.get(link.fetch("public_id")).fetch("data")
clicks = shortn.analytics.link(link.fetch("public_id"))

puts "#{link['short_url']} -> #{details['original_url']} (#{clicks['total_clicks']} clicks)"
