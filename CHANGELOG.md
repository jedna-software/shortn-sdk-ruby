# Changelog

## 0.1.0 - 2026-11-22

First release.

- `Shortn::SDK::Client` for the public API at `<base_url>/api/v1`, with API-key
  authentication (`Authorization: Bearer`), configurable base URL, timeout,
  retry policy, user agent suffix and HTTP transport.
- 50 methods covering the API: `links` (list, get, create, update, delete,
  enable, set_ab_winner), `analytics.link`, `workspaces`, `tags`,
  `utm_templates`, `destinations`, `teams`, `domains`, `reports` rules,
  `conversions` (track and validate leads, sales and refunds; summary,
  attribution, timeline, events) and the key-less `public` helpers
  (validate_url, qr_code, plans).
- Responses are the API's JSON as plain Hashes, so new fields need no release.
- `APIError` carries status, code, message, hint, field, details, request id,
  parsed and raw body, and headers.
- Request bodies are encoded in the forms the API parses: `Time`/`DateTime`
  as UTC RFC 3339 (`2026-01-01T00:00:00Z`), `Date` as midnight UTC,
  `BigDecimal`/`Rational` as plain decimal Strings, and a numeric `amount` as a
  decimal String (`19.99` => `"19.99"`). Times are
  converted without mutating the caller's object, so frozen Times work.
- Query booleans are sent as `1`/`0` (the QR endpoint keeps `true`/`false`).
- `base_url` is validated in `Client.new` (http or https with a host;
  `ConfigurationError` otherwise).
- Retries on 429, 503 and transient network errors (timeouts, refused or reset
  connections, DNS, TLS other than certificate failures) for GET, PUT, DELETE
  and live conversion POSTs with an `idempotency_key`, honouring `Retry-After`
  and raising when it exceeds `max_retry_after`. Test-mode conversions are
  never retried, other exceptions propagate unchanged and unretried, and
  Net::HTTP's own automatic retry is off, so `retry_options: false` sends each
  request once.
- Offline unit tests for every method and an opt-in live smoke test.
