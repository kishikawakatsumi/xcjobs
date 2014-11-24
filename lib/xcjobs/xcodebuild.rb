require 'rake/tasklib'
require 'rake/clean'

module XCJobs
  class Xcodebuild < Rake::TaskLib
    include Rake::DSL if defined?(Rake::DSL)

    attr_accessor :name
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

    def initialize(name)
      @name = name
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

      puts cmd.join(" ")

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

  class Test < Xcodebuild
    def initialize(name = :test)
      super
      yield self if block_given?
      define
    end

    def sdk
      @sdk || 'iphonesimulator'
    end

    private

    def define
      raise 'test action requires specifying a scheme' unless scheme
      raise 'cannot specify both a scheme and targets' if scheme && target

      desc 'test application'
      task @name do
        if sdk == 'iphonesimulator'
          add_build_setting('CODE_SIGN_IDENTITY', '""')
          add_build_setting('CODE_SIGNING_REQUIRED', 'NO')
          add_build_setting('GCC_SYMBOLS_PRIVATE_EXTERN', 'NO')
        end

        run(['xcodebuild', 'test'] + options)
      end
    end
  end

  class Build < Xcodebuild
    def initialize(name = :build)
      super
      yield self if block_given?
      define
    end

    private

    def define
      raise 'the scheme is required when specifying build_dir' if build_dir && !scheme
      raise 'cannot specify both a scheme and targets' if scheme && target

      CLEAN.include(build_dir)
      CLOBBER.include(build_dir)

      desc 'build application'
      task @name do
        add_build_setting('CONFIGURATION_TEMP_DIR', File.join(build_dir, 'temp')) if build_dir
        add_build_setting('CODE_SIGN_IDENTITY', signing_identity) if signing_identity
        add_build_setting('PROVISIONING_PROFILE', provisioning_profile_uuid) if provisioning_profile_uuid

        run(['xcodebuild', 'build'] + options)
      end
    end
  end

  class Archive < Xcodebuild
    attr_accessor :archivePath

    def initialize(name = :archive)
      super
      yield self if block_given?
      define
    end

    private

    def define
      raise 'archive action requires specifying a scheme' unless scheme
      raise 'cannot specify both a scheme and targets' if scheme && target

      CLEAN.include(build_dir)
      CLOBBER.include(build_dir)

      desc 'make xcarchive'
      namespace :build do
        task @name do
          add_build_setting('CONFIGURATION_TEMP_DIR', File.join(build_dir, 'temp')) if build_dir
          add_build_setting('CODE_SIGN_IDENTITY', signing_identity) if signing_identity
          add_build_setting('PROVISIONING_PROFILE', provisioning_profile_uuid) if provisioning_profile_uuid

          run(['xcodebuild', 'archive'] + options)

          sh %[(cd "#{build_dir}"; zip -ryq "dSYMs.zip" #{File.join("#{scheme}.xcarchive", "dSYMs")})] if build_dir && scheme
          sh %[(cd "#{build_dir}"; zip -ryq #{scheme}.xcarchive.zip #{scheme}.xcarchive)] if build_dir && scheme
        end
      end
    end

    def archivePath
      @archivePath || (build_dir && scheme ? File.join(build_dir, scheme) : nil)
    end

    def options
      super.tap do |opts|
        opts.concat(['-archivePath', archivePath]) if archivePath
      end
    end
  end

  class Export < Xcodebuild
    attr_accessor :archivePath
    attr_accessor :exportFormat
    attr_accessor :exportPath
    attr_accessor :exportProvisioningProfile
    attr_accessor :exportSigningIdentity
    attr_accessor :exportInstallerIdentity
    attr_accessor :exportWithOriginalSigningIdentity

    def initialize(name = :export)
      super
      yield self if block_given?
      define
    end

    private

    def define
      desc 'export from an archive'
      namespace :build do
        task name do
          run(['xcodebuild', '-exportArchive'] + options)
        end
      end
    end

    def archivePath
      @archivePath || (build_dir && scheme ? File.join(build_dir, scheme) : nil)
    end

    def exportFormat
      @exportFormat || 'IPA'
    end

    def options
      [].tap do |opts|
        opts.concat(['-archivePath', archivePath]) if archivePath
        opts.concat(['-exportFormat', exportFormat])  if exportFormat
        opts.concat(['-exportPath', exportPath]) if exportPath
        opts.concat(['-exportProvisioningProfile', exportProvisioningProfile]) if exportProvisioningProfile
        opts.concat(['-exportSigningIdentity', exportSigningIdentity]) if exportSigningIdentity
        opts.concat(['-exportInstallerIdentity', exportInstallerIdentity]) if exportInstallerIdentity
        opts.concat(['-exportWithOriginalSigningIdentity']) if exportWithOriginalSigningIdentity
      end
    end
  end
end
