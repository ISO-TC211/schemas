# frozen_string_literal: true

require "fileutils"
require "open-uri"
require "open3"
require_relative "../config"

module Hrma
  module Build
    # Handles downloading, setting up, and executing external tools needed for documentation generation
    class Tools
      # URLs for tools
      XERCES_URL = "https://archive.apache.org/dist/xerces/j/binaries/Xerces-J-bin.2.12.1.tar.gz"
      XSDVI_URL = "https://github.com/metanorma/xsdvi/releases/download/v1.0/xsdvi-1.0.jar"
      XS3P_URL = "https://github.com/metanorma/xs3p/archive/refs/tags/v3.0.tar.gz"

      # Tool paths
      XERCES_PATH = "xsdvi/xercesImpl.jar"
      XSDVI_PATH = "xsdvi/xsdvi.jar"
      XS3P_PATH = "xsl/xs3p.xsl"
      XSDMERGE_PATH = "xsl/xsdmerge.xsl"

      # Initialize with the current working directory
      #
      # @param pwd [String] Current working directory
      def initialize(pwd: Dir.pwd)
        @pwd = pwd
      end

      # Generate diagrams for a schema file
      #
      # @param schema_path [String] Path to the schema file
      # @param output_dir [String] Path to the output directory
      # @param logger [Logger] Logger for output
      # @return [Boolean] True if successful
      def generate_diagrams(schema_path:, output_dir:, logger: nil)
        # Build command as string
        diagrams_cmd = "java -jar #{XSDVI_PATH} #{@pwd}/#{schema_path} -rootNodeName all -oneNodeOnly -outputPath #{output_dir}/diagrams"

        execute_command(cmd: diagrams_cmd, error_message: "Error generating diagrams for #{schema_path}", logger: logger)
      end

      # Generate merged XSD
      #
      # @param schema_path [String] Path to the schema file
      # @param output_path [String] Path to the output file
      # @param logger [Logger] Logger for output
      # @return [Boolean] True if successful
      def generate_merged_xsd(schema_path:, output_path:, logger: nil)
        # Build command as string
        xsdmerge_cmd = "xsltproc --nonet --stringparam rootxsd #{schema_path} --output #{output_path} #{XSDMERGE_PATH} #{schema_path}"

        execute_command(cmd: xsdmerge_cmd, error_message: "Error generating merged XSD for #{schema_path}", logger: logger)
      end

      # Generate documentation using xs3p
      #
      # @param input_path [String] Path to the input file (merged XSD)
      # @param output_path [String] Path to the output file
      # @param title [String] Title for the documentation
      # @param logger [Logger] Logger for output
      # @return [Boolean] True if successful
      def xs3p(input_path:, output_path:, title:, logger: nil)
        # Build command as string
        xs3p_cmd = "xsltproc --nonet --param title \"'Schema Documentation for #{title}'\" --output #{output_path} #{XS3P_PATH} #{input_path}"

        execute_command(cmd: xs3p_cmd, error_message: "Error generating documentation", logger: logger)
      end

      class << self
        # Setup all required tools by downloading and extracting them
        #
        # @return [void]
        def setup
          download_tool(XERCES_URL, xerces_cache)
          download_tool(XSDVI_URL, xsdvi_cache)
          download_tool(XS3P_URL, xs3p_cache)

          setup_xsdvi
          setup_xerces
          setup_xs3p
        end

        # Verify required system dependencies (xsltproc and Java)
        #
        # @return [void]
        # @raise [SystemExit] If required dependencies are not installed
        def verify_dependencies
          # Check for xsltproc
          unless command_exists?("xsltproc")
            puts "Error: xsltproc is not installed or not in your PATH."
            puts "Please install xsltproc and ensure it's available in your PATH."
            puts "  - On macOS: brew install libxslt"
            puts "  - On Ubuntu/Debian: sudo apt-get install xsltproc"
            puts "  - On RHEL/CentOS/Fedora: sudo yum install libxslt"
            exit 1
          end

          # Optional version check for xsltproc
          xsltproc_version = `xsltproc --version`
          if xsltproc_version.empty?
            puts "Warning: Could not determine xsltproc version."
          else
            puts "Found xsltproc: #{xsltproc_version.split("\n").first}"
          end

          # Check for Java
          unless command_exists?("java")
            puts "Error: Java is not installed or not in your PATH."
            puts "Please install Java and ensure it's available in your PATH."
            puts "  - On macOS: brew install java"
            puts "  - On Ubuntu/Debian: sudo apt-get install default-jre"
            puts "  - On RHEL/CentOS/Fedora: sudo yum install java-latest-openjdk"
            exit 1
          end

          # Optional version check for Java
          java_version = `java -version 2>&1`
          if java_version.empty?
            puts "Warning: Could not determine Java version."
          else
            puts "Found Java: #{java_version.split("\n").first}"
          end
        end

        private

        # Helper method to get cache file path
        #
        # @param filename [String] Name of the file to cache
        # @return [String] Full path to the cached file
        def cache_file(filename)
          File.join(Hrma::Config.cache_dir, filename)
        end

        # Get the path to the cached Xerces JAR file
        #
        # @return [String] Path to the cached Xerces JAR file
        def xerces_cache
          cache_file("Xerces-J-bin.2.12.1.tar.gz")
        end

        # Get the path to the cached XSDVI JAR file
        #
        # @return [String] Path to the cached XSDVI JAR file
        def xsdvi_cache
          cache_file("xsdvi-1.0.jar")
        end

        # Get the path to the cached XS3P archive
        #
        # @return [String] Path to the cached XS3P archive
        def xs3p_cache
          cache_file("xs3p.tar.gz")
        end

        # Download a tool from a URL to a target path
        #
        # @param url [String] URL to download from
        # @param target_path [String] Path to save the downloaded file
        # @return [void]
        # @raise [SystemExit] If download fails
        def download_tool(url, target_path)
          return if File.exist?(target_path)

          puts "Downloading #{url}..."
          FileUtils.mkdir_p(File.dirname(target_path))

          begin
            URI.open(url) do |remote_file|
              File.open(target_path, "wb") do |local_file|
                local_file.write(remote_file.read)
              end
            end
          rescue OpenURI::HTTPError => e
            puts "Error downloading #{url}: #{e.message}"
            puts "Please check if the URL is correct or try downloading manually."
            exit 1
          rescue => e
            puts "Error downloading #{url}: #{e.message}"
            exit 1
          end
        end

        # Setup XSDVI tool
        #
        # @return [void]
        def setup_xsdvi
          return if File.exist?(XSDVI_PATH)

          puts "Setting up XSDVI..."
          FileUtils.mkdir_p(File.dirname(XSDVI_PATH))
          FileUtils.cp(xsdvi_cache, XSDVI_PATH)
        end

        # Setup Xerces tool
        #
        # @return [void]
        # @raise [SystemExit] If extraction fails
        def setup_xerces
          return if File.exist?(XERCES_PATH)

          puts "Setting up Xerces..."
          FileUtils.mkdir_p(File.dirname(XERCES_PATH))
          unless system("tar -zxvf #{xerces_cache} -C xsdvi --strip-components=1 xerces-2_12_1/xercesImpl.jar")
            puts "Error extracting Xerces JAR file"
            exit 1
          end
          FileUtils.touch(XERCES_PATH)
        end

        # Setup XS3P tool
        #
        # @return [void]
        # @raise [SystemExit] If extraction fails
        def setup_xs3p
          return if File.exist?(XS3P_PATH)

          puts "Setting up XS3P..."
          FileUtils.mkdir_p(File.dirname(XS3P_PATH))
          unless system("tar -zxvf #{xs3p_cache} -C xsl --strip-components=2 xs3p-3.0/xsl")
            puts "Error extracting XS3P files"
            exit 1
          end
          FileUtils.touch(XS3P_PATH)
        end

        # Check if a command exists in the system
        #
        # @param command [String] Command to check
        # @return [Boolean] True if the command exists
        def command_exists?(command)
          system("which #{command} > /dev/null 2>&1")
        end
      end

      private

      # Execute a command and handle the result
      #
      # @param cmd [String] Command to execute
      # @param error_message [String] Error message to log if the command fails
      # @param logger [Logger] Logger for output
      # @return [Boolean] True if successful
      def execute_command(cmd:, error_message:, logger:)
        begin
          if logger
            logger.info("Running: #{cmd}")
            stdout_and_stderr_str, status = Open3.capture2e(cmd)
            logger.info(stdout_and_stderr_str)
            result = status.success?
            logger.error(error_message) unless result
            result
          else
            stdout_and_stderr_str, status = Open3.capture2e(cmd)
            status.success?
          end
        rescue => e
          # Handle any errors that might occur when executing the command
          message = "Error executing command: #{e.message}"
          logger.error(message) if logger
          puts message
          false
        end
      end
    end
  end
end
