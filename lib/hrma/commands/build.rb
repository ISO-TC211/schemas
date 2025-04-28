# frozen_string_literal: true

require "thor"
require "yaml"
require "pathname"
require "fileutils"
require "open-uri"
require "rake"
require_relative "../config"

module Hrma
  module Commands
    class Build < Thor
      include FileUtils

      class_option :cache_dir, type: :string, desc: "Directory for caching downloaded tools"

      # URLs for tools
      XERCES_URL = "https://archive.apache.org/dist/xerces/j/binaries/Xerces-J-bin.2.12.1.tar.gz"
      XSDVI_URL = "https://github.com/metanorma/xsdvi/releases/download/v1.0/xsdvi-1.0.jar"
      XS3P_URL = "https://github.com/metanorma/xs3p/archive/refs/tags/v3.0.tar.gz"

      # Tool paths
      XERCES_PATH = "xsdvi/xercesImpl.jar"
      XSDVI_PATH = "xsdvi/xsdvi.jar"
      XS3P_PATH = "xsl/xs3p.xsl"
      XSDMERGE_PATH = "xsl/xsdmerge.xsl"

      # Initialize with options
      def initialize(*args)
        super
        Hrma::Config.cache_dir = options[:cache_dir] if options[:cache_dir]

        # Ensure cache directory exists
        FileUtils.mkdir_p(Hrma::Config.cache_dir) unless File.directory?(Hrma::Config.cache_dir)
      end

      no_commands do
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
      end

      desc "documentation", "Generate documentation for schemas"
      def documentation
        verify_dependencies
        setup_tools
        generate_documentation
        puts "Documentation generation complete. See _site/ directory."
      end

      desc "clean", "Remove generated documentation"
      def clean
        rm_rf("_site")
        rm_rf("xsl")
        rm_rf("xsdvi")
        puts "Cleaned generated documentation."
      end

      desc "distclean", "Remove generated documentation and downloaded tools"
      method_option :global_cache, type: :boolean, default: false, desc: "Also clean the global cache directory"
      def distclean
        clean

        if options[:global_cache]
          puts "Cleaning global cache directory: #{Hrma::Config.cache_dir}"
          rm_rf(Hrma::Config.cache_dir)
          mkdir_p(Hrma::Config.cache_dir)
        else
          puts "Cleaning local .archive directory"
          rm_rf(".archive")
        end

        puts "Cleaned generated documentation and downloaded tools."
      end

      private

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

      def command_exists?(command)
        system("which #{command} > /dev/null 2>&1")
      end

      def setup_tools
        download_tool(XERCES_URL, xerces_cache)
        download_tool(XSDVI_URL, xsdvi_cache)
        download_tool(XS3P_URL, xs3p_cache)

        setup_xsdvi
        setup_xerces
        setup_xs3p
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

      def generate_documentation
        # Load schemas.yml to get XSD files
        yaml_path = File.join(Dir.pwd, "schemas.yml")
        manifest = YAML.load_file(yaml_path)

        xsd_files = []
        if manifest.dig("source", "schemas", "xsd")
          xsd_files = manifest["source"]["schemas"]["xsd"]
        elsif manifest.dig("source", "schemas") && manifest["source"]["schemas"].is_a?(Array)
          xsd_files = manifest["source"]["schemas"]
        end

        return if xsd_files.empty?

        # Process each XSD file
        xsd_files.each do |xsd_file|
          generate_doc_for_xsd(xsd_file)
        end
      end

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
        unless system("java -jar #{XSDVI_PATH} #{Dir.pwd}/#{xsd_file} -rootNodeName all -oneNodeOnly -outputPath #{output_dir}/diagrams")
          puts "Error generating diagrams for #{xsd_file}"
          return
        end

        # Generate documentation
        temp_file = "#{output_file}.tmp"
        unless system("xsltproc --nonet --stringparam rootxsd #{xsd_file} --output #{temp_file} #{XSDMERGE_PATH} #{xsd_file}")
          puts "Error generating merged XSD for #{xsd_file}"
          return
        end

        file_basename = File.basename(target_html)
        unless system("xsltproc --nonet --param title \"'Schema Documentation for #{file_basename}'\" --output #{output_file} #{XS3P_PATH} #{temp_file}")
          puts "Error generating documentation for #{xsd_file}"
          return
        end

        rm(temp_file)
      end
    end
  end
end
