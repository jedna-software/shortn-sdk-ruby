# Contributing

Thanks for helping improve the Shortn Link Ruby SDK.

## Development

```sh
bundle config set --local path vendor/bundle
bundle install
bundle exec rake test
gem build shortn-sdk.gemspec
```

Unit tests use a mocked transport and run offline. The live smoke test
(`bundle exec rake smoke`) is opt-in: it is skipped unless `SHORTN_API_KEY` and
`SHORTN_BASE_URL` are set, and it refuses production. Run it only against a
test instance with a test key.

## Pull requests

- Keep changes focused.
- Add a unit test for every new method: HTTP method, path, query and body.
- Update README, GAP_LIST and CHANGELOG when behaviour changes.
- Do not commit secrets or real customer data.
