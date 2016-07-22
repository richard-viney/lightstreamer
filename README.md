# Ruby Lightstreamer Client Gem

[![Gem][gem-badge]][gem-link]
[![Build Status][travis-ci-badge]][travis-ci-link]
[![Test Coverage][test-coverage-badge]][test-coverage-link]
[![Code Climate][code-climate-badge]][code-climate-link]
[![Dependencies][dependencies-badge]][dependencies-link]
[![Documentation][documentation-badge]][documentation-link]
[![License][license-badge]][license-link]

Easily interface with a Lightstreamer service from Ruby. Written against the
[official API specification](http://www.lightstreamer.com/docs/client_generic_base/Network%20Protocol%20Tutorial.pdf).

## License

Licensed under the MIT license. You must read and agree to its terms to use this software.

## Installation

Install the latest version of the `lightstreamer` gem with the following command:

```
$ gem install lightstreamer
```

## Usage

```ruby
require 'lightstreamer'

# Create a new session that connects to a Lightstreamer demo server which needs no authentication
session = Lightstreamer::Session.new server_url: 'http://push.lightstreamer.com',
                                     adapter_set: 'DEMO', username: '', password: ''

# Connect the session
session.connect

# Create a new subscription that subscribes to five items and to four fields on each item
subscription = Lightstreamer::Subscription.new items: [:item1, :item2, :item3, :item4, :item5],
                                               fields: [:time, :stock_name, :bid, :ask],
                                               mode: :merge, adapter: 'QUOTE_ADAPTER'

# Create a thread-safe queue object
queue = Queue.new

# When new data becomes available for the subscription it will be put on the queue. This callback
# will be run on a worker thread.
subscription.add_data_callback do |subscription, item_name, item_data, new_values|
  queue.push item_data
end

# Activate the subscription
session.subscribe subscription

# The main thread now loops printing out new data as it becomes available on the queue
loop do
  data = queue.pop
  puts "#{data[:time]} - #{data[:stock_name]} - bid: #{data[:bid]}, ask: #{data[:ask]}"
end
```

## Documentation

API documentation is available [here](http://www.rubydoc.info/github/rviney/lightstreamer).

## Contributors

Gem created by Richard Viney. All contributions welcome.

[gem-link]: https://rubygems.org/gems/lightstreamer
[gem-badge]: https://badge.fury.io/rb/lightstreamer.svg
[travis-ci-link]: http://travis-ci.org/rviney/lightstreamer
[travis-ci-badge]: https://travis-ci.org/rviney/lightstreamer.svg?branch=master
[test-coverage-link]: https://codeclimate.com/github/rviney/lightstreamer/coverage
[test-coverage-badge]: https://codeclimate.com/github/rviney/lightstreamer/badges/coverage.svg
[code-climate-link]: https://codeclimate.com/github/rviney/lightstreamer
[code-climate-badge]: https://codeclimate.com/github/rviney/lightstreamer/badges/gpa.svg
[dependencies-link]: https://gemnasium.com/rviney/lightstreamer
[dependencies-badge]: https://gemnasium.com/rviney/lightstreamer.svg
[documentation-link]: https://inch-ci.org/github/rviney/lightstreamer
[documentation-badge]: https://inch-ci.org/github/rviney/lightstreamer.svg?branch=master
[license-link]: https://github.com/rviney/lightstreamer/blob/master/LICENSE.md
[license-badge]: https://img.shields.io/badge/license-MIT-blue.svg
