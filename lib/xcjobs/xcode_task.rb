require 'rake/task'
require 'rake/clean'
require 'open3'

module XCJobs
  class Task < Rake::Task
    include Rake::DSL if defined?(Rake::DSL)
    
    attr_accessor :project
    attr_accessor :target
    attr_accessor :workspace
    attr_accessor :scheme
    attr_accessor :sdk
    attr_accessor :configuration
    attr_accessor :signing_identity
    attr_accessor :provisioning_profile
    attr_accessor :build_dir
    attr_accessor :formatter

    attr_reader :destinations
    attr_reader :provisioning_profile_name
    attr_reader :provisioning_profile_uuid

    def initialize(*args, &block)
      super(*args, &block)
      @destinations = []
      @build_settings = {}
    end

    def before_action(&block)
      @before_action = block
    end

    def after_action(&block)
      @after_action = block
    end

    def provisioning_profile=(provisioning_profile)
      @provisioning_profile = provisioning_profile

      if File.file?(provisioning_profile)
        @provisioning_profile_path = provisioning_profile
      else
        path = File.join("#{Dir.home}/Library/MobileDevice/Provisioning Profiles/", provisioning_profile)
        if File.file?(path)
          @provisioning_profile_path = path
        end
      end
      if @provisioning_profile_path
        out, status = Open3.capture2 %[/usr/libexec/PlistBuddy -c Print:UUID /dev/stdin <<< $(security cms -D -i "#{@provisioning_profile_path}")]
        @provisioning_profile_uuid = out.strip if status.success?

        out, status = Open3.capture2 %[/usr/libexec/PlistBuddy -c Print:Name /dev/stdin <<< $(security cms -D -i "#{@provisioning_profile_path}")]
        @provisioning_profile_name = out.strip if status.success?
      else
        @provisioning_profile_name = provisioning_profile
      end
    end

    def add_destination(destination)
      @destinations << destination
    end

    def add_build_setting(setting, value)
      @build_settings[setting] = value
    end

    private

    def run(cmd)
      @before_action.call if @before_action

      if @formatter
        puts (cmd + ['|', @formatter]).join(" ")
      else
        puts cmd.join(" ")
      end

      if @formatter
        Open3.pipeline_r(cmd, [@formatter]) do |stdout, wait_thrs|
          output = []
          while line = stdout.gets
            puts line
            output << line
          end

          status = wait_thrs.first.value
          if status.success?
            @after_action.call(output, status) if @after_action
          else
            fail "xcodebuild failed (exited with status: #{status.exitstatus})"
          end
        end
      else
        Open3.popen2e(*cmd) do |stdin, stdout_err, wait_thr|
          output = []
          while line = stdout_err.gets
            puts line
            output << line
          end

          status = wait_thr.value
          if status.success?
            @after_action.call(output, status) if @after_action
          else
            fail "xcodebuild failed (exited with status: #{status.exitstatus})"
          end
        end
      end
    end

    def options
      [].tap do |opts|
        opts.concat(['-project', project]) if project
        opts.concat(['-target', target]) if target
        opts.concat(['-workspace', workspace]) if workspace
        opts.concat(['-scheme', scheme]) if scheme
        opts.concat(['-sdk', sdk]) if sdk
        opts.concat(['-configuration', configuration]) if configuration
        opts.concat(['-derivedDataPath', build_dir]) if build_dir

        @destinations.each do |destination|
          opts.concat(['-destination', destination])
        end

        @build_settings.each do |setting, value|
          opts << "#{setting}=#{value}"
        end
      end
    end
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
