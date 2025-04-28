# frozen_string_literal: true

require "thor"
require_relative "commands/schemas"

module Hrma
  class Cli < Thor
    desc "schemas SUBCOMMAND", "Manage schemas for ISO/TC 211"
    subcommand "schemas", Hrma::Commands::Schemas
  end
end
