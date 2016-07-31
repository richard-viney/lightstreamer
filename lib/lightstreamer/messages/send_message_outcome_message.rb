module Lightstreamer
  # Helper class used by {Session} in order to parse incoming overflow send message outcome messages.
  #
  # @private
  class SendMessageOutcomeMessage
    # The name of the sequence this message outcome is for.
    #
    # @return [String]
    attr_accessor :sequence

    # The message number(s) this message outcome is for. There will always be exactly one entry in this array except in
    # the case where {#error} is a {MessagesSkippedByTimeoutError} in which case there may be more than one entry if
    # multiple messages were skipped.
    #
    # @return [Array<Fixnum>]
    attr_accessor :numbers

    # If an error occurred processing the message then it will be set here.
    #
    # @return [LightstreamerError, nil]
    attr_accessor :error

    class << self
      # Attempts to parses the specified line as a message outcome message and returns an instance of
      # {SendMessageOutcomeMessage} on success, or `nil` on failure.
      def parse(line)
        match = line.match Regexp.new '^MSG,([A-Za-z0-9_]+),(\d*),(?:DONE|ERR,(\d*),(.*))$'
        return unless match

        message = new

        message.sequence = match.captures[0]
        message.numbers = [match.captures[1].to_i]
        handle_error_outcome message, match.captures if match.captures.compact.size == 4

        message
      end

      private

      def handle_error_outcome(message, captures)
        message.error = LightstreamerError.build captures[3], captures[2]

        return unless captures[2].to_i == 39

        last_number = message.numbers[0]
        first_number = last_number - captures[3].to_i + 1

        message.numbers = Array(first_number..last_number)
      end
    end
  end
end
