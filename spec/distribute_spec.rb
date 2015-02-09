require 'spec_helper'
require 'date'

describe XCJobs::Distribute do
  before(:each) do
    @commands = []

    allow_any_instance_of(FileUtils).to receive(:sh) do |object, command|
      @commands << command
    end

    allow_any_instance_of(XCJobs::Distribute).to receive(:upload) do |object, url, form_data|
      @url = url
      @form_data = form_data
    end

    Rake.application = rake
  end

  let(:rake) { Rake::Application.new }

  describe XCJobs::Distribute::TestFlight do
    describe 'define upload ipa task' do
      let(:credentials) do
        { api_token: 'abcde12345efghi67890d543957972cd_MTE3NjUyMjBxMS0wOE0wNiAwMzwzMjoyNy41MTA3MzE',
          team_token: '12345ab2692bd1c3093408a3399ee947_NDIzMDYyPDExLGExLTIwIDIxOjM9OjS2LjQxOTgzOA',
        }
      end

      let(:file) do
        File.join('build', 'Example.ipa')
      end

      let(:notes) { "Uploaded: #{DateTime.now.strftime("%Y/%m/%d %H:%M:%S")}" }

      let!(:task) do
        XCJobs::Distribute::TestFlight.new do |t|
          t.file = file
          t.api_token = credentials[:api_token]
          t.team_token = credentials[:team_token]
          t.notify = true
          t.replace = true
          t.distribution_lists = 'Dev'
          t.notes = notes
        end
      end

      it 'configures the ipa file path' do
        expect(task.file).to eq file
      end

      it 'configures the api_token' do
        expect(task.api_token).to eq credentials[:api_token]
      end

      it 'configures the team_token' do
        expect(task.team_token).to eq credentials[:team_token]
      end

      it 'configures the notify' do
        expect(task.notify).to eq true
      end

      it 'configures the replace' do
        expect(task.replace).to eq true
      end

      it 'configures the distribution_lists' do
        expect(task.distribution_lists).to eq 'Dev'
      end

      it 'configures the notes' do
        expect(task.notes).to eq notes
      end

      describe 'tasks' do
        describe 'distribute:testflight' do
          subject { Rake.application['distribute:testflight'] }

          it 'executes the appropriate commands' do
            subject.invoke
            expect(@url).to eq 'http://testflightapp.com/api/builds.json'
            expect(@form_data).to eq({
              file: "@#{file}",
              api_token: credentials[:api_token],
              team_token: credentials[:team_token],
              notify: true,
              replace: true,
              distribution_lists: 'Dev',
              notes: notes,
            })
          end
        end
      end
    end
  end

  describe XCJobs::Distribute::DeployGate do
    describe 'define upload ipa task' do
      let(:owner_name) { 'kishikawakatsumi' }

      let(:credentials) do
        { token: 'abcde12345efghi67890abcde12345efghi67890',
          distribution_key: '12345abcde67890efghi12345abcde67890efghi',
        }
      end

      let(:file) do
        File.join('build', 'Example.ipa')
      end

      let(:message) { 'New build uploaded!' }
      let(:release_note) { "Uploaded: #{DateTime.now.strftime("%Y/%m/%d %H:%M:%S")}" }

      let!(:task) do
        XCJobs::Distribute::DeployGate.new do |t|
          t.owner_name = owner_name
          t.file = file
          t.token = credentials[:token]
          t.distribution_key = credentials[:distribution_key]
          t.message = message
          t.release_note = release_note
          t.disable_notify = true
          t.visibility = 'public'
        end
      end

      it 'configures the ipa file path' do
        expect(task.file).to eq file
      end

      it 'configures the token' do
        expect(task.token).to eq credentials[:token]
      end

      it 'configures the distribution_key' do
        expect(task.distribution_key).to eq credentials[:distribution_key]
      end

      it 'configures the message' do
        expect(task.message).to eq message
      end

      it 'configures the release_note' do
        expect(task.release_note).to eq release_note
      end

      it 'configures the disable_notify' do
        expect(task.disable_notify).to eq true
      end

      it 'configures the visibility' do
        expect(task.visibility).to eq 'public'
      end

      describe 'tasks' do
        describe 'distribute:deploygate' do
          subject { Rake.application['distribute:deploygate'] }

          it 'executes the appropriate commands' do
            subject.invoke
            expect(@url).to eq "https://deploygate.com/api/users/#{owner_name}/apps"
            expect(@form_data).to eq({
              file: "@#{file}",
              token: credentials[:token],
              distribution_key: credentials[:distribution_key],
              message: message,
              release_note: release_note,
              disable_notify: 'yes',
              visibility: 'public',
            })
          end
        end
      end
    end
  end

  describe XCJobs::Distribute::Crittercism do
    describe 'define upload dSYMs task' do
      let(:credentials) do
        { app_id: '123456789abcdefg12345678',
          key: 'abcdefghijklmnopqrstuvwxyz123456',
        }
      end

      let(:dsym_file) do
        File.join('build', 'dSYMs.zip')
      end

      let!(:task) do
        XCJobs::Distribute::Crittercism.new do |t|
          t.app_id = credentials[:app_id]
          t.key = credentials[:key]
          t.dsym = dsym_file
        end
      end

      it 'configures the app_id' do
        expect(task.app_id).to eq credentials[:app_id]
      end

      it 'configures the key' do
        expect(task.key).to eq credentials[:key]
      end

      it 'configures the dsym file path' do
        expect(task.dsym).to eq dsym_file
      end

      describe 'tasks' do
        describe 'distribute:crittercism' do
          subject { Rake.application['distribute:crittercism'] }

          it 'executes the appropriate commands' do
            subject.invoke
            expect(@url).to eq "https://api.crittercism.com/api_beta/dsym/#{credentials[:app_id]}"
            expect(@form_data).to eq({
              dsym: "@#{dsym_file}",
              key: credentials[:key],
            })
          end
        end
      end
    end
  end

  describe XCJobs::Distribute::ITC do
    describe 'define upload ipa task' do
      let(:credentials) do
        { username: 'kishikawakatsumi',
          password: 'password1234',
        }
      end

      let(:file) do
        File.join('build', 'Example.ipa')
      end

      let(:altool) { '/Applications/Xcode.app/Contents/Applications/Application Loader.app/Contents/Frameworks/ITunesSoftwareService.framework/Support/altool' }

      let!(:task) do
        XCJobs::Distribute::ITC.new do |t|
          t.username = credentials[:username]
          t.password = credentials[:password]
          t.file = file
        end
      end

      it 'configures the username' do
        expect(task.username).to eq credentials[:username]
      end

      it 'configures the password' do
        expect(task.password).to eq credentials[:password]
      end

      it 'configures the file path' do
        expect(task.file).to eq file
      end

      describe 'tasks' do
        describe 'distribute:itc' do
          subject { Rake.application['distribute:itc'] }

          it 'executes the appropriate commands' do
            subject.invoke
            expect(@commands).to eq [%["#{altool}" --upload-app --file "#{file}" --username #{credentials[:username]} --password #{credentials[:password]}]]
          end
        end
      end
    end
  end
end
