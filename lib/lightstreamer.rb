require 'rest-client'
require 'thor'

require 'lightstreamer/control_connection'
require 'lightstreamer/line_buffer'
require 'lightstreamer/protocol_error'
require 'lightstreamer/request_error'
require 'lightstreamer/session'
require 'lightstreamer/stream_connection'
require 'lightstreamer/subscription'
require 'lightstreamer/utf16'
require 'lightstreamer/version'

require 'lightstreamer/cli/main'
require 'lightstreamer/cli/commands/stream_command'

# This module contains all the code for the Lightstreamer gem. See `README.md` to get started with using this gem.
module Lightstreamer
end
