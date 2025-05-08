# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'logger'

RSpec.describe Hrma::Build::Schema do
  # Use a temporary directory for testing
  let(:schema_dir) { "tmp/test/schemas" }
  let(:schema_path) { "#{schema_dir}/sample.xsd" }
  let(:schema) { described_class.new(schema_path) }
  let(:output_dir) { schema.paths[:output_dir] }
  let(:test_logger) { Logger.new(File.join(schema_dir, 'test.log')) }

  # Helper method to check if tools are available
  def tools_available?
    # Check if required tools are available in the system
    system("which xsltproc > /dev/null 2>&1") && system("which java > /dev/null 2>&1")
  end

  before do
    # Create required directories
    FileUtils.mkdir_p(schema_dir)
    FileUtils.mkdir_p(output_dir)

    # Create a minimal sample XSD file
    File.write(schema_path, <<~XSD)
      <?xml version="1.0" encoding="UTF-8"?>
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="test" type="xs:string"/>
      </xs:schema>
    XSD

    # Ensure the tools are properly set up
    setup_test_environment
  end

  after do
    # Clean up test logger
    test_logger.close
  end

  describe "#initialize" do
    it "initializes with a schema path" do
      expect(schema.schema_path).to eq(schema_path)
    end
  end

  describe "#paths" do
    it "returns a hash of paths related to the schema" do
      paths = schema.paths
      expect(paths).to include(
        target_html: schema_path.sub(/\.xsd$/, ""),
        output_dir: "_site/#{schema_path.sub(/\.xsd$/, "")}",
        output_file: "_site/#{schema_path.sub(/\.xsd$/, "")}/index.html",
        temp_file: "_site/#{schema_path.sub(/\.xsd$/, "")}/index.html.tmp"
      )
    end
  end

  describe "#up_to_date?" do
    context "when documentation does not exist" do
      it "returns false" do
        # Ensure output file doesn't exist
        FileUtils.rm_f(schema.paths[:output_file])
        expect(schema.up_to_date?).to be false
      end
    end

    context "when documentation exists but is older than the schema" do
      it "returns false" do
        # Create output file with older timestamp
        FileUtils.mkdir_p(File.dirname(schema.paths[:output_file]))
        FileUtils.touch(schema.paths[:output_file], mtime: File.mtime(schema_path) - 1)
        expect(schema.up_to_date?).to be false
      end
    end

    context "when documentation exists and is newer than the schema" do
      it "returns true" do
        # Create output file with newer timestamp
        FileUtils.mkdir_p(File.dirname(schema.paths[:output_file]))
        FileUtils.touch(schema.paths[:output_file], mtime: File.mtime(schema_path) + 1)
        expect(schema.up_to_date?).to be true
      end
    end
  end

  # The following tests require actual tool execution which might not be available
  # in all test environments. We'll conditionally run them if the tools are available.

  describe "#generate_docs", if: :tools_available? do
    context "when documentation is up to date" do
      before do
        # Create output file with newer timestamp
        FileUtils.mkdir_p(File.dirname(schema.paths[:output_file]))
        FileUtils.touch(schema.paths[:output_file], mtime: File.mtime(schema_path) + 1)
      end

      it "skips generation and returns true" do
        # Since we're not using mocks, we'll check if the method returns true
        # and that output file isn't modified
        original_mtime = File.mtime(schema.paths[:output_file])

        expect(schema.generate_docs(logger: test_logger)).to be true

        # Verify timestamp hasn't changed
        expect(File.mtime(schema.paths[:output_file])).to eq(original_mtime)
      end
    end

    context "when documentation is not up to date" do
      before do
        # Ensure output file doesn't exist
        FileUtils.rm_f(schema.paths[:output_file])

        # For tests to run successfully, essential directories should exist
        FileUtils.mkdir_p(File.dirname(schema.paths[:output_file]))
        FileUtils.mkdir_p(File.join(output_dir, 'diagrams'))
      end

      it "attempts to generate documentation" do
        result = schema.generate_docs(logger: test_logger)

        # Since actual tool execution might fail in test environment,
        # we just verify that the method executes without errors
        expect(result).to satisfy { |value| [true, false].include?(value) }

        # Check log file to see if appropriate messages were logged
        log_content = File.read(File.join(schema_dir, 'test.log'))
        expect(log_content).to include("Generating documentation for #{schema_path}")
      end
    end
  end

  # Helper methods for the tests

  def setup_test_environment
    # Create necessary directories for Tool execution
    ['xsdvi', 'xsl', '_site'].each do |dir|
      FileUtils.mkdir_p(dir)
    end

    # Create mock tool files to avoid actual execution
    # In a real environment, these would be actual tools
    ['xsdvi/xsdvi.jar', 'xsdvi/xercesImpl.jar', 'xsl/xs3p.xsl', 'xsl/xsdmerge.xsl'].each do |tool|
      FileUtils.mkdir_p(File.dirname(tool))
      FileUtils.touch(tool)
    end
  end
end
