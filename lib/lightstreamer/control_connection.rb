module Lightstreamer
  # Helper class used by {Session} and is responsible for sending Lightstreamer control requests.
  #
  # @private
  class ControlConnection
    # Initializes this class for sending Lightstreamer control requests using the specified session ID and control
    # address.
    #
    # @param [String] session_id The Lightstreamer session ID.
    # @param [String] control_url The URL of the server to send Lightstreamer control requests to.
    def initialize(session_id, control_url)
      @session_id = session_id
      @control_url = URI.join(control_url, '/lightstreamer/control.txt').to_s
    end

    # Sends a Lightstreamer control request that executes the specified operation with the specified options. If an
    # error occurs then a {LightstreamerError} subclass will be raised.
    #
    # @param [String] operation The operation to execute.
    # @param [Hash] options The options to include on the request.
    def execute(operation, options = {})
      result = execute_post_request build_payload(operation, options)

      raise SyncError if result.first == 'SYNC ERROR'
      raise LightstreamerError.build(result[2], result[1]) if result.first != 'OK'
    end

    # Sends a Lightstreamer subscription control request with the specified operation, table, and options. If an error
    # occurs then a {LightstreamerError} subclass will be raised.
    #
    # @param [:add, :add_silent, :start, :delete] operation The operation to execute.
    # @param [Fixnum] table The ID of the table this request pertains to.
    # @param [Hash] options The subscription control request options.
    def subscription_execute(operation, table, options = {})
      options[:table] = table

      validate_subscription_options operation, options

      execute operation, options
    end

    private

    # Validates the passed subscription control request options.
    def validate_subscription_options(operation, options)
      raise ArgumentError, 'Invalid table' unless options[:table].is_a? Fixnum
      raise ArgumentError, 'Unsupported operation' unless [:add, :add_silent, :start, :delete].include? operation

      validate_add_subscription_options options if [:add, :add_silent].include? operation
    end

    # Validates options required for subscription control requests that perform `add` operations.
    def validate_add_subscription_options(options)
      raise ArgumentError, 'Items not specified' if Array(options[:items]).empty?
      raise ArgumentError, 'Fields not specified' if Array(options[:fields]).empty?
      raise ArgumentError, 'Unsupported mode' unless [:distinct, :merge].include? options[:mode]
    end

    # Executes a POST request to the control address with the specified payload. Raises {RequestError} if the HTTP
    # request fails. Returns the response body split into individual lines.
    def execute_post_request(payload)
      response = Typhoeus.post @control_url, body: payload, timeout: 15

      raise RequestError.new(response.return_message, response.response_code) unless response.success?

      response.body.split("\n").map(&:strip)
    end

    # Constructs the payload for a Lightstreamer control request based on the given options hash. See {#execute} for
    # details on the supported keys.
    def build_payload(operation, options)
      params = {}

      build_optional_payload_fields options, params

      params[:LS_session] = @session_id
      params[:LS_op] = operation

      params
    end

    OPTION_NAME_TO_API_PARAMETER = {
      table: :LS_table,
      adapter: :LS_data_adapter,
      items: :LS_id,
      fields: :LS_schema,
      selector: :LS_selector,
      maximum_update_frequency: :LS_requested_max_frequency
    }.freeze

    def build_optional_payload_fields(options, params)
      params[:LS_mode] = options[:mode].to_s.upcase if options[:mode]

      options.each do |key, value|
        next if key == :mode
        next if value.nil?

        value = value.map(&:to_s).join(' ') if value.is_a? Array

        api_parameter = OPTION_NAME_TO_API_PARAMETER.fetch key

        params[api_parameter] = value
      end
    end
  end
end
