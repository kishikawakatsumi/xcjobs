require 'spec_helper'

describe XCJobs::Distribute do
  before(:each) do
    allow_any_instance_of(XCJobs::Distribute).to receive(:upload) do |object, url, form_data|
      @url = url
      @form_data = form_data
    end

    Rake.application = rake
  end

  let(:rake) { Rake::Application.new }

  describe XCJobs::Distribute::Crittercism do
    describe 'define upload dSYMs task' do
      let(:credentials) do
        {
          app_id: '123456789abcdefg12345678',
          key:'abcdefghijklmnopqrstuvwxyz123456',
        }
      end

      let(:dsym_file) do
        File.join('build', 'dSYMs.zip')
      end

      let!(:task) do
        XCJobs::Distribute::Crittercism.new do |t|
          t.app_id = credentials['app_id']
          t.key = credentials['key']
          t.dsym = dsym_file
        end
      end

      it 'configures the app_id' do
        expect(task.app_id).to eq credentials['app_id']
      end

      it 'configures the key' do
        expect(task.app_id).to eq credentials['key']
      end

      it 'configures the dsym file path' do
        expect(task.dsym).to eq dsym_file
      end

      describe 'tasks' do
        describe 'distribute:crittercism' do
          subject { Rake.application['distribute:crittercism'] }

          it 'executes the appropriate commands' do
            subject.invoke
            expect(@url).to eq "https://api.crittercism.com/api_beta/dsym/#{credentials['app_id']}"
            expect(@form_data).to eq ({ dsym: "@#{dsym_file}" })
          end
        end
      end
    end
  end
end
