# frozen_string_literal: true

require "yaml"
require "fileutils"
require "ruby-progressbar"
require "etc"
require "timeout"
require "open3"
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

        # Check if we should use Ractors for parallel processing
        if options[:parallel] && ractor_supported? && !ENV["HRMA_DISABLE_RACTORS"]
          begin
            generate_parallel(xsd_files)
          rescue => e
            puts "Error using Ractors for parallel processing: #{e.message}"
            puts "Falling back to sequential processing"
            generate_sequential(xsd_files)
          end
        else
          puts "Using sequential processing (parallel processing disabled or not supported)"
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
      # @param requested_ractors [Integer, nil] User-requested number of ractors
      # @return [Integer] Optimal number of ractors to use
      def calculate_auto_ractors(file_count, requested_ractors = nil)
        # Return specific numbers if explicitly requested
        return requested_ractors if requested_ractors && requested_ractors > 0

        # Get total number of cores
        cores = Etc.nprocessors
        puts "System has #{cores} CPU cores"

        # Calculate optimal ractor count
        # For "auto" mode, use the maximum between 1 and half the number of cores
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

      # Generate documentation in parallel using Ractors in a ring pattern with supervisor
      #
      # @param xsd_files [Array<String>] List of XSD files to process
      # @return [void]
      def generate_parallel(xsd_files)
        # Use provided ractors count or calculate automatically
        requested_ractors = options[:ractors] ? options[:ractors].to_i : nil
        ractor_count = calculate_auto_ractors(xsd_files.size, requested_ractors)

        puts "Generating documentation in parallel using #{ractor_count} ractors in a ring topology..."

        # Create log directory per schema if logging is enabled
        if @log_dir
          log_dir = @log_dir.to_s
          FileUtils.mkdir_p(log_dir) unless Dir.exist?(log_dir)
        else
          log_dir = nil
        end

        # Pass necessary tool paths to Ractors - make them shareable
        tools_constants = {
          xsdvi_path: Tools::XSDVI_PATH.to_s,
          xsdmerge_path: Tools::XSDMERGE_PATH.to_s,
          xs3p_path: Tools::XS3P_PATH.to_s
        }
        tools_constants = Ractor.make_shareable(tools_constants)

        # Current working directory as shareable string
        pwd_copy = Dir.pwd.to_s

        # Ensure xsd_files is shareable - convert all entries to simple strings
        shareable_files = xsd_files.map { |f| f.to_s.dup }
        shareable_files = Ractor.make_shareable(shareable_files)

        # Initialize current Ractor as start of the ring
        r = Ractor.current

        # Create ring of ractors following the sample pattern
        rs = (1..ractor_count).map do |i|
          r = Hrma::Build::RactorDocumentProcessor.make_processor_ractor(
            r, i, tools_constants, log_dir, pwd_copy
          )
        end

        # Track processed files and failures
        failed_files = []
        processed_count = 0

        # Process files following the ring pattern with supervisor and restart
        shareable_files.each do |file|
          puts "Processing: #{file}"
          msg = file

          begin
            # Send the file to the first Ractor in the ring
            rs.first.send(msg)

            # Wait for the result to cycle through the ring back to us
            result = Ractor.select(*rs, Ractor.current)[1]

            # Process the result
            if result.is_a?(Array) && result.size >= 3
              file_path = result[0].to_s
              success = !!result[1]  # Convert to boolean explicitly
              error_message = result[2] ? result[2].to_s : nil

              processed_count += 1
              progressbar.increment

              if success
                puts "Successfully processed #{file_path} (#{processed_count}/#{xsd_files.size})"
              else
                failed_files << "#{file_path}: #{error_message}"
                puts "\nError processing #{file_path}: #{error_message}"
              end
            end

          rescue Ractor::RemoteError => e
            puts "Ractor error detected: #{e.message}"
            puts "Restarting failed Ractor..."

            # Restart the last Ractor in the ring, following the sample pattern
            r = rs[-1] = Hrma::Build::RactorDocumentProcessor.make_processor_ractor(
              rs[-2], ractor_count, tools_constants, log_dir, pwd_copy
            )

            # Use 'x0' as a safe message that won't trigger an error
            msg = file.gsub('e', 'x')

            # Retry with the safe message
            retry
          end
        end

        # Clean up by sending :exit signal to all Ractors
        puts "All files processed, cleaning up Ractors"
        rs.each_with_index do |ractor, i|
          begin
            ractor.send(:exit)
          rescue => e
            puts "Warning: Failed to cleanly exit Ractor #{i}: #{e.message}"
          end
        end

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
