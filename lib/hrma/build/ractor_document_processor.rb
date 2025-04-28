# frozen_string_literal: true

module Hrma
  module Build
    # A self-contained class for processing XSD documents that can run within a Ractor
    class RactorDocumentProcessor
      # Process a batch of XSD files
      #
      # @param files [Array<String>] List of XSD files to process
      # @param log_dir [String, nil] Directory for log files, nil for no logging
      # @param pwd [String] Current working directory
      # @param tool_paths [Hash] Paths to required tools
      # @return [Array<Array>] Results of processing each file [file_path, success_flag, error_message]
      def self.process(files, log_dir, pwd, tool_paths)
        results = []
        files.each do |file|
          results << process_single_file(file, log_dir, pwd, tool_paths)
        end
        results
      end

      # Process a single file with appropriate logging
      #
      # @param file [String] Path to the XSD file
      # @param log_dir [String, nil] Directory for log files, nil for no logging
      # @param pwd [String] Current working directory
      # @param tool_paths [Hash] Paths to required tools
      # @return [Array] Result of processing [file_path, success_flag, error_message]
      def self.process_single_file(file, log_dir, pwd, tool_paths)
        if log_dir
          process_with_logging(file, log_dir, pwd, tool_paths)
        else
          process_without_logging(file, pwd, tool_paths)
        end
      rescue => e
        [file, false, "Exception: #{e.message}"]
      end

      # Process a file with logging
      #
      # @param file [String] Path to the XSD file
      # @param log_dir [String] Directory for log files
      # @param pwd [String] Current working directory
      # @param tool_paths [Hash] Paths to required tools
      # @return [Array] Result of processing [file_path, success_flag, error_message]
      def self.process_with_logging(file, log_dir, pwd, tool_paths)
        log_file = File.join(log_dir, "#{File.basename(file, '.xsd')}.log")
        FileUtils.mkdir_p(File.dirname(log_file))

        File.open(log_file, 'w') do |log|
          log.puts "Processing #{file}..."
          result = process_file(file, pwd, tool_paths, log)
          [file, result ? true : false, result.is_a?(String) ? result : nil]
        end
      end

      # Process a file without logging
      #
      # @param file [String] Path to the XSD file
      # @param pwd [String] Current working directory
      # @param tool_paths [Hash] Paths to required tools
      # @return [Array] Result of processing [file_path, success_flag, error_message]
      def self.process_without_logging(file, pwd, tool_paths)
        result = process_file_without_logging(file, pwd, tool_paths)
        [file, result ? true : false, result.is_a?(String) ? result : nil]
      end

      # Process a single file with logging
      #
      # @param file [String] Path to the XSD file
      # @param pwd [String] Current working directory
      # @param tool_paths [Hash] Paths to required tools
      # @param log [IO] Log file IO object
      # @return [true, String] True if successful, error message string if failed
      def self.process_file(file, pwd, tool_paths, log)
        # Get paths for processing
        paths = get_file_paths(file)

        # Skip if up to date
        if skip_if_up_to_date?(paths[:output_file], file)
          log.puts "Skipping #{file} (up to date)"
          return true
        end

        log.puts "Generating documentation for #{file}..."

        # Create output directory
        create_output_directory(paths[:output_dir])

        # Generate diagrams
        return "Error generating diagrams" unless generate_diagrams(file, pwd, paths[:output_dir], tool_paths[:xsdvi_path], log)

        # Generate documentation
        return "Error generating merged XSD" unless generate_merged_xsd(file, paths[:temp_file], tool_paths[:xsdmerge_path], log)

        # Generate final documentation
        file_basename = File.basename(paths[:target_html])
        return "Error generating documentation" unless generate_final_doc(paths[:temp_file], paths[:output_file], file_basename, tool_paths[:xs3p_path], log)

        # Clean up and return success
        FileUtils.rm_f(paths[:temp_file])
        true
      end

      # Process a single file without logging
      #
      # @param file [String] Path to the XSD file
      # @param pwd [String] Current working directory
      # @param tool_paths [Hash] Paths to required tools
      # @return [true, String] True if successful, error message string if failed
      def self.process_file_without_logging(file, pwd, tool_paths)
        # Get paths for processing
        paths = get_file_paths(file)

        # Skip if up to date
        return true if skip_if_up_to_date?(paths[:output_file], file)

        # Create output directory
        create_output_directory(paths[:output_dir])

        # Generate diagrams
        diagrams_cmd = "java -jar #{tool_paths[:xsdvi_path]} #{pwd}/#{file} -rootNodeName all -oneNodeOnly -outputPath #{paths[:output_dir]}/diagrams"
        return "Error generating diagrams" unless system(diagrams_cmd)

        # Generate documentation
        xsdmerge_cmd = "xsltproc --nonet --stringparam rootxsd #{file} --output #{paths[:temp_file]} #{tool_paths[:xsdmerge_path]} #{file}"
        return "Error generating merged XSD" unless system(xsdmerge_cmd)

        # Generate final documentation
        file_basename = File.basename(paths[:target_html])
        xs3p_cmd = "xsltproc --nonet --param title \"'Schema Documentation for #{file_basename}'\" --output #{paths[:output_file]} #{tool_paths[:xs3p_path]} #{paths[:temp_file]}"
        return "Error generating documentation" unless system(xs3p_cmd)

        # Clean up and return success
        FileUtils.rm_f(paths[:temp_file])
        true
      end

      private

      # Get file paths needed for processing
      #
      # @param file [String] Path to the XSD file
      # @return [Hash] Hash containing all necessary paths
      def self.get_file_paths(file)
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
      def self.skip_if_up_to_date?(output_file, source_file)
        File.exist?(output_file) && File.mtime(output_file) > File.mtime(source_file)
      end

      # Create output directory
      #
      # @param output_dir [String] Path to the output directory
      # @return [void]
      def self.create_output_directory(output_dir)
        FileUtils.mkdir_p("#{output_dir}/diagrams")
      end

      # Generate diagrams
      #
      # @param file [String] Path to the XSD file
      # @param pwd [String] Current working directory
      # @param output_dir [String] Path to the output directory
      # @param xsdvi_path [String] Path to the XSDVI tool
      # @param log [IO, nil] Log file IO object, nil for no logging
      # @return [Boolean] True if successful
      def self.generate_diagrams(file, pwd, output_dir, xsdvi_path, log = nil)
        diagrams_cmd = "java -jar #{xsdvi_path} #{pwd}/#{file} -rootNodeName all -oneNodeOnly -outputPath #{output_dir}/diagrams"

        if log
          log.puts "Running: #{diagrams_cmd}"
          result = system(diagrams_cmd, out: log, err: log)
          log.puts "Error generating diagrams for #{file}" unless result
          result
        else
          system(diagrams_cmd)
        end
      end

      # Generate merged XSD
      #
      # @param file [String] Path to the XSD file
      # @param temp_file [String] Path to the temporary file
      # @param xsdmerge_path [String] Path to the XSD merge tool
      # @param log [IO, nil] Log file IO object, nil for no logging
      # @return [Boolean] True if successful
      def self.generate_merged_xsd(file, temp_file, xsdmerge_path, log = nil)
        xsdmerge_cmd = "xsltproc --nonet --stringparam rootxsd #{file} --output #{temp_file} #{xsdmerge_path} #{file}"

        if log
          log.puts "Running: #{xsdmerge_cmd}"
          result = system(xsdmerge_cmd, out: log, err: log)
          log.puts "Error generating merged XSD for #{file}" unless result
          result
        else
          system(xsdmerge_cmd)
        end
      end

      # Generate final documentation
      #
      # @param temp_file [String] Path to the temporary file
      # @param output_file [String] Path to the output file
      # @param file_basename [String] Base name of the file
      # @param xs3p_path [String] Path to the XS3P tool
      # @param log [IO, nil] Log file IO object, nil for no logging
      # @return [Boolean] True if successful
      def self.generate_final_doc(temp_file, output_file, file_basename, xs3p_path, log = nil)
        xs3p_cmd = "xsltproc --nonet --param title \"'Schema Documentation for #{file_basename}'\" --output #{output_file} #{xs3p_path} #{temp_file}"

        if log
          log.puts "Running: #{xs3p_cmd}"
          result = system(xs3p_cmd, out: log, err: log)
          log.puts "Error generating documentation" unless result
          result
        else
          system(xs3p_cmd)
        end
      end
    end
  end
end
