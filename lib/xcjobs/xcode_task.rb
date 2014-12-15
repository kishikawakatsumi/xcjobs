require 'rake/task'
require 'rake/clean'
require 'open3'

module XCJobs
  class Task < Rake::Task
    include XCJobs::XcodebuildBase
  end

  class Task::Test < Task
    def sdk
      @sdk || 'iphonesimulator'
    end

    def run
      raise 'test action requires specifying a scheme' unless scheme
      raise 'cannot specify both a scheme and targets' if scheme && target

      if sdk == 'iphonesimulator'
        add_build_setting('CODE_SIGN_IDENTITY', '""')
        add_build_setting('CODE_SIGNING_REQUIRED', 'NO')
        add_build_setting('GCC_SYMBOLS_PRIVATE_EXTERN', 'NO')
      end

      super(['xcodebuild', 'test'] + options)
    end
  end

  class Task::Build < Task
    def run
      raise 'the scheme is required when specifying build_dir' if build_dir && !scheme
      raise 'cannot specify both a scheme and targets' if scheme && target

      CLEAN.include(build_dir) if build_dir
      CLOBBER.include(build_dir) if build_dir

      add_build_setting('CONFIGURATION_TEMP_DIR', File.join(build_dir, 'temp')) if build_dir
      add_build_setting('CODE_SIGN_IDENTITY', signing_identity) if signing_identity
      add_build_setting('PROVISIONING_PROFILE', provisioning_profile_uuid) if provisioning_profile_uuid

      super(['xcodebuild', 'build'] + options)
    end
  end

  class Task::Archive < Task
    attr_accessor :archive_path

    def run
      raise 'archive action requires specifying a scheme' unless scheme
      raise 'cannot specify both a scheme and targets' if scheme && target

      CLEAN.include(build_dir) if build_dir
      CLOBBER.include(build_dir) if build_dir

      add_build_setting('CONFIGURATION_TEMP_DIR', File.join(build_dir, 'temp')) if build_dir
      add_build_setting('CODE_SIGN_IDENTITY', signing_identity) if signing_identity
      add_build_setting('PROVISIONING_PROFILE', provisioning_profile_uuid) if provisioning_profile_uuid

      super(['xcodebuild', 'archive'] + options)

      sh %[(cd "#{build_dir}"; zip -ryq "dSYMs.zip" #{File.join("#{scheme}.xcarchive", "dSYMs")})] if build_dir && scheme
      sh %[(cd "#{build_dir}"; zip -ryq #{scheme}.xcarchive.zip #{scheme}.xcarchive)] if build_dir && scheme
    end

    def archive_path
      @archive_path || (build_dir && scheme ? File.join(build_dir, scheme) : nil)
    end

    def options
      super.tap do |opts|
        opts.concat(['-archivePath', archive_path]) if archive_path
      end
    end
  end

  class Task::Export < Task
    attr_accessor :archive_path
    attr_accessor :export_format
    attr_accessor :export_path
    attr_accessor :export_provisioning_profile
    attr_accessor :export_signing_identity
    attr_accessor :export_installer_identity
    attr_accessor :export_with_original_signing_identity

    def run
      super(['xcodebuild', '-exportArchive'] + options)
    end

    def archive_path
      @archive_path || (build_dir && scheme ? File.join(build_dir, scheme) : nil)
    end

    def export_format
      @export_format || 'IPA'
    end

    def options
      [].tap do |opts|
        opts.concat(['-archivePath', archive_path]) if archive_path
        opts.concat(['-exportFormat', export_format])  if export_format
        opts.concat(['-exportPath', export_path]) if export_path
        opts.concat(['-exportProvisioningProfile', export_provisioning_profile]) if export_provisioning_profile
        opts.concat(['-exportSigningIdentity', export_signing_identity]) if export_signing_identity
        opts.concat(['-exportInstallerIdentity', export_installer_identity]) if export_installer_identity
        opts.concat(['-exportWithOriginalSigningIdentity']) if export_with_original_signing_identity
      end
    end
  end

end

module XCJobs

  private

  module DSL
    def xcode_task(*args, &block)
      XCJobs::Task.define_task(*args, &block)
    end

    def xcode_test(*args, &block)
      XCJobs::Task::Test.define_task(*args, &block)
    end

    def xcode_build(*args, &block)
      XCJobs::Task::Build.define_task(*args, &block)
    end

    def xcode_archive(*args, &block)
      XCJobs::Task::Archive.define_task(*args, &block)
    end

    def xcode_export(*args, &block)
      XCJobs::Task::Export.define_task(*args, &block)
    end
  end
end

self.extend XCJobs::DSL
