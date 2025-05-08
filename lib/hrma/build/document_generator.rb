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

        # Always use parallel processing with Fractor
        generate_parallel(xsd_files)

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

        # Create work items with simple data structures (strings only)
        # This ensures Ractor-safety by avoiding complex objects
        work_items = xsd_files.map do |xsd_file|
          # Create log file path for this file if log_dir is specified
          log_file = nil
          if @log_dir
            log_file_name = "#{File.basename(xsd_file, '.xsd')}.log"
            log_file = File.join(@log_dir, log_file_name)
            FileUtils.mkdir_p(File.dirname(log_file))
          end

          # Create SchemaWork with primitive data only
          SchemaWork.new({
            schema_path: xsd_file.to_s,  # Ensure it's a string
            log_file: log_file.to_s      # Ensure it's a string or nil
          })
        end

        # Create supervisor with worker pools
        begin
          supervisor = Fractor::Supervisor.new(
            worker_pools: [
              { worker_class: SchemaWorker, num_workers: num_workers }
            ]
          )

          # Add work items
          supervisor.add_work_items(work_items)

          # Run processing with timeout handling
          supervisor.run

          # Process results
          process_results(supervisor.results)
        rescue => e
          puts "Error in parallel processing: #{e.message}"
          puts e.backtrace.join("\n")
          # Raise error to stop processing completely
          raise "Parallel processing failed: #{e.message}"
        end
      end

      # Process results from parallel processing
      #
      # @param aggregator [Fractor::ResultAggregator] Result aggregator
      # @return [void]
      def process_results(aggregator)
        # Handle successful results
        aggregator.results.each do |result|
          # Access schema_path safely through input hash
          schema_path = result.work.input[:schema_path]
          puts "Successfully processed #{schema_path}"
          progressbar.increment
        end

        # Handle errors
        if aggregator.errors.any?
          puts "\nEncountered errors during processing:"
          aggregator.errors.each do |error_result|
            # Access schema_path safely through input hash
            schema_path = error_result.work.input[:schema_path]
            puts "Error processing #{schema_path}: #{error_result.error}"
            progressbar.increment
          end
        end
      end

      private

      # Load XSD files from schemas.yml
      #
      # @return [Array<String>] List of XSD files to process
      def load_xsd_files
        yaml_path = options[:manifest_path]
        manifest = YAML.load_file(yaml_path)

        xsd_files = []
        if manifest.dig("source", "schemas", "xsd")
          xsd_files = manifest["source"]["schemas"]["xsd"]
        else
          puts "No XSD files found in #{yaml_path}"
        end

        xsd_files
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
