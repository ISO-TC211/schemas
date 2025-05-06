# frozen_string_literal: true

require "yaml"
require "fileutils"
require "ruby-progressbar"
require "logger"
require_relative "../config"
require_relative "schema_processor"

module Hrma
  module Build
    # Class for generating documentation for XSD files
    class DocumentGenerator
      # @return [Hash] Options for document generation
      # @return [ProgressBar] Progress bar for tracking document generation
      attr_reader :options, :progressbar

      # Initialize a new DocumentGenerator
      #
      # @param options [Hash] Options for document generation
      # @option options [String] :manifest_path Path to schemas.yml manifest file
      # @option options [String] :log_dir Directory for storing log files
      def initialize(options = {})
        @options = options
        @log_dir = Hrma::Config.log_dir
      end

      # Generate documentation for all XSD files in schemas.yml
      #
      # @return [void]
      def generate
        xsd_files = load_xsd_files
        return if xsd_files.empty?

        puts "Found #{xsd_files.size} XSD files to process"
        @progressbar = create_progressbar(xsd_files.size)

        generate_sequential(xsd_files)

        puts "\nDocumentation generation complete. See _site/ directory."
      end

      private

      # Load XSD files from schemas.yml
      #
      # @return [Array<String>] List of XSD files to process
      def load_xsd_files
        yaml_path = options[:manifest_path] || File.join(Dir.pwd, "schemas.yml")
        manifest = YAML.load_file(yaml_path)

        xsd_files = []
        if manifest.dig("source", "schemas", "xsd")
          xsd_files = manifest["source"]["schemas"]["xsd"]
        elsif manifest.dig("source", "schemas") && manifest["source"]["schemas"].is_a?(Array)
          xsd_files = manifest["source"]["schemas"]
        end

        xsd_files
      end

      # Generate documentation sequentially
      #
      # @param xsd_files [Array<String>] List of XSD files to process
      # @return [void]
      def generate_sequential(xsd_files)
        puts "Generating documentation sequentially..."

        # Create a schema processor
        processor = SchemaProcessor.new

        # Process each file
        xsd_files.each do |xsd_file|
          puts "Processing: #{xsd_file}"

          # Create a logger for this file if log_dir is specified
          logger = create_logger(xsd_file) if @log_dir

          # Process the file
          result = processor.process(schema_path: xsd_file, logger: logger)

          # Close the logger if it was created
          logger&.close

          # Handle the result
          if result
            puts "Successfully processed #{xsd_file}"
          else
            puts "Error processing #{xsd_file}"
          end

          progressbar.increment
        end
      end

      # Create a logger for a specific file
      #
      # @param xsd_file [String] Path to the XSD file
      # @return [Logger] Logger for the file
      def create_logger(xsd_file)
        log_file = File.join(@log_dir, "#{File.basename(xsd_file, '.xsd')}.log")
        FileUtils.mkdir_p(File.dirname(log_file))

        logger = Logger.new(log_file)
        logger.level = Logger::INFO
        logger.formatter = proc do |severity, datetime, progname, msg|
          "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{msg}\n"
        end

        logger
      end

      # Create a progress bar
      #
      # @param total [Integer] Total number of items
      # @return [ProgressBar] Progress bar object
      def create_progressbar(total)
        ProgressBar.create(
          title: "Progress",
          total: total,
          format: "%t: |%B| %p%% %e",
          output: $stdout
        )
      end
    end
  end
end
