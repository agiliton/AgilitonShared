#!/usr/bin/env ruby
# Agiliton Shared Xcode Test Configuration Utilities
# Version: 1.0.0
#
# This script provides utilities for configuring Xcode test targets correctly.
# Usage:
#   require_relative 'path/to/test_configuration'
#   TestConfig.fix_all(project_path: 'MyApp.xcodeproj', test_target: 'MyAppTests')

require 'xcodeproj'

module TestConfig
  class << self
    # Fix PRODUCT_NAME for test target
    # Ensures test bundle is named correctly (e.g., "MyAppTests.xctest" instead of ".xctest")
    #
    # @param project [Xcodeproj::Project] Xcode project
    # @param test_target [Xcodeproj::AbstractTarget] Test target
    # @param main_target [Xcodeproj::AbstractTarget] Main app target
    def fix_product_name(project:, test_target:, main_target:)
      puts "Fixing PRODUCT_NAME for #{test_target.name}..."

      main_bundle_id = main_target.build_configurations.first.build_settings['PRODUCT_BUNDLE_IDENTIFIER']

      test_target.build_configurations.each do |config|
        settings = config.build_settings

        # Fix PRODUCT_NAME - use the target name
        settings['PRODUCT_NAME'] = '$(TARGET_NAME)'

        # Fix PRODUCT_BUNDLE_IDENTIFIER
        settings['PRODUCT_BUNDLE_IDENTIFIER'] = "#{main_bundle_id}.#{test_target.name}"

        # Fix TEST_HOST path (use BUILT_PRODUCTS_DIR for proper path resolution)
        app_name = main_target.product_name || main_target.name
        settings['TEST_HOST'] = "$(BUILT_PRODUCTS_DIR)/#{app_name}.app/#{app_name}"
        settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
      end

      puts "✅ PRODUCT_NAME fixed"
    end

    # Fix deployment target for test target to match main app
    # Prevents "compiling for iOS X, but module requires iOS Y" errors
    #
    # @param project [Xcodeproj::Project] Xcode project
    # @param test_target [Xcodeproj::AbstractTarget] Test target
    # @param main_target [Xcodeproj::AbstractTarget] Main app target
    def fix_deployment_target(project:, test_target:, main_target:)
      puts "Fixing deployment target for #{test_target.name}..."

      # Get deployment target from main app
      main_deployment_target = main_target.build_configurations.first.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
      macos_deployment_target = main_target.build_configurations.first.build_settings['MACOSX_DEPLOYMENT_TARGET']

      test_target.build_configurations.each do |config|
        if main_deployment_target
          config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = main_deployment_target
          puts "  Set iOS deployment target to #{main_deployment_target}"
        end

        if macos_deployment_target
          config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = macos_deployment_target
          puts "  Set macOS deployment target to #{macos_deployment_target}"
        end
      end

      puts "✅ Deployment target fixed"
    end

    # Remove files from test target that should only be in main target
    # Prevents "ambiguous use" errors when files are compiled in both targets
    #
    # @param project [Xcodeproj::Project] Xcode project
    # @param test_target [Xcodeproj::AbstractTarget] Test target
    # @param files_to_remove [Array<String>] File names to remove (e.g., ['LoggingService.swift'])
    def remove_duplicate_files(project:, test_target:, files_to_remove:)
      puts "Removing duplicate files from #{test_target.name}..."

      removed_count = 0

      test_target.source_build_phase.files.each do |file|
        if file.file_ref && files_to_remove.include?(file.file_ref.path)
          puts "  Removing #{file.file_ref.path}"
          file.remove_from_project
          removed_count += 1
        end
      end

      if removed_count > 0
        puts "✅ Removed #{removed_count} duplicate file(s)"
      else
        puts "⚠️  No duplicate files found"
      end
    end

    # Ensure test target has proper test host configuration
    # Sets up the relationship between test bundle and app being tested
    #
    # @param project [Xcodeproj::Project] Xcode project
    # @param test_target [Xcodeproj::AbstractTarget] Test target
    # @param main_target [Xcodeproj::AbstractTarget] Main app target
    def fix_test_host(project:, test_target:, main_target:)
      puts "Fixing test host configuration for #{test_target.name}..."

      # Ensure test target depends on main target
      unless test_target.dependencies.any? { |dep| dep.target == main_target }
        test_target.add_dependency(main_target)
        puts "  Added dependency on #{main_target.name}"
      end

      app_name = main_target.product_name || main_target.name

      test_target.build_configurations.each do |config|
        settings = config.build_settings

        # Set TEST_HOST
        settings['TEST_HOST'] = "$(BUILT_PRODUCTS_DIR)/#{app_name}.app/#{app_name}"
        settings['BUNDLE_LOADER'] = '$(TEST_HOST)'

        # Enable code coverage
        settings['CLANG_ENABLE_CODE_COVERAGE'] = 'YES'
      end

      puts "✅ Test host configuration fixed"
    end

    # Fix all common test target issues
    # Convenience method that runs all fixes
    #
    # @param project_path [String] Path to .xcodeproj file
    # @param test_target_name [String] Name of test target (e.g., "MyAppTests")
    # @param main_target_name [String] Name of main app target (optional, auto-detected if not provided)
    # @param files_to_remove [Array<String>] Files to remove from test target (optional)
    def fix_all(project_path:, test_target_name:, main_target_name: nil, files_to_remove: [])
      puts "🔧 Fixing test configuration for #{File.basename(project_path)}..."
      puts ""

      # Open project
      project = Xcodeproj::Project.open(project_path)

      # Find targets
      test_target = project.targets.find { |t| t.name == test_target_name }
      raise "Test target '#{test_target_name}' not found" unless test_target

      # Auto-detect main target if not provided
      if main_target_name.nil?
        # Find the main app target (usually the first non-test target)
        main_target = project.targets.find { |t| !t.name.include?('Test') && t.product_type == 'com.apple.product-type.application' }
        raise "Could not auto-detect main target. Please specify main_target_name parameter." unless main_target
      else
        main_target = project.targets.find { |t| t.name == main_target_name }
        raise "Main target '#{main_target_name}' not found" unless main_target
      end

      puts "Test target: #{test_target.name}"
      puts "Main target: #{main_target.name}"
      puts ""

      # Run all fixes
      fix_product_name(project: project, test_target: test_target, main_target: main_target)
      fix_deployment_target(project: project, test_target: test_target, main_target: main_target)
      fix_test_host(project: project, test_target: test_target, main_target: main_target)

      if files_to_remove.any?
        remove_duplicate_files(project: project, test_target: test_target, files_to_remove: files_to_remove)
      end

      # Save changes
      project.save
      puts ""
      puts "✅ All test configuration fixes applied!"
    end

    # Detect common issues with test configuration
    # Returns array of issue descriptions
    #
    # @param project_path [String] Path to .xcodeproj file
    # @param test_target_name [String] Name of test target
    # @return [Array<String>] List of detected issues
    def detect_issues(project_path:, test_target_name:)
      project = Xcodeproj::Project.open(project_path)
      test_target = project.targets.find { |t| t.name == test_target_name }
      return ["Test target '#{test_target_name}' not found"] unless test_target

      issues = []

      config = test_target.build_configurations.first.build_settings

      # Check PRODUCT_NAME
      if config['PRODUCT_NAME'].nil? || config['PRODUCT_NAME'].empty?
        issues << "PRODUCT_NAME is empty or missing"
      end

      # Check TEST_HOST
      unless config['TEST_HOST']
        issues << "TEST_HOST is not configured"
      end

      # Check deployment target
      unless config['IPHONEOS_DEPLOYMENT_TARGET'] || config['MACOSX_DEPLOYMENT_TARGET']
        issues << "Deployment target not set"
      end

      issues
    end
  end
