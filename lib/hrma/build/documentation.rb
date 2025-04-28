# frozen_string_literal: true

require "yaml"
require "fileutils"
require "ruby-progressbar"
require "etc"
require_relative "../config"
require_relative "tools"
require_relative "ractor_document_processor"

module Hrma
  module Build
    # Handles documentation generation for XSD files
    module Documentation
      include FileUtils

      module_function

      # Generate documentation for all XSD files in schemas.yml
      #
      # @param options [Hash] Options for document generation
      # @option options [String] :manifest_path Path to schemas.yml manifest file
      # @option options [Boolean] :parallel Enable parallel processing with Ractors
      # @option options [Integer] :ractors Number of parallel ractors to use
      # @option options [String] :cache_dir Directory for caching downloaded tools
      # @option options [String] :log_dir Directory for storing log files
      # @return [void]
      def generate(options = {})
        xsd_files = load_xsd_files(options[:manifest_path])
        return if xsd_files.empty?

        puts "Found #{xsd_files.size} XSD files to process"
        progressbar = create_progressbar(xsd_files.size)

        if options[:parallel] && ractor_supported? && !ENV["HRMA_DISABLE_RACTORS"]
          generate_parallel(xsd_files, options, progressbar)
        else
          generate_sequential(xsd_files, progressbar)
        end

        puts "\nDocumentation generation complete. See _site/ directory."
      end

      # Load XSD files from schemas.yml
      #
      # @param manifest_path [String, nil] Path to schemas.yml manifest file
      # @return [Array<String>] List of XSD files to process
      def load_xsd_files(manifest_path = nil)
        yaml_path = manifest_path || File.join(Dir.pwd, "schemas.yml")
        manifest = YAML.load_file(yaml_path)

        xsd_files = []
        if manifest.dig("source", "schemas", "xsd")
          xsd_files = manifest["source"]["schemas"]["xsd"]
        elsif manifest.dig("source", "schemas") && manifest["source"]["schemas"].is_a?(Array)
          xsd_files = manifest["source"]["schemas"]
        end

        xsd_files
      end

      # Check if Ractor is supported
      #
      # @return [Boolean] True if Ractor is supported
      def ractor_supported?
        defined?(Ractor) && Ractor.respond_to?(:new)
      rescue StandardError
        false
      end

      # Generate documentation sequentially
      #
      # @param xsd_files [Array<String>] List of XSD files to process
      # @param progressbar [ProgressBar] Progress bar for tracking document generation
      # @return [void]
      def generate_sequential(xsd_files, progressbar)
        puts "Generating documentation sequentially..."

        # Process each XSD file
        xsd_files.each do |xsd_file|
          puts "Processing: #{xsd_file}"
          process_xsd_file(xsd_file)
          progressbar.increment
        end
      end

      # Process a single XSD file
      #
      # @param xsd_file [String] Path to the XSD file
      # @return [void]
      def process_xsd_file(xsd_file)
        log_dir = Hrma::Config.log_dir

        if log_dir
          process_with_logging(xsd_file, log_dir)
        else
          puts "Generating documentation for #{xsd_file}..."
          result = process_single_file(xsd_file)
          puts "Error: #{result}" if result.is_a?(String)
        end
      end

      # Process a file with logging
      #
      # @param xsd_file [String] Path to the XSD file
      # @param log_dir [String] Directory for log files
      # @return [void]
      def process_with_logging(xsd_file, log_dir)
        log_file = File.join(log_dir, "#{File.basename(xsd_file, '.xsd')}.log")
        puts "Generating documentation for #{xsd_file}... (Logging to #{log_file})"

        FileUtils.mkdir_p(File.dirname(log_file))

        # Capture original stdout
        original_stdout = $stdout.dup
        begin
          # Redirect stdout to log file
          $stdout.reopen(log_file, 'w')
          result = process_single_file(xsd_file)
          puts "Error: #{result}" if result.is_a?(String)
        ensure
          # Restore stdout
          $stdout.reopen(original_stdout)
        end
      end

      # Process a single file
      #
      # @param xsd_file [String] Path to the XSD file
      # @return [true, String] True if successful, error message string if failed
      def process_single_file(xsd_file)
        # Use the RactorDocumentProcessor to process the file
        # This avoids code duplication
        tool_paths = {
          xsdvi_path: Tools::XSDVI_PATH,
          xsdmerge_path: Tools::XSDMERGE_PATH,
          xs3p_path: Tools::XS3P_PATH
        }

        RactorDocumentProcessor.process_file_without_logging(xsd_file, Dir.pwd, tool_paths)
      end

      # Calculate the optimal number of ractors to use
      #
      # @param file_count [Integer] Number of files to process
      # @return [Integer] Optimal number of ractors to use
      def calculate_auto_ractors(file_count)
        # Get total number of cores
        cores = Etc.nprocessors
        puts "System has #{cores} CPU cores"

        # Calculate optimal ractor count
        # Use the maximum between 1 and half the number of cores
        optimal_ractors = [1, cores / 2].max
        puts "Optimal ractors (max of 1 and half cores): #{optimal_ractors}"

        # Ensure at least 2 cores are left free
        if optimal_ractors > cores - 2
          adjusted_ractors = [cores - 2, 1].max
          puts "Adjusted to leave 2 cores free: #{adjusted_ractors}"
          optimal_ractors = adjusted_ractors
        else
          puts "No adjustment needed, already leaves at least 2 cores free"
        end

        # Use file_count as ractor count if we have enough cores
        # This means we'll process each file in its own ractor if possible
        result = [optimal_ractors, file_count].min
        puts "Final ractor count (min of optimal ractors and file count): #{result}"

        result
      end

      # Generate documentation in parallel using Ractors
      #
      # @param xsd_files [Array<String>] List of XSD files to process
      # @param options [Hash] Options for document generation
      # @param progressbar [ProgressBar] Progress bar for tracking document generation
      # @return [void]
      def generate_parallel(xsd_files, options, progressbar)
        # Use provided ractors count or calculate automatically
        ractor_count = if options[:ractors]
                         options[:ractors].to_i
                       else
                         calculate_auto_ractors(xsd_files.size)
                       end

        puts "Generating documentation in parallel using #{ractor_count} ractors..."

        # Process files in parallel
        failed_files = []
        mutex = Mutex.new

        # Pass necessary tool paths to Ractors
        tools_constants = {
          xsdvi_path: Tools::XSDVI_PATH,
          xsdmerge_path: Tools::XSDMERGE_PATH,
          xs3p_path: Tools::XS3P_PATH
        }

        # Create a pool Ractor that will distribute work
        pool = Ractor.new do
          # This Ractor acts as a work distributor
          loop do
            # Receive a file to process and yield it to any worker that asks
            file = Ractor.receive
            puts "Queue: Received file #{file} for processing"
            Ractor.yield(file)
          end
        end

        # Create worker Ractors
        workers = ractor_count.times.map do |i|
          Ractor.new(pool, Hrma::Config.log_dir, Dir.pwd, tools_constants, i) do |pool, log_dir, pwd, tool_paths, id|
            # Worker Ractor
            loop do
              begin
                # Take a file from the pool
                file = pool.take
                puts "Worker #{id}: Processing file #{file}"

                # Process the file
                result = Hrma::Build::RactorDocumentProcessor.process_single_file(file, log_dir, pwd, tool_paths)

                # Yield the result
                Ractor.yield([file, *result])
              rescue Ractor::ClosedError
                # Pool is closed, exit the loop
                puts "Worker #{id}: Pool closed, exiting"
                break
              end
            end
          end
        end

        # Send all files to the pool
        xsd_files.each do |file|
          puts "Main: Sending file #{file} to queue"
          pool.send(file)
        end

        # Process results as they come in
        xsd_files.size.times do
          # Wait for any worker to produce a result
          worker, result = Ractor.select(*workers)

          # Process the result
          file, success, error_message = result

          mutex.synchronize do
            progressbar.increment

            if success
              puts "Main: Successfully processed #{file}"
            else
              failed_files << "#{file}: #{error_message}"
              puts "\nError processing #{file}: #{error_message}"
            end
          end
        end

        # Close the pool to signal workers to exit
        puts "Main: All files processed, closing pool"
        pool.close_outgoing

        if !failed_files.empty?
          puts "\nFailed to process #{failed_files.size} files. See logs for details."
        end
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
