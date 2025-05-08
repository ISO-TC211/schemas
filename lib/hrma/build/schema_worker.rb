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

        # Create logger with the existing file
        logger = create_logger(log_file) if log_file

        # Create schema object
        schema = Schema.new(schema_path)

        # Generate documentation
        logger&.info("Processing schema in worker: #{schema_path}")
        result = schema.generate_docs(logger: logger)

        # Close the logger
        logger&.close if logger

        # Return result
        Fractor::WorkResult.new(result: result, work: work)
      rescue => e
        # Log error
        error_message = "Error processing schema #{schema_path}: #{e.message}"
        logger&.error(error_message) if logger
        logger&.error(e.backtrace.join("\n")) if logger && e.backtrace
        logger&.close if logger

        # Return error result
        Fractor::WorkResult.new(error: error_message, work: work)
      end

      private

      # Ensure logfile exists to avoid Logger::ProgName issues
      #
      # @param log_file [String] Path to the log file
      # @return [void]
      def ensure_logfile_exists(log_file)
        return unless log_file

        # Ensure directory exists
        FileUtils.mkdir_p(File.dirname(log_file))

        # Touch the file if it doesn't exist - this prevents Logger from creating it
        # and avoids the issue with Logger::ProgName in Ractors
        FileUtils.touch(log_file)
      end

      # Create a logger for a specific file
      #
      # @param log_file [String] Path to the log file
      # @return [Logger] Logger for the file
      def create_logger(log_file)
        # Create logger with the existing file
        # Ensure logfile exists before creating logger to avoid Logger::ProgName issues
        ensure_logfile_exists(log_file)

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
