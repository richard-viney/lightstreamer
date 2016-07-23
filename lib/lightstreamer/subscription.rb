module Lightstreamer
  # Describes a subscription that can be bound to a Lightstreamer session in order to consume its data. A subscription
  # is described by the options passed to {#initialize}. Incoming data can be consumed by registering an asynchronous
  # data callback using {#add_data_callback}, or by polling {#retrieve_item_data}. Subscriptions start receiving data
  # only once they are attached to a Lightstreamer session using {Session#subscribe}.
  class Subscription
    # @return [Fixnum] The unique identification number of this subscription. This is used to identify the subscription
    #                  in incoming Lightstreamer data.
    attr_reader :id

    # @return [Array] The names of the items to subscribe to.
    attr_reader :items

    # @return [Array] The names of the fields to subscribe to on the items.
    attr_reader :fields

    # @return [:distinct, :merge] The operation mode of this subscription.
    attr_reader :mode

    # @return [String] The name of the data adapter from the Lightstreamer session's adapter set that should be used.
    #                  If `nil` then the default data adapter will be used.
    attr_reader :adapter

    # Initializes a new Lightstreamer subscription with the specified options. This can then be passed to
    # {Session#subscribe} to activate the subscription on a Lightstreamer session.
    #
    # @param [Hash] options The options to create the subscription with.
    # @option options [Array] :items The names of the items to subscribe to.
    # @option options [Array] :fields The names of the fields to subscribe to on the items.
    # @option options [:distinct, :merge] :mode The operation mode of this subscription.
    # @option options [String] :adapter The name of the data adapter from the Lightstreamer session's adapter set that
    #                 should be used. If `nil` then the default data adapter will be used.
    def initialize(options)
      @id = self.class.next_id

      @items = Array(options.fetch(:items))
      @fields = Array(options.fetch(:fields))
      @mode = options.fetch(:mode).to_sym
      @adapter = options[:adapter]

      @data_mutex = Mutex.new
      clear_data

      @data_callbacks = []
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
    # @param [Proc] block The callback block that is to be run when new data arrives.
    #
    # @return [Proc] The same `Proc` object that was passed to this method. This can be used to remove this data
    #         callback at a later stage using {#remove_data_callback}.
    def add_data_callback(&block)
      @data_mutex.synchronize { @data_callbacks << block }

      block
    end

    # Removes a data callback that was added by {#add_data_callback}.
    #
    # @param [Proc] block The data callback block to remove.
    def remove_data_callback(block)
      @data_mutex.synchronize { @data_callbacks.delete block }
    end

    # Returns the current data of one of this subscription's items.
    #
    # @param [String] item_name The name of the item to return the current data for.
    #
    # @return [Hash, Array] The item data. Will be a `Hash` if {#mode} is `:merge`, and an `Array` if {#mode} is
    #         `:distinct`.
    def retrieve_item_data(item_name)
      index = @items.index item_name
      raise ArgumentError, 'Unrecognized item name' unless index

      @data_mutex.synchronize do
        @data[index].dup
      end
    end

    # Processes a line of stream data if it is relevant to this subscription. This method is thread-safe and is intended
    # to be called by the session's processing thread.
    #
    # @param [String] line The line of stream data to process.
    #
    # @return [Boolean] Whether the passed line of stream data was relevant to this subscription and was successfully
    #         processed by it.
    def process_stream_data(line)
      item_index, values = parse_stream_data line
      return false unless item_index

      @data_mutex.synchronize do
        data = @data[item_index]

        data << values if mode == :distinct
        data.merge!(values) if mode == :merge

        @data_callbacks.each { |callback| callback.call self, @items[item_index], data, values }
      end

      true
    end

    # Returns the next unique ID to use for a new subscription.
    #
    # @return [Fixnum]
    def self.next_id
      @next_id ||= 0
      @next_id += 1
    end

    private

    # Attempts to parse an line of stream data.
    #
    # @param [String] line The line of stream data to parse.
    #
    # @return [Array] The first value is the item index, and the second is a hash of the values contained in the stream
    #                 data. Will be nil if the stream data was not able to be parsed.
    def parse_stream_data(line)
      match = line.match stream_data_regex
      return unless match

      item_index = match.captures[0].to_i - 1
      return unless item_index < @items.size

      [item_index, parse_values(match.captures[1..-1])]
    end

    # Returns the regular expression that will match a single line of data in the incoming stream that is relevant to
    # this subscription. The ID at the beginning must match, as well as the number of fields.
    #
    # @return [Regexp]
    def stream_data_regex
      Regexp.new "^#{id},(\\d+)#{'\|(.*)' * fields.size}"
    end

    # Parses an array of values from an incoming line of stream data into a hash where the keys are the field names
    # defined for this subscription.
    #
    # @param [String] values The raw values from the incoming stream data.
    #
    # @return [Hash] The parsed values as a hash where the keys are the field names of this subscription.
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

      # TODO: parse any non-ASCII characters which are specified as UTF-16 escape sequences in the form '\uXXXX' or
      # '\uXXXX\uYYYY'. They need to be transformed into native Unicode characters.

      value
    end
  end
end
