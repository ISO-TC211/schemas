# frozen_string_literal: true

require "fileutils"
require_relative "../config"

module Hrma
  module Build
    # Class for cleaning generated files and downloaded tools
    class Cleaner
      include FileUtils

      # Initialize a new Cleaner
      #
      # @param options [Hash] Options for cleaning
      # @option options [Boolean] :global_cache Whether to clean the global cache directory
      def initialize(options = {})
        @options = options
      end

      # Clean generated documentation
      #
      # Removes the _site, xsl, and xsdvi directories
      #
      # @return [void]
      def clean
        rm_rf("_site")
        rm_rf("xsl")
        rm_rf("xsdvi")
        puts "Cleaned generated documentation."
      end

      # Clean generated documentation and downloaded tools
      #
      # Calls clean and then removes the cache directories
      #
      # @return [void]
      def distclean
        clean

        if @options[:global_cache]
          puts "Cleaning global cache directory: #{Hrma::Config.cache_dir}"
          rm_rf(Hrma::Config.cache_dir)
          mkdir_p(Hrma::Config.cache_dir)
        else
          puts "Cleaning local .archive directory"
          rm_rf(".archive")
        end

        puts "Cleaned generated documentation and downloaded tools."
      end
    end
  end
end
