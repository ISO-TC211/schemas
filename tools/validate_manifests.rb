#!/usr/bin/env ruby
# frozen_string_literal: true

# Validates lxr_packages.yml and ljr_packages.yml:
# - YAML structure (required fields)
# - All referenced files exist on disk
# - No duplicate package names
# - Required keys: name, title, standard, files
#
# With --list-files: outputs one file path per line (for use by other CI steps)

require "yaml"

SCHEMAS_DIR = File.expand_path(__dir__ + "/..")
LIST_MODE = ARGV.include?("--list-files")

REQUIRED_KEYS = %w[name title standard files].freeze

def load_files_from_manifest(path)
  unless File.exist?(path)
    abort "ABORT: #{path} not found"
  end

  manifest = YAML.load_file(path)
  packages = manifest["packages"] || []

  if LIST_MODE
    packages.flat_map { |pkg| pkg["files"] || [] }.each { |f| puts f }
    return
  end

  puts "\n== Validating #{File.basename(path)} (#{File.basename(path, '.yml')}) =="

  if packages.empty?
    abort "  ABORT: no packages defined"
  end

  puts "  #{packages.size} packages found"

  names = []
  errors = 0

  packages.each_with_index do |pkg, i|
    prefix = "  [#{i + 1}/#{packages.size}] #{pkg['name'] || '(unnamed)'}"

    missing = REQUIRED_KEYS.reject { |k| pkg.key?(k) && !pkg[k].nil? }
    unless missing.empty?
      puts "#{prefix}: MISSING keys: #{missing.join(', ')}"
      errors += 1
      next
    end

    if names.include?(pkg["name"])
      puts "#{prefix}: DUPLICATE name '#{pkg['name']}'"
      errors += 1
    end
    names << pkg["name"]

    files = pkg["files"] || []
    file_errors = 0
    files.each do |f|
      full = File.join(SCHEMAS_DIR, f)
      unless File.exist?(full)
        puts "#{prefix}: MISSING file: #{f}"
        file_errors += 1
      end
    end

    if file_errors.zero?
      puts "#{prefix}: OK (#{files.size} files)"
    else
      errors += file_errors
    end
  end

  if errors.zero?
    puts "  PASSED: all #{packages.size} packages valid"
  else
    abort "  FAILED: #{errors} error(s)"
  end
end

lxr_path = File.join(SCHEMAS_DIR, "lxr_packages.yml")
ljr_path = File.join(SCHEMAS_DIR, "ljr_packages.yml")

unless LIST_MODE
  puts "Schemas dir: #{SCHEMAS_DIR}"
end

load_files_from_manifest(lxr_path)
load_files_from_manifest(ljr_path)

unless LIST_MODE
  puts "\nAll manifests valid."
end
