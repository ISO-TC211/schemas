# frozen_string_literal: true

require 'open3'
require 'fileutils'

module Hrma
  module Build
    # A self-contained class for processing XSD documents that can run within a Ractor
    # Implements a ring pattern with supervisor and restart capabilities
    class RactorDocumentProcessor
      # Check if the file should cause an error (for testing purposes)
      #
      # @param file [String] Filename to check
      # @return [Boolean] True if this file should cause an error
      def self.error_causing_file?(file)
        file.to_s.match?(/error_file_with_e/)
      end

      # Creates a worker Ractor that processes files as they are received
      #
      # @param id [Integer] Worker ID number
      # @param name [String] Worker name for identification
      # @param tool_paths [Hash] Paths to required tools
      # @param log_dir [String, nil] Directory for log files, nil for no logging
      # @param pwd [String] Current working directory
      # @return [Ractor] The worker Ractor
      def self.create_worker(id, name, tool_paths, log_dir, pwd)
        worker = Ractor.new(id, name, tool_paths, log_dir, pwd) do |id, name, tool_paths, log_dir, pwd|
          # Print worker startup message
          puts "Worker ##{id} (#{name}) started and ready for work"
          # Define error_causing_file? method inside the Ractor
          error_check = ->(file) { file.to_s.match?(/error_file_with_e/) }

          # Process files as they arrive
          loop do
            file = Ractor.receive

            # Exit signal
            break if file == :exit

            # Log that we received work
            puts "Worker ##{id} (#{name}) received file: #{file}"

            begin
              # Check for error-causing files using the local function
              if error_check.call(file)
                raise "Worker #{id} (#{name}): Error-causing file detected: #{file}"
              end

              # Process the file
              result = Hrma::Build::RactorDocumentProcessor.process_single_file(
                file, log_dir, pwd, tool_paths
              )

              # Log completion
              puts "Worker ##{id} (#{name}) completed processing: #{file}"

              # Send the result back to the supervisor with worker info
              # Format: [worker_id, worker_name, file_path, result]
              Ractor.yield([id, name, file, result])
            rescue => e
              if e.message.include?('e')
                # Fatal errors should be caught by the supervisor
                puts "Worker #{id} (#{name}): Fatal error detected: #{e.message}"
                raise e
              else
                # Non-fatal errors are wrapped and returned with worker info
                error_message = "Worker #{id} (#{name}) Exception: #{e.message}".to_s
                # Format: [worker_id, worker_name, file_path, result]
                Ractor.yield([id, name, file, [file, false, error_message]])
              end
            end
          end
        end

        # Return the created worker
        worker
      end

      # Process a single file with appropriate logging
      #
      # @param file [String] Path to the XSD file
      # @param log_dir [String, nil] Directory for log files, nil for no logging
      # @param pwd [String] Current working directory
      # @param tool_paths [Hash] Paths to required tools
      # @return [Array] Result of processing [file_path, success_flag, error_message]
      def self.process_single_file(file, log_dir, pwd, tool_paths)
        # Ensure all inputs are simple strings to avoid unshareable objects
        file_str = file.to_s
        log_dir_str = log_dir ? log_dir.to_s : nil
        pwd_str = pwd.to_s

        # Process with appropriate method
        begin
          if log_dir_str
            process_with_logging(file_str, log_dir_str, pwd_str, tool_paths)
          else
            process_without_logging(file_str, pwd_str, tool_paths)
          end
        rescue => e
          # Create a shareable result for the error case
          error_message = "Exception: #{e.message}".to_s
          shareable_result = [file_str, false, error_message]
          Ractor.make_shareable(shareable_result)
        end
      end

      # Process a batch of XSD files
      #
      # @param files [Array<String>] List of XSD files to process
      # @param log_dir [String, nil] Directory for log files, nil for no logging
      # @param pwd [String] Current working directory
      # @param tool_paths [Hash] Paths to required tools
      # @return [Array<Array>] Results of processing each file [file_path, success_flag, error_message]
      def self.process_batch(files, log_dir, pwd, tool_paths)
        results = []
        files.each do |file|
          results << process_single_file(file, log_dir, pwd, tool_paths)
        end
        results
      end

      # Process a file with logging
      #
      # @param file [String] Path to the XSD file
      # @param log_dir [String] Directory for log files
      # @param pwd [String] Current working directory
      # @param tool_paths [Hash] Paths to required tools
      # @return [Array] Result of processing [file_path, success_flag, error_message]
  def self.process_with_logging(file, log_dir, pwd, tool_paths)
    # Ensure all inputs are simple strings to avoid unshareable objects
    file_str = file.to_s
    log_dir_str = log_dir.to_s
    pwd_str = pwd.to_s

    # Create log file path as a simple string
    log_file = File.join(log_dir_str, "#{File.basename(file_str, '.xsd')}.log")

    # Create log directory using our safe method (not FileUtils)
    safe_mkdir_p(File.dirname(log_file))

    # Process the file, writing to the log
    # We need to avoid using File.open with a block as it might contain unshareable Procs
    begin
      # Open log file manually without a block
      log_handle = File.open(log_file, 'w')
      log_handle.puts "Processing #{file_str}..."

      # Process the file
      result = process_file(file_str, pwd_str, tool_paths, log_handle)

      # Create a shareable result array
      success = result == true
      error_message = result.is_a?(String) ? result.to_s : nil
      shareable_result = [file_str, success, error_message]

      # Close the log file
      log_handle.close

      # Return explicitly shareable result
      Ractor.make_shareable(shareable_result)
    rescue => e
      # Ensure log file is closed if there's an error
      log_handle.close if log_handle && !log_handle.closed?
      Ractor.make_shareable([file_str, false, "Error writing to log: #{e.message}"])
    end
  end

      # Process a file without logging
      #
      # @param file [String] Path to the XSD file
      # @param pwd [String] Current working directory
      # @param tool_paths [Hash] Paths to required tools
      # @return [Array] Result of processing [file_path, success_flag, error_message]
      def self.process_without_logging(file, pwd, tool_paths)
        # Ensure all inputs are simple strings
        file_str = file.to_s
        pwd_str = pwd.to_s

        # Process the file
        result = process_file_without_logging(file_str, pwd_str, tool_paths)

        # Create a shareable result array
        success = result == true
        error_message = result.is_a?(String) ? result.to_s : nil
        shareable_result = [file_str, success, error_message]

        # Return explicitly shareable result
        Ractor.make_shareable(shareable_result)
      end

      # Process a single file with logging
      #
      # @param file [String] Path to the XSD file
      # @param pwd [String] Current working directory
      # @param tool_paths [Hash] Paths to required tools
      # @param log [IO] Log file IO object
      # @return [true, String] True if successful, error message string if failed
      def self.process_file(file, pwd, tool_paths, log)
        # Ensure all inputs are simple strings
        file_str = file.to_s
        pwd_str = pwd.to_s

        # Get paths for processing - these are already made shareable
        paths = get_file_paths(file_str)

        # Skip if up to date
        if skip_if_up_to_date?(paths[:output_file], file_str)
          log.puts "Skipping #{file_str} (up to date)"
          return true
        end

        log.puts "Generating documentation for #{file_str}..."

        # Create output directory using ractor-safe approach
        safe_mkdir_p(paths[:output_dir])
        safe_mkdir_p(File.join(paths[:output_dir], "diagrams"))

        # Generate diagrams
        unless generate_diagrams(file_str, pwd_str, paths[:output_dir], tool_paths[:xsdvi_path], log)
          return "Error generating diagrams"
        end

        # Generate documentation
        unless generate_merged_xsd(file_str, paths[:temp_file], tool_paths[:xsdmerge_path], log)
          return "Error generating merged XSD"
        end

        # Generate final documentation
        file_basename = File.basename(paths[:target_html])
        unless generate_final_doc(paths[:temp_file], paths[:output_file], file_basename, tool_paths[:xs3p_path], log)
          return "Error generating documentation"
        end

        # Clean up and return success
        safe_rm(paths[:temp_file])
        true
      end

      # Process a single file without logging
      #
      # @param file [String] Path to the XSD file
      # @param pwd [String] Current working directory
      # @param tool_paths [Hash] Paths to required tools
      # @return [true, String] True if successful, error message string if failed
      def self.process_file_without_logging(file, pwd, tool_paths)
        # Ensure all inputs are simple strings
        file_str = file.to_s
        pwd_str = pwd.to_s

        # Get paths for processing - these are already made shareable
        paths = get_file_paths(file_str)

        # Skip if up to date
        return true if skip_if_up_to_date?(paths[:output_file], file_str)

        # Create output directory using ractor-safe approach
        safe_mkdir_p(paths[:output_dir])
        safe_mkdir_p(File.join(paths[:output_dir], "diagrams"))

        # Generate diagrams
        unless generate_diagrams(file_str, pwd_str, paths[:output_dir], tool_paths[:xsdvi_path])
          return "Error generating diagrams"
        end

        # Generate merged XSD
        unless generate_merged_xsd(file_str, paths[:temp_file], tool_paths[:xsdmerge_path])
          return "Error generating merged XSD"
        end

        # Generate final documentation
        file_basename = File.basename(paths[:target_html])
        unless generate_final_doc(paths[:temp_file], paths[:output_file], file_basename, tool_paths[:xs3p_path])
          return "Error generating documentation"
        end

        # Clean up and return success
        safe_rm(paths[:temp_file])
        true
      end

      private

      # Get file paths needed for processing
      #
      # @param file [String] Path to the XSD file
      # @return [Hash] Hash containing all necessary paths
      def self.get_file_paths(file)
        # Ensure file is a simple string
        file_str = file.to_s

        # Generate paths as simple strings
        target_html = file_str.sub(/\.xsd$/, "")
        output_dir = "_site/#{target_html}"
        output_file = "#{output_dir}/index.html"
        temp_file = "#{output_file}.tmp"

        # Create a hash with string keys and string values
        paths = {
          target_html: target_html,
          output_dir: output_dir,
          output_file: output_file,
          temp_file: temp_file
        }

        # Make the hash explicitly shareable for Ractors
        Ractor.make_shareable(paths)
      end

      # Check if output file is up to date
      #
      # @param output_file [String] Path to the output file
      # @param source_file [String] Path to the source file
      # @return [Boolean] True if output file is up to date
      def self.skip_if_up_to_date?(output_file, source_file)
        # Ensure paths are simple strings
        output_file_str = output_file.to_s
        source_file_str = source_file.to_s

        # Check if file exists and is up to date
        begin
          File.exist?(output_file_str) && File.mtime(output_file_str) > File.mtime(source_file_str)
        rescue => e
          # Handle any errors in file operations (return false to force processing)
          puts "Error checking file timestamps: #{e.message}"
          false
        end
      end

      # Safe mkdir_p implementation that doesn't rely on FileUtils
      # This avoids the un-shareable Proc issue in Ractors
      #
      # @param dir [String] Directory path to create
      # @return [void]
      def self.safe_mkdir_p(dir)
        # Ensure dir is a simple string
        dir_str = dir.to_s
        return if Dir.exist?(dir_str)

        # Create parent directories first
        parent = File.dirname(dir_str)
        unless Dir.exist?(parent)
          safe_mkdir_p(parent)
        end

        # Create the directory
        begin
          Dir.mkdir(dir_str)
        rescue Errno::EEXIST
          # Directory already exists (possible race condition)
        rescue => e
          # Log other errors but don't fail
          puts "Error creating directory #{dir_str}: #{e.message}"
        end
      end

      # Safe file removal that doesn't rely on FileUtils
      #
      # @param file [String] File to remove
      # @return [void]
      def self.safe_rm(file)
        # Ensure file is a simple string
        file_str = file.to_s
        File.unlink(file_str) if File.exist?(file_str)
      rescue Errno::ENOENT
        # File doesn't exist, which is what we wanted anyway
      rescue => e
        # Log other errors but don't fail
        puts "Error removing file #{file_str}: #{e.message}"
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
        # Ensure all parameters are simple strings
        file_str = file.to_s
        pwd_str = pwd.to_s
        output_dir_str = output_dir.to_s
        xsdvi_path_str = xsdvi_path.to_s

        # Build command as string
        diagrams_cmd = "java -jar #{xsdvi_path_str} #{pwd_str}/#{file_str} -rootNodeName all -oneNodeOnly -outputPath #{output_dir_str}/diagrams"

        begin
          if log
            log.puts "Running: #{diagrams_cmd}"
            stdout_and_stderr_str, status = Open3.capture2e(diagrams_cmd)
            log.puts stdout_and_stderr_str
            result = status.success?
            log.puts "Error generating diagrams for #{file_str}" unless result
            result
          else
            stdout_and_stderr_str, status = Open3.capture2e(diagrams_cmd)
            status.success?
          end
        rescue => e
          # Handle any errors that might occur when executing the command
          message = "Error executing diagrams command: #{e.message}"
          log.puts message if log
          puts message
          false
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
        # Ensure all parameters are simple strings
        file_str = file.to_s
        temp_file_str = temp_file.to_s
        xsdmerge_path_str = xsdmerge_path.to_s

        # Build command as string
        xsdmerge_cmd = "xsltproc --nonet --stringparam rootxsd #{file_str} --output #{temp_file_str} #{xsdmerge_path_str} #{file_str}"

        begin
          if log
            log.puts "Running: #{xsdmerge_cmd}"
            stdout_and_stderr_str, status = Open3.capture2e(xsdmerge_cmd)
            log.puts stdout_and_stderr_str
            result = status.success?
            log.puts "Error generating merged XSD for #{file_str}" unless result
            result
          else
            stdout_and_stderr_str, status = Open3.capture2e(xsdmerge_cmd)
            status.success?
          end
        rescue => e
          # Handle any errors that might occur when executing the command
          message = "Error executing XSD merge command: #{e.message}"
          log.puts message if log
          puts message
          false
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
        # Ensure all parameters are simple strings
        temp_file_str = temp_file.to_s
        output_file_str = output_file.to_s
        file_basename_str = file_basename.to_s
        xs3p_path_str = xs3p_path.to_s

        # Build command as string
        xs3p_cmd = "xsltproc --nonet --param title \"'Schema Documentation for #{file_basename_str}'\" --output #{output_file_str} #{xs3p_path_str} #{temp_file_str}"

        begin
          if log
            log.puts "Running: #{xs3p_cmd}"
            stdout_and_stderr_str, status = Open3.capture2e(xs3p_cmd)
            log.puts stdout_and_stderr_str
            result = status.success?
            log.puts "Error generating documentation" unless result
            result
          else
            stdout_and_stderr_str, status = Open3.capture2e(xs3p_cmd)
            status.success?
          end
        rescue => e
          # Handle any errors that might occur when executing the command
          message = "Error executing XS3P command: #{e.message}"
          log.puts message if log
          puts message
          false
        end
      end
    end
  end
end
