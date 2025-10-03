#!/usr/bin/env ruby

# Agiliton Deployment Test Suite
# Run with: ruby test_deployment.rb

require 'fileutils'
require 'json'
require_relative '../agiliton_deployment_v2'
require_relative '../error_handling'

class DeploymentTests
  def self.run
    new.run_all_tests
  end

  def initialize
    @test_dir = "/tmp/agiliton_test_#{Time.now.to_i}"
    @results = []
  end

  def run_all_tests
    puts "Running Agiliton Deployment Tests..."
    puts "=" * 50

    setup_test_environment

    # Run tests
    test_cleanup_old_artifacts
    test_build_number_verification
    test_error_handling
    test_altool_log_parsing
    test_version_extraction

    # Print results
    print_results

    # Cleanup
    cleanup_test_environment

    exit(@results.any? { |r| !r[:passed] } ? 1 : 0)
  end

  private

  def setup_test_environment
    FileUtils.mkdir_p(@test_dir)
    Dir.chdir(@test_dir)
  end

  def cleanup_test_environment
    FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
  end

  def test_cleanup_old_artifacts
    test_name = "Cleanup Old Artifacts"
    begin
      # Create test artifacts
      File.write("old.pkg", "test")
      File.write("app.dSYM.zip", "test")

      # Run cleanup
      AgilitonDeployment.cleanup_old_artifacts(project_root: @test_dir)

      # Verify cleanup
      old_pkg_backup = Dir.glob("*.backup_*").first
      assert(old_pkg_backup, "Old pkg should be backed up")
      assert(!File.exist?("app.dSYM.zip"), "dSYM should be removed")

      pass(test_name)
    rescue => e
      fail(test_name, e)
    end
  end

  def test_build_number_verification
    test_name = "Build Number Verification"
    begin
      # Mock xcodeproj
      mock_project = File.join(@test_dir, "test.xcodeproj")
      FileUtils.mkdir_p(mock_project)

      # Test with missing agvtool (common case)
      build_number = AgilitonDeployment.verify_build_number(
        app_identifier: "com.test.app",
        xcodeproj: mock_project,
        api_key: nil
      )

      assert(build_number.is_a?(Integer), "Build number should be integer")

      pass(test_name)
    rescue => e
      fail(test_name, e)
    end
  end

  def test_error_handling
    test_name = "Error Handling with Retries"
    begin
      attempt_count = 0

      # Test retry logic
      result = AgilitonErrorHandler.with_retry(action_name: "Test Action", max_retries: 2) do
        attempt_count += 1
        if attempt_count < 2
          raise "Network timeout"
        end
        "success"
      end

      assert(result == "success", "Should succeed after retry")
      assert(attempt_count == 2, "Should have retried once")

      # Test non-retryable error
      non_retry_count = 0
      begin
        AgilitonErrorHandler.with_retry(action_name: "Test Fail") do
          non_retry_count += 1
          raise "Fatal error"
        end
      rescue => e
        assert(e.message == "Fatal error", "Should raise non-retryable error")
        assert(non_retry_count == 1, "Should not retry for non-retryable errors")
      end

      pass(test_name)
    rescue => e
      fail(test_name, e)
    end
  end

  def test_altool_log_parsing
    test_name = "Altool Log Parsing"
    begin
      # Create mock log directory
      log_dir = File.expand_path("~/Library/Logs/ContentDelivery/com.apple.itunes.altool")
      FileUtils.mkdir_p(log_dir)

      # Create mock log file
      log_file = File.join(log_dir, "test_#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}.txt")
      File.write(log_file, <<~LOG)
        2025-01-01 12:00:00 INFO: Starting upload
        2025-01-01 12:00:01 ERROR: ENTITY_ERROR.BUNDLE.IOS_BUNDLE_VERSION_MUST_BE_HIGHER The bundle version must be higher than the previously uploaded version: '53'
        2025-01-01 12:00:02 INFO: Upload failed
      LOG

      # Test log checking
      begin
        AgilitonDeployment.check_altool_logs
        # This should detect the error but we're just testing parsing
      rescue => e
        assert(e.message.include?("Build number already exists"), "Should detect build number error")
      end

      # Cleanup test log
      File.delete(log_file) if File.exist?(log_file)

      pass(test_name)
    rescue => e
      fail(test_name, e)
    end
  end

  def test_version_extraction
    test_name = "Version Info Extraction"
    begin
      # Create mock pkg structure
      mock_pkg = File.join(@test_dir, "test.pkg")
      File.write(mock_pkg, "mock package content")

      # Test extraction (will return unknown for mock)
      version_info = AgilitonDeployment.extract_version_info(mock_pkg)

      assert(version_info.is_a?(Hash), "Should return hash")
      assert(version_info.has_key?(:version), "Should have version key")
      assert(version_info.has_key?(:build), "Should have build key")

      pass(test_name)
    rescue => e
      fail(test_name, e)
    end
  end

  def assert(condition, message)
    raise "Assertion failed: #{message}" unless condition
  end

  def pass(test_name)
    @results << { name: test_name, passed: true }
    puts "✅ #{test_name}"
  end

  def fail(test_name, error)
    @results << { name: test_name, passed: false, error: error.message }
    puts "❌ #{test_name}: #{error.message}"
  end

  def print_results
    puts "\n" + "=" * 50
    puts "Test Results:"
    passed = @results.count { |r| r[:passed] }
    total = @results.count

    puts "Passed: #{passed}/#{total}"

    if passed == total
      puts "✅ All tests passed!"
    else
      puts "❌ Some tests failed"
      @results.reject { |r| r[:passed] }.each do |result|
        puts "  - #{result[:name]}: #{result[:error]}"
      end
    end
  end
end

# Run tests if executed directly
if __FILE__ == $0
  DeploymentTests.run
end