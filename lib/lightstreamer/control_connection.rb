module Lightstreamer
  # Helper class used by {Session} that is responsible for sending Lightstreamer control requests.
  #
  # @private
  class ControlConnection
    class << self
      # Sends a Lightstreamer control request that executes the specified operation with the specified options. If an
      # error occurs then a {LightstreamerError} subclass will be raised.
      #
      # @param [String] control_address The operation to execute.
      # @param [String] session_id The Lightstreamer session IDs.
      # @param [String] operation The operation to execute.
      # @param [Hash] options The options to include with the request.
      def execute(control_address, session_id, operation, options = {})
        url = URI.join(control_address, '/lightstreamer/control.txt').to_s

        result = execute_request url, build_payload(session_id, operation, options)

        raise Errors::SyncError if result.first == 'SYNC ERROR'
        raise LightstreamerError.build(result[2], result[1]) if result.first != 'OK'
      end

      private

      def execute_request(url, payload)
        response = Excon.post url, body: URI.encode_www_form(payload), connect_timeout: 15

        response.body.split("\n").map(&:strip)
      rescue Excon::Error => error
        raise Errors::ConnectionError, error.message
      end

      def build_payload(session_id, operation, options)
        params = {}

        params[:LS_session] = session_id
        params[:LS_op] = operation

        options.each do |key, value|
          next if value.nil?
          value = value.map(&:to_s).join(' ') if value.is_a? Array
          params[key] = value
        end

        params
      end
    end
  end
end
