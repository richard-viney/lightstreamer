# Lightstreamer Changelog

### 0.3 — Unreleased

- Seamlessly rebind the stream connection when a `LOOP` message is received
- Correctly handle UTF-16 escape sequences in stream data, including UTF-16 surrogate pairs

### 0.2 — July 23, 2016

- Added complete test suite
- Added `Lightstreamer::Session#subscribed?` and `Lightstreamer::Session#disconnect`
- Fixed `Lightstreamer::ProtocolError#code` not being set
- Renamed the command-line client's `--address` option to `--server-url`

### 0.1 — July 22, 2016

- Initial release
