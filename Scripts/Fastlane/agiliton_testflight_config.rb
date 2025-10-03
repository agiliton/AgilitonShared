# Agiliton Shared TestFlight Configuration
# Central configuration for all Agiliton macOS apps
# This ensures consistent export compliance and TestFlight uploads

module AgilitonTestFlight
  # Standard export options for all Agiliton macOS apps
  # CRITICAL: ITSAppUsesNonExemptEncryption must be false for our apps
  def self.export_options(team_id: "4S7KX75F3B")
    {
      ITSAppUsesNonExemptEncryption: false,
      manageAppVersionAndBuildNumber: false,
      teamID: team_id,
      method: "app-store"
    }
  end

  # Standard gym (xcodebuild) configuration
  def self.gym_config(
    scheme:,
    output_directory: "./build",
    build_path: "./build",
    derived_data_path: "./DerivedData",
    project: nil,
    workspace: nil,
    installer_cert_name: "3rd Party Mac Developer Installer: Agiliton Ltd. (4S7KX75F3B)"
  )
    config = {
      scheme: scheme,
      export_method: "app-store",
      export_options: export_options,
      configuration: "Release",
      output_directory: output_directory,
      build_path: build_path,
      derived_data_path: derived_data_path,
      installer_cert_name: installer_cert_name,
      destination: "generic/platform=macOS"
    }

    config[:project] = project if project
    config[:workspace] = workspace if workspace

    config
  end

  # Standard upload_to_testflight configuration
  # CRITICAL FIXES:
  # 1. uses_non_exempt_encryption: false - declares no encryption
  # 2. skip_waiting_for_build_processing: false - MUST wait for processing
  # 3. wait_for_uploaded_build: true - ensures compliance is submitted
  def self.upload_config(
    api_key:,
    app_identifier: nil,
    groups: ["Beta Testers"],
    changelog: "Bug fixes and improvements",
    notify_external_testers: true
  )
    config = {
      api_key: api_key,
      uses_non_exempt_encryption: false,  # CRITICAL: No encryption used
      distribute_external: true,
      groups: groups,
      changelog: changelog,
      notify_external_testers: notify_external_testers,
      skip_waiting_for_build_processing: false,  # CRITICAL: Must wait to submit compliance
      wait_for_uploaded_build: true,  # CRITICAL: Ensures compliance submitted
      distribute_only: false
    }

    config[:app_identifier] = app_identifier if app_identifier

    config
  end

  # Complete TestFlight deployment lane for Xcode projects
  def self.deploy_testflight(
    api_key:,
    scheme:,
    app_identifier: nil,
    project: nil,
    workspace: nil,
    xcodeproj_for_build_increment: nil,
    groups: ["Beta Testers"],
    changelog: "Bug fixes and improvements",
    notify_external_testers: true
  )
    # Increment build number if xcodeproj provided
    if xcodeproj_for_build_increment
      increment_build_number(xcodeproj: xcodeproj_for_build_increment)
    end

    # Build the app
    gym_options = gym_config(
      scheme: scheme,
      project: project,
      workspace: workspace
    )
    gym(gym_options)

    # Upload to TestFlight with proper export compliance
    upload_options = upload_config(
      api_key: api_key,
      app_identifier: app_identifier,
      groups: groups,
      changelog: changelog,
      notify_external_testers: notify_external_testers
    )
    upload_to_testflight(upload_options)
  end
end

# Make available for import
def agiliton_testflight_export_options(team_id: "4S7KX75F3B")
  AgilitonTestFlight.export_options(team_id: team_id)
end

def agiliton_testflight_gym_config(**options)
  AgilitonTestFlight.gym_config(**options)
end

def agiliton_testflight_upload_config(**options)
  AgilitonTestFlight.upload_config(**options)
end

def agiliton_deploy_testflight(**options)
  AgilitonTestFlight.deploy_testflight(**options)
end
