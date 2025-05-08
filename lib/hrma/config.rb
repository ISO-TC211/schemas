# frozen_string_literal: true

require "yaml"
require "fileutils"

module Hrma
  # Configuration management for the hrma tool
  class Config
    # Default cache directory path
    DEFAULT_CACHE_DIR = File.expand_path("~/.hrma/cache")

    # Default log directory path
    DEFAULT_LOG_DIR = File.expand_path(File.join(Dir.pwd), "logs")

    class << self
      # Get the cache directory path
      #
      # @return [String] Path to the cache directory
      def cache_dir
        @cache_dir ||= determine_cache_dir
      end

      # Set the cache directory path
      #
      # @param dir [String] Path to the cache directory
      # @return [String] The new cache directory path
      def cache_dir=(dir)
        @cache_dir = dir
      end

      # Get the log directory path
      #
      # @return [String] Path to the log directory
      def log_dir
        @log_dir ||= determine_log_dir
      end

      # Set the log directory path
      #
      # @param dir [String] Path to the log directory
      # @return [String] The new log directory path
      def log_dir=(dir)
        @log_dir = dir
      end

      private

      # Determine the cache directory path based on priority:
      # Environment variable > Config file > Default
      #
      # @return [String] Path to the cache directory
      def determine_cache_dir
        env_cache_dir || config_file_cache_dir || DEFAULT_CACHE_DIR
      end

      # Determine the log directory path based on priority:
      # Environment variable > Config file > Default
      #
      # @return [String] Path to the log directory
      def determine_log_dir
        env_log_dir || config_file_log_dir || DEFAULT_LOG_DIR
      end

      # Get the cache directory path from environment variable
      #
      # @return [String, nil] Path to the cache directory or nil if not set
      def env_cache_dir
        ENV["HRMA_CACHE_DIR"]
      end

      # Get the log directory path from environment variable
      #
      # @return [String, nil] Path to the log directory or nil if not set
      def env_log_dir
        ENV["HRMA_LOG_DIR"]
      end

      # Get the cache directory path from config file
      #
      # @return [String, nil] Path to the cache directory or nil if not set
      def config_file_cache_dir
        config = read_config_file
        config && config["cache_dir"]
      end

      # Get the log directory path from config file
      #
      # @return [String, nil] Path to the log directory or nil if not set
      def config_file_log_dir
        config = read_config_file
        config && config["log_dir"]
      end

      # Read the config file
      #
      # @return [Hash, nil] Config hash or nil if file doesn't exist or is invalid
      def read_config_file
        config_file = File.expand_path("~/.hrma/config.yml")
        return nil unless File.exist?(config_file)

        begin
          YAML.load_file(config_file)
        rescue StandardError
          nil
        end
      end
    end
  end
end
