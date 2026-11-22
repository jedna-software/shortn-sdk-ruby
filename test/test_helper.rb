# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "json"
require "time"
require "uri"
require "minitest/autorun"
require "shortn/sdk"

# Records requests and answers them from a queue of canned responses.
# A response is [status, body] or [status, body, headers]; a body that isn't a
# String is sent as JSON. An Exception instance in the queue is raised.
class MockTransport
  Request = Struct.new(:method, :url, :headers, :body, :timeout, keyword_init: true) do
    def uri
      URI.parse(url)
    end

    def path
      uri.path
    end

    # Raw (still escaped) path, as sent on the wire.
    def raw_path
      url.sub(%r{\Ahttps?://[^/]+}, "").split("?", 2).first
    end

    def query
      URI.decode_www_form(uri.query.to_s).to_h
    end

    def json
      body.nil? ? nil : JSON.parse(body)
    end
  end

  attr_reader :requests

  def initialize(*responses)
    @responses = responses
    @requests = []
  end

  def call(method, url, headers, body, timeout)
    @requests << Request.new(method: method, url: url, headers: headers.dup, body: body, timeout: timeout)
    response = @responses.shift || [200, {}]
    raise response if response.is_a?(Exception)

    status, payload, headers = response
    [status, headers || {}, payload.is_a?(String) ? payload : JSON.generate(payload)]
  end

  def last
    @requests.last
  end
end

module ClientHelpers
  BASE = "https://api.example.test"

  def build_client(*responses, api_key: "sk_live_test", retry_options: nil, **options)
    @transport = MockTransport.new(*responses)
    @sleeps = []
    Shortn::SDK::Client.new(
      api_key: api_key,
      base_url: BASE,
      transport: @transport,
      retry_options: retry_options || Shortn::SDK::RetryOptions.new(max_retries: 2, initial_delay: 0.1, jitter: false),
      sleeper: ->(seconds) { @sleeps << seconds },
      **options
    )
  end

  attr_reader :transport, :sleeps
end
