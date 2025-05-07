# frozen_string_literal: true

require 'fileutils'
require_relative 'tools'

module Hrma
  module Build
    # Class for processing a single schema file
    class SchemaProcessor
      # Initialize a new SchemaProcessor
      def initialize
        @tools = Tools.new
      end

      # Process a schema file
      #
      # @param schema_path [String] Path to the schema file
      # @param logger [Logger] Logger for output
      # @return [Boolean] True if successful
      def process(schema_path:, logger: nil)
        # Get paths for processing
        paths = get_file_paths(schema_path)

        # Skip if up to date
        if skip_if_up_to_date?(paths[:output_file], schema_path)
          logger&.info("Skipping #{schema_path} (up to date)")
          return true
        end

        logger&.info("Generating documentation for #{schema_path}...")

        # Create output directory
        FileUtils.mkdir_p("#{paths[:output_dir]}/diagrams")

        # Generate diagrams
        unless @tools.generate_diagrams(schema_path: schema_path, output_dir: paths[:output_dir], logger: logger)
          logger&.error("Error generating diagrams for #{schema_path}")
          return false
        end

        # Generate merged XSD
        unless @tools.generate_merged_xsd(schema_path: schema_path, output_path: paths[:temp_file], logger: logger)
          logger&.error("Error generating merged XSD for #{schema_path}")
          return false
        end

        # Generate final documentation
        file_basename = File.basename(paths[:target_html])
        unless @tools.xs3p(input_path: paths[:temp_file], output_path: paths[:output_file], title: file_basename, logger: logger)
          logger&.error("Error generating documentation for #{schema_path}")
          return false
        end

        # Clean up temporary file
        FileUtils.rm(paths[:temp_file])
        true
      end

      private

      # Get file paths needed for processing
      #
      # @param file [String] Path to the XSD file
      # @return [Hash] Hash containing all necessary paths
      def get_file_paths(file)
        target_html = file.sub(/\.xsd$/, "")
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

      # Check if output file is up to date
      #
      # @param output_file [String] Path to the output file
      # @param source_file [String] Path to the source file
      # @return [Boolean] True if output file is up to date
      def skip_if_up_to_date?(output_file, source_file)
        File.exist?(output_file) && File.mtime(output_file) > File.mtime(source_file)
      end
    end
  end
end
