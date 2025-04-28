# frozen_string_literal: true

require "thor"
require "yaml"
require "fileutils"
require_relative "../config"

module Hrma
  module Commands
    class Config < Thor
      desc "get KEY", "Get a configuration value"
      def get(key)
        case key
        when "cache_dir"
          puts Hrma::Config.cache_dir
        else
          puts "Unknown configuration key: #{key}"
          exit 1
        end
      end
      
      desc "set KEY VALUE", "Set a configuration value"
      def set(key, value)
        case key
        when "cache_dir"
          config_file = File.expand_path("~/.hrma/config.yml")
          config = File.exist?(config_file) ? YAML.load_file(config_file) : {}
          config["cache_dir"] = value
          
          FileUtils.mkdir_p(File.dirname(config_file))
          File.write(config_file, config.to_yaml)
          puts "Cache directory set to: #{value}"
        else
          puts "Unknown configuration key: #{key}"
          exit 1
        end
      end
    end
  end
end
