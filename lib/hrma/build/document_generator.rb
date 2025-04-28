# frozen_string_literal: true

require "yaml"
require "fileutils"
require "ruby-progressbar"
require "etc"
require "timeout"
require_relative "../config"
require_relative "tools"
require_relative "ractor_document_processor"

module Hrma
  module Build
    # Class for generating documentation for XSD files
    class DocumentGenerator
      include FileUtils

      attr_reader :options, :progressbar

      def initialize(options = {})
        @options = options
        @log_dir = Hrma::Config.log_dir
      end

      # Generate documentation for all XSD files in schemas.yml
      def generate
        xsd_files = load_xsd_files
        return if xsd_files.empty?

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
      def ractor_supported?
        defined?(Ractor) && Ractor.respond_to?(:new)
      rescue
        false
      end

      # Generate documentation sequentially
      def generate_sequential(xsd_files)
        puts "Generating documentation sequentially..."

        xsd_files.each do |xsd_file|
          process_xsd_file(xsd_file)
          progressbar.increment
        end
      end

      # Generate documentation in parallel using Ractors
      def generate_parallel(xsd_files)
        thread_count = options[:threads] || [Etc.nprocessors, xsd_files.size].min
        puts "Generating documentation in parallel using #{thread_count} threads..."

        # Pre-load all necessary libraries that might be used by Ractors
        # These must be loaded in the main thread before any Ractor is created
        require 'fileutils'

        # Process files in parallel
        total = xsd_files.size
        failed_files = []
        mutex = Mutex.new

        # Split files into chunks for each Ractor
        file_chunks = xsd_files.each_slice((xsd_files.size.to_f / thread_count).ceil).to_a
        puts "Split #{xsd_files.size} files into #{file_chunks.size} chunks..."

        # Pass necessary tool paths to Ractors
        tools_constants = {
          xsdvi_path: Tools::XSDVI_PATH,
          xsdmerge_path: Tools::XSDMERGE_PATH,
          xs3p_path: Tools::XS3P_PATH
        }

        # Create a Ractor for each chunk
        ractors = []
        file_chunks.each_with_index do |chunk, index|
          puts "Creating Ractor #{index} for #{chunk.size} files..."

          # Create Ractor with minimal context
          ractor = Ractor.new(chunk, @log_dir, Dir.pwd, tools_constants) do |files, log_dir, pwd, tool_paths|
            # Use our dedicated processor class inside the Ractor
            # The class contains all logic needed to process files
            Hrma::Build::RactorDocumentProcessor.process(files, log_dir, pwd, tool_paths)
          end

          ractors << ractor
        end

        # Process results as they come in
        ractors.each_with_index do |ractor, index|
          begin
            puts "Waiting for results from Ractor #{index}..."
            results = ractor.take

            # Process the results
            results.each do |file, success, error_message|
              mutex.synchronize do
                progressbar.increment

                if !success && error_message
                  failed_files << "#{file}: #{error_message}"
                  puts "\nError processing #{file}: #{error_message}"
                end
              end
            end
          rescue => e
            puts "\nError getting results from Ractor #{index}: #{e.message}"
          end
        end

        if !failed_files.empty?
          puts "\nFailed to process #{failed_files.size} files. See logs for details."
        end
      end

      # Process a single XSD file
      def process_xsd_file(xsd_file)
        if @log_dir
          log_file = File.join(@log_dir, "#{File.basename(xsd_file, '.xsd')}.log")
          puts "Generating documentation for #{xsd_file}... (Logging to #{log_file})"

          # Capture original stdout
          original_stdout = $stdout.dup
          begin
            # Redirect stdout to log file
            $stdout.reopen(log_file, 'w')
            generate_doc_for_xsd(xsd_file)
          ensure
            # Restore stdout
            $stdout.reopen(original_stdout)
          end
        else
          puts "Generating documentation for #{xsd_file}..."
          generate_doc_for_xsd(xsd_file)
        end
      end

      # Process a file within a ractor
      def self.process_file_in_ractor(xsd_file, ractor_id, log_dir)
        if log_dir
          log_file = File.join(log_dir, "#{File.basename(xsd_file, '.xsd')}_ractor#{ractor_id}.log")
          File.open(log_file, 'w') do |f|
            f.puts "Processing #{xsd_file} in Ractor #{ractor_id}"
            result = generate_doc_for_xsd_with_logging(xsd_file, f)
            return result
          end
        else
          return generate_doc_for_xsd_without_logging(xsd_file)
        end
      end

      # Generate documentation for a single XSD file with logging
      def self.generate_doc_for_xsd_with_logging(xsd_file, log)
        target_html = xsd_file.sub(/\.xsd$/, "")
        output_dir = "_site/#{target_html}"
        output_file = "#{output_dir}/index.html"

        # Skip if the output file is newer than the source file
        if File.exist?(output_file) && File.mtime(output_file) > File.mtime(xsd_file)
          log.puts "Skipping #{xsd_file} (up to date)"
          return true
        end

        log.puts "Generating documentation for #{xsd_file}..."

        # Create output directory
        FileUtils.mkdir_p("#{output_dir}/diagrams")

        # Generate diagrams
        diagrams_cmd = "java -jar #{Tools::XSDVI_PATH} #{Dir.pwd}/#{xsd_file} -rootNodeName all -oneNodeOnly -outputPath #{output_dir}/diagrams"
        log.puts "Running: #{diagrams_cmd}"
        unless system(diagrams_cmd, out: log, err: log)
          log.puts "Error generating diagrams for #{xsd_file}"
          return false
        end

        # Generate documentation
        temp_file = "#{output_file}.tmp"
        xsdmerge_cmd = "xsltproc --nonet --stringparam rootxsd #{xsd_file} --output #{temp_file} #{Tools::XSDMERGE_PATH} #{xsd_file}"
        log.puts "Running: #{xsdmerge_cmd}"
        unless system(xsdmerge_cmd, out: log, err: log)
          log.puts "Error generating merged XSD for #{xsd_file}"
          return false
        end

        file_basename = File.basename(target_html)
        xs3p_cmd = "xsltproc --nonet --param title \"'Schema Documentation for #{file_basename}'\" --output #{output_file} #{Tools::XS3P_PATH} #{temp_file}"
        log.puts "Running: #{xs3p_cmd}"
        unless system(xs3p_cmd, out: log, err: log)
          log.puts "Error generating documentation for #{xsd_file}"
          return false
        end

        FileUtils.rm(temp_file)
        true
      end

      # Generate documentation for a single XSD file without logging
      def self.generate_doc_for_xsd_without_logging(xsd_file)
        target_html = xsd_file.sub(/\.xsd$/, "")
        output_dir = "_site/#{target_html}"
        output_file = "#{output_dir}/index.html"

        # Skip if the output file is newer than the source file
        if File.exist?(output_file) && File.mtime(output_file) > File.mtime(xsd_file)
          return true
        end

        # Create output directory
        FileUtils.mkdir_p("#{output_dir}/diagrams")

        # Generate diagrams
        unless system("java -jar #{Tools::XSDVI_PATH} #{Dir.pwd}/#{xsd_file} -rootNodeName all -oneNodeOnly -outputPath #{output_dir}/diagrams")
          return false
        end

        # Generate documentation
        temp_file = "#{output_file}.tmp"
        unless system("xsltproc --nonet --stringparam rootxsd #{xsd_file} --output #{temp_file} #{Tools::XSDMERGE_PATH} #{xsd_file}")
          return false
        end

        file_basename = File.basename(target_html)
        unless system("xsltproc --nonet --param title \"'Schema Documentation for #{file_basename}'\" --output #{output_file} #{Tools::XS3P_PATH} #{temp_file}")
          return false
        end

        FileUtils.rm(temp_file)
        true
      end

      # Generate documentation for a single XSD file (instance method)
      def generate_doc_for_xsd(xsd_file)
        target_html = xsd_file.sub(/\.xsd$/, "")
        output_dir = "_site/#{target_html}"
        output_file = "#{output_dir}/index.html"

        # Skip if the output file is newer than the source file
        if File.exist?(output_file) && File.mtime(output_file) > File.mtime(xsd_file)
          puts "Skipping #{xsd_file} (up to date)"
          return
        end

        puts "Generating documentation for #{xsd_file}..."

        # Create output directory
        mkdir_p("#{output_dir}/diagrams")

        # Generate diagrams
        unless system("java -jar #{Tools::XSDVI_PATH} #{Dir.pwd}/#{xsd_file} -rootNodeName all -oneNodeOnly -outputPath #{output_dir}/diagrams")
          puts "Error generating diagrams for #{xsd_file}"
          return
        end

        # Generate documentation
        temp_file = "#{output_file}.tmp"
        unless system("xsltproc --nonet --stringparam rootxsd #{xsd_file} --output #{temp_file} #{Tools::XSDMERGE_PATH} #{xsd_file}")
          puts "Error generating merged XSD for #{xsd_file}"
          return
        end

        file_basename = File.basename(target_html)
        unless system("xsltproc --nonet --param title \"'Schema Documentation for #{file_basename}'\" --output #{output_file} #{Tools::XS3P_PATH} #{temp_file}")
          puts "Error generating documentation for #{xsd_file}"
          return
        end

        rm(temp_file)
      end

      # Create a progress bar
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
