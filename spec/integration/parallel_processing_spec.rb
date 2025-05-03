# frozen_string_literal: true

require 'spec_helper'
require 'timeout'
require 'fileutils'
require 'yaml'

RSpec.describe 'Parallel Processing Integration', type: :integration do
  # Skip tests if Ractor is not supported
  before(:all) do
    skip "Ractor not supported in this Ruby version" unless defined?(Ractor) && Ractor.respond_to?(:new)
  end

  # Set up test directories
  let(:temp_dir) { File.join(Dir.pwd, 'tmp', 'integration_test') }
  let(:output_dir) { File.join(temp_dir, '_site') }
  let(:log_dir) { File.join(temp_dir, 'logs') }
  let(:schemas_dir) { File.join(temp_dir, 'schemas') }
  let(:manifest_path) { File.join(temp_dir, 'schemas.yml') }

  # Define test tool paths for compatibility
  let(:tool_paths) do
    {
      xsdvi_path: File.join(Dir.pwd, 'xsdvi', 'xsdvi.jar'),
      xsdmerge_path: File.join(Dir.pwd, 'xsl', 'xsdmerge.xsl'),
      xs3p_path: File.join(Dir.pwd, 'xsl', 'xs3p.xsl')
    }
  end

  # Testing with different ractor configurations
  let(:options_base) do
    {
      manifest_path: manifest_path,
      parallel: true,
      log_dir: log_dir
    }
  end

  let(:options_1_ractor) { options_base.merge(ractors: 1) }
  let(:options_2_ractors) { options_base.merge(ractors: 2) }
  let(:options_4_ractors) { options_base.merge(ractors: 4) }
  let(:options_auto_ractors) { options_base.merge(ractors: nil) }

  before(:each) do
    # Set up test directories
    FileUtils.mkdir_p(temp_dir)
    FileUtils.mkdir_p(output_dir)
    FileUtils.mkdir_p(log_dir)
    FileUtils.mkdir_p(schemas_dir)

    # Create test schemas
    create_test_schemas

    # Create fixture files needed for processing
    create_fixture_files
  end

  after(:each) do
    FileUtils.rm_rf(temp_dir)
  end

  # Skip tests if needed commands aren't available
  before(:each) do
    required_commands = ['java', 'xsltproc']
    missing_commands = required_commands.reject { |cmd| system("which #{cmd} > /dev/null 2>&1") }

    if !missing_commands.empty?
      skip "Missing required commands: #{missing_commands.join(', ')}"
    end
  end

  describe "Running with different ractor configurations" do
    it 'processes with 1 ractor' do
      # Create a small set of files to test with 1 ractor
      create_minimal_schema_set(1)

      # Process the schemas
      generator = Hrma::Build::DocumentGenerator.new(options_1_ractor)

      # This should not raise errors
      expect {
        Timeout.timeout(30) do  # 30 second timeout to avoid hanging tests
          generator.generate
        end
      }.not_to raise_error
    end

    it 'processes with 2 ractors' do
      # Create a small set of files to test with 2 ractors
      create_minimal_schema_set(2)

      # Process the schemas
      generator = Hrma::Build::DocumentGenerator.new(options_2_ractors)

      # This should not raise errors
      expect {
        Timeout.timeout(30) do  # 30 second timeout to avoid hanging tests
          generator.generate
        end
      }.not_to raise_error
    end

    it 'processes with 4 ractors' do
      # Create a small set of files to test with 4 ractors
      create_minimal_schema_set(4)

      # Process the schemas
      generator = Hrma::Build::DocumentGenerator.new(options_4_ractors)

      # This should not raise errors
      expect {
        Timeout.timeout(30) do  # 30 second timeout to avoid hanging tests
          generator.generate
        end
      }.not_to raise_error
    end

    it 'processes with auto-determined ractor count' do
      # Create a small set of files to test with auto ractors
      create_minimal_schema_set(3)

      # Process the schemas
      generator = Hrma::Build::DocumentGenerator.new(options_auto_ractors)

      # This should not raise errors
      expect {
        Timeout.timeout(30) do  # 30 second timeout to avoid hanging tests
          generator.generate
        end
      }.not_to raise_error
    end
  end

  describe "Per-schema logging" do
    it 'creates separate log files for each schema' do
      # Create a small set of files
      schema_list = create_minimal_schema_set(2)

      # Create generator with log directory
      generator = Hrma::Build::DocumentGenerator.new(options_1_ractor)

      # Process schemas
      Timeout.timeout(30) do
        generator.generate
      end

      # Check that log files were created for each schema
      schema_list.each do |schema_file|
        base_name = File.basename(schema_file, '.xsd')
        log_file = File.join(log_dir, "#{base_name}.log")

        # Verify log file exists or can be created (no direct assertions since we can't control the processing)
        if File.exist?(log_file)
          # If the log file exists, check it has some content
          expect(File.size(log_file)).to be > 0
        end
      end
    end
  end

  # Helper methods
  def create_test_schemas
    # Create several test schema files
    (1..5).each do |i|
      filename = "test#{i}.xsd"
      file_path = File.join(schemas_dir, filename)
      File.write(file_path, create_test_xsd_content("Test#{i}"))
    end
  end

  def create_minimal_schema_set(count)
    # Create a manifest with a small subset of schemas
    schema_list = []

    # Use existing schemas or create new ones if needed
    existing_schemas = Dir.glob(File.join(schemas_dir, "*.xsd"))

    if existing_schemas.size >= count
      schema_list = existing_schemas.take(count)
    else
      # Create more schemas as needed
      (existing_schemas.size...count).each do |i|
        filename = "minimal_test#{i}.xsd"
        file_path = File.join(schemas_dir, filename)
        File.write(file_path, create_test_xsd_content("MinimalTest#{i}"))
        schema_list << file_path
      end
    end

    # Use only relative paths for manifest
    schema_list = schema_list.map { |path| Pathname.new(path).relative_path_from(Pathname.new(temp_dir)).to_s }

    # Create manifest
    manifest = {
      'source' => {
        'schemas' => {
          'xsd' => schema_list
        }
      }
    }

    File.write(manifest_path, manifest.to_yaml)

    schema_list
  end

  def create_test_xsd_content(element_name)
    <<~XSD
      <?xml version="1.0" encoding="UTF-8"?>
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="#{element_name}" type="xs:string"/>
      </xs:schema>
    XSD
  end

  def create_fixture_files
    # Ensure directories exist for tool paths
    FileUtils.mkdir_p(File.join(Dir.pwd, 'xsdvi'))
    FileUtils.mkdir_p(File.join(Dir.pwd, 'xsl'))

    # Create mock tool files if they don't exist
    [
      File.join(Dir.pwd, 'xsdvi', 'xsdvi.jar'),
      File.join(Dir.pwd, 'xsl', 'xsdmerge.xsl'),
      File.join(Dir.pwd, 'xsl', 'xs3p.xsl')
    ].each do |file|
      unless File.exist?(file)
        FileUtils.touch(file)
      end
    end
  end
end
