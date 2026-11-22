# Shortn Link Ruby SDK

Ruby client for the [Shortn Link](https://shortn.link) public API
(`https://app.shortn.link/api/v1`): links, link analytics, workspaces, tags, UTM
templates, report destinations, teams, custom domains, report and alert rules,
conversions, and the key-less public helpers.

Use it from trusted server-side code only. Never ship a Shortn API key to a
browser, mobile app or any other client-controlled code.

- Ruby 3.1 or newer, no runtime dependencies (Net::HTTP and JSON from the
  standard library).
- Responses are plain Hashes and Arrays with string keys, exactly as the API
  sends them, so new API fields are available without an SDK release.
- API reference: [docs.shortn.link/docs/api](https://docs.shortn.link/docs/api/).

## Installation

```sh
gem install shortn-sdk
```

or in a Gemfile:

```ruby
gem "shortn-sdk"
```

```ruby
require "shortn/sdk"
```

## Quick start

```ruby
require "shortn/sdk"

shortn = Shortn::SDK::Client.new(api_key: ENV.fetch("SHORTN_API_KEY"))

workspace = shortn.workspaces.list["data"].first
link = shortn.links.create(
  url: "https://example.com/spring",
  title: "Spring campaign",
  workspace_public_id: workspace["public_id"],
  utm_source: "newsletter",
  utm_medium: "email"
)
puts link["short_url"]
```

Create a key under **Profile → API keys** in the app. Each key has scopes
(`links:read`, `links:write`, `conversions:write`, ...) and is either
account-wide or limited to one workspace; see
[authentication](https://docs.shortn.link/docs/api/authentication/).

## Configuration

```ruby
shortn = Shortn::SDK::Client.new(
  api_key: ENV.fetch("SHORTN_API_KEY"), # optional only for client.public
  base_url: "https://app.shortn.link",  # "/api/v1" is appended
  timeout: 10,                          # seconds (open, read, write)
  retry_options: Shortn::SDK::RetryOptions.new(max_retries: 3),
  user_agent: "my-app/1.4"              # appended to shortn-sdk-ruby/0.1.0
)
```

`transport:` replaces the HTTP layer (for tests or a different HTTP client).
It is any object with `call(method, url, headers, body, timeout)` returning
`[status, headers, body]`.

`base_url` must be an `http` or `https` URL with a host; anything else raises
`Shortn::SDK::ConfigurationError` from `Client.new`.

Methods take ids as positional arguments and request fields as a Hash, with
symbol or string keys, named as in the API docs (snake_case). The Hash is sent
with the same fields; the API refuses fields it doesn't know with
`400 unsupported_fields`. Values are converted to the forms the API parses:

- `Time` and `DateTime` become UTC RFC 3339 (`"2026-01-01T09:30:00Z"`), `Date`
  becomes midnight UTC (`"2026-01-01T00:00:00Z"`), for fields such as
  `occurred_at`, `starts_at` and `expires_at`.
- `BigDecimal` and `Rational` become plain decimal Strings (`"19.99"`).
- `amount` is a String such as `"19.99"`; an Integer, Float or BigDecimal
  given for `amount` is converted to one (`19.99` =>
  `"19.99"`, `20` => `"20"`). Other numeric fields are sent as numbers.

Query parameters you leave out (or set to `nil`) are not sent; Arrays are sent
comma-separated, `true`/`false` as `1`/`0`, and a `Time` as UTC RFC 3339.

## Resources

| Group | Methods |
|---|---|
| `links` | `list(query)`, `get(id)`, `create(params)`, `update(id, params)`, `delete(id)`, `enable(id)`, `set_ab_winner(id, params)` |
| `analytics` | `link(id, query)` |
| `workspaces` | `list`, `get(public_id)` |
| `tags` | `list(workspace_id, query)`, `create(workspace_id, params)`, `get(id)`, `update(id, params)`, `delete(id)` |
| `utm_templates` | `list(workspace_id, query)`, `create(workspace_id, params)`, `update(template_id, params)`, `delete(template_id, query)` |
| `destinations` | `list(workspace_id)`, `create(workspace_id, params)`, `update(workspace_id, destination_id, params)`, `delete(workspace_id, destination_id)` |
| `teams` | `list(workspace_id)`, `create(workspace_id, params)`, `get(slug, query)`, `update(slug, params, query)`, `delete(slug, query)` |
| `domains` | `list`, `create(params)`, `verify(id)`, `delete(id)` |
| `reports` | `list_rules(query)`, `get_rule(id)`, `create_rule(params)`, `update_rule(id, params)`, `delete_rule(id)` |
| `conversions` | `track_lead`, `validate_lead`, `track_sale`, `validate_sale`, `track_refund`, `validate_refund` (each `(params)`), `summary(query)`, `attribution(query)`, `timeline(query)`, `events(query)` |
| `public` (no key) | `validate_url(url)`, `qr_code(params)`, `plans` |

`query` arguments are optional everywhere.

### Links

```ruby
links = shortn.links.list(limit: 50, offset: 0)
links["data"].each { |l| puts "#{l['short_code']} #{l['clicks']}" }
next_offset = links["pagination"]["next_offset"]

link = shortn.links.get(public_id)["data"]
shortn.links.update(public_id, title: "Spring sale", url: "https://example.com/sale")
shortn.links.delete(public_id)     # suspends the link; history is kept
shortn.links.enable(public_id)
shortn.links.set_ab_winner(public_id, variant: "B")
```

### Analytics

```ruby
totals = shortn.analytics.link(public_id)
totals["total_clicks"]       # => 1280
totals["clicks_by_country"]  # => {"Germany" => 512, ...}
```

The endpoint reads no query parameters; `query` has no effect today.

### Workspaces

```ruby
shortn.workspaces.list["data"]
shortn.workspaces.get(workspace_id)["data"]
```

### Tags

```ruby
tag = shortn.tags.create(workspace_id, name: "Spring", color: "#14b8a6")
shortn.tags.list(workspace_id)["tags"]   # nil when there are none
shortn.tags.update(tag["public_id"], name: "Spring 2027")
shortn.tags.delete(tag["public_id"])
```

### UTM templates

```ruby
template = shortn.utm_templates.create(workspace_id, name: "Newsletter", utm_source: "newsletter", utm_medium: "email")["data"]
shortn.utm_templates.list(workspace_id, include_team_scoped: 1)["data"]
shortn.utm_templates.update(template["public_id"], name: "Newsletter", utm_source: "newsletter", utm_medium: "email", utm_campaign: "dec")
shortn.utm_templates.delete(template["public_id"], links: "keep")
```

### Destinations

```ruby
destination = shortn.destinations.create(workspace_id, name: "Ops inbox", type: "email", config: { to: ["ops@example.com"] })
shortn.destinations.list(workspace_id)   # an Array
shortn.destinations.update(workspace_id, destination["public_id"], name: "Ops", type: "email")
shortn.destinations.delete(workspace_id, destination["public_id"])
```

### Teams

```ruby
team = shortn.teams.create(workspace_id, name: "Paid Social")
shortn.teams.list(workspace_id)["teams"]
shortn.teams.get(team["slug"], workspace: workspace_id)
shortn.teams.update(team["slug"], { description: "Paid social links" }, workspace: workspace_id)
shortn.teams.delete(team["slug"], workspace: workspace_id)   # archives the team
```

A slug is unique only within its workspace; pass `workspace:` when the key
reaches several workspaces.

### Custom domains

```ruby
shortn.domains.list["data"]
domain = shortn.domains.create(domain: "go.example.com")["domain"]
shortn.domains.verify(domain["id"])
shortn.domains.delete(domain["id"])
```

Adding, verifying and deleting a domain need an account-wide key.

### Reports and alerts

```ruby
rules = shortn.reports.list_rules(workspace_public_id: workspace_id, schedule_types: ["every_x"])["data"]
rule = shortn.reports.get_rule(rules.first["public_id"])["data"]
shortn.reports.update_rule(rule["public_id"], enabled: false)
created = shortn.reports.create_rule(
  workspace_public_id: workspace_id,
  report_type: "custom_builder_v1",
  interval_seconds: 604_800,
  report_name: "Weekly traffic",
  destination_public_ids: [destination_id],
  definition_json: rule["definition"]
)["data"]
shortn.reports.delete_rule(created["public_id"])
```

A new rule is always enabled: `create_rule` ignores `enabled`. To create a
paused rule, create it and then call `update_rule(id, enabled: false)`.

### Conversions

Send events from your backend, with the click id the
[capture script](https://docs.shortn.link/docs/conversion-tracking/install-capture-script/)
stored on your site:

```ruby
shortn.conversions.track_lead(
  click_id: params[:snt_click_id],
  event_name: "Sign up",
  lead_category: "signup",
  idempotency_key: "signup_#{user.id}"
)

shortn.conversions.track_sale(
  click_id: params[:snt_click_id],
  amount_cents: 4900,   # hundredths of the main unit, whatever the currency
  currency: "EUR",
  invoice_id: invoice.number
)

shortn.conversions.track_refund(invoice_id: invoice.number, refund_id: refund.id, amount_cents: 1900)

# Or a decimal amount: a String such as "19.99" (numeric types are converted).
shortn.conversions.track_sale(click_id: params[:snt_click_id], amount: "19.99", currency: "EUR",
                              invoice_id: invoice.number, occurred_at: invoice.paid_at)

# Same checks, nothing recorded:
shortn.conversions.validate_sale(click_id: "clk_...", amount_cents: 4900, currency: "EUR", invoice_id: "inv_1")

shortn.conversions.summary["data"]
shortn.conversions.attribution(from: "2026-11-01", to: "2026-11-30", limit: 20)
shortn.conversions.timeline(interval: "week")
shortn.conversions.events(event_type: "sale", environment: "test")
```

Add `test_mode: true` to record test events, and read them back with
`environment: "test"`. Test events are never deduplicated: each request
records a new event, even with a repeated `idempotency_key`, and a test-mode
refund finds only live sales. Conversion events hold no customer profile; keep
personal data out of `event_name` and `metadata`.

### Public helpers (no API key)

```ruby
shortn = Shortn::SDK::Client.new   # no key needed

shortn.public.validate_url("example.com/menu")
# => {"valid" => true, "normalized" => "https://example.com/menu"}

png = shortn.public.qr_code(url: "https://shtnl.ink/abC12x9", format: "png", size: "download")
File.binwrite("menu-qr.png", png)   # a binary String

shortn.public.plans["plans"].keys   # => ["free", "starter", ...]
```

The client never sends its API key to these endpoints. Creating a link without
a key and the anonymous link preview are not in the SDK: they need a browser
human check. Use `links.create` and `analytics.link` with a key instead.

## Errors

Every non-2xx response raises `Shortn::SDK::APIError`:

```ruby
begin
  shortn.links.create(url: "https://example.com", title: "Example", custom_code: "spring")
rescue Shortn::SDK::APIError => e
  e.status      # => 409
  e.code        # => "custom_code_conflict" (nil for the few errors without one)
  e.message     # the API's "error" text
  e.hint        # extra guidance, when sent
  e.field       # details["field"], when sent
  e.details     # the details Hash, when sent
  e.request_id  # conversion intake errors (also the Shortn-Request-Id header)
  e.data        # the whole parsed body, e.g. e.data["feature"] on plan limits
  e.body        # the raw body
  e.headers     # response headers, lower-case names
  e.retry_after # seconds from Retry-After, if any
end
```

Other errors, all subclasses of `Shortn::SDK::Error`:

- `Shortn::SDK::NetworkError`: no response arrived (connection, DNS, TLS,
  timeout); the original exception is `#cause`.
- `Shortn::SDK::ConfigurationError`: `base_url` is not an http(s) URL, or an
  endpoint that needs a key was called on a client without one. Nothing is
  sent.

Any other exception a transport raises (an `ArgumentError`, a bug in a custom
transport) propagates unchanged and is not retried.

## Retries

The client retries on `429` and `503` responses and on transient network
errors (timeouts, refused or reset connections, DNS failures, TLS errors other
than a failed certificate check), waiting for `Retry-After` when the API sends
it and backing off exponentially otherwise. It retries only requests that are
safe to repeat:

- `GET`, `PUT` and `DELETE`;
- live conversion `POST`s that carry an `idempotency_key`, which the API
  records once per key.

Other `POST`s and `PATCH`es (creating a link, a tag, a rule...) are never
retried, and neither are test-mode conversions (`test_mode: true`): the API
doesn't deduplicate test events, so a retry would record a second one.
Net::HTTP's own automatic retry is switched off, so `retry_options: false`
sends every request exactly once. Defaults: 2 retries, 0.5 s initial delay,
factor 2, 8 s cap, ±20% jitter, and a `Retry-After` longer than 60 s raises
instead of waiting.

```ruby
Shortn::SDK::RetryOptions.new(max_retries: 4, initial_delay: 1, max_delay: 10, max_retry_after: 30)
Shortn::SDK::Client.new(api_key: key, retry_options: false)   # no retries
```

## Development

```sh
bundle config set --local path vendor/bundle
bundle install
bundle exec rake test     # offline unit tests
```

The smoke test runs against a live instance and is skipped unless
`SHORTN_API_KEY` and `SHORTN_BASE_URL` are set. It creates resources with a
random suffix in `SHORTN_SMOKE_WORKSPACE` and removes them again (the smoke
link is suspended, since links can't be deleted through the API). Point it at
a test instance, never at production:

```sh
SHORTN_API_KEY=... SHORTN_BASE_URL=https://test.example SHORTN_SMOKE_WORKSPACE=... \
SHORTN_SMOKE_CLICK_ID=clk_... bundle exec rake smoke
```

## License

MIT
