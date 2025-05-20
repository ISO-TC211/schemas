# frozen_string_literal: true

require 'fractor'

module Hrma
  module Build
    # Class representing a work item for schema processing
    class SchemaWork < Fractor::Work
      # Initialize a new SchemaWork
      #
      # @param data [Hash] Hash containing schema_path and log_file
      # @option data [String] :schema_path Path to the schema file
      # @option data [String, nil] :log_file Path to log file, if any
      def initialize(data)
        # Store data directly in input hash - don't store as instance variables
        # This ensures Ractor-safety by keeping everything in the input hash
        # which is properly handled by Fractor
        super(data)
      end

      # Get the schema path
      #
      # @return [String] Path to the schema file
      def schema_path
        input[:schema_path]
      end

      # Get the log file path
      #
      # @return [String, nil] Path to the log file, if any
      def log_file
        input[:log_file]
      end

      # Provide a readable representation of this work item
      #
      # @return [String] String representation
      def to_s
        "SchemaWork: #{schema_path}"
      end
    end
  end
end
