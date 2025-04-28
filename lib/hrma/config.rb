# frozen_string_literal: true

require "yaml"
require "fileutils"

module Hrma
  class Config
    DEFAULT_CACHE_DIR = File.expand_path("~/.hrma/cache")
    
    class << self
      def cache_dir
        @cache_dir ||= determine_cache_dir
      end
      
      def cache_dir=(dir)
        @cache_dir = dir
      end
      
      private
      
      def determine_cache_dir
        # Priority: Environment variable > Config file > Default
        env_cache_dir || config_file_cache_dir || DEFAULT_CACHE_DIR
      end
      
      def env_cache_dir
        ENV["HRMA_CACHE_DIR"]
      end
      
      def config_file_cache_dir
        config_file = File.expand_path("~/.hrma/config.yml")
        return nil unless File.exist?(config_file)
        
        begin
          config = YAML.load_file(config_file)
          config["cache_dir"]
        rescue
          nil
        end
      end
    end
  end
end
