module Lightstreamer
  module CLI
    # Implements the `lightstreamer stream` command.
    class Main < Thor
      desc 'stream', 'Streams a set of items and fields from a Lightstreamer server and prints the live output'

      option :server_url, required: true, desc: 'The URL of the Lightstreamer server'
      option :username, desc: 'The username for the session'
      option :password, desc: 'The password for the session'
      option :adapter_set, desc: 'The name of the adapter set for the session'
      option :adapter, desc: 'The name of the data adapter to stream data from'
      option :items, type: :array, required: true, desc: 'The names of the item(s) to stream'
      option :fields, type: :array, required: true, desc: 'The field(s) to stream'
      option :mode, enum: %w(distinct merge), default: :merge, desc: 'The operation mode'
      option :selector, desc: 'The selector for table items'
      option :maximum_update_frequency, type: :numeric, desc: 'The maximum number of updates per second for each item'

      def stream
        session = create_session
        session.connect

        @queue = Queue.new

        session.subscribe create_subscription

        loop do
          puts @queue.pop unless @queue.empty?

          raise session.error if session.error
        end
      end

      private

      # Creates a new session from the specified options.
      def create_session
        Lightstreamer::Session.new server_url: options[:server_url], username: options[:username],
                                   password: options[:password], adapter_set: options[:adapter_set]
      end

      # Creates a new subscription from the specified options.
      def create_subscription
        subscription = Lightstreamer::Subscription.new subscription_options

        subscription.add_data_callback(&method(:subscription_data_callback))

        subscription
      end

      def subscription_options
        {
          items: options[:items], fields: options[:fields], mode: options[:mode], adapter: options[:adapter],
          maximum_update_frequency: options[:maximum_update_frequency], selector: options[:selector]
        }
      end

      def subscription_data_callback(_subscription, item_name, _item_data, new_values)
        @queue.push "#{item_name} - #{new_values.map { |key, value| "#{key}: #{value}" }.join ', '}"
      end
    end
  end
end
