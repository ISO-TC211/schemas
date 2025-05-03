# frozen_string_literal: true

require 'fileutils'
require 'timeout'

# Add lib directory to load path
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

# Require the main library files
require 'hrma/build/ractor_document_processor'
require 'hrma/build/document_generator'

# Configure RSpec
RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  # Enable warnings
  config.warnings = true

  # Use the specified formatter
  config.formatter = :documentation

  # Run specs in random order
  config.order = :random
  Kernel.srand config.seed

  # Set up test environment before all tests
  config.before(:suite) do
    # Create temporary directories
    FileUtils.mkdir_p('tmp/test')
  end

  # Clean up after all tests
  config.after(:suite) do
    # Remove temporary directories
    FileUtils.rm_rf('tmp')
  end

  # Mock system calls to avoid actual execution during tests
  config.before(:each) do
    # Allow FileUtils methods to execute normally
    allow(FileUtils).to receive(:mkdir_p).and_call_original
    allow(FileUtils).to receive(:rm_rf).and_call_original
  end
end

# Helper module for testing with deadlock detection
module DeadlockDetection
  def self.run_with_timeout(timeout_seconds = 5)
    Timeout.timeout(timeout_seconds) do
      yield
    end
  rescue Timeout::Error
    raise "Possible deadlock detected - operation timed out after #{timeout_seconds} seconds"
  end
end
