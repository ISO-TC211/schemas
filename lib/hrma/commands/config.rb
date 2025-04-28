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
        when "log_dir"
          puts Hrma::Config.log_dir
        else
          puts "Unknown configuration key: #{key}"
          exit 1
        end
      end

      desc "set KEY VALUE", "Set a configuration value"
      def set(key, value)
        config_file = File.expand_path("~/.hrma/config.yml")
        config = File.exist?(config_file) ? YAML.load_file(config_file) : {}

        case key
        when "cache_dir"
          config["cache_dir"] = value
          save_config(config, config_file)
          puts "Cache directory set to: #{value}"
        when "log_dir"
          config["log_dir"] = value
          save_config(config, config_file)
          puts "Log directory set to: #{value}"
        else
          puts "Unknown configuration key: #{key}"
          exit 1
        end
      end

      private

      def save_config(config, config_file)
        FileUtils.mkdir_p(File.dirname(config_file))
        File.write(config_file, config.to_yaml)
      end
    end
  end
end
