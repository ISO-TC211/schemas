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
    # Class for generating documentation for XSD files
    class DocumentGenerator
      include FileUtils

      # @return [Hash] Options for document generation
      # @return [ProgressBar] Progress bar for tracking document generation
      attr_reader :options, :progressbar

      # Initialize a new DocumentGenerator
      #
      # @param options [Hash] Options for document generation
      # @option options [String] :manifest_path Path to schemas.yml manifest file
      # @option options [Boolean] :parallel Enable parallel processing with Ractors
      # @option options [Integer] :ractors Number of parallel ractors to use
      # @option options [String] :cache_dir Directory for caching downloaded tools
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

        if options[:parallel] && ractor_supported? && !ENV["HRMA_DISABLE_RACTORS"]
          generate_parallel(xsd_files)
        else
          generate_sequential(xsd_files)
        end

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
      # @return [void]
      def generate_sequential(xsd_files)
        puts "Generating documentation sequentially..."

        xsd_files.each do |xsd_file|
          puts "Processing: #{xsd_file}"
          process_xsd_file(xsd_file)
          progressbar.increment
        end
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
      # @return [void]
      def generate_parallel(xsd_files)
        # Use provided ractors count or calculate automatically
        ractor_count = if options[:ractors]
                         options[:ractors].to_i
                       else
                         calculate_auto_ractors(xsd_files.size)
                       end

        puts "Generating documentation in parallel using #{ractor_count} ractors..."

        # Pre-load all necessary libraries that might be used by Ractors
        # These must be loaded in the main thread before any Ractor is created
        require 'fileutils'

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

            # Signal which file is being sent to workers
            Ractor.yield(file)
          end
        end

        # Create worker Ractors with improved error handling
        workers = ractor_count.times.map do |i|
          Ractor.new(pool, @log_dir, Dir.pwd, tools_constants, i) do |pool, log_dir, pwd, tool_paths, id|
            # Worker Ractor
            loop do
              begin
                # Take a file from the pool with timeout to prevent deadlocks
                file = nil
                begin
                  # Print worker ID to help with debugging
                  puts "Worker #{id}: Waiting for work..."
                  file = pool.take
                  puts "Worker #{id}: Processing file #{file}"
                rescue => e
                  puts "Worker #{id}: Error taking work: #{e.message}"
                  # Sleep briefly to avoid tight loop if there's an error
                  sleep 0.1
                  next
                end

                # Process the file with timeout protection
                result = nil
                begin
                  # Use timeout to prevent hanging on external processes
                  require 'timeout'
                  result = Timeout.timeout(300) do # 5 minute timeout
                    Hrma::Build::RactorDocumentProcessor.process_single_file(file, log_dir, pwd, tool_paths)
                  end
                rescue Timeout::Error
                  puts "Worker #{id}: Timeout processing file #{file}"
                  result = [file, false, "Timeout after 300 seconds"]
                rescue => e
                  puts "Worker #{id}: Error processing file #{file}: #{e.message}"
                  result = [file, false, "Exception: #{e.message}"]
                end

                # Yield the result
                Ractor.yield([file, *result])
              rescue Ractor::ClosedError
                # Pool is closed, exit the loop
                puts "Worker #{id}: Pool closed, exiting"
                break
              rescue => e
                # Catch any other errors to prevent worker from dying
                puts "Worker #{id}: Unexpected error: #{e.class} - #{e.message}"
                # Don't break the loop, try to continue with next file
              end
            end
          end
        end

        # Send all files to the pool with better error handling
        xsd_files.each do |file|
          begin
            puts "Main: Sending file #{file} to queue"
            pool.send(file)
          rescue => e
            puts "Main: Error sending file #{file} to queue: #{e.message}"
            mutex.synchronize do
              failed_files << "#{file}: Failed to queue - #{e.message}"
            end
          end
        end

        # Process results as they come in with timeout protection
        processed_count = 0
        begin
          # Use timeout for the entire processing to prevent hanging
          require 'timeout'
          Timeout.timeout(xsd_files.size * 60) do # Allow average 1 minute per file
            while processed_count < xsd_files.size
              begin
                # Wait for any worker to produce a result with a timeout
                worker, result = Ractor.select(*workers)

                # Process the result
                file, success, error_message = result

                mutex.synchronize do
                  processed_count += 1
                  progressbar.increment

                  if success
                    puts "Main: Successfully processed #{file} (#{processed_count}/#{xsd_files.size})"
                  else
                    failed_files << "#{file}: #{error_message}"
                    puts "\nError processing #{file}: #{error_message}"
                  end
                end
              rescue => e
                puts "Main: Error receiving result: #{e.message}"
                # Continue trying to receive results
              end
            end
          end
        rescue Timeout::Error
          puts "\nTimeout waiting for all files to process. Some files may not have been processed."
        end

        # Close the pool to signal workers to exit
        puts "Main: All files processed, closing pool"
        pool.close_outgoing

        if !failed_files.empty?
          puts "\nFailed to process #{failed_files.size} files. See logs for details."
        end
      end

      # Process a single XSD file
      #
      # @param xsd_file [String] Path to the XSD file
      # @return [void]
      def process_xsd_file(xsd_file)
        if @log_dir
          process_with_logging(xsd_file)
        else
          puts "Generating documentation for #{xsd_file}..."
          result = process_single_file(xsd_file)
          puts "Error: #{result}" if result.is_a?(String)
        end
      end

      # Process a file with logging
      #
      # @param xsd_file [String] Path to the XSD file
      # @return [void]
      def process_with_logging(xsd_file)
        log_file = File.join(@log_dir, "#{File.basename(xsd_file, '.xsd')}.log")
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
        # Get paths for processing
        paths = get_file_paths(xsd_file)

        # Skip if up to date
        if skip_if_up_to_date?(paths[:output_file], xsd_file)
          puts "Skipping #{xsd_file} (up to date)"
          return true
        end

        puts "Generating documentation for #{xsd_file}..."

        # Create output directory
        mkdir_p("#{paths[:output_dir]}/diagrams")

        # Generate diagrams
        diagrams_cmd = "java -jar #{Tools::XSDVI_PATH} #{Dir.pwd}/#{xsd_file} -rootNodeName all -oneNodeOnly -outputPath #{paths[:output_dir]}/diagrams"
        unless system(diagrams_cmd)
          return "Error generating diagrams for #{xsd_file}"
        end

        # Generate documentation
        unless generate_documentation(xsd_file, paths)
          return "Error generating documentation for #{xsd_file}"
        end

        true
      end

      # Generate documentation for a file
      #
      # @param xsd_file [String] Path to the XSD file
      # @param paths [Hash] Hash containing all necessary paths
      # @return [Boolean] True if successful
      def generate_documentation(xsd_file, paths)
        # Generate merged XSD
        xsdmerge_cmd = "xsltproc --nonet --stringparam rootxsd #{xsd_file} --output #{paths[:temp_file]} #{Tools::XSDMERGE_PATH} #{xsd_file}"
        unless system(xsdmerge_cmd)
          puts "Error generating merged XSD for #{xsd_file}"
          return false
        end

        # Generate final documentation
        file_basename = File.basename(paths[:target_html])
        xs3p_cmd = "xsltproc --nonet --param title \"'Schema Documentation for #{file_basename}'\" --output #{paths[:output_file]} #{Tools::XS3P_PATH} #{paths[:temp_file]}"
        unless system(xs3p_cmd)
          puts "Error generating documentation for #{xsd_file}"
          return false
        end

        # Clean up temporary file
        rm(paths[:temp_file])
        true
      end

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
