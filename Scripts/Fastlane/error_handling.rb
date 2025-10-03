# Agiliton Error Handling Module
# Provides comprehensive error handling with retries and logging

module AgilitonErrorHandler
  MAX_RETRIES = 3
  RETRY_DELAY = 5

  class << self
    # Wrap any action with retry logic
    def with_retry(action_name:, max_retries: MAX_RETRIES)
      attempt = 0
      begin
        attempt += 1
        UI.message("Executing #{action_name} (attempt #{attempt}/#{max_retries + 1})")
        yield
      rescue => e
        if attempt <= max_retries && retryable_error?(e)
          UI.error("#{action_name} failed (attempt #{attempt}): #{e.message}")
          UI.message("Retrying in #{RETRY_DELAY} seconds...")
          sleep(RETRY_DELAY)
          retry
        else
          handle_failure(action_name: action_name, error: e, attempt: attempt)
          raise
        end
      end
    end

    # Check if error is retryable
    def retryable_error?(error)
      retryable_patterns = [
        /network/i,
        /timeout/i,
        /connection reset/i,
        /502 Bad Gateway/i,
        /503 Service Unavailable/i,
        /Could not connect/i,
        /SSL_connect/i,
        /ENTITY_ERROR.BUNDLE.IOS_BUNDLE_STATE_MISSING_UPLOAD/i
      ]

      retryable_patterns.any? { |pattern| error.message =~ pattern }
    end

    # Handle non-retryable failures
    def handle_failure(action_name:, error:, attempt:)
      UI.header("Error Analysis for #{action_name}")

      # Log error details
      log_error(action_name: action_name, error: error, attempt: attempt)

      # Provide specific remediation steps
      remediation = get_remediation(error)
      if remediation
        UI.important("Suggested fix:")
        UI.message(remediation)
      end

      # Check for common issues
      check_common_issues(error)
    end

    # Log error details for debugging
    def log_error(action_name:, error:, attempt:)
      log_file = File.expand_path("~/.fastlane/agiliton_errors.log")
      FileUtils.mkdir_p(File.dirname(log_file))

      File.open(log_file, 'a') do |f|
        f.puts "=" * 50
        f.puts "Time: #{Time.now}"
        f.puts "Action: #{action_name}"
        f.puts "Attempt: #{attempt}"
        f.puts "Error: #{error.class} - #{error.message}"
        f.puts "Backtrace:"
        f.puts error.backtrace.first(5).join("\n")
        f.puts
      end

      UI.message("Error logged to: #{log_file}")
    end

    # Get remediation steps for specific errors
    def get_remediation(error)
      case error.message
      when /bundle version must be higher/
        <<~MSG
          1. Check current build number in App Store Connect
          2. Run: fastlane fix_deployment
          3. Or manually increment: agvtool next-version -all
        MSG
      when /Code signing/i, /No signing certificate/i
        <<~MSG
          1. Open Xcode and check signing settings
          2. Run: fastlane match development (if using match)
          3. Verify certificates in Keychain Access
        MSG
      when /No API key/i, /401 Unauthorized/i
        <<~MSG
          1. Verify API key file exists: ~/.fastlane/agiliton/credentials/AuthKey_29D5LPCY4W.p8
          2. Check API key permissions in App Store Connect
          3. Regenerate key if needed
        MSG
      when /artifact not found/i, /No pkg file found/i
        <<~MSG
          1. Check build output directory
          2. Verify Xcode archive succeeded
          3. Run: fastlane build_only (to test build separately)
        MSG
      when /DUPLICATE/i
        "This build was already uploaded. Increment build number and try again."
      when /Apple Generic versioning/i
        <<~MSG
          1. Enable versioning in Xcode: Build Settings -> Versioning -> Current Project Version
          2. Or use Info.plist directly for version management
        MSG
      end
    end

    # Check for common environment issues
    def check_common_issues(error)
      issues = []

      # Check for old pkg files
      old_pkgs = Dir.glob("*.pkg*")
      if old_pkgs.any?
        issues << "Found old pkg files that might interfere: #{old_pkgs.join(', ')}"
      end

      # Check for UTF-8 encoding
      unless ENV['LC_ALL'] == 'en_US.UTF-8'
        issues << "UTF-8 encoding not set. Run: export LC_ALL=en_US.UTF-8"
      end

      # Check for Xcode command line tools
      begin
        Actions.sh("xcode-select -p", log: false)
      rescue
        issues << "Xcode command line tools not configured. Run: sudo xcode-select -s /Applications/Xcode.app"
      end

      if issues.any?
        UI.header("Detected Environmental Issues")
        issues.each { |issue| UI.important("- #{issue}") }
      end
    end

    # Validate inputs before operations
    def validate_inputs(xcodeproj:, scheme:, app_identifier:)
      errors = []

      # Check project exists
      unless File.exist?(xcodeproj)
        errors << "Project file not found: #{xcodeproj}"
      end

      # Check scheme exists
      begin
        schemes = Actions.sh("xcodebuild -list -project '#{xcodeproj}' 2>/dev/null | grep -A 100 'Schemes:' | tail -n +2", log: false).strip.split("\n").map(&:strip)
        unless schemes.include?(scheme)
          errors << "Scheme '#{scheme}' not found. Available schemes: #{schemes.join(', ')}"
        end
      rescue
        errors << "Could not list schemes from #{xcodeproj}"
      end

      # Check app identifier format
      unless app_identifier =~ /^[a-zA-Z0-9.-]+$/
        errors << "Invalid app identifier format: #{app_identifier}"
      end

      if errors.any?
        UI.user_error!(errors.join("\n"))
      end

      true
    end

    # Clean recovery from failed builds
    def clean_failed_build(project_root:)
      UI.header("Cleaning up after failed build")

      # Remove incomplete builds
      FileUtils.rm_rf(File.join(project_root, "build"))
      FileUtils.rm_rf(File.join(project_root, "DerivedData"))

      # Clear any .pkg files in root
      Dir.glob(File.join(project_root, "*.pkg*")).each do |pkg|
        FileUtils.rm_f(pkg)
        UI.message("Removed: #{File.basename(pkg)}")
      end

      UI.success("Cleanup complete")
    end
  end
end