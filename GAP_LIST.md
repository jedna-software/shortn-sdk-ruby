# Gap list

## Covered

All 50 API-key and public routes of `/api/v1` that a server can call:

- links: list, get, create, update, delete (suspend), enable, A/B winner
- analytics: link totals
- workspaces: list, get
- tags, UTM templates, destinations, teams: list, create, update, delete (and
  get for tags and teams)
- custom domains: list, add, verify, delete
- report and alert rules: list, get, create, update, delete
- conversions: track and validate leads, sales and refunds; summary,
  attribution, timeline, events
- public helpers without a key: URL validation, QR codes, plan catalog

## Left out on purpose

- `POST /links` without a key and `GET /links/{code}/analytics`: both need a
  browser human check (`X-Turnstile-Token`), so a server can't call them. With a
  key, use `links.create` and `analytics.link`.

## Behaviour to know

- Test mode and refunds (by design): test-mode events are never
  deduplicated, so a repeated `idempotency_key` with `test_mode: true` records
  a new event (the SDK therefore never retries test-mode conversions), and a
  test-mode refund finds only live sales, answering
  `404 conversion_sale_not_found` for a test sale.
- `create_rule` ignores `enabled`: a new rule is always enabled; pause it with
  `update_rule`.
- `analytics.link` reads no query parameters.

## Not yet

- Response headers on success (`X-RateLimit-*`, `X-Analytics-As-Of`) are not
  returned by the resource methods; `client.request_raw` exposes them.
- Pagination helpers (iterate `links.list` / `conversions.events` by
  `next_offset`).
- Typed value objects for callers who prefer objects over Hashes.
- YARD-generated API docs.
