require 'rake/tasklib'
require 'rake/clean'
require 'open3'
require 'shellwords'
require 'securerandom'
require_relative 'helper'

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
    attr_accessor :coverage
    attr_accessor :formatter

    attr_reader :destinations
    attr_reader :provisioning_profile_name
    attr_reader :provisioning_profile_uuid

    def initialize(name)
      $stdout.sync = $stderr.sync = true
      
      @name = name
      @destinations = []
      @build_settings = {}
    end

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

      env = {}
      options = { unsetenv_others: true }

      if @formatter
        Open3.pipeline_r([env] + cmd + [options], [@formatter]) do |stdout, wait_thrs|
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
        Open3.popen2e(env, *cmd, options) do |stdin, stdout_err, wait_thr|
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
        opts.concat(['-enableCodeCoverage', 'YES']) if coverage_enabled
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
    
    def show_coverage(profdata_path, target_path)
      cmd = ['xcrun', 'llvm-cov', 'report']
      opts = ['-instr-profile', profdata_path, target_path, '-use-color=0']
      puts (cmd + opts).join(" ")
      out, status = Open3.capture2(*(cmd + opts))
      out.lines.each do |line|
        puts line
      end
    end
    
    def generate_gcov_file(profdata_path, target_path)
      puts 'Generage gcov file...'
      gcov_file = {}
      source_path = ''
      
      cmd = ['xcrun', 'llvm-cov', 'show']
      opts = ['-instr-profile', profdata_path, target_path, '-use-color=0']
      
      out, status = Open3.capture2(*(cmd + opts))
      out.lines.each do |line|
        match = /^(['"]?(?:\/[^\/]+)*['"]?):$/.match(line)
        if match.to_a.count > 0
          source_path = match.to_a[1]
          gcov_file[source_path] = []
          next
        end
        
        match = /^[ ]*([0-9]+|[ ]+)\|[ ]*([0-9]+)\|(.*)$/.match(line)
        next unless match.to_a.count == 4
        count, number, text = match.to_a[1..3]
        
        execution_count = case count.strip
            when ''
              '-'.rjust(5)
            when '0'
              '#####'
            else count
            end
        gcov_file[source_path] << "#{execution_count.rjust(5)}:#{number.rjust(5)}:#{text}"
      end
      
      gcov_file.each do |key, value|
        gcon_path = File.join(File.dirname(profdata_path), "#{SecureRandom.urlsafe_base64(6)}-#{File.basename(target_path)}.gcov")
        file = File::open(gcon_path, "w")
        file.puts("#{'-'.rjust(5)}:#{'0'.rjust(5)}:Source:#{key}")
        file.puts(value)
        file.flush
      end
    end
    
    def coverage_report(options)
      settings = build_settings(options)
      
      targetSettings = settings.select { |key, _| settings[key]['PRODUCT_TYPE'] != 'com.apple.product-type.bundle.unit-test' }
      targetSettings.each do |target, settings|
        if settings['PRODUCT_TYPE'] == 'com.apple.product-type.framework'
          if sdk.start_with?('iphone') && settings['ONLY_ACTIVE_ARCH'] == 'NO'
            target_dir = settings['OBJECT_FILE_DIR_normal'].gsub('Build/Intermediates', "Build/Intermediates/CodeCoverage/#{target}/Intermediates")
            executable_name = settings['EXECUTABLE_NAME']
            target_path = File.join(File.join(target_dir, settings['CURRENT_ARCH']), executable_name)
          else
            target_dir = settings['CODESIGNING_FOLDER_PATH'].gsub('Build/Products', "Build/Intermediates/CodeCoverage/#{target}/Products")
            executable_name = settings['EXECUTABLE_NAME']
            target_path = File.join(target_dir, executable_name)
          end
        else
          
        end
        
        code_coverage_dir = settings['BUILD_DIR'].gsub('Build/Products', "Build/Intermediates/CodeCoverage/#{target}/")
        profdata_path = File.join(code_coverage_dir, 'Coverage.profdata')
        
        show_coverage(profdata_path, target_path)
        generate_gcov_file(profdata_path, target_path)
      end
    end
    
    def build_settings(options)
      out, status = Open3.capture2(*(['xcodebuild', 'test'] + options + ['-showBuildSettings']))
      
      settings, target = {}, nil
      out.lines.each do |line|
        case line
        when /Build settings for action test and target (.+):/
          target = $1
          settings[target] = {}
        else
          key, value = line.split(/\=/).collect(&:strip)
          settings[target][key] = value if target
        end
      end
      return settings
    end

    def define
      raise 'test action requires specifying a scheme' unless scheme
      raise 'cannot specify both a scheme and targets' if scheme && target

      desc 'test application'
      task @name do
        if sdk == 'iphonesimulator'
          add_build_setting('CODE_SIGN_IDENTITY', '""')
          add_build_setting('CODE_SIGNING_REQUIRED', 'NO')
        end
        
        add_build_setting('GCC_SYMBOLS_PRIVATE_EXTERN', 'NO')

        run(['xcodebuild', 'test'] + options)
        
        if coverage_enabled
          coverage_report(options)
        end
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

      CLEAN.include(build_dir) if build_dir
      CLOBBER.include(build_dir) if build_dir

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
    attr_accessor :archive_path

    def initialize(name = :archive)
      super
      yield self if block_given?
      define
    end

    private

    def define
      raise 'archive action requires specifying a scheme' unless scheme
      raise 'cannot specify both a scheme and targets' if scheme && target

      if build_dir
        CLEAN.include(build_dir)
        CLOBBER.include(build_dir)
      end

      desc 'make xcarchive'
      namespace :build do
        task @name do
          add_build_setting('CONFIGURATION_TEMP_DIR', File.join(build_dir, 'temp')) if build_dir
          add_build_setting('CODE_SIGN_IDENTITY', signing_identity) if signing_identity
          add_build_setting('PROVISIONING_PROFILE', provisioning_profile_uuid) if provisioning_profile_uuid

          run(['xcodebuild', 'archive'] + options)

          if build_dir && scheme
            bd = build_dir.shellescape
            s = scheme.shellescape
            sh %[(cd #{bd}; zip -ryq dSYMs.zip #{File.join("#{s}.xcarchive", "dSYMs")})]
            sh %[(cd #{bd}; zip -ryq #{s}.xcarchive.zip #{s}.xcarchive)]
          end
        end
      end
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

  class Export < Xcodebuild
    attr_accessor :archive_path
    attr_accessor :export_format
    attr_accessor :export_path
    attr_accessor :export_provisioning_profile
    attr_accessor :export_signing_identity
    attr_accessor :export_installer_identity
    attr_accessor :export_with_original_signing_identity

    def initialize(name = :export)
      super
      yield self if block_given?
      define
    end

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

    private

    def define
      desc 'export from an archive'
      namespace :build do
        task name do
          run(['xcodebuild', '-exportArchive'] + options)
        end
      end
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
