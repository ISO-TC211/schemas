# frozen_string_literal: true

require 'spec_helper'
require 'timeout'

RSpec.describe Hrma::Build::DocumentGenerator do
  # Skip tests if Ractor is not supported
  before(:all) do
    skip "Ractor not supported in this Ruby version" unless defined?(Ractor) && Ractor.respond_to?(:new)
  end

  let(:temp_dir) { File.join(Dir.pwd, 'tmp', 'test') }
  let(:test_files) { create_test_xsd_files(3) }
  let(:options) { { parallel: true, ractors: 2, log_dir: File.join(temp_dir, 'logs') } }

  before(:each) do
    FileUtils.mkdir_p(temp_dir)
    FileUtils.mkdir_p(options[:log_dir])

    # Stub the load_xsd_files method to return our test files
    allow_any_instance_of(described_class).to receive(:load_xsd_files).and_return(test_files)

    # Stub the process_single_file method to avoid actual processing
    allow_any_instance_of(Hrma::Build::RactorDocumentProcessor).to receive(:process_single_file).and_return(['test.xsd', true, nil])

    # Stub system calls
    allow(Kernel).to receive(:system).and_return(true)

    # Stub Open3.capture2e
    allow(Open3).to receive(:capture2e).and_return(['Output', double(success?: true)])
  end

  after(:each) do
    FileUtils.rm_rf(temp_dir)
  end

  describe '#generate_parallel' do
    it 'processes files with multiple ractors without deadlocking' do
      generator = described_class.new(options)

      # Test with timeout to catch deadlocks
      expect {
        DeadlockDetection.run_with_timeout(10) do
          generator.generate
        end
      }.not_to raise_error
    end

    it 'handles worker errors gracefully' do
      # Make one worker fail
      allow(Open3).to receive(:capture2e).and_return(['Error output', double(success?: false)])

      generator = described_class.new(options)

      # Should complete without exceptions
      expect {
        DeadlockDetection.run_with_timeout(10) do
          generator.generate
        end
      }.not_to raise_error
    end

    it 'handles timeouts gracefully' do
      # Simulate a timeout by making Open3.capture2e hang
      allow(Open3).to receive(:capture2e) do
        sleep 0.5 # Short sleep for testing
        ['Output', double(success?: true)]
      end

      generator = described_class.new(options)

      # Should complete without deadlocking
      expect {
        DeadlockDetection.run_with_timeout(10) do
          generator.generate
        end
      }.not_to raise_error
    end
  end

  # Helper methods
  def create_test_xsd_files(count)
    files = []
    count.times do |i|
      file_path = File.join(temp_dir, "test#{i}.xsd")
      File.write(file_path, <<~XSD)
        <?xml version="1.0" encoding="UTF-8"?>
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="test#{i}" type="xs:string"/>
        </xs:schema>
      XSD
      files << file_path
    end
    files
  end
end
