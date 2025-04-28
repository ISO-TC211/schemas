# frozen_string_literal: true

require "thor"
require "fileutils"
require_relative "../config"
require_relative "../build/tools"
require_relative "../build/document_generator"
require_relative "../build/cleaner"

module Hrma
  module Commands
    class Build < Thor
      class_option :cache_dir, type: :string, desc: "Directory for caching downloaded tools"
      class_option :log_dir, type: :string, desc: "Directory for storing log files"
      class_option :parallel, type: :boolean, default: true, desc: "Enable parallel processing with Ractors"
      class_option :threads, type: :numeric, desc: "Number of parallel threads to use (default: CPU count)"
      class_option :manifest_path, type: :string, desc: "Path to schemas.yml manifest file"

      # Initialize with options
      def initialize(*args)
        super
        Hrma::Config.cache_dir = options[:cache_dir] if options[:cache_dir]
        Hrma::Config.log_dir = options[:log_dir] if options[:log_dir]

        # Ensure cache directory exists
        FileUtils.mkdir_p(Hrma::Config.cache_dir) unless File.directory?(Hrma::Config.cache_dir)

        # Ensure log directory exists if specified
        FileUtils.mkdir_p(Hrma::Config.log_dir) if Hrma::Config.log_dir && !File.directory?(Hrma::Config.log_dir)
      end

      desc "documentation", "Generate documentation for schemas"
      method_option :manifest_path, type: :string, desc: "Path to schemas.yml manifest file"
      def documentation
        # Verify dependencies and setup tools
        Hrma::Build::Tools.verify_dependencies
        Hrma::Build::Tools.setup

        # Generate documentation
        generator = Hrma::Build::DocumentGenerator.new(options)
        generator.generate
      end

      desc "clean", "Remove generated documentation"
      def clean
        cleaner = Hrma::Build::Cleaner.new
        cleaner.clean
      end

      desc "distclean", "Remove generated documentation and downloaded tools"
      method_option :global_cache, type: :boolean, default: false, desc: "Also clean the global cache directory"
      def distclean
        cleaner = Hrma::Build::Cleaner.new(options)
        cleaner.distclean
      end
    end
  end
end
