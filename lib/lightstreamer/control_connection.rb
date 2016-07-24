module Lightstreamer
  # This is an internal class used by {Session} and is responsible for sending Lightstreamer control requests.
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

    # Sends a Lightstreamer control request with the specified options. If an error occurs then {RequestError} or
    # {ProtocolError} will be raised.
    #
    # @param [Hash] options The control request options.
    # @option options [Fixnum] :table The ID of the table this request pertains to. Required.
    # @option options [:add, :add_silent, :start, :delete] :operation The operation to perform. Required.
    # @option options [String] :adapter The name of the data adapter to use. Optional.
    # @option options [Array<String>] :items The names of the items that this request pertains to. Required if
    #                 `:operation` is `:add` or `:add_silent`.
    # @option options [Array<String>] :fields The names of the fields that this request pertains to. Required if
    #                 `:operation` is `:add` or `:add_silent`.
    # @option options [:raw, :merge, :distinct, :command] :mode The subscription mode.
    def execute(options)
      result = execute_post_request build_payload(options)

      raise ProtocolError.new(result[2], result[1]) if result.first == 'ERROR'
    end

    private

    # Executes a POST request to the control address with the specified payload. Raises {RequestError} if the HTTP
    # request fails. Returns the response body split into individual lines.
    def execute_post_request(payload)
      response = Typhoeus.post @control_url, body: payload

      raise RequestError.new(response.return_message, response.response_code) unless response.success?

      response.body.split("\n").map(&:strip)
    end

    # Constructs the payload for a Lightstreamer control request based on the given options hash. See {#execute} for
    # details on the supported keys.
    def build_payload(options)
      params = {
        LS_session: @session_id,
        LS_table: options.fetch(:table),
        LS_op: options.fetch(:operation)
      }

      build_optional_payload_fields options, params

      params
    end

    def build_optional_payload_fields(options, params)
      params[:LS_data_adapter] = options[:adapter] if options.key? :adapter
      params[:LS_id] = options[:items].join(' ') if options.key? :items
      params[:LS_schema] = options[:fields].map(&:to_s).join(' ') if options.key? :fields
      params[:LS_mode] = options[:mode].to_s.upcase if options.key? :mode
    end
  end
end
