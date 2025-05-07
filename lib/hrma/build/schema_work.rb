# frozen_string_literal: true

require 'fractor'

module Hrma
  module Build
    # Class representing a work item for schema processing
    class SchemaWork < Fractor::Work
      attr_reader :schema_path, :log_file

      # Initialize a new SchemaWork
      #
      # @param data [Hash] Hash containing schema_path and log_file
      # @option data [String] :schema_path Path to the schema file
      # @option data [String, nil] :log_file Path to log file, if any
      def initialize(data)
        @schema_path = data[:schema_path]
        @log_file = data[:log_file]
        super(data)
      end

      # Provide a readable representation of this work item
      #
      # @return [String] String representation
      def to_s
        "SchemaWork: #{@schema_path}"
      end
    end
  end
end
