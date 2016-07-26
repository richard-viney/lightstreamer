module Lightstreamer
  # Base class for all errors raised by this gem.
  class Error < StandardError
  end

  # This error is raised when the session username and password check fails.
  class AuthenticationError < Error
  end

  # This error is raised when the requested adapter set is unknown.
  class UnknownAdapterSetError < Error
  end

  # This error is raise when trying to bind to a session that was initialized with a different and incompatible
  # communication protocol.
  class IncompatibleSessionError < Error
  end

  # This error is raised when the licensed maximum number of sessions is reached.
  class LicensedMaximumSessionsReachedError < Error
  end

  # This error is raised when the configured maximum number of sessions is reached.
  class ConfiguredMaximumSessionsReachedError < Error
  end

  # This error is raised when the configured maximum server load is reached.
  class ConfiguredMaximumServerLoadReachedError < Error
  end

  # This error is raised when the creation of new sessions has been temporarily blocked.
  class NewSessionsTemporarilyBlockedError < Error
  end

  # This error is raised when streaming is not available because of the current license terms.
  class StreamingNotAvailableError < Error
  end

  # This error is raised when the specified table can't be modified because it is configured for unfiltered dispatching.
  class TableModificationNotAllowedError < Error
  end

  # This error is raised when the specified data adapter is invalid or the data adapter is not specified and there is
  # no default data adapter.
  class InvalidDataAdapterError < Error
  end

  # This error occurs when the specified table is not found.
  class UnknownTableError < Error
  end

  # This error is raised when an invalid item name is specified.
  class InvalidItemError < Error
  end

  # This error is raised when an invalid item name for the given fields is specified.
  class InvalidItemForFieldsError < Error
  end

  # This error is raised when an invalid field name is specified.
  class InvalidFieldError < Error
  end

  # This error is raised when the specified subscription mode is not supported by one of the items.
  class UnsupportedModeForItemError < Error
  end

  # This error is raised when an invalid selector is specified.
  class InvalidSelectorError < Error
  end

  # This error is raised when unfiltered dispatching is requested on an item that does not allow it.
  class UnfilteredDispatchingNotAllowedForItemError < Error
  end

  # This error is raised when unfiltered dispatching is requested on an item that does not support it.
  class UnfilteredDispatchingNotSupportedForItemError < Error
  end

  # This error is raised when unfiltered dispatching is requested but is not allowed by the current license terms.
  class UnfilteredDispatchingNotAllowedByLicenseError < Error
  end

  # This error is raised when `RAW` mode was requested but is not allowed by the current license terms.
  class RawModeNotAllowedByLicenseError < Error
  end

  # This error is raised when subscriptions are not allowed by the current license terms.
  class SubscriptionsNotAllowedByLicenseError < Error
  end

  # This error is raised when the specified progressive sequence number for the custom message was invalid.
  class InvalidProgressiveNumberError < Error
  end

  # This error is raised when the client version requested is not supported by the server.
  class ClientVersionNotSupportedError < Error
  end

  # This error is raised when a error defined by a metadata adapter is raised.
  class MetadataAdapterError < Error
    # @return [String] The error message from the metadata adapter.
    attr_reader :adapter_error_message

    # @return [Fixnum] The error code from the metadata adapter.
    attr_reader :adapter_error_code

    # Initializes this metadata adapter error with the specified error message and error code.
    #
    # @param [String] message The error message.
    # @param [Fixnum] code The error code.
    def initialize(message, code)
      @adapter_error_message = message
      @adapter_error_code = code.to_i

      super message
    end
  end

  # This error is raised when a sync error occurs, which most often means that the session ID provided is invalid and
  # a new session needs to be created.
  class SyncError < Error
  end

  # This error is raised when the specified session ID is for a session that has been terminated.
  class SessionEndError < Error
    # @return [Fixnum] The cause code specifying why the session was terminated by the server, or `nil` if unknown.
    attr_reader :cause_code

    # Initializes this session end error with the specified cause code.
    #
    # @param [Fixnum] cause_code
    def initialize(cause_code = nil)
      @cause_code = cause_code.to_i
      super()
    end
  end

  # This error is raised when an HTTP request error occurs.
  class RequestError < Error
    # @return [String] A description of the request error that occurred.
    attr_reader :request_error_message

    # @return [Fixnum] The HTTP code that was returned, or zero if unknown.
    attr_reader :request_error_code

    # Initializes this request error with a message and an HTTP code.
    #
    # @param [String] message The error description.
    # @param [Fixnum] code The HTTP code for the request failure, if known.
    def initialize(message, code)
      @request_error_message = message
      @request_error_code = code

      if code != 0
        super "#{code}: #{message}"
      else
        super message
      end
    end
  end

  # Base class for all errors raised by this gem.
  class Error
    # Takes a Lightstreamer error message and numeric code and returns an instance of the relevant error class that
    # should be raised in response to the error.
    #
    # @param [String] message The error message.
    # @param [Fixnum] code The numeric error code that is used to determine which {Error} subclass to instantiate.
    #
    # @return [Error]
    def self.build(message, code)
      code = code.to_i

      if API_ERROR_CODE_TO_CLASS.key? code
        API_ERROR_CODE_TO_CLASS[code].new
      elsif code <= 0
        MetadataAdapterError.new message, code
      else
        new "#{code}: #{message}"
      end
    end

    API_ERROR_CODE_TO_CLASS = {
      1 => AuthenticationError,
      2 => UnknownAdapterSetError,
      3 => IncompatibleSessionError,
      7 => LicensedMaximumSessionsReachedError,
      8 => ConfiguredMaximumSessionsReachedError,
      9 => ConfiguredMaximumServerLoadReachedError,
      10 => NewSessionsTemporarilyBlockedError,
      11 => StreamingNotAvailableError,
      13 => TableModificationNotAllowedError,
      17 => InvalidDataAdapterError,
      19 => UnknownTableError,
      21 => InvalidItemError,
      22 => InvalidItemForFieldsError,
      23 => InvalidFieldError,
      24 => UnsupportedModeForItemError,
      25 => InvalidSelectorError,
      26 => UnfilteredDispatchingNotAllowedForItemError,
      27 => UnfilteredDispatchingNotSupportedForItemError,
      28 => UnfilteredDispatchingNotAllowedByLicenseError,
      29 => RawModeNotAllowedByLicenseError,
      30 => SubscriptionsNotAllowedByLicenseError,
      32 => InvalidProgressiveNumberError,
      33 => InvalidProgressiveNumberError,
      60 => ClientVersionNotSupportedError
    }.freeze

    private_constant :API_ERROR_CODE_TO_CLASS
  end
end
