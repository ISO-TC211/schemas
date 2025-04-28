# frozen_string_literal: true

require "thor"
require "yaml"
require "pathname"
require "fileutils"

module Hrma
  module Commands
    class Schemas < Thor
      class Manifest < Thor
        desc "update", "Update schemas.yml with all 3-character XSD and JSON files"
        def update
          yaml_path = File.join(Dir.pwd, "schemas.yml")
          schema_data = find_schema_files
          
          # Load existing file if present
          manifest = if File.exist?(yaml_path)
            YAML.load_file(yaml_path) || {}
          else
            {}
          end
          
          # Update with new structure
          manifest["source"] ||= {}
          manifest["source"]["schemas"] = {
            "xsd" => schema_data[:xsd].sort,
            "json" => schema_data[:json].sort
          }
          
          # Write updated manifest
          File.open(yaml_path, "w") do |file|
            file.write(manifest.to_yaml)
          end
          
          puts "Updated schemas.yml with #{schema_data[:xsd].size} XSD and #{schema_data[:json].size} JSON schemas"
        end

        desc "list", "List all schemas in the manifest file"
        method_option :type, type: :string, desc: "Filter by schema type (xsd or json)"
        method_option :doc, type: :string, desc: "Filter by document number"
        def list
          yaml_path = File.join(Dir.pwd, "schemas.yml")
          unless File.exist?(yaml_path)
            puts "Error: schemas.yml not found"
            return
          end
          
          manifest = YAML.load_file(yaml_path)
          schemas = []
          
          # Add XSD schemas if not filtering or filtering for XSD
          if !options[:type] || options[:type].downcase == "xsd"
            if manifest.dig("source", "schemas", "xsd")
              manifest["source"]["schemas"]["xsd"].each do |path|
                schemas << { type: "xsd", path: path }
              end
            elsif manifest.dig("source", "schemas") && manifest["source"]["schemas"].is_a?(Array)
              # Handle legacy format
              manifest["source"]["schemas"].each do |path|
                schemas << { type: "xsd", path: path }
              end
            end
          end
          
          # Add JSON schemas if not filtering or filtering for JSON
          if !options[:type] || options[:type].downcase == "json"
            if manifest.dig("source", "schemas", "json")
              manifest["source"]["schemas"]["json"].each do |path|
                schemas << { type: "json", path: path }
              end
            end
          end
          
          # Filter by document number if specified
          if options[:doc]
            schemas.select! do |schema|
              schema[:path].start_with?(options[:doc])
            end
          end
          
          # Display results
          if schemas.empty?
            puts "No matching schemas found"
          else
            puts "Found #{schemas.size} schemas:"
            schemas.each do |schema|
              puts "[#{schema[:type].upcase}] #{schema[:path]}"
            end
          end
        end

        desc "validate", "Verify all schemas in the manifest exist"
        def validate
          yaml_path = File.join(Dir.pwd, "schemas.yml")
          unless File.exist?(yaml_path)
            puts "Error: schemas.yml not found"
            return
          end
          
          manifest = YAML.load_file(yaml_path)
          all_valid = true
          missing_files = []
          
          # Check XSD schemas
          if manifest.dig("source", "schemas", "xsd")
            manifest["source"]["schemas"]["xsd"].each do |path|
              unless File.exist?(path)
                missing_files << path
                all_valid = false
              end
            end
          elsif manifest.dig("source", "schemas") && manifest["source"]["schemas"].is_a?(Array)
            # Handle legacy format
            manifest["source"]["schemas"].each do |path|
              unless File.exist?(path)
                missing_files << path
                all_valid = false
              end
            end
          end
          
          # Check JSON schemas
          if manifest.dig("source", "schemas", "json")
            manifest["source"]["schemas"]["json"].each do |path|
              unless File.exist?(path)
                missing_files << path
                all_valid = false
              end
            end
          end
          
          # Report results
          if all_valid
            puts "All schemas exist"
          else
            puts "Error: #{missing_files.size} schemas are missing:"
            missing_files.each do |path|
              puts "  - #{path}"
            end
            exit 1
          end
        end
        
        private
        
        def find_schema_files
          result = { xsd: [], json: [] }
          
          # Find all XSD files
          Dir.glob("**/*.xsd").each do |path|
            filename = File.basename(path)
            name_without_ext = File.basename(filename, ".xsd")
            
            # Check if basename (without extension) is exactly 3 characters
            if name_without_ext.length == 3
              result[:xsd] << path
            end
          end
          
          # Find all JSON files
          Dir.glob("**/*.json").each do |path|
            filename = File.basename(path)
            name_without_ext = File.basename(filename, ".json")
            
            # Check if basename (without extension) is exactly 3 characters
            if name_without_ext.length == 3
              result[:json] << path
            end
          end
          
          result
        end
      end
      
      desc "manifest SUBCOMMAND", "Manage the schema manifest file"
      subcommand "manifest", Manifest
    end
  end
end
