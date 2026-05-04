# frozen_string_literal: true

require "thor"
require_relative "commands/schemas"
require_relative "commands/config"

module Hrma
  class Cli < Thor
    desc "schemas SUBCOMMAND", "Manage schemas"
    subcommand "schemas", Hrma::Commands::Schemas

    desc "config SUBCOMMAND", "Manage CLI configuration"
    subcommand "config", Hrma::Commands::Config
  end
end
