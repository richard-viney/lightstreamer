module Lightstreamer
  module CLI
    # Implements the `lightstreamer stream` command.
    class Main < Thor
      desc 'stream', 'Streams a set of items and fields from a Lightstreamer server and prints the live output'

      option :server_url, required: true, desc: 'The URL of the Lightstreamer server'
      option :username, desc: 'The username for the session'
      option :password, desc: 'The password for the session'
      option :adapter_set, desc: 'The name of the adapter set for the session'
      option :polling_enabled, type: :boolean, desc: 'Whether to poll instead of using long-running stream connections'
      option :requested_maximum_bandwidth, type: :numeric, desc: 'The requested maximum bandwidth, in kbps'

      option :data_adapter, desc: 'The name of the data adapter to stream data from'
      option :items, type: :array, required: true, desc: 'The names of the item(s) to stream'
      option :fields, type: :array, required: true, desc: 'The field(s) to stream'
      option :mode, enum: %w[command distinct merge raw], desc: 'The operation mode'
      option :selector, desc: 'The selector for table items'
      option :snapshot, type: :boolean, desc: 'Whether to send snapshot data for the items'
      option :maximum_update_frequency, desc: 'The maximum number of updates per second for each item'

      def stream
        prepare_stream

        puts "Session ID: #{@session.session_id}"

        loop do
          data = @queue.pop

          if data.is_a? Lightstreamer::LightstreamerError
            puts "Error: #{data}"
            break
          end

          puts data
        end
      end

      private

      def prepare_stream
        @queue = Queue.new

        create_session
        create_subscription
      end

      def create_session
        @session = Lightstreamer::Session.new session_options
        @session.connect
        @session.on_message_result { |sequence, numbers, error| on_message_result sequence, numbers, error }
        @session.on_error { |error| on_error error }
      end

      def create_subscription
        subscription = @session.build_subscription subscription_options

        subscription.on_data { |sub, item_name, item_data, new_data| on_data sub, item_name, item_data, new_data }
        subscription.on_overflow { |sub, item_name, overflow_size| on_overflow sub, item_name, overflow_size }
        subscription.on_end_of_snapshot { |sub, item_name| on_end_of_snapshot sub, item_name }

        subscription.start
      end

      def session_options
        { server_url: options[:server_url], username: options[:username], password: options[:password],
          adapter_set: options[:adapter_set], requested_maximum_bandwidth: options[:requested_maximum_bandwidth],
          polling_enabled: options[:polling_enabled] }
      end

      def subscription_options
        { items: options[:items], fields: options[:fields], mode: options[:mode], data_adapter: options[:data_adapter],
          maximum_update_frequency: options[:maximum_update_frequency], selector: options[:selector],
          snapshot: options[:snapshot] }
      end

      def on_data(_subscription, item_name, _item_data, new_data)
        @queue.push "#{item_name} - #{new_data.map { |key, value| "#{key}: #{value}" }.join ', '}"
      end

      def on_overflow(_subscription, item_name, overflow_size)
        @queue.push "Overflow of size #{overflow_size} on item #{item_name}"
      end

      def on_message_result(sequence, numbers, error)
        @queue.push "Message result for #{sequence}#{numbers} = #{error ? error.class : 'Done'}"
      end

      def on_end_of_snapshot(_subscription, item_name)
        @queue.push "End of snapshot for item #{item_name}"
      end

      def on_error(error)
        @queue.push error
      end
    end
  end
end
