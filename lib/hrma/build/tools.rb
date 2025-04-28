# frozen_string_literal: true

require "fileutils"
require "open-uri"
require_relative "../config"

module Hrma
  module Build
    # Handles downloading and setting up external tools needed for documentation generation
    class Tools
      include FileUtils

      # URLs for tools
      XERCES_URL = "https://archive.apache.org/dist/xerces/j/binaries/Xerces-J-bin.2.12.1.tar.gz"
      XSDVI_URL = "https://github.com/metanorma/xsdvi/releases/download/v1.0/xsdvi-1.0.jar"
      XS3P_URL = "https://github.com/metanorma/xs3p/archive/refs/tags/v3.0.tar.gz"

      # Tool paths
      XERCES_PATH = "xsdvi/xercesImpl.jar"
      XSDVI_PATH = "xsdvi/xsdvi.jar"
      XS3P_PATH = "xsl/xs3p.xsl"
      XSDMERGE_PATH = "xsl/xsdmerge.xsl"

      class << self
        include FileUtils

        # Setup all required tools
        def setup
          download_tool(XERCES_URL, xerces_cache)
          download_tool(XSDVI_URL, xsdvi_cache)
          download_tool(XS3P_URL, xs3p_cache)

          setup_xsdvi
          setup_xerces
          setup_xs3p
        end

        # Verify required system dependencies
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
        def cache_file(filename)
          File.join(Hrma::Config.cache_dir, filename)
        end

        # Cached file paths
        def xerces_cache
          cache_file("Xerces-J-bin.2.12.1.tar.gz")
        end

        def xsdvi_cache
          cache_file("xsdvi-1.0.jar")
        end

        def xs3p_cache
          cache_file("xs3p.tar.gz")
        end

        def download_tool(url, target_path)
          return if File.exist?(target_path)

          puts "Downloading #{url}..."
          mkdir_p(File.dirname(target_path))

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

        def setup_xsdvi
          return if File.exist?(XSDVI_PATH)

          puts "Setting up XSDVI..."
          mkdir_p(File.dirname(XSDVI_PATH))
          cp(xsdvi_cache, XSDVI_PATH)
        end

        def setup_xerces
          return if File.exist?(XERCES_PATH)

          puts "Setting up Xerces..."
          mkdir_p(File.dirname(XERCES_PATH))
          unless system("tar -zxvf #{xerces_cache} -C xsdvi --strip-components=1 xerces-2_12_1/xercesImpl.jar")
            puts "Error extracting Xerces JAR file"
            exit 1
          end
          touch(XERCES_PATH)
        end

        def setup_xs3p
          return if File.exist?(XS3P_PATH)

          puts "Setting up XS3P..."
          mkdir_p(File.dirname(XS3P_PATH))
          unless system("tar -zxvf #{xs3p_cache} -C xsl --strip-components=2 xs3p-3.0/xsl")
            puts "Error extracting XS3P files"
            exit 1
          end
          touch(XS3P_PATH)
        end

        def command_exists?(command)
          system("which #{command} > /dev/null 2>&1")
        end
      end
    end
  end
end
