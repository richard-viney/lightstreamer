module Lightstreamer
  # This class manages a subscription that can be used to stream data from a {Session}. Subscriptions should always be
  # created using {Session#build_subscription}. Subscriptions start receiving data after {#start} is called, and
  # streaming subscription data can be consumed by registering an asynchronous data callback using {#on_data}, or by
  # polling using {#item_data}.
  class Subscription
    # The session that this subscription is associated with.
    #
    # @return [Session]
    attr_reader :session

    # The names of the items to subscribe to.
    #
    # @return [Array]
    attr_reader :items

    # The names of the fields to subscribe to on the items.
    #
    # @return [Array]
    attr_reader :fields

    # The operation mode of this subscription. The four supported operation modes are: `:command`, `:distinct`, `:merge`
    # and `:raw`. See the Lightstreamer documentation for details on the different modes.
    #
    # @return [:command, :distinct, :merge, :raw]
    attr_reader :mode

    # The name of the data adapter from the Lightstreamer session's adapter set to use, or `nil` to use the default
    # data adapter.
    #
    # @return [String, nil]
    attr_reader :data_adapter

    # The selector for table items.
    #
    # @return [String, nil]
    attr_reader :selector

    # The maximum number of updates this subscription should receive per second. If this is set to zero, which is the
    # default, then there is no limit on the update frequency. If set to `:unfiltered` then unfiltered streaming will be
    # used for this subscription and it is possible for overflows to occur (see {#on_overflow}). If {#mode} is `:raw`
    # then the maximum update frequency is treated as `:unfiltered` regardless of its actual value.
    #
    # @return [Float, :unfiltered]
    attr_reader :maximum_update_frequency

    # Whether this subscription is currently started and actively streaming data. See {#start} and {#stop} for details.
    #
    # @return [Boolean]
    attr_reader :active

    # Initializes a new Lightstreamer subscription with the specified options.
    #
    # @param [Session] session The session this subscription is associated with.
    # @param [Hash] options The options to create the subscription with. See {Session#build_subscription}
    #
    # @private
    def initialize(session, options)
      @mutex = Mutex.new

      @session = session
      @items = options.fetch(:items)
      @fields = options.fetch(:fields)
      @mode = options.fetch(:mode).to_sym
      @data_adapter = options[:data_adapter]
      @selector = options[:selector]
      @maximum_update_frequency = sanitize_frequency options[:maximum_update_frequency]

      clear_data
      clear_callbacks
    end

    # Returns this subscription's unique identification number.
    #
    # @return [Fixnum]
    #
    # @private
    def id
      @id ||= self.class.next_id
    end

    # Starts streaming data for this Lightstreamer subscription. If an error occurs then a {LightstreamerError} subclass
    # will be raised.
    #
    # @param [Hash] options The options to start the subscription with.
    # @option options [Boolean] :silent Whether the subscription should be started in silent mode. In silent mode the
    #                 subscription is initiated on the server and begins buffering incoming data, however this data will
    #                 not be sent to the client for processing until {#unsilence} is called.
    # @option options [Boolean, Fixnum] :snapshot Controls whether the server should send a snapshot of this
    #                 subscription's items. The default value is `false` which means then the server will not send
    #                 snapshot information. If set to `true` then the server will send snapshot information if it is
    #                 available. If this subscription's {#mode} is `:distinct` then `:snapshot` can also be an integer
    #                 specifying the number of events the server should send as part of the snapshot. If this latter
    #                 option is used, or {#mode} is `:command`, then any callbacks registered with {#on_end_of_snapshot}
    #                 will be called once the snapshot for each item is complete. This option is ignored when {#mode} is
    #                 `:raw`.
    def start(options = {})
      return if @active

      session.control_request control_request_options(:start, options)
      after_control_request :start
    end

    # Unsilences this subscription if it was initially started in silent mode by passing `silent: true` to {#start}. If
    # this subscription was not started in silent mode then this method has no effect. If an error occurs then a
    # {LightstreamerError} subclass will be raised.
    def unsilence
      session.control_request control_request_options(:unsilence)
      after_control_request :unsilence
    end

    # Stops streaming data for this Lightstreamer subscription. If an error occurs then a {LightstreamerError} subclass
    # will be raised.
    def stop
      session.control_request control_request_options(:stop) if @active
      after_control_request :stop
    end

    # Sets this subscription's maximum update frequency. This can be done while a subscription is streaming data in
    # order to change its update frequency limit, but an actively streaming subscription cannot switch between filtered
    # and unfiltered dispatching, and {TableModificationNotAllowedError} will be raised if this is attempted. If {#mode}
    # is `:raw` then the maximum update frequency is treated as `:unfiltered` regardless of its actual value.
    #
    # @param [Float, :unfiltered] new_frequency The new maximum update frequency. See {#maximum_update_frequency} for
    #        details.
    def maximum_update_frequency=(new_frequency)
      new_frequency = sanitize_frequency new_frequency
      session.control_request LS_op: :reconf, LS_table: id, LS_requested_max_frequency: new_frequency if @active
      @maximum_update_frequency = new_frequency
    end

    # Clears all current data stored for this subscription. New data will continue to be processed as it becomes
    # available.
    def clear_data
      @mutex.synchronize { @data = (0...items.size).map { SubscriptionItemData.new } }
    end

    # Returns a copy of the current data of one of this subscription's items. If {#mode} is `:merge` then the returned
    # object will be a hash of the item's state, if it is `:command` then an array of row data for the item will be
    # returned, and if it is `:distinct` or `:raw` then just the most recent update received for the item will be
    # returned. The return value will be `nil` if no data for the item has been set or been received.
    #
    # @param [String] item_name The name of the item to return the current data for.
    #
    # @return [Hash, Array, nil] A copy of the item data.
    def item_data(item_name)
      index = @items.index item_name
      raise ArgumentError, 'Unknown item' unless index

      @mutex.synchronize { @data[index].data && @data[index].data.dup }
    end

    # Sets the current data for the item with the specified name. This is only allowed when {mode} is `:command` or
    # `:merge`. Raises an exception if the specified item name or item data is invalid.
    #
    # @param [String] item_name The name of the item to set the data for.
    # @param [Hash, Array<Hash>] item_data The new data for the item. If {#mode} is `:merge` this must be a hash. If
    #        {#mode} is `:command` then this must be an `Array<Hash>` and each hash entry must have a unique `:key`
    #        value.
    def set_item_data(item_name, item_data)
      index = @items.index item_name
      raise ArgumentError, 'Unknown item' unless index

      @mutex.synchronize { @data[index].set_data item_data, mode }
    end

    # Adds the passed block to the list of callbacks that will be run when new data for this subscription arrives. The
    # block will be called on a worker thread and so the code that is run by the block must be thread-safe. The
    # arguments passed to the block are `|subscription, item_name, item_data, new_data|`. The `item_data` argument will
    # be an array if {#mode} is `:command`, for all other modes it will be a hash. Note that if {#mode} is `:distinct`
    # or `:raw` then `item_data` and `new_data` will be the same.
    #
    # @param [Proc] callback The callback that is to be run when new data arrives.
    def on_data(&callback)
      @mutex.synchronize { @callbacks[:on_data] << callback }
    end

    # Adds the passed block to the list of callbacks that will be run when the server reports an overflow for this
    # subscription. This is only relevant when this subscription's {#mode} is `:command` or `:raw`, or if
    # {#maximum_update_frequency} is `:unfiltered`. The block will be called on a worker thread and so the code that is
    # run by the block must be thread-safe. The arguments passed to the block are `|subscription, item_name,
    # overflow_size|`.
    #
    # @param [Proc] callback The callback that is to be run when an overflow is reported for this subscription.
    def on_overflow(&callback)
      @mutex.synchronize { @callbacks[:on_overflow] << callback }
    end

    # Adds the passed block to the list of callbacks that will be run when the server reports an end-of-snapshot
    # notification for this subscription. End-of-snapshot notifications are only sent when {#mode} is `:command` or
    # `:distinct` and `snapshot: true` was passed to {#start}. The block will be called on a worker thread and so the
    # code that is run by the block must be thread-safe. The arguments passed to the block are `|subscription,
    # item_name|`.
    #
    # @param [Proc] callback The callback that is to be run when an overflow is reported for this subscription.
    def on_end_of_snapshot(&callback)
      @mutex.synchronize { @callbacks[:on_end_of_snapshot] << callback }
    end

    # Removes all {#on_data}, {#on_overflow} and {#on_end_of_snapshot} callbacks present on this subscription.
    def clear_callbacks
      @mutex.synchronize { @callbacks = { on_data: [], on_overflow: [], on_end_of_snapshot: [] } }
    end

    # Processes a line of stream data if it is relevant to this subscription. This method is thread-safe and is intended
    # to be called by the session's processing thread.
    #
    # @param [String] line The line of stream data to process.
    #
    # @return [Boolean] Whether the passed line of stream data was processed by this subscription.
    #
    # @private
    def process_stream_data(line)
      return true if process_update_message UpdateMessage.parse(line, id, items, fields)
      return true if process_overflow_message OverflowMessage.parse(line, id, items)
      return true if process_end_of_snapshot_message EndOfSnapshotMessage.parse(line, id, items)
    end

    # Returns the control request arguments to use to perform the specified action on this subscription.
    #
    # @private
    def control_request_options(action, options = nil)
      case action.to_sym
      when :start
        start_control_request_options options
      when :unsilence
        { LS_session: session.session_id, LS_op: :start, LS_table: id }
      when :stop
        { LS_session: session.session_id, LS_op: :delete, LS_table: id }
      end
    end

    # Performs any required updates to this subscription's state after a control request succeeds.
    #
    # @private
    def after_control_request(action)
      @active = true if action == :start
      @active = false if action == :stop
    end

    private

    class << self
      # Returns the next unique numeric subscription ID.
      #
      # @private
      def next_id
        @next_id ||= 0
        @next_id += 1
      end
    end

    def sanitize_frequency(frequency)
      frequency.to_s == 'unfiltered' ? :unfiltered : frequency.to_f
    end

    def process_update_message(message)
      return unless message

      @mutex.synchronize do
        @data[message.item_index].send "process_new_#{mode}_data", message.data.dup
        run_callbacks :on_data, @items[message.item_index], @data[message.item_index].data, message.data
      end
    end

    def process_overflow_message(message)
      return unless message

      @mutex.synchronize { run_callbacks :on_overflow, @items[message.item_index], message.overflow_size }
    end

    def process_end_of_snapshot_message(message)
      return unless message

      @mutex.synchronize { run_callbacks :on_end_of_snapshot, @items[message.item_index] }
    end

    def run_callbacks(callback_type, *args)
      @callbacks.fetch(callback_type).each { |callback| callback.call self, *args }

      true
    end

    def start_control_request_options(options)
      options ||= {}

      operation = options[:silent] ? :add_silent : :add

      { LS_session: session.session_id, LS_op: operation, LS_table: id, LS_mode: mode.to_s.upcase, LS_id: items,
        LS_schema: fields, LS_selector: selector, LS_snapshot: options.fetch(:snapshot, false),
        LS_requested_max_frequency: maximum_update_frequency, LS_data_adapter: data_adapter }
    end
  end
end
