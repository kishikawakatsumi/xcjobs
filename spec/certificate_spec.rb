require 'spec_helper'

describe XCJobs::Certificate do
  before(:each) do
    Rake.application = rake
  end

  let(:rake) { Rake::Application.new }

  describe XCJobs::Certificate do
    describe 'simple task' do
      let!(:task) do
        XCJobs::Certificate.new do |t|
          passphrase = "password1234"

          t.add_certificate('./certificates/apple.cer')
          t.add_certificate('./certificates/appstore.cer')
          t.add_certificate('./certificates/appstore.p12', passphrase)

          t.add_profile('./spec/profiles/adhoc.mobileprovision')
          t.add_profile('./spec/profiles/distribution.mobileprovision')
        end
      end

      describe 'tasks' do
        describe 'certificates:install' do
          subject { Rake.application['certificates:install'] }

          it 'defines the appropriate task' do
            expect(subject.name).to eq('certificates:install')
          end
        end

        describe 'certificates:remove' do
          subject { Rake.application['certificates:remove'] }

          it 'defines the appropriate task' do
            expect(subject.name).to eq('certificates:remove')
          end
        end

        describe 'profiles:install' do
          subject { Rake.application['profiles:install'] }

          it 'defines the appropriate task' do
            expect(subject.name).to eq('profiles:install')
          end
        end
      end
    end
  end
end
