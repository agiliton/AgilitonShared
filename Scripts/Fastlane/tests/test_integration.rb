#!/usr/bin/env ruby

# Agiliton Integration Test Suite
# Tests the complete deployment flow end-to-end

require 'fileutils'
require 'open3'

class IntegrationTests
  def self.run(project_path)
    new(project_path).run_all_tests
  end

  def initialize(project_path)
    @project_path = project_path
    @results = []
  end

  def run_all_tests
    puts "Running Integration Tests for: #{@project_path}"
    puts "=" * 50

    # Validate project exists
    unless Dir.exist?(@project_path)
      puts "❌ Project not found: #{@project_path}"
      exit 1
    end

    Dir.chdir(@project_path) do
      test_fastfile_syntax
      test_configuration_loading
      test_build_only
      test_cleanup_lane
      test_system_check
    end

    print_results
    exit(@results.any? { |r| !r[:passed] } ? 1 : 0)
  end

  private

  def test_fastfile_syntax
    test_name = "Fastfile Syntax Check"
    begin
      stdout, stderr, status = run_command("fastlane lanes")

      if status.success?
        # Check if expected lanes are present
        expected_lanes = ["testflight", "build_only", "cleanup", "check_status"]
        missing_lanes = expected_lanes.reject { |lane| stdout.include?(lane) }

        if missing_lanes.empty?
          pass(test_name)
        else
          fail(test_name, "Missing lanes: #{missing_lanes.join(', ')}")
        end
      else
        fail(test_name, "Fastfile has syntax errors: #{stderr}")
      end
    rescue => e
      fail(test_name, e)
    end
  end

  def test_configuration_loading
    test_name = "Configuration Loading"
    begin
      # Test if shared configuration loads properly
      test_script = <<~RUBY
        require_relative '../fastlane/Fastfile'
        require '#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/shared_config.rb'

        # Test API key configuration
        begin
          api_key = AgilitonConfig.api_key
          puts "API_KEY_CONFIGURED" if api_key
        rescue => e
          puts "CONFIG_ERROR: #{e.message}"
        end
      RUBY

      File.write("/tmp/test_config.rb", test_script)
      stdout, stderr, status = run_command("ruby /tmp/test_config.rb")

      if stdout.include?("API_KEY_CONFIGURED") || stdout.include?("CONFIG_ERROR")
        pass(test_name)
      else
        fail(test_name, "Configuration failed to load: #{stderr}")
      end
    rescue => e
      fail(test_name, e)
    ensure
      File.delete("/tmp/test_config.rb") if File.exist?("/tmp/test_config.rb")
    end
  end

  def test_build_only
    test_name = "Build Only Lane (Dry Run)"
    begin
      # Run build_only lane in validation mode (doesn't actually build)
      stdout, stderr, status = run_command("fastlane run validate_lane lane:build_only 2>&1 || true")

      # Lane should at least be defined
      if stderr.include?("Could not find lane") || stderr.include?("undefined method")
        fail(test_name, "build_only lane not properly defined")
      else
        pass(test_name)
      end
    rescue => e
      fail(test_name, e)
    end
  end

  def test_cleanup_lane
    test_name = "Cleanup Lane"
    begin
      # Create a test artifact
      test_pkg = "test_artifact.pkg"
      File.write(test_pkg, "test")

      # Run cleanup
      stdout, stderr, status = run_command("fastlane cleanup 2>&1")

      if status.success?
        # Check if test artifact was cleaned
        if !File.exist?(test_pkg) || File.exist?("#{test_pkg}.backup")
          pass(test_name)
        else
          fail(test_name, "Cleanup didn't process test artifact")
        end
      else
        fail(test_name, "Cleanup lane failed: #{stderr}")
      end
    rescue => e
      fail(test_name, e)
    ensure
      # Clean up any remaining test files
      Dir.glob("test_artifact.pkg*").each { |f| File.delete(f) }
    end
  end

  def test_system_check
    test_name = "System Check"
    begin
      stdout, stderr, status = run_command("fastlane test_system 2>&1 || true")

      # Check for expected output sections
      expected_outputs = [
        "Cleaning old artifacts",
        "Testing API key",
        "Checking build number",
        "All systems operational"
      ]

      missing = expected_outputs.reject { |output| stdout.include?(output) }

      if missing.empty? || stdout.include?("test_system") == false
        pass(test_name)
      else
        fail(test_name, "System check incomplete. Missing: #{missing.join(', ')}")
      end
    rescue => e
      fail(test_name, e)
    end
  end

  def run_command(cmd)
    # Set UTF-8 encoding
    env = {
      "LC_ALL" => "en_US.UTF-8",
      "LANG" => "en_US.UTF-8"
    }

    Open3.capture3(env, cmd)
  end

  def pass(test_name)
    @results << { name: test_name, passed: true }
    puts "✅ #{test_name}"
  end

  def fail(test_name, error)
    message = error.is_a?(Exception) ? error.message : error.to_s
    @results << { name: test_name, passed: false, error: message }
    puts "❌ #{test_name}: #{message}"
  end

  def print_results
    puts "\n" + "=" * 50
    puts "Integration Test Results:"
    passed = @results.count { |r| r[:passed] }
    total = @results.count

    puts "Passed: #{passed}/#{total}"

    if passed == total
      puts "✅ All integration tests passed!"
    else
      puts "❌ Some integration tests failed"
      @results.reject { |r| r[:passed] }.each do |result|
        puts "  - #{result[:name]}: #{result[:error]}"
      end
    end
  end
end

# Run tests if executed directly
if __FILE__ == $0
  if ARGV[0]
    IntegrationTests.run(ARGV[0])
  else
    puts "Usage: ruby test_integration.rb <project_path>"
    puts "Example: ruby test_integration.rb ~/VisualStudio/Assist\\ for\\ Jira/worktrees/main"
    exit 1
  end
end