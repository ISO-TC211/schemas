# frozen_string_literal: true

require 'fileutils'
require_relative 'tools'

module Hrma
  module Build
    # Class representing a schema file and its artifacts
    class Schema
      # @return [String] Path to the schema file
      attr_reader :schema_path

      # Initialize a new Schema
      #
      # @param schema_path [String] Path to the schema file
      def initialize(schema_path)
        @schema_path = schema_path
        @tools = Tools.new
      end

      # Generate diagrams for this schema
      #
      # @param logger [Logger] Logger for output
      # @return [Boolean] True if successful
      def generate_diagrams(logger: nil)
        ensure_output_directory_exists
        @tools.generate_diagrams(
          schema_path: @schema_path,
          output_dir: paths[:output_dir],
          logger: logger
        )
      end

      # Generate merged XSD for this schema
      #
      # @param logger [Logger] Logger for output
      # @return [Boolean] True if successful
      def generate_merged_xsd(logger: nil)
        ensure_output_directory_exists
        @tools.generate_merged_xsd(
          schema_path: @schema_path,
          output_path: paths[:temp_file],
          logger: logger
        )
      end

      # Generate documentation for this schema
      #
      # @param logger [Logger] Logger for output
      # @return [Boolean] True if successful
      def generate_docs(logger: nil)
        # Skip if up to date
        if up_to_date?
          logger&.info("Skipping #{@schema_path} (up to date)")
          return true
        end

        logger&.info("Generating documentation for #{@schema_path}...")

        # Generate diagrams
        unless generate_diagrams(logger: logger)
          logger&.error("Error generating diagrams")
          return false
        end

        # Generate merged XSD
        unless generate_merged_xsd(logger: logger)
          logger&.error("Error generating merged XSD")
          return false
        end

        # Generate final documentation
        file_basename = File.basename(paths[:target_html])
        unless @tools.xs3p(
          input_path: paths[:temp_file],
          output_path: paths[:output_file],
          title: file_basename,
          logger: logger
        )
          logger&.error("Error generating documentation")
          return false
        end

        # Clean up temporary file
        FileUtils.rm(paths[:temp_file])
        true
      end

      # Check if documentation is up to date
      #
      # @return [Boolean] True if documentation is up to date
      def up_to_date?
        File.exist?(paths[:output_file]) &&
          File.mtime(paths[:output_file]) > File.mtime(@schema_path)
      end

      # Get paths related to this schema
      #
      # @return [Hash] Hash containing all necessary paths
      def paths
        @paths ||= begin
          target_html = @schema_path.sub(/\.xsd$/, "")
          output_dir = "_site/#{target_html}"
          output_file = "#{output_dir}/index.html"
          temp_file = "#{output_file}.tmp"

          {
            target_html: target_html,
            output_dir: output_dir,
            output_file: output_file,
            temp_file: temp_file
          }
        end
      end

      private

      # Ensure output directory exists
      #
      # @return [void]
      def ensure_output_directory_exists
        FileUtils.mkdir_p("#{paths[:output_dir]}/diagrams")
      end
    end
  end
end
