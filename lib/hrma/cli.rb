# frozen_string_literal: true

require "thor"
require_relative "commands/schemas"
require_relative "commands/build"
require_relative "commands/config"

module Hrma
  class Cli < Thor
    desc "schemas SUBCOMMAND", "Manage schemas for ISO/TC 211"
    subcommand "schemas", Hrma::Commands::Schemas
    
    desc "build SUBCOMMAND", "Build documentation for schemas"
    subcommand "build", Hrma::Commands::Build
    
    desc "config SUBCOMMAND", "Manage hrma configuration"
    subcommand "config", Hrma::Commands::Config
  end
end
