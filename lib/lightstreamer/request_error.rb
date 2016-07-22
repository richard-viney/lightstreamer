module Lightstreamer
  # This error class is raised by {Session} when a request to the Lightstreamer API fails.
  class RequestError < StandardError
    # @return [String] A description of the error that occurred when the request was attempted.
    attr_reader :error

    # @return [Fixnum] The HTTP code that was returned, or `nil` if unknown.
    attr_reader :http_code

    # Initializes this request error with a message and an HTTP code.
    #
    # @param [String] error The error description.
    # @param [Integer] http_code The HTTP code for the request failure, if known.
    def initialize(error, http_code = nil)
      @error = error.to_s
      @http_code = http_code ? http_code.to_i : nil

      super "Request error: #{error}#{http_code ? ", http code: #{http_code}" : ''}>"
    end
  end
end
