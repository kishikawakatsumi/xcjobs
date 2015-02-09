require 'rake/tasklib'
require 'open3'

module XCJobs
  module Distribute
    def upload(url, form_data = {})
      @before_action.call if @before_action

      curl_options = ['curl', '-sSf', "#{url}"]
      form_fields = form_data.flat_map { |k, v| ['-F', "#{k}=#{v}"] }
      puts (curl_options + form_fields).join(' ')
      Open3.popen2e(*(curl_options + form_fields)) do |stdin, stdout_err, wait_thr|
        output = ''
        while line = stdout_err.gets
          puts line
          output << line
        end

        status = wait_thr.value
        if status.success?
          @after_action.call(output, status) if @after_action
        else
          fail "upload failed (exited with status: #{status.exitstatus})"
        end
      end
    end

    def before_action(&block)
      @before_action = block
    end

    def after_action(&block)
      @after_action = block
    end

    class TestFlight < Rake::TaskLib
      include Rake::DSL if defined?(Rake::DSL)
      include Distribute

      attr_accessor :file
      attr_accessor :api_token
      attr_accessor :team_token
      attr_accessor :notify
      attr_accessor :replace
      attr_accessor :distribution_lists
      attr_accessor :notes

      def initialize()
        yield self if block_given?
        define
      end

      private

      def define
        namespace :distribute do
          desc 'upload IPA to TestFlight'
          task :testflight do
            upload('http://testflightapp.com/api/builds.json', form_data)
          end
        end
      end

      def form_data
        {}.tap do |fields|
          fields[:file] = "@#{file}" if file
          fields[:api_token] = api_token if api_token
          fields[:team_token] = team_token if team_token
          fields[:notify] = notify if notify
          fields[:replace] = replace if replace
          fields[:distribution_lists] = distribution_lists if distribution_lists
          fields[:notes] = notes if notes
        end
      end
    end

    class DeployGate < Rake::TaskLib
      include Rake::DSL if defined?(Rake::DSL)
      include Distribute

      attr_accessor :owner_name

      attr_accessor :token
      attr_accessor :file
      attr_accessor :message
      attr_accessor :distribution_key
      attr_accessor :release_note
      attr_accessor :disable_notify
      attr_accessor :visibility

      def initialize()
        yield self if block_given?
        define
      end

      private

      def define
        namespace :distribute do
          desc 'upload IPA to DeployGate'
          task :deploygate do
            upload("https://deploygate.com/api/users/#{owner_name}/apps", form_data)
          end
        end
      end

      def form_data
        {}.tap do |fields|
          fields[:token] = token if token
            fields[:file] = "@#{file}" if file
          fields[:message] = message if message
          fields[:distribution_key] = distribution_key if distribution_key
          fields[:release_note] = release_note if release_note
          fields[:disable_notify] = 'yes' if disable_notify
          fields[:visibility] = visibility if visibility
        end
      end
    end

    class Crittercism < Rake::TaskLib
      include Rake::DSL if defined?(Rake::DSL)
      include Distribute

      attr_accessor :app_id
      attr_accessor :dsym
      attr_accessor :key

      def initialize(name=:export)
        yield self if block_given?
        define
      end

      private

      def define
        namespace :distribute do
          desc 'upload dSYMs to Crittercism'
          task :crittercism do
            upload("https://api.crittercism.com/api_beta/dsym/#{app_id}", form_data)
          end
        end
      end

      def form_data
        {}.tap do |fields|
          fields[:dsym] = "@#{dsym}" if dsym
          fields[:key] = key if key
        end
      end
    end

    class ITC < Rake::TaskLib
      include Rake::DSL if defined?(Rake::DSL)
      include Distribute

      attr_accessor :file
      attr_accessor :username
      attr_accessor :password
      attr_accessor :altool

      def initialize(name=:export)
        yield self if block_given?
        define
      end

      def altool
        @altool || '/Applications/Xcode.app/Contents/Applications/Application Loader.app/Contents/Frameworks/ITunesSoftwareService.framework/Support/altool'
      end

      private

      def define
        namespace :distribute do
          desc 'upload ipa to iTunes Connect'
          task :itc do
            sh %["#{altool}" --upload-app --file "#{file}" --username #{username} --password #{password}]
          end
        end
      end
    end
  end
end
