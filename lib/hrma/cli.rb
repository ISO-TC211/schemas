# frozen_string_literal: true

require "thor"
require_relative "commands/schemas"
require_relative "commands/build"
require_relative "commands/config"

module Hrma
  # Main CLI class for the hrma tool
  class Cli < Thor
    desc "schemas SUBCOMMAND", "Manage schemas"
    # Manage schemas
    #
    # @return [void]
    subcommand "schemas", Hrma::Commands::Schemas

    desc "build SUBCOMMAND", "Build documentation for schemas"
    # Build documentation for schemas
    #
    # @return [void]
    subcommand "build", Hrma::Commands::Build

    desc "config SUBCOMMAND", "Manage CLI configuration"
    # Manage hrma configuration
    #
    # @return [void]
    subcommand "config", Hrma::Commands::Config
  end
end
