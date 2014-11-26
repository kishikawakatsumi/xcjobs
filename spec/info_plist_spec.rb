require 'spec_helper'

describe XCJobs::InfoPlist do
  before(:each) do
    if ENV['CI']
      allow_any_instance_of(XCJobs::InfoPlist).to receive(:marketing_version).and_return('3.2.6')
      allow_any_instance_of(XCJobs::InfoPlist).to receive(:build_version).and_return('5413')
    end

    allow_any_instance_of(XCJobs::InfoPlist).to receive(:marketing_version=) do |object, arg|
      @marketing_version = arg
    end

    allow_any_instance_of(XCJobs::InfoPlist).to receive(:build_version=) do |object, arg|
      @build_version = arg
    end

    Rake.application = rake
  end

  let(:rake) { Rake::Application.new }

  describe 'test reading Info.plist' do
    let(:path) do
      File.join('spec', 'Info.plist')
    end

    let(:marketing_version) { '3.2.6' }
    let(:build_version) { '5413' }

    let!(:task) do
      XCJobs::InfoPlist::Version.new do |t|
        t.path = path
      end
    end

    it 'configures the Info.plist file path' do
      expect(task.path).to eq path
    end

    it 'configures the marketing_version' do
      expect(task.marketing_version).to eq marketing_version
    end

    it 'configures the build_version' do
      expect(task.build_version).to eq build_version
    end

    describe 'test bumping patch' do
      subject { Rake.application['version:bump:patch'] }

      it 'executes the appropriate commands' do
        subject.invoke
        expect(@marketing_version).to eq '3.2.7'
      end
    end

    describe 'test bumping minor' do
      subject { Rake.application['version:bump:minor'] }

      it 'executes the appropriate commands' do
        subject.invoke
        expect(@marketing_version).to eq '3.3.0'
      end
    end

    describe 'test bumping major' do
      subject { Rake.application['version:bump:major'] }

      it 'executes the appropriate commands' do
        subject.invoke
        expect(@marketing_version).to eq '4.0.0'
      end
    end

    describe 'test update build number' do
      subject { Rake.application['version:set_build_version'] }

      it 'executes the appropriate commands' do
        subject.invoke
        expect(@build_version).to eq %x[git rev-parse --short HEAD].strip
      end
    end

    describe 'test update build number' do
      subject { Rake.application['version:set_build_number'] }

      it 'executes the appropriate commands' do
        subject.invoke
        expect(@build_version).to eq %x[git rev-list --count HEAD].strip
      end
    end
  end
end
