require 'rake/tasklib'
require 'rake/clean'
require 'open3'
require_relative 'helper'

module XCJobs
  module XcodebuildBase
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
    attr_accessor :coverage
    attr_accessor :formatter

    attr_reader :provisioning_profile_name
    attr_reader :provisioning_profile_uuid

    def project
      if @project
        File.extname(@project).empty? ? "#{@project}.xcodeproj" : @project
      end
    end

    def workspace
      if @workspace
        File.extname(@workspace).empty? ? "#{@workspace}.xcworkspace" : @workspace
      end
    end

    def coverage=(coverage)
      @coverage = coverage
      if coverage
        add_build_setting('GCC_INSTRUMENT_PROGRAM_FLOW_ARCS', 'YES')
        add_build_setting('GCC_GENERATE_TEST_COVERAGE_FILES', 'YES')
      else
        @build_settings.delete('GCC_INSTRUMENT_PROGRAM_FLOW_ARCS')
        @build_settings.delete('GCC_GENERATE_TEST_COVERAGE_FILES')
      end
    end

    def coverage_enabled
      @coverage
    end

    def before_action(&block)
      @before_action = block
    end

    def after_action(&block)
      @after_action = block
    end

    def provisioning_profile=(provisioning_profile)
      @provisioning_profile = provisioning_profile
      @provisioning_profile_path, @provisioning_profile_uuid, @provisioning_profile_name = XCJobs::Helper.extract_provisioning_profile(provisioning_profile)
    end

    def destinations
      @destinations ||= []
    end

    def add_destination(destination)
      destinations << destination
    end

    def build_settings
      @build_settings ||= {}
    end

    def add_build_setting(setting, value)
      build_settings[setting] = value
    end

    def run(cmd)
      @before_action.call if @before_action

      if coverage_enabled
        out, status = Open3.capture2(*(cmd + ['-showBuildSettings']))
        configuration_temp_dir = out.lines.grep(/\bCONFIGURATION_TEMP_DIR\b/).first.split('=').last.strip
      end

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
            if coverage_enabled
              XCJobs::Coverage.run_gcov(configuration_temp_dir)
            end

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
            if coverage_enabled
              XCJobs::Coverage.run_gcov(configuration_temp_dir)
            end

            @after_action.call(output, status) if @after_action
          else
            fail "xcodebuild failed (exited with status: #{status.exitstatus})"
          end
        end
      end
    end

    private

    def options
      [].tap do |opts|
        opts.concat(['-project', project]) if project
        opts.concat(['-target', target]) if target
        opts.concat(['-workspace', workspace]) if workspace
        opts.concat(['-scheme', scheme]) if scheme
        opts.concat(['-sdk', sdk]) if sdk
        opts.concat(['-configuration', configuration]) if configuration
        opts.concat(['-derivedDataPath', build_dir]) if build_dir

        destinations.each do |destination|
          opts.concat(['-destination', destination])
        end

        build_settings.each do |setting, value|
          opts << "#{setting}=#{value}"
        end
      end
    end
  end

  module XcodebuildTest
    def sdk
      @sdk || 'iphonesimulator'
    end

    def check_conditions
      raise 'test action requires specifying a scheme' unless scheme
      raise 'cannot specify both a scheme and targets' if scheme && target
    end

    def run
      if sdk == 'iphonesimulator'
        add_build_setting('CODE_SIGN_IDENTITY', '""')
        add_build_setting('CODE_SIGNING_REQUIRED', 'NO')
      end

      add_build_setting('GCC_SYMBOLS_PRIVATE_EXTERN', 'NO')

      super(['xcodebuild', 'test'] + options)
    end
  end

  module XcodebuildBuild
    def check_conditions
      raise 'the scheme is required when specifying build_dir' if build_dir && !scheme
      raise 'cannot specify both a scheme and targets' if scheme && target

      CLEAN.include(build_dir) if build_dir
      CLOBBER.include(build_dir) if build_dir
    end

    def run
      add_build_setting('CONFIGURATION_TEMP_DIR', File.join(build_dir, 'temp')) if build_dir
      add_build_setting('CODE_SIGN_IDENTITY', signing_identity) if signing_identity
      add_build_setting('PROVISIONING_PROFILE', provisioning_profile_uuid) if provisioning_profile_uuid

      super(['xcodebuild', 'build'] + options)
    end
  end

  module XcodebuildArchive
    attr_accessor :archive_path

    def check_conditions
      raise 'archive action requires specifying a scheme' unless scheme
      raise 'cannot specify both a scheme and targets' if scheme && target

      CLEAN.include(build_dir) if build_dir
      CLOBBER.include(build_dir) if build_dir
    end

    def run
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

    private

    def options
      super.tap do |opts|
        opts.concat(['-archivePath', archive_path]) if archive_path
      end
    end
  end

  module XcodebuildExport
    attr_accessor :archive_path
    attr_accessor :export_format
    attr_accessor :export_path
    attr_accessor :export_provisioning_profile
    attr_accessor :export_signing_identity
    attr_accessor :export_installer_identity
    attr_accessor :export_with_original_signing_identity

    def archive_path
      @archive_path || (build_dir && scheme ? File.join(build_dir, scheme) : nil)
    end

    def export_format
      @export_format || 'IPA'
    end

    def export_provisioning_profile=(provisioning_profile)
      provisioning_profile_path, provisioning_profile_uuid, provisioning_profile_name = XCJobs::Helper.extract_provisioning_profile(provisioning_profile)
      if provisioning_profile_name
        @export_provisioning_profile = provisioning_profile_name
      else
        @export_provisioning_profile = provisioning_profile
      end
    end

    def run
      super(['xcodebuild', '-exportArchive'] + options)
    end

    private

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

  class Xcodebuild < Rake::TaskLib
    include XCJobs::XcodebuildBase

    attr_accessor :name
    attr_accessor :description

    def initialize(name, description)
      @name = name
      @description = description
      yield self if block_given?
      define
    end

    private

    def define
      check_conditions if self.class.method_defined?(:check_conditions)
      desc @description
      task @name do
        run
      end
    end
  end

  class Test < Xcodebuild
    include XCJobs::XcodebuildTest

    def initialize(name = :test, description = 'test application')
      super
    end
  end

  class Build < Xcodebuild
    include XCJobs::XcodebuildBuild

    def initialize(name = :build, description = 'build application')
      super
    end
  end

  class Archive < Xcodebuild
    include XCJobs::XcodebuildArchive

    def initialize(name = "build:archive", description = 'make xcarchive')
      super
    end
  end

  class Export < Xcodebuild
    include XCJobs::XcodebuildExport

    def initialize(name = "build:export", description = 'export from an archive')
      super
    end
  end
end
