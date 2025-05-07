# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'

RSpec.describe Hrma::Build::SchemaProcessor do
  # Create a temporary directory for test files
  let(:temp_dir) { File.join(Dir.pwd, 'tmp', 'test') }
  let(:test_file) { File.join(temp_dir, 'test.xsd') }

  before(:each) do
    FileUtils.mkdir_p(temp_dir)
    FileUtils.mkdir_p("_site")

    # Create test XSD file
    File.write(test_file, <<~XSD)
      <?xml version="1.0" encoding="UTF-8"?>
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="test" type="xs:string"/>
      </xs:schema>
    XSD
  end

  after(:each) do
    FileUtils.rm_rf(temp_dir)
    FileUtils.rm_rf("_site/#{test_file.sub(/\.xsd$/, '')}")
  end

  # Create a simple logger for testing
  def create_test_logger
    logger = Logger.new(StringIO.new)
    logger.level = Logger::INFO
    logger
  end

  describe '#process' do
    it 'skips processing if the output file is up to date' do
      # Create the output file and set its modification time to the future
      output_dir = "_site/#{test_file.sub(/\.xsd$/, '')}"
      output_file = "#{output_dir}/index.html"

      FileUtils.mkdir_p(output_dir)
      FileUtils.touch(output_file)

      # Set the modification time to the future
      future_time = Time.now + 3600 # 1 hour in the future
      File.utime(future_time, future_time, output_file)

      # Create a processor
      processor = described_class.new

      # Process the file - it should be skipped
      result = processor.process(schema_path: test_file, logger: create_test_logger)

      # Check the result
      expect(result).to be true
    end
  end
end
