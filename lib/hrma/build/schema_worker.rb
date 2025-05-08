# frozen_string_literal: true

require 'fractor'
require 'fileutils'
require 'logger'
require_relative 'schema'

module Hrma
  module Build
    # Class for processing schema files in a Ractor
    class SchemaWorker < Fractor::Worker
      # Initialize a new SchemaWorker
      #
      # @param name [String] Name for this worker
      def initialize(name: nil)
        super(name: name)
      end

      # Process a schema file
      #
      # @param work [SchemaWork] Work item containing schema path and log file path
      # @return [Fractor::WorkResult] Result of processing
      def process(work)
        # Safely access data through work.input hash - this is Ractor-safe
        schema_path = work.input[:schema_path]
        log_file = work.input[:log_file]

        # Process the schema file
        begin
          # Create schema object
          schema = Schema.new(schema_path)

          # Log message to stdout for tracking progress
          log_message("Processing schema in worker: #{schema_path}")

          # Generate documentation
          result = schema.generate_docs(logger: nil) # Don't use Logger in Ractor

          # Log success
          log_message("Successfully processed #{schema_path}")

          # Return result
          Fractor::WorkResult.new(result: result, work: work)
        rescue => e
          # Log error
          log_message("Error processing schema #{schema_path}: #{e.message}")

          # Return error result
          Fractor::WorkResult.new(error: nil, work: work)
        end
      end

      private

      # Simple thread-safe logging that avoids using Logger class
      # @param message [String] Message to log
      def log_message(message)
        timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
        puts "#{timestamp} - #{message}"
      end
    end
  end
end
