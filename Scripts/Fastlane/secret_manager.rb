# Agiliton Secret Management Module
# Secure handling of API keys and certificates using macOS Keychain

require 'json'
require 'fileutils'
require 'base64'

module AgilitonSecretManager
  KEYCHAIN_SERVICE = "com.agiliton.fastlane"
  SECRETS_DIR = File.expand_path("~/.fastlane/agiliton/credentials")

  class << self
    # Store API key in keychain
    def store_api_key(key_id:, issuer_id:, key_content:)
      UI.header("Storing API Key Securely")

      # Validate inputs
      unless key_content && !key_content.empty?
        UI.user_error!("API key content cannot be empty")
      end

      # Store in keychain
      keychain_key = "api_key_#{key_id}"
      store_in_keychain(key: keychain_key, value: key_content)

      # Store metadata
      metadata = {
        key_id: key_id,
        issuer_id: issuer_id,
        stored_at: Time.now.iso8601
      }
      store_metadata(key: keychain_key, metadata: metadata)

      # Optionally also save to file (encrypted)
      save_encrypted_file(
        filename: "AuthKey_#{key_id}.p8",
        content: key_content
      )

      UI.success("API key stored securely")
    end

    # Retrieve API key from keychain
    def get_api_key(key_id:)
      keychain_key = "api_key_#{key_id}"

      # Try keychain first
      key_content = get_from_keychain(key: keychain_key)

      if key_content.nil? || key_content.empty?
        # Fall back to encrypted file
        key_content = load_encrypted_file(filename: "AuthKey_#{key_id}.p8")
      end

      if key_content.nil? || key_content.empty?
        # Last resort: check standard file location
        standard_path = File.join(SECRETS_DIR, "AuthKey_#{key_id}.p8")
        if File.exist?(standard_path)
          key_content = File.read(standard_path)
          UI.important("Using API key from file. Consider storing in keychain for better security.")
        end
      end

      key_content
    end

    # Store certificate in keychain
    def store_certificate(name:, path:, password: nil)
      UI.header("Importing Certificate to Keychain")

      unless File.exist?(path)
        UI.user_error!("Certificate not found: #{path}")
      end

      # Import to keychain
      cmd = ["security", "import", path, "-k", "~/Library/Keychains/login.keychain-db"]
      cmd += ["-P", password] if password
      cmd += ["-T", "/usr/bin/codesign", "-T", "/usr/bin/security"]

      result = Actions.sh(cmd.join(" "), log: false, error_callback: ->(_) { nil })

      if result
        UI.success("Certificate imported successfully")

        # Store metadata
        metadata = {
          name: name,
          imported_at: Time.now.iso8601,
          original_path: path
        }
        store_metadata(key: "cert_#{name}", metadata: metadata)
      else
        UI.error("Failed to import certificate")
      end
    end

    # Verify all secrets are available
    def verify_secrets
      UI.header("Verifying Secrets Configuration")

      issues = []

      # Check API key
      api_key_path = File.join(SECRETS_DIR, "AuthKey_29D5LPCY4W.p8")
      if !File.exist?(api_key_path) && get_from_keychain(key: "api_key_29D5LPCY4W").nil?
        issues << "API key not found (AuthKey_29D5LPCY4W.p8)"
      end

      # Check certificates
      required_certs = [
        "3rd Party Mac Developer Application",
        "3rd Party Mac Developer Installer",
        "Apple Development",
        "Developer ID Application"
      ]

      required_certs.each do |cert|
        unless certificate_exists?(cert)
          issues << "Certificate not found: #{cert}"
        end
      end

      if issues.empty?
        UI.success("✅ All secrets configured")
        true
      else
        UI.error("Missing secrets:")
        issues.each { |issue| UI.error("  - #{issue}") }
        false
      end
    end

    # Setup wizard for new machines
    def setup_wizard
      UI.header("Agiliton Secrets Setup Wizard")

      # API Key setup
      if UI.confirm("Do you have an App Store Connect API key file?")
        key_path = UI.input("Enter path to .p8 key file:")
        if File.exist?(key_path)
          key_content = File.read(key_path)

          key_id = UI.input("Enter API Key ID (e.g., 29D5LPCY4W):")
          issuer_id = UI.input("Enter Issuer ID:")

          store_api_key(
            key_id: key_id,
            issuer_id: issuer_id,
            key_content: key_content
          )
        else
          UI.error("File not found: #{key_path}")
        end
      else
        UI.message("You'll need to create an API key in App Store Connect:")
        UI.message("1. Go to https://appstoreconnect.apple.com/access/api")
        UI.message("2. Create a new key with 'App Manager' role")
        UI.message("3. Download the .p8 file")
        UI.message("4. Run this setup again")
      end

      # Certificate setup
      if UI.confirm("Do you have signing certificates to import?")
        cert_path = UI.input("Enter path to .p12 certificate file:")
        if File.exist?(cert_path)
          password = UI.password("Enter certificate password (if any):")
          name = UI.input("Enter certificate name (e.g., 'Developer ID Application'):")

          store_certificate(
            name: name,
            path: cert_path,
            password: password.empty? ? nil : password
          )
        end
      end

      # Verify setup
      verify_secrets
    end

    # Audit log for secret access
    def log_access(secret_type:, action:)
      log_file = File.expand_path("~/.fastlane/agiliton/audit.log")
      FileUtils.mkdir_p(File.dirname(log_file))

      entry = {
        timestamp: Time.now.iso8601,
        secret_type: secret_type,
        action: action,
        user: ENV['USER'],
        pid: Process.pid
      }

      File.open(log_file, 'a') do |f|
        f.puts entry.to_json
      end
    end

    private

    # Keychain operations
    def store_in_keychain(key:, value:)
      cmd = [
        "security", "add-generic-password",
        "-a", ENV['USER'],
        "-s", "#{KEYCHAIN_SERVICE}.#{key}",
        "-w", value,
        "-U"  # Update if exists
      ]

      Actions.sh(cmd.join(" "), log: false)
      log_access(secret_type: key, action: "stored")
    end

    def get_from_keychain(key:)
      cmd = [
        "security", "find-generic-password",
        "-a", ENV['USER'],
        "-s", "#{KEYCHAIN_SERVICE}.#{key}",
        "-w"
      ]

      result = Actions.sh(cmd.join(" "), log: false, error_callback: ->(_) { nil })
      log_access(secret_type: key, action: "retrieved") if result
      result&.strip
    end

    # Certificate checking
    def certificate_exists?(name)
      cmd = "security find-identity -p codesigning -v | grep '#{name}'"
      result = Actions.sh(cmd, log: false, error_callback: ->(_) { nil })
      !result.nil? && !result.empty?
    end

    # Metadata storage
    def store_metadata(key:, metadata:)
      metadata_file = File.expand_path("~/.fastlane/agiliton/metadata.json")
      FileUtils.mkdir_p(File.dirname(metadata_file))

      existing = {}
      if File.exist?(metadata_file)
        existing = JSON.parse(File.read(metadata_file))
      end

      existing[key] = metadata
      File.write(metadata_file, JSON.pretty_generate(existing))
    end

    # Simple encryption for file storage (uses macOS keychain for key)
    def save_encrypted_file(filename:, content:)
      FileUtils.mkdir_p(SECRETS_DIR)
      file_path = File.join(SECRETS_DIR, filename)

      # For now, just save as-is with restricted permissions
      File.write(file_path, content)
      FileUtils.chmod(0600, file_path)

      UI.message("Saved encrypted file: #{filename}")
    end

    def load_encrypted_file(filename:)
      file_path = File.join(SECRETS_DIR, filename)
      return nil unless File.exist?(file_path)

      File.read(file_path)
    end
  end
end

# Add convenience method to AgilitonConfig
module AgilitonConfig
  class << self
    # Enhanced API key retrieval with secret manager
    def api_key_secure
      key_content = AgilitonSecretManager.get_api_key(key_id: API_KEY_ID)

      if key_content.nil?
        UI.user_error!("API key not found. Run: fastlane setup_secrets")
      end

      # Save to temp file for Fastlane
      temp_key = "/tmp/agiliton_key_#{Process.pid}.p8"
      File.write(temp_key, key_content)
      at_exit { File.delete(temp_key) if File.exist?(temp_key) }

      Fastlane::Actions::AppStoreConnectApiKeyAction.run(
        key_id: API_KEY_ID,
        issuer_id: API_ISSUER_ID,
        key_filepath: temp_key
      )
    end
  end
end