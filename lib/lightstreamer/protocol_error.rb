module Lightstreamer
  # This error class is raised by {Session} when a request to the Lightstreamer API fails with a Lightstreamer-specific
  # error code and error message.
  class ProtocolError < StandardError
    # @return [String] A description of the Lightstreamer error that occurred.
    attr_reader :error

    # @return [Fixnum] The numeric code of the Lightstreamer error.
    attr_reader :code

    # Initializes this protocol error with the specific message and code.
    #
    # @param [String] error The error description.
    # @param [Integer] code The numeric code for the error.
    def initialize(error, code)
      @error = error.to_s
      @http_code = code.to_i

      super "Lightstreamer error: #{@error}, code: #{code}"
    end
  end
end
