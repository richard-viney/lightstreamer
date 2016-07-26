module Lightstreamer
  # Describes a subscription that can be bound to a {Session} in order to consume its streaming data. A subscription is
  # described by the options passed to {#initialize}. Incoming data can be consumed by registering an asynchronous data
  # callback using {#on_data}, or by polling {#retrieve_item_data}. Subscriptions start receiving data once they are
  # attached to a session using {Session#subscribe}.
  class Subscription
    # The unique identification number of this subscription.
    #
    # @return [Fixnum]
    attr_reader :id

    # The names of the items to subscribe to.
    #
    # @return [Array]
    attr_reader :items

    # The names of the fields to subscribe to on the items.
    #
    # @return [Array]
    attr_reader :fields

    # The operation mode of this subscription.
    #
    # @return [:distinct, :merge]
    attr_reader :mode

    # The name of the data adapter from the Lightstreamer session's adapter set that should be used, or `nil` to use the
    # default data adapter.
    #
    # @return [String, nil]
    attr_reader :adapter

    # The selector for table items, or `nil` to specify no selector.
    #
    # @return [String, nil]
    attr_reader :selector

    # The maximum number of updates this subscription should receive per second. If this is set to zero, which is the
    # default, then there is no limit on the update frequency.
    #
    # @return [Float]
    attr_reader :maximum_update_frequency

    # Initializes a new Lightstreamer subscription with the specified options. This can then be passed to
    # {Session#subscribe} to activate the subscription on a Lightstreamer session.
    #
    # @param [Hash] options The options to create the subscription with.
    # @option options [Array] :items The names of the items to subscribe to. Required.
    # @option options [Array] :fields The names of the fields to subscribe to on the items. Required.
    # @option options [:distinct, :merge] :mode The operation mode of this subscription. Required.
    # @option options [String] :adapter The name of the data adapter from the Lightstreamer session's adapter set that
    #                 should be used. If `nil` then the default data adapter will be used.
    # @option options [String] :selector The selector for table items. Optional.
    # @option options [Float] :maximum_update_frequency The maximum number of updates this subscription should receive
    #                 per second. Defaults to zero which means there is no limit on the update frequency.
    def initialize(options)
      @id = self.class.next_id

      @items = options.fetch(:items)
      @fields = options.fetch(:fields)
      @mode = options.fetch(:mode).to_sym
      @adapter = options[:adapter]
      @selector = options[:selector]
      @maximum_update_frequency = options[:maximum_update_frequency] || 0.0

      @data_mutex = Mutex.new
      clear_data

      @on_data_callbacks = []
    end

    # Clears all current data stored for this subscription. New data will continue to be processed as it becomes
    # available.
    def clear_data
      @data_mutex.synchronize do
        @data = (0...items.size).map { { distinct: [], merge: {} }.fetch(mode) }
      end
    end

    # Clears the current data stored for the specified item. This is important to do when {#mode} is `:distinct` as
    # otherwise the incoming data will build up indefinitely.
    #
    # @param [String] item_name The name of the item to clear the current data for.
    def clear_data_for_item(item_name)
      index = @items.index item_name
      raise ArgumentError, 'Unrecognized item name' unless index

      @data_mutex.synchronize do
        @data[index] = { distinct: [], merge: {} }.fetch(mode)
      end
    end

    # Adds the passed block to the list of callbacks that will be run when new data for this subscription arrives. The
    # block will be called on a worker thread and so the code that is run by the block must be thread-safe. The
    # arguments passed to the block are `|subscription, item_name, item_data, new_values|`.
    #
    # @param [Proc] callback The callback that is to be run when new data arrives.
    def on_data(&callback)
      @data_mutex.synchronize { @on_data_callbacks << callback }
    end

    # Returns a copy of the current data of one of this subscription's items.
    #
    # @param [String] item_name The name of the item to return the current data for.
    #
    # @return [Hash, Array] A copy of the item data. Will be a `Hash` if {#mode} is `:merge`, and an `Array` if {#mode}
    #         is `:distinct`.
    def retrieve_item_data(item_name)
      index = @items.index item_name
      raise ArgumentError, 'Unrecognized item name' unless index

      @data_mutex.synchronize { @data[index].dup }
    end

    # Processes a line of stream data if it is relevant to this subscription. This method is thread-safe and is intended
    # to be called by the session's processing thread.
    #
    # @param [String] line The line of stream data to process.
    #
    # @return [Boolean] Whether the passed line of stream data was relevant to this subscription and was successfully
    #         processed by it.
    #
    # @private
    def process_stream_data(line)
      return true if overflow_message? line

      item_index, new_values = parse_stream_data line
      return false unless item_index

      @data_mutex.synchronize do
        data = @data[item_index]

        data << new_values if mode == :distinct
        data.merge!(new_values) if mode == :merge

        run_on_data_callbacks @items[item_index], data, new_values
      end

      true
    end

    # Returns the next unique subscription ID.
    #
    # @return [Fixnum]
    #
    # @private
    def self.next_id
      @next_id ||= 0
      @next_id += 1
    end

    private

    # Attempts to parse a line of stream data. If parsing is successful then the first return value is the item index,
    # and the second is a hash of the values contained in the stream data.
    def parse_stream_data(line)
      match = line.match stream_data_regexp
      return unless match

      item_index = match.captures[0].to_i - 1
      return unless item_index < @items.size

      [item_index, parse_values(match.captures[1..-1])]
    end

    # Returns whether the specified line of stream data is an overflow message for this subscription. Currently nothing
    # is done with overflow messages if they occur.
    def overflow_message?(line)
      line.match Regexp.new("^#{id},\\d+,OV\\d+$")
    end

    # Returns the regular expression that will match a single line of data in the incoming stream that is relevant to
    # this subscription. The ID at the beginning must match, as well as the number of fields.
    def stream_data_regexp
      Regexp.new "^#{id},(\\d+)#{'\|(.*)' * fields.size}"
    end

    # Parses an array of values from an incoming line of stream data into a hash where the keys are the field names
    # defined for this subscription.
    def parse_values(values)
      hash = {}

      values.each_with_index do |value, index|
        next if value == ''

        hash[fields[index]] = parse_raw_field_value value
      end

      hash
    end

    # Parses a raw field value according to to the Lightstreamer specification.
    def parse_raw_field_value(value)
      return '' if value == '$'
      return nil if value == '#'

      value = value[1..-1] if value =~ /^(\$|#)/

      UTF16.decode_escape_sequences value
    end

    # Runs all of this subscription's on_data callbacks with the specified arguments.
    def run_on_data_callbacks(item_name, item_data, new_values)
      @on_data_callbacks.each do |callback|
        callback.call self, item_name, item_data, new_values
      end
    end
  end
end
