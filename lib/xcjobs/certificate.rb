require 'rake/tasklib'

module XCJobs
  class Certificate < Rake::TaskLib
    include Rake::DSL if defined?(Rake::DSL)

    attr_accessor :keychain_name

    def initialize()
      @certificates = {}
      @profiles = []
      yield self if block_given?
      define
    end

    def keychain_name
      @keychain_name || 'build.keychain'
    end

    def profile_dir
      @profile_dir || '$HOME/Library/MobileDevice/Provisioning Profiles'
    end

    def add_certificate(certificate, passphrase='')
      @certificates[certificate] = passphrase
    end

    def add_profile(profile)
      @profiles << profile
    end

    private

    def define
      namespace :certificates do
        desc 'install certificates'
        task :install do
          sh %[security create-keychain -p "" "#{keychain_name}"]

          @certificates.each do |certificate, passphrase|
            puts %[security import "#{certificate}" -k #{keychain_name} -P "********" -T /usr/bin/codesign]
            out, status = Open3.capture2(*(['security', 'import', "#{certificate}", '-k', "#{keychain_name}", '-P', "#{passphrase}", '-T', '/usr/bin/codesign']))
            if !status.success?
              fail'failed to import keychain'
            end
          end

          sh %[security default-keychain -s "#{keychain_name}"]
        end

        desc 'remove certificates'
        task :remove do
          sh %[security delete-keychain #{keychain_name}]
        end
      end

      namespace :profiles do
        desc 'install provisioning profiles'
        task :install do
          sh %[mkdir -p "#{profile_dir}"]

          @profiles.each do |profile|
            sh %[cp "#{profile}" "#{profile_dir}"]
          end
        end
      end
    end
  end
end
