module Lightstreamer
  # This module contains helper methods for sending single and multiple POST requests to a Lightstreamer server and
  # handling the possible error responses.
  #
  # @private
  module PostRequest
    module_function

    # Sends a POST request to the specified Lightstreamer URL with the given query params. If an error occurs then a
    # {LightstreamerError} subclass will be raised.
    #
    # @param [String] url The URL to send the POST request to.
    # @param [Hash] query The POST request's query params.
    def execute(url, query)
      errors = execute_multiple url, [request_body(query)]
      raise errors.first if errors.first
    end

    # Sends a POST request to the specified Lightstreamer URL that concatenates multiple individual POST request bodies
    # into one to avoid sending lots of individual requests. The return value is an array with one entry per body and
    # indicates the error state returned by the server for that body's request, or `nil` if no error occurred.
    #
    # @param [String] url The URL to send the POST request to.
    # @param [Array<String>] bodies The individual POST request bodies that are to be sent together in one request.
    #        These should be created with {#request_body}.
    #
    # @return [Array<LightstreamerError, nil>] The execution result of each of the passed bodies. If an entry is `nil`
    #         then no error occurred when executing that body.
    def execute_multiple(url, bodies)
      response = Excon.post url, body: bodies.join("\r\n"), expects: 200, connect_timeout: 15

      response_lines = response.body.split("\n").map(&:strip)

      errors = []
      errors << parse_error(response_lines) until response_lines.empty?

      raise LightstreamerError if errors.size != bodies.size

      errors
    rescue Excon::Error => e
      raise Errors::ConnectionError, e.message
    end

    # Returns the request body to send for a POST request with the given options.
    #
    # @param [Hash] query The POST request's query params.
    #
    # @return [String] The request body for the given query params.
    def request_body(query)
      params = {}

      query.each do |key, value|
        next if value.nil?

        value = value.map(&:to_s).join(' ') if value.is_a? Array
        params[key] = value
      end

      URI.encode_www_form params
    end

    # Parses the next error from the given lines that were returned by a POST request. The consumed lines are removed
    # from the passed array.
    #
    # @param [Array<String>] response_lines
    #
    # @return [LightstreamerError, nil]
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
