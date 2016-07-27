module Lightstreamer
  class LightstreamerError < StandardError
  end

  # This module contains all the error classes for this gem. They all subclass {LightstreamerError}.
  module Errors
    # This error is raised when the session username and password check fails.
    class AuthenticationError < LightstreamerError
    end

    # This error is raised when the requested adapter set is unknown.
    class UnknownAdapterSetError < LightstreamerError
    end

    # This error is raised when trying to bind to a session that was initialized with a different and incompatible
    # communication protocol.
    class IncompatibleSessionError < LightstreamerError
    end

    # This error is raised when the licensed maximum number of sessions is reached.
    class LicensedMaximumSessionsReachedError < LightstreamerError
    end

    # This error is raised when the configured maximum number of sessions is reached.
    class ConfiguredMaximumSessionsReachedError < LightstreamerError
    end

    # This error is raised when the configured maximum server load is reached.
    class ConfiguredMaximumServerLoadReachedError < LightstreamerError
    end

    # This error is raised when the creation of new sessions has been temporarily blocked.
    class NewSessionsTemporarilyBlockedError < LightstreamerError
    end

    # This error is raised when streaming is not available because of the current license terms.
    class StreamingNotAvailableError < LightstreamerError
    end

    # This error is raised when the specified table can't be modified because it is configured for unfiltered
    # dispatching.
    class TableModificationNotAllowedError < LightstreamerError
    end

    # This error is raised when the specified data adapter is invalid or the data adapter is not specified and there is
    # no default data adapter.
    class InvalidDataAdapterError < LightstreamerError
    end

    # This error occurs when the specified table is not found.
    class UnknownTableError < LightstreamerError
    end

    # This error is raised when an invalid item name is specified.
    class InvalidItemError < LightstreamerError
    end

    # This error is raised when an invalid item name for the given fields is specified.
    class InvalidItemForFieldsError < LightstreamerError
    end

    # This error is raised when an invalid field name is specified.
    class InvalidFieldError < LightstreamerError
    end

    # This error is raised when the specified subscription mode is not supported by one of the items.
    class UnsupportedModeForItemError < LightstreamerError
    end

    # This error is raised when an invalid selector is specified.
    class InvalidSelectorError < LightstreamerError
    end

    # This error is raised when unfiltered dispatching is requested on an item that does not allow it.
    class UnfilteredDispatchingNotAllowedForItemError < LightstreamerError
    end

    # This error is raised when unfiltered dispatching is requested on an item that does not support it.
    class UnfilteredDispatchingNotSupportedForItemError < LightstreamerError
    end

    # This error is raised when unfiltered dispatching is requested but is not allowed by the current license terms.
    class UnfilteredDispatchingNotAllowedByLicenseError < LightstreamerError
    end

    # This error is raised when `RAW` mode was requested but is not allowed by the current license terms.
    class RawModeNotAllowedByLicenseError < LightstreamerError
    end

    # This error is raised when subscriptions are not allowed by the current license terms.
    class SubscriptionsNotAllowedByLicenseError < LightstreamerError
    end

    # This error is raised when the specified progressive sequence number for the custom message was invalid.
    class InvalidProgressiveNumberError < LightstreamerError
    end

    # This error is raised when the client version requested is not supported by the server.
    class ClientVersionNotSupportedError < LightstreamerError
    end

    # This error is raised when a error defined by a metadata adapter is raised.
    class MetadataAdapterError < LightstreamerError
      # The error message from the metadata adapter.
      #
      # @return [String]
      attr_reader :adapter_error_message

      # The error code from the metadata adapter.
      #
      # @return [Fixnum]
      attr_reader :adapter_error_code

      # Initializes this metadata adapter error with the specified error message and error code.
      #
      # @param [String] message The error message.
      # @param [Fixnum] code The error code.
      def initialize(message, code)
        @adapter_error_message = message
        @adapter_error_code = code

        super message
      end
    end

    # This error is raised when a sync error occurs, which most often means that the session ID provided is invalid and
    # a new session needs to be created.
    class SyncError < LightstreamerError
    end

    # This error is raised when the session was explicitly closed on the server side. The reason for this is specified
    # by {#cause_code}.
    class SessionEndError < LightstreamerError
      # The cause code specifying why the session was terminated by the server, or `nil` if unknown.
      #
      # The following codes are defined, but other values are allowed and signal an unexpected cause.
      #
      # - `<=0` - The session was closed through a `destroy` request and this custom code was specified.
      # - `31` - The session was closed through a `destroy` request.
      # - `32` - The session was closed by an administrator through JMX.
      # - `33`, `34` - An unexpected error occurred on the server.
      # - `35` - Another session was opened on the metadata adapter and the metadata adpater only supports one session.
      # - `40` - A manual rebind to the session was done by another client.
      # - `48` - The maximum session duration configured on the server has been reached. This is meant as a way to
      #          refresh the session and the client should recover by opening a new session immediately.
      #
      # @return [Fixnum, nil]
      attr_reader :cause_code

      # Initializes this session end error with the specified cause code.
      #
      # @param [Session?] cause_code See {#cause_code} for details.
      def initialize(cause_code)
        @cause_code = cause_code && cause_code.to_i
        super()
      end
    end

    # This error is raised when an HTTP request error occurs.
    class RequestError < LightstreamerError
      # The description of the request error that occurred.
      #
      # @return [String]
      attr_reader :request_error_message

      # The HTTP code that was returned, or zero if unknown.
      #
      # @return [Fixnum]
      attr_reader :request_error_code

      # Initializes this request error with a message and an HTTP code.
      #
      # @param [String] message The error description.
      # @param [Fixnum] code The HTTP code for the request failure, or zero if unknown.
      def initialize(message, code)
        @request_error_message = message
        @request_error_code = code

        if code.nonzero?
          super "#{code}: #{message}"
        else
          super message
        end
      end
    end
  end

  # Base class for all errors raised by this gem.
  class LightstreamerError
    # Takes a Lightstreamer error message and numeric code and returns an instance of the relevant error class that
    # should be raised in response to the error.
    #
    # @param [String] message The error message.
    # @param [Fixnum] code The numeric error code that is used to determine which {LightstreamerError} subclass to
    #        instantiate.
    #
    # @return [LightstreamerError]
    #
    # @private
    def self.build(message, code)
      code = code.to_i

      if API_ERROR_CODE_TO_CLASS.key? code
        API_ERROR_CODE_TO_CLASS[code].new ''
      elsif code <= 0
        Errors::MetadataAdapterError.new message, code
      else
        new "#{code}: #{message}"
      end
    end

    API_ERROR_CODE_TO_CLASS = {
      1 => Errors::AuthenticationError,
      2 => Errors::UnknownAdapterSetError,
      3 => Errors::IncompatibleSessionError,
      7 => Errors::LicensedMaximumSessionsReachedError,
      8 => Errors::ConfiguredMaximumSessionsReachedError,
      9 => Errors::ConfiguredMaximumServerLoadReachedError,
      10 => Errors::NewSessionsTemporarilyBlockedError,
      11 => Errors::StreamingNotAvailableError,
      13 => Errors::TableModificationNotAllowedError,
      17 => Errors::InvalidDataAdapterError,
      19 => Errors::UnknownTableError,
      21 => Errors::InvalidItemError,
      22 => Errors::InvalidItemForFieldsError,
      23 => Errors::InvalidFieldError,
      24 => Errors::UnsupportedModeForItemError,
      25 => Errors::InvalidSelectorError,
      26 => Errors::UnfilteredDispatchingNotAllowedForItemError,
      27 => Errors::UnfilteredDispatchingNotSupportedForItemError,
      28 => Errors::UnfilteredDispatchingNotAllowedByLicenseError,
      29 => Errors::RawModeNotAllowedByLicenseError,
      30 => Errors::SubscriptionsNotAllowedByLicenseError,
      32 => Errors::InvalidProgressiveNumberError,
      33 => Errors::InvalidProgressiveNumberError,
      60 => Errors::ClientVersionNotSupportedError
    }.freeze

    private_constant :API_ERROR_CODE_TO_CLASS
  end
end