end

# Command-line interface
if __FILE__ == $0
  require 'optparse'

  options = {
    files_to_remove: []
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: #{File.basename($0)} [options]"
    opts.on("-p", "--project PATH", "Path to .xcodeproj file (required)") { |v| options[:project] = v }
    opts.on("-t", "--test-target NAME", "Test target name (required)") { |v| options[:test_target] = v }
    opts.on("-m", "--main-target NAME", "Main target name (optional, auto-detected)") { |v| options[:main_target] = v }
    opts.on("-r", "--remove FILES", Array, "Files to remove from test target (comma-separated)") { |v| options[:files_to_remove] = v }
    opts.on("-d", "--detect", "Detect issues without fixing") { options[:detect] = true }
    opts.on("-h", "--help", "Show this help") do
      puts opts
      exit
    end
  end.parse!

  unless options[:project] && options[:test_target]
    puts "Error: --project and --test-target are required"
    puts "Run with --help for usage information"
    exit 1
  end

  if options[:detect]
    issues = TestConfig.detect_issues(
      project_path: options[:project],
      test_target_name: options[:test_target]
    )

    if issues.empty?
      puts "✅ No issues detected"
    else
      puts "❌ Found #{issues.count} issue(s):"
      issues.each { |issue| puts "  • #{issue}" }
    end
  else
    TestConfig.fix_all(
      project_path: options[:project],
      test_target_name: options[:test_target],
      main_target_name: options[:main_target],
      files_to_remove: options[:files_to_remove]
    )
  end
end
