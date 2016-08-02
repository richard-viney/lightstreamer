module Lightstreamer
  # Helper class used by {Subscription} to process incoming item data according to the four different subscription
  # modes.
  #
  # @private
  class SubscriptionItemData
    # The current item data. Item data is a hash for all subscription modes except `:command` when it is an array.
    #
    # @return [Hash, Array, nil]
    attr_accessor :data

    # Explicitly sets this item data. See {Subscription#set_item_data} for details.
    #
    # @param [Array, Hash] new_data The new data for the item.
    # @param [:command, :merge] mode The subscription mode.
    def set_data(new_data, mode)
      raise ArgumentError, "Data can't be set unless mode is :command or :merge" unless [:command, :merge].include? mode
      raise ArgumentError, 'Data must be a hash when in merge mode' if mode == :merge && !new_data.is_a?(Hash)

      validate_rows new_data if mode == :command

      @data = new_data.dup
    end

    # Processes new data for the `:command` subscription mode.
    #
    # @param [Hash] new_data The new data.
    def process_new_command_data(new_data)
      @data ||= []

      key = row_key new_data
      command = new_data.delete(:command) || new_data.delete('command')

      send "process_#{command.to_s.downcase}_command", key, new_data
    end

    # Processes new data for the `:distinct` subscription mode.
    #
    # @param [Hash] new_data The new data.
    def process_new_distinct_data(new_data)
      @data = new_data
    end

    # Processes new data for the `:merge` subscription mode.
    #
    # @param [Hash] new_data The new data.
    def process_new_merge_data(new_data)
      @data ||= {}
      @data.merge! new_data
    end

    # Processes new data for the `:raw` subscription mode.
    #
    # @param [Hash] new_data The new data.
    def process_new_raw_data(new_data)
      @data = new_data
    end

    private

    def validate_rows(rows)
      raise ArgumentError, 'Data must be an array when in command mode' unless rows.is_a? Array

      keys = rows.map { |row| row_key row }
      raise ArgumentError, 'Each row must have a unique key' if keys.uniq.size != rows.size
    end

    def row_key(row)
      return row[:key] if row.key? :key
      return row['key'] if row.key? 'key'

      raise ArgumentError, 'Row does not have a key'
    end

    def process_add_command(key, new_data)
      process_update_command key, new_data
    end

    def process_update_command(key, new_data)
      row_to_update = @data.detect { |row| row_key(row) == key }

      if row_to_update
        row_to_update.merge! new_data
      else
        data << new_data
      end
    end

    def process_delete_command(key, _new_data)
      @data.delete_if { |row| row_key(row) == key }
    end
  end
end
