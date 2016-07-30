module Lightstreamer
  # Helper class used by {Session} that is responsible for sending Lightstreamer control requests.
  #
  # @private
  class ControlConnection
    class << self
      # Sends a Lightstreamer control request that executes the specified operation with the specified options. If an
      # error occurs then a {LightstreamerError} subclass will be raised.
      #
      # @param [String] control_address The control address to use.
      # @param [String] session_id The Lightstreamer session ID.
      # @param [String] operation The operation to execute.
      # @param [Hash] options The options to include with the request.
      def execute(control_address, session_id, operation, options = {})
        body = body_for_request session_id, operation, options

        response_lines = execute_request control_address, body

        error = parse_error response_lines
        raise error if error
      end

      # Executes multiple Lightstreamer control requests in one single bulk request. The bodies of the requests are
      # concatenated and sent as one. The return value is an array with one entry per body and indicates the error state
      # returned by the server for that body's request, or `nil` if no error occurred.
      #
      # @param [String] control_address The operation to execute.
      # @param [Array<String>] bodies The request bodies that are to be sent together in one request.
      #
      # @return [Array<LightstreamerError, nil>] The execution result of each of the passed bodies. If an entry if `nil`
      #         then no error occurred when executing that body.
      def bulk_execute(control_address, bodies)
        response_lines = execute_request control_address, bodies.join("\r\n")

        errors = []
        errors << parse_error(response_lines) until response_lines.empty?

        raise LightstreamerError if errors.size != bodies.size

        errors
      end

      # Returns the body to send for a control request with the given session ID, operation and options.
      #
      # @param [String] session_id The Lightstreamer session ID.
      # @param [String] operation The operation to execute.
      # @param [Hash] options The options to include with the request.
      def body_for_request(session_id, operation, options)
        params = {}

        params[:LS_session] = session_id
        params[:LS_op] = operation

        options.each do |key, value|
          next if value.nil?
          value = value.map(&:to_s).join(' ') if value.is_a? Array
          params[key] = value
        end

        URI.encode_www_form params
      end

      private

      def execute_request(control_address, body)
        url = URI.join(control_address, '/lightstreamer/control.txt').to_s

        response = Excon.post url, body: body, connect_timeout: 15, expects: 200

        response.body.split("\n").map(&:strip)
      rescue Excon::Error => error
        raise Errors::ConnectionError, error.message
      end

      def parse_error(response_lines)
        first_line = response_lines.shift

        return nil if first_line == 'OK'
        return Errors::SyncError.new if first_line == 'SYNC ERROR'

        if first_line == 'ERROR'
          error_code = response_lines.shift
          LightstreamerError.build response_lines.shift, error_code
        else
          LightstreamerError.new first_line
        end
      end
    end
  end
end
