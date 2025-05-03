# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'timeout'
require 'fileutils'

RSpec.describe Hrma::Build::RactorDocumentProcessor do
  # Create a temporary directory for test files
  let(:temp_dir) { File.join(Dir.pwd, 'tmp', 'test') }
  let(:log_dir) { File.join(temp_dir, 'logs') }
  let(:output_dir) { File.join(temp_dir, 'output') }
  let(:test_file) { File.join(temp_dir, 'test.xsd') }
  let(:safe_test_file) { File.join(temp_dir, 'safe_test.xsd') }
  let(:error_test_file) { File.join(temp_dir, 'error_file_with_e.xsd') }

  # Define test tool paths for compatibility
  let(:tool_paths) do
    {
      xsdvi_path: File.join(Dir.pwd, 'xsdvi', 'xsdvi.jar'),
      xsdmerge_path: File.join(Dir.pwd, 'xsl', 'xsdmerge.xsl'),
      xs3p_path: File.join(Dir.pwd, 'xsl', 'xs3p.xsl')
    }
  end

  before(:each) do
    FileUtils.mkdir_p(temp_dir)
    FileUtils.mkdir_p(log_dir)
    FileUtils.mkdir_p(output_dir)
    FileUtils.mkdir_p(File.join(output_dir, 'diagrams'))

    # Create test XSD files
    write_test_xsd_file(test_file)
    write_test_xsd_file(safe_test_file)
    write_test_xsd_file(error_test_file)

    # Create placeholder tool files if they don't exist
    create_fixture_files
  end

  after(:each) do
    FileUtils.rm_rf(temp_dir)
  end

  # Helper to write a test XSD file
  def write_test_xsd_file(filepath)
    File.write(filepath, <<~XSD)
      <?xml version="1.0" encoding="UTF-8"?>
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="test" type="xs:string"/>
      </xs:schema>
    XSD
  end

  # Create necessary fixture files for testing
  def create_fixture_files
    # Ensure directories exist
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

  # Skip this test if commands aren't available
  before(:each) do
    # These commands are used in the actual code
    required_commands = ['java', 'xsltproc']
    missing_commands = required_commands.reject { |cmd| system("which #{cmd} > /dev/null 2>&1") }

    if !missing_commands.empty?
      skip "Missing required commands: #{missing_commands.join(', ')}"
    end
  end

  describe '.process_single_file' do
    it 'processes a file and returns the expected result format' do
      # Process a test file
      result = described_class.process_single_file(
        safe_test_file, log_dir, Dir.pwd, tool_paths
      )

      # Check result format regardless of actual success
      expect(result).to be_an(Array)
      expect(result.size).to eq(3)
      expect(result[0]).to eq(safe_test_file.to_s)
      expect([true, false]).to include(result[1]) # Boolean success flag
      if !result[1]  # If it failed, should have error message
        expect(result[2]).to be_a(String)
      end
    end
  end

  # Only run Ractor tests if Ractor is supported
  if defined?(Ractor) && Ractor.respond_to?(:new)
    describe 'Error handling pattern' do
      it 'identifies error-causing files correctly' do
        # Test the method directly
        expect(described_class.error_causing_file?("error_file_with_e.xsd")).to be true
        expect(described_class.error_causing_file?("another_error_file_with_e.xsd")).to be true
        expect(described_class.error_causing_file?("safe_file.xsd")).to be false
        expect(described_class.error_causing_file?("file_with_letter_e.xsd")).to be false
      end
    end

    describe '.create_worker' do
      let(:tools) { { xsdvi_path: 'path/to/xsdvi', xsdmerge_path: 'path/to/xsdmerge', xs3p_path: 'path/to/xs3p' } }

      it 'creates a worker Ractor' do
        # Skip if we're not in a context where we can create Ractors
        skip "Can't create Ractor in this context" unless Ractor.respond_to?(:new)

        # Create a worker
        worker = nil
        expect {
          worker = described_class.create_worker(1, "Test-Worker", tools, log_dir, Dir.pwd)
        }.not_to raise_error

        # Clean up
        worker.send(:exit) if worker
      end
    end
  end
end
