# frozen_string_literal: true

require "yaml"
require "fileutils"
require "ruby-progressbar"
require "etc"
require_relative "../config"
require_relative "tools"

module Hrma
  module Build
    # Handles documentation generation for XSD files
    module Documentation
      include FileUtils

      module_function

      # Generate documentation for all XSD files in schemas.yml
      def generate(options = {})
        xsd_files = load_xsd_files(options[:manifest_path])
        return if xsd_files.empty?

        if options[:parallel] && ractor_supported? && !ENV["HRMA_DISABLE_RACTORS"]
          generate_parallel(xsd_files, options)
        else
          generate_sequential(xsd_files, options)
        end

        puts "\nDocumentation generation complete. See _site/ directory."
      end

      # Load XSD files from schemas.yml
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
      def ractor_supported?
        defined?(Ractor) && Ractor.respond_to?(:new)
      rescue
        false
      end

      # Generate documentation sequentially
      def generate_sequential(xsd_files, options = {})
        puts "Generating documentation sequentially..."

        # Setup progress bar
        progressbar = create_progressbar(xsd_files.size)

        # Process each XSD file
        xsd_files.each do |xsd_file|
          # Redirect output to log file if log_dir is configured
          if Hrma::Config.log_dir
            log_file = File.join(Hrma::Config.log_dir, "#{File.basename(xsd_file, '.xsd')}.log")
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

          progressbar.increment
        end
      end

      # Generate documentation in parallel using Ractors
      def generate_parallel(xsd_files, options = {})
        # Determine number of threads to use (default to CPU count)
        thread_count = options[:threads] || [Etc.nprocessors, xsd_files.size].min
        puts "Generating documentation in parallel using #{thread_count} threads..."

        # Setup progress bar
        progressbar = create_progressbar(xsd_files.size)
        mutex = Mutex.new

        # Create Ractors to process XSD files
        ractors = []

        # Split files among ractors
        file_chunks = xsd_files.each_slice((xsd_files.size.to_f / thread_count).ceil).to_a

        file_chunks.each_with_index do |chunk, index|
          ractors << Ractor.new(chunk, index, Hrma::Config.log_dir) do |files, ractor_id, log_dir|
            require 'fileutils'

            files.map do |xsd_file|
              begin
                if log_dir
                  log_file = File.join(log_dir, "#{File.basename(xsd_file, '.xsd')}_ractor#{ractor_id}.log")
                  File.open(log_file, 'w') do |f|
                    f.puts "Processing #{xsd_file} in Ractor #{ractor_id}"

                    # Logic from generate_doc_for_xsd but with output to log file
                    target_html = xsd_file.sub(/\.xsd$/, "")
                    output_dir = "_site/#{target_html}"
                    output_file = "#{output_dir}/index.html"

                    # Skip if the output file is newer than the source file
                    if File.exist?(output_file) && File.mtime(output_file) > File.mtime(xsd_file)
                      f.puts "Skipping #{xsd_file} (up to date)"
                      next true
                    end

                    f.puts "Generating documentation for #{xsd_file}..."

                    # Create output directory
                    FileUtils.mkdir_p("#{output_dir}/diagrams")

                    # Generate diagrams
                    diagrams_cmd = "java -jar xsdvi/xsdvi.jar #{Dir.pwd}/#{xsd_file} -rootNodeName all -oneNodeOnly -outputPath #{output_dir}/diagrams"
                    f.puts "Running: #{diagrams_cmd}"
                    unless system(diagrams_cmd, out: f, err: f)
                      f.puts "Error generating diagrams for #{xsd_file}"
                      next false
                    end

                    # Generate documentation
                    temp_file = "#{output_file}.tmp"
                    xsdmerge_cmd = "xsltproc --nonet --stringparam rootxsd #{xsd_file} --output #{temp_file} xsl/xsdmerge.xsl #{xsd_file}"
                    f.puts "Running: #{xsdmerge_cmd}"
                    unless system(xsdmerge_cmd, out: f, err: f)
                      f.puts "Error generating merged XSD for #{xsd_file}"
                      next false
                    end

                    file_basename = File.basename(target_html)
                    xs3p_cmd = "xsltproc --nonet --param title \"'Schema Documentation for #{file_basename}'\" --output #{output_file} xsl/xs3p.xsl #{temp_file}"
                    f.puts "Running: #{xs3p_cmd}"
                    unless system(xs3p_cmd, out: f, err: f)
                      f.puts "Error generating documentation for #{xsd_file}"
                      next false
                    end

                    FileUtils.rm(temp_file)
                    next true
                  end
                else
                  # Call original method with system output
                  # This branch won't normally be used when parallelizing with log_dir
                  target_html = xsd_file.sub(/\.xsd$/, "")
                  output_dir = "_site/#{target_html}"
                  output_file = "#{output_dir}/index.html"

                  # Skip if the output file is newer than the source file
                  if File.exist?(output_file) && File.mtime(output_file) > File.mtime(xsd_file)
                    next true
                  end

                  # Create output directory
                  FileUtils.mkdir_p("#{output_dir}/diagrams")

                  # Generate diagrams
                  unless system("java -jar xsdvi/xsdvi.jar #{Dir.pwd}/#{xsd_file} -rootNodeName all -oneNodeOnly -outputPath #{output_dir}/diagrams")
                    next false
                  end

                  # Generate documentation
                  temp_file = "#{output_file}.tmp"
                  unless system("xsltproc --nonet --stringparam rootxsd #{xsd_file} --output #{temp_file} xsl/xsdmerge.xsl #{xsd_file}")
                    next false
                  end

                  file_basename = File.basename(target_html)
                  unless system("xsltproc --nonet --param title \"'Schema Documentation for #{file_basename}'\" --output #{output_file} xsl/xs3p.xsl #{temp_file}")
                    next false
                  end

                  FileUtils.rm(temp_file)
                  next true
                end
              rescue => e
                # Return the error as part of the result
                next [false, "Error processing #{xsd_file}: #{e.message}"]
              end
            end
          end
        end

        # Process results as they come in
        completed_files = []
        failed_files = []

        loop do
          break if ractors.empty?

          # Wait for any ractor to complete
          ready_ractor, value = Ractor.select(*ractors)
          ractor_index = ractors.index(ready_ractor)
          ractors.delete_at(ractor_index)

          # Process results
          value.each do |result|
            mutex.synchronize do
              progressbar.increment

              if result == true
                completed_files << result
              elsif result.is_a?(Array) && !result[0]
                # This is an error with a message
                failed_files << result[1]
                puts "\nError: #{result[1]}"
              else
                failed_files << result
              end
            end
          end
        end

        if !failed_files.empty?
          puts "\nFailed to process #{failed_files.size} files. See logs for details."
        end
      end

      # Generate documentation for a single XSD file
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
