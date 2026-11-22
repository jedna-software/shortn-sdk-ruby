# frozen_string_literal: true

# The key-less helpers: validate a URL, draw its QR code, list the plans.
#
#   ruby examples/public_helpers.rb

require "shortn/sdk"

shortn = Shortn::SDK::Client.new

validation = shortn.public.validate_url("example.com/pricing")
raise(validation["error"] || "URL is not valid") unless validation["valid"]

png = shortn.public.qr_code(url: validation.fetch("normalized"), format: "png")
File.binwrite("pricing-qr.png", png)

plans = shortn.public.plans.fetch("plans")
puts "#{validation['normalized']}: QR code saved (#{png.bytesize} bytes); plans: #{plans.keys.join(', ')}"
