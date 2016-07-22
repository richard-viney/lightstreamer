module Lightstreamer
  # This module contains the code for the CLI frontend. See `README.md` for usage details.
  module CLI
    # Implements the `lightstreamer` command-line client.
    class Main < Thor
      default_task :stream

      class << self
        # This is the initial entry point for the execution of the command-line client. It is responsible for the
        # --version/-v options and then invoking the main application.
        #
        # @param [Array<String>] argv The array of command-line arguments.
        def bootstrap(argv)
          if argv.index('--version') || argv.index('-v')
            puts VERSION
            exit
          end

          start argv
        end
      end
    end
  end
end
