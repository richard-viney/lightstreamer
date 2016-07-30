# Lightstreamer Changelog

### 0.7 — Unreleased

- Refactored subscription handling to be more object-oriented, subscriptions are now created using
  `Lightstreamer::Session#build_subscription` and there are new `#start`, `#stop` and `#unsilence` methods on
  `Lightstreamer::Subscription` that control a subscription's current state
- Added `Lightstreamer::Session#bulk_subscription_start` for efficiently starting a number of subscriptions at once
- Added support for setting initial subscription data
- Added support for changing a subscription's requested update frequency after it has been started
- Added support for setting and altering the session's requested maximum bandwidth
- Added `Lightstreamer::Session#session_id` to query the session ID
- Added `Lightstreamer::Subscription#active` to query whether the subscription is active and streaming data
- Stream connection bind requests are now sent to the custom control address if one was specified in the stream
  connection header
- The command-line client now prints the session ID following successful connection

### 0.6 — July 27, 2016

- Switched to the `excon` HTTP library
- Moved all subclasses of `Lightstreamer::LightstreamerError` into the `Lightstreamer::Errors` module
- Replaced `Lightstreamer::Errors::RequestError` with `Lightstreamer::Errors::ConnectionError`

### 0.5 — July 26, 2016

- Improved handling of `:distinct` subscriptions
- Subscriptions can now request an unfiltered stream and handle any overflow messages from the server using
  `Lightstreamer::Subscription#on_overflow`
- Added a connection timeout to all requests
- Unhandled exceptions in subscription data callbacks are no longer automatically rescued
- Improved API documentation
- Renamed `Lightstreamer::Subscription#add_data_callback` to `Lightstreamer::Subscription#on_data`
- Replaced `Lightstreamer::Subscription#remove_data_callback` with `Lightstreamer::Subscription#clear_callbacks`
- Renamed `Lightstreamer::Error` class to `Lightstreamer::LightstreamerError`
- Renamed `Lightstreamer::Subscription#retrieve_item_data` to `Lightstreamer::Subscription#item_data`
- Removed `Lightstreamer::Subscription#clear_data_for_item`

### 0.4 — July 25, 2016

- Added support for specifying a subscription's selector and maximum update frequency
- Added `Lightstreamer::Session#force_rebind` which asks the server to send a `LOOP` message so the client has to rebind 
  using a new stream connection
- Added validation of the arguments for control connection subscription requests
- All error classes now inherit from `Lightstreamer::Error` and the different Lightstreamer errors that can occur are
  separated into a variety of new subclasses
- Removed `Lightstreamer::ProtocolError`
- `Lightstreamer::Session#disconnect` now properly terminates the session with the server by sending the relevant
  control request
- The reason why a session terminated can now be queried using `Lightstreamer::Session#error`
- Fixed handling of `nil` subscription adapters
- Correctly handle when an `END` message is received on the stream connection
- All valid error responses from session create and bind requests are now handled correctly
- Unhandled exceptions on the internal worker threads now cause the application to terminate

### 0.3 — July 24, 2016

- Seamlessly rebind the stream connection when a `LOOP` message is received
- Correctly handle UTF-16 escape sequences in stream data, including UTF-16 surrogate pairs
- Switched to the `typhoeus` library for HTTP support
- Improved error handling on the stream thread
- Added `Lightstreamer::Session#connected?`

### 0.2 — July 23, 2016

- Added complete test suite
- Added `Lightstreamer::Session#subscribed?` and `Lightstreamer::Session#disconnect`
- Fixed `Lightstreamer::ProtocolError#code` not being set
- Renamed the command-line client's `--address` option to `--server-url`

### 0.1 — July 22, 2016

- Initial release
