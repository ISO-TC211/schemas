# frozen_string_literal: true

module Hrma
  module Build
    # A self-contained class for processing XSD documents that can run within a Ractor
    class RactorDocumentProcessor
      # Process a batch of XSD files
      # This class is designed to run entirely within a Ractor
      def self.process(files, log_dir, pwd, tool_paths)
        results = []
        files.each do |file|
          begin
            # Process this file
            if log_dir
              log_file = File.join(log_dir, "#{File.basename(file, '.xsd')}.log")
              FileUtils.mkdir_p(File.dirname(log_file))

              # Process with logging
              File.open(log_file, 'w') do |log|
                log.puts "Processing #{file}..."

                result = process_file(file, pwd, tool_paths, log)
                results << [file, result ? true : false, result.is_a?(String) ? result : nil]
              end
            else
              # Process without logging
              result = process_file_without_logging(file, pwd, tool_paths)
              results << [file, result ? true : false, result.is_a?(String) ? result : nil]
            end
          rescue => e
            # Return error information
            results << [file, false, "Exception: #{e.message}"]
          end
        end

        # Return all results
        results
      end

      # Process a single file with logging
      def self.process_file(file, pwd, tool_paths, log)
        target_html = file.sub(/\.xsd$/, "")
        output_dir = "_site/#{target_html}"
        output_file = "#{output_dir}/index.html"

        # Skip if the output file is newer than the source file
        if File.exist?(output_file) && File.mtime(output_file) > File.mtime(file)
          log.puts "Skipping #{file} (up to date)"
          return true
        end

        log.puts "Generating documentation for #{file}..."

        # Create output directory
        FileUtils.mkdir_p("#{output_dir}/diagrams")

        # Generate diagrams
        diagrams_cmd = "java -jar #{tool_paths[:xsdvi_path]} #{pwd}/#{file} -rootNodeName all -oneNodeOnly -outputPath #{output_dir}/diagrams"
        log.puts "Running: #{diagrams_cmd}"
        unless system(diagrams_cmd, out: log, err: log)
          log.puts "Error generating diagrams for #{file}"
          return "Error generating diagrams"
        end

        # Generate documentation
        temp_file = "#{output_file}.tmp"
        xsdmerge_cmd = "xsltproc --nonet --stringparam rootxsd #{file} --output #{temp_file} #{tool_paths[:xsdmerge_path]} #{file}"
        log.puts "Running: #{xsdmerge_cmd}"
        unless system(xsdmerge_cmd, out: log, err: log)
          log.puts "Error generating merged XSD for #{file}"
          return "Error generating merged XSD"
        end

        file_basename = File.basename(target_html)
        xs3p_cmd = "xsltproc --nonet --param title \"'Schema Documentation for #{file_basename}'\" --output #{output_file} #{tool_paths[:xs3p_path]} #{temp_file}"
        log.puts "Running: #{xs3p_cmd}"
        unless system(xs3p_cmd, out: log, err: log)
          log.puts "Error generating documentation for #{file}"
          return "Error generating documentation"
        end

        FileUtils.rm_f(temp_file)
        true
      end

      # Process a single file without logging
      def self.process_file_without_logging(file, pwd, tool_paths)
        target_html = file.sub(/\.xsd$/, "")
        output_dir = "_site/#{target_html}"
        output_file = "#{output_dir}/index.html"

        # Skip if the output file is newer than the source file
        if File.exist?(output_file) && File.mtime(output_file) > File.mtime(file)
          return true
        end

        # Create output directory
        FileUtils.mkdir_p("#{output_dir}/diagrams")

        # Generate diagrams
        unless system("java -jar #{tool_paths[:xsdvi_path]} #{pwd}/#{file} -rootNodeName all -oneNodeOnly -outputPath #{output_dir}/diagrams")
          return "Error generating diagrams"
        end

        # Generate documentation
        temp_file = "#{output_file}.tmp"
        unless system("xsltproc --nonet --stringparam rootxsd #{file} --output #{temp_file} #{tool_paths[:xsdmerge_path]} #{file}")
          return "Error generating merged XSD"
        end

        file_basename = File.basename(target_html)
        unless system("xsltproc --nonet --param title \"'Schema Documentation for #{file_basename}'\" --output #{output_file} #{tool_paths[:xs3p_path]} #{temp_file}")
          return "Error generating documentation"
        end

        FileUtils.rm_f(temp_file)
        true
      end
    end
  end
end
