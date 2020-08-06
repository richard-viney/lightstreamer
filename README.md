# Ruby Lightstreamer Client Gem

[![Gem][gem-badge]][gem-link]
[![Build Status][ci-badge]][ci-link]
[![Documentation][documentation-badge]][documentation-link]
[![License][license-badge]][license-link]

Easily interface with a Lightstreamer service from Ruby with this gem, either directly through code or by using the
provided command-line client. Written against the
[official API specification](http://www.lightstreamer.com/docs/client_generic_base/Network%20Protocol%20Tutorial.pdf).

Includes support for:

- Streaming and polling connections
- All subscription modes: command, distinct, merge and raw
- Automatic management of table content when in command mode
- Silent subscriptions
- Item snapshots and end-of-snapshot notifications
- Unfiltered subscriptions and overflow notifications
- Performing multiple subscription actions in a single request
- Synchronous and asynchronous message sending
- Detailed error reporting and error handling callbacks

## License

Licensed under the MIT license. You must read and agree to its terms to use this software.

## Installation

Install the latest version of the `lightstreamer` gem with the following command:

```
$ gem install lightstreamer
```

## Usage — Library

The two primary classes that make up the public API are:

- [`Lightstreamer::Session`](http://www.rubydoc.info/github/richard-viney/lightstreamer/main/Lightstreamer/Session)
- [`Lightstreamer::Subscription`](http://www.rubydoc.info/github/richard-viney/lightstreamer/main/Lightstreamer/Subscription)

The following code demonstrates how to create a Lightstreamer session, build a subscription, then use a thread-safe
queue to print streaming output as it arrives.

```ruby
require 'lightstreamer'

# Create a new session that connects to the Lightstreamer demo server
session = Lightstreamer::Session.new server_url: 'http://push.lightstreamer.com',
                                     adapter_set: 'DEMO', username: '', password: ''

# Add a simple error handler that just raises the error and so terminates the application
session.on_error do |error|
  raise error
end

# Connect the session
session.connect

# Create a new subscription that subscribes to thirty items and to four fields on each item
subscription = session.build_subscription data_adapter: 'QUOTE_ADAPTER', mode: :merge,
                                          items: (1..30).map { |i| "item#{i}" },
                                          fields: [:ask, :bid, :stock_name, :time]

# Create a thread-safe queue
queue = Queue.new

# When new data becomes available for the subscription it will be put on the queue. This callback
# will be run on a worker thread.
subscription.on_data do |subscription, item_name, item_data, new_data|
  queue.push item_data
end

# Start streaming data for the subscription and request an initial snapshot
subscription.start snapshot: true

# Print new data as soon as it becomes available on the queue
loop do
  data = queue.pop
  puts "#{data[:time]} - #{data[:stock_name]} - bid: #{data[:bid]}, ask: #{data[:ask]}"
end
```

## Usage — Command-Line Client

This gem provides a simple command-line client that can connect to a Lightstreamer server and display
live streaming output for a set of items and fields.

To stream data from Lightstreamer's demo server run the following command:

```
lightstreamer --server-url http://push.lightstreamer.com --adapter-set DEMO \
              --data-adapter QUOTE_ADAPTER --mode merge --snapshot \
              --items item1 item2 item3 item4 item5 --fields ask bid stock_name
```

To see the full list of available options for the command-line client run the following command:

```
lightstreamer help stream
```

## Documentation

API documentation is available [here](http://www.rubydoc.info/github/richard-viney/lightstreamer/main).

## Contributors

Gem created by Richard Viney. All contributions welcome.

[gem-link]: https://rubygems.org/gems/lightstreamer
[gem-badge]: https://badge.fury.io/rb/lightstreamer.svg
[ci-link]: https://github.com/richard-viney/lightstreamer/actions
[ci-badge]: https://github.com/richard-viney/lightstreamer/workflows/ci/badge.svg?branch=main
[documentation-link]: https://inch-ci.org/github/richard-viney/lightstreamer?branch=main
[documentation-badge]: https://inch-ci.org/github/richard-viney/lightstreamer.svg?branch=main
[license-link]: https://github.com/richard-viney/lightstreamer/blob/main/LICENSE.md
[license-badge]: https://img.shields.io/badge/license-MIT-blue.svg
