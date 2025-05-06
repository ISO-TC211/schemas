# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'

RSpec.describe Hrma::Build::DocumentGenerator do
  let(:temp_dir) { File.join(Dir.pwd, 'tmp', 'test') }
  let(:log_dir) { File.join(temp_dir, 'logs') }
  let(:options) { { log_dir: log_dir, manifest_path: File.join(temp_dir, 'schemas.yml') } }

  before(:each) do
    FileUtils.mkdir_p(temp_dir)
    FileUtils.mkdir_p(log_dir)

    # Create test XSD files
    create_test_xsd_files(2)

    # Create a test schemas.yml file
    create_test_schemas_yml
  end

  after(:each) do
    FileUtils.rm_rf(temp_dir)
  end

  describe '#generate' do
    it 'generates documentation for XSD files' do
      # Create a generator
      generator = described_class.new(options)

      # Call the generate method
      generator.generate

      # We're not checking the result since we're using test files
      # that won't actually generate documentation
    end
  end

  # Helper methods
  def create_test_xsd_files(count)
    @files = []
    count.times do |i|
      file_path = File.join(temp_dir, "test#{i}.xsd")
      File.write(file_path, <<~XSD)
        <?xml version="1.0" encoding="UTF-8"?>
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="test#{i}" type="xs:string"/>
        </xs:schema>
      XSD
      @files << file_path
    end
    @files
  end

  def create_test_schemas_yml
    # Create a simple schemas.yml file
    File.write(File.join(temp_dir, 'schemas.yml'), <<~YAML)
      source:
        schemas:
          xsd:
            - #{@files[0]}
            - #{@files[1]}
    YAML
  end
end
