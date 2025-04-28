# frozen_string_literal: true

require "yaml"
require "fileutils"

module Hrma
  class Config
    DEFAULT_CACHE_DIR = File.expand_path("~/.hrma/cache")
    DEFAULT_LOG_DIR = File.expand_path("~/.hrma/logs")

    class << self
      def cache_dir
        @cache_dir ||= determine_cache_dir
      end

      def cache_dir=(dir)
        @cache_dir = dir
      end

      def log_dir
        @log_dir ||= determine_log_dir
      end

      def log_dir=(dir)
        @log_dir = dir
      end

      private

      def determine_cache_dir
        # Priority: Environment variable > Config file > Default
        env_cache_dir || config_file_cache_dir || DEFAULT_CACHE_DIR
      end

      def determine_log_dir
        # Priority: Environment variable > Config file > Default
        env_log_dir || config_file_log_dir || DEFAULT_LOG_DIR
      end

      def env_cache_dir
        ENV["HRMA_CACHE_DIR"]
      end

      def env_log_dir
        ENV["HRMA_LOG_DIR"]
      end

      def config_file_cache_dir
        config = read_config_file
        config && config["cache_dir"]
      end

      def config_file_log_dir
        config = read_config_file
        config && config["log_dir"]
      end

      def read_config_file
        config_file = File.expand_path("~/.hrma/config.yml")
        return nil unless File.exist?(config_file)

        begin
          YAML.load_file(config_file)
        rescue
          nil
        end
      end
    end
  end
end
