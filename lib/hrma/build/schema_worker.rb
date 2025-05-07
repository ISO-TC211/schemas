# frozen_string_literal: true

require 'fractor'
require 'logger'
require_relative 'schema_processor'

module Hrma
  module Build
    # Class for processing schema files in a Ractor
    class SchemaWorker < Fractor::Worker
      # Process a schema file
      #
      # @param work [SchemaWork] Work item containing schema path and log file path
      # @return [Fractor::WorkResult] Result of processing
      def process(work)
        processor = SchemaProcessor.new

        # Get schema path and log file directly from work object attributes
        schema_path = work.schema_path
        log_file = work.log_file

        logger = create_logger(log_file) if log_file

        begin
          # Log start of processing
          logger&.info("Processing schema in worker: #{schema_path}")

          # Process the schema - pass the string path directly
          result = processor.process(schema_path: schema_path, logger: logger)

          # Close the logger if it was created
          logger&.close

          # Return success result
          Fractor::WorkResult.new(result: result, work: work)
        rescue => e
          # Log error
          error_message = "Error processing schema #{schema_path}: #{e.message}"
          logger&.error(error_message)
          logger&.error(e.backtrace.join("\n")) if logger
          logger&.close

          # Return error result
          Fractor::WorkResult.new(error: error_message, work: work)
        end
      end

      private

      # Create a logger for a specific file
      #
      # @param log_file [String] Path to the log file
      # @return [Logger] Logger for the file
      def create_logger(log_file)
        logger = Logger.new(log_file)
        logger.level = Logger::INFO
        logger.formatter = proc do |severity, datetime, progname, msg|
          "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{msg}\n"
        end

        logger
      end
    end
  end
end
