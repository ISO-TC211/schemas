# frozen_string_literal: true

require "yaml"
require "fileutils"
require "ruby-progressbar"
require "logger"
require "etc"
require "fractor"
require_relative "../config"
require_relative "schema_processor"
require_relative "schema_work"
require_relative "schema_worker"

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

        if options[:parallel] == false
          generate_sequential(xsd_files)
        else
          generate_parallel(xsd_files)
        end

        puts "\nDocumentation generation complete. See _site/ directory."
      end

      # Generate documentation in parallel using Fractors
      #
      # @param xsd_files [Array<String>] List of XSD files to process
      # @return [void]
      def generate_parallel(xsd_files)
        puts "Generating documentation in parallel..."

        # Determine number of workers - use either the specified number or auto-detect
        num_workers = options[:workers] || [xsd_files.size, Etc.nprocessors].min
        puts "Using #{num_workers} parallel workers"

        # Create work items - each item contains just the basic string path and log file path
        work_items = xsd_files.map do |xsd_file|
          # Create log file path for this file if log_dir is specified
          log_file = nil
          if @log_dir
            log_file_name = "#{File.basename(xsd_file, '.xsd')}.log"
            log_file = File.join(@log_dir, log_file_name)
            FileUtils.mkdir_p(File.dirname(log_file))
          end

          # Use the original string path directly - no nested objects
          SchemaWork.new({
            schema_path: xsd_file,  # This is just a string
            log_file: log_file
          })
        end

        # Create supervisor with worker pools
        supervisor = Fractor::Supervisor.new(
          worker_pools: [
            { worker_class: SchemaWorker, num_workers: num_workers }
          ]
        )

        # Add work items
        supervisor.add_work_items(work_items)

        # Run processing
        supervisor.run

        # Process results
        process_results(supervisor.results)
      end

      # Process results from parallel processing
      #
      # @param aggregator [Fractor::ResultAggregator] Result aggregator
      # @return [void]
      def process_results(aggregator)
        # Handle successful results
        aggregator.results.each do |result|
          schema_path = result.work.input[:schema_path]
          puts "Successfully processed #{schema_path}"
          progressbar.increment
        end

        # Handle errors
        aggregator.errors.each do |error_result|
          schema_path = error_result.work.input[:schema_path]
          puts "Error processing #{schema_path}: #{error_result.error}"
          progressbar.increment
        end
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

      # Generate documentation sequentially (using parallel processing with 1 worker)
      #
      # @param xsd_files [Array<String>] List of XSD files to process
      # @return [void]
      def generate_sequential(xsd_files)
        puts "Generating documentation sequentially (single worker)..."

        # Just use parallel processing with 1 worker
        options_with_one_worker = options.dup
        options_with_one_worker[:workers] = 1
        @options = options_with_one_worker

        # Use the parallel implementation with 1 worker
        generate_parallel(xsd_files)
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
