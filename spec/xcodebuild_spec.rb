require 'spec_helper'

describe XCJobs::Xcodebuild do
  before(:each) do
    @commands = []

    allow_any_instance_of(FileUtils).to receive(:sh) do |object, command|
      @commands << command
    end

    allow_any_instance_of(XCJobs::Xcodebuild).to receive(:run) do |object, command|
      @commands << command.join(' ')
    end

    Rake.application = rake
  end

  let(:rake) { Rake::Application.new }

  let(:destinations) do
    ['name=iPhone 6,OS=8.1', 'name=iPhone 6 Plus,OS=8.1', 'name=iPad 2,OS=7.1', 'name=iPad Air,OS=8.1']
  end

  describe XCJobs::Test do
    context 'when a scheme is not specified' do
      subject do
        XCJobs::Test.new do |t|
          t.project = 'Example.xcodeproj'
        end
      end

      it 'fails' do
        expect { subject }.to raise_error(RuntimeError, 'test action requires specifying a scheme')
      end
    end

    context 'when both scheme and targets specified' do
      subject do
        XCJobs::Test.new do |t|
          t.project = 'Example.xcodeproj'
          t.scheme = 'Example'
          t.target = 'Example'
        end
      end

      it 'fails' do
        expect { subject.invoke }.to raise_error(RuntimeError, 'cannot specify both a scheme and targets')
      end
    end

    context 'When no file extension (project)' do
      let!(:task) do
        XCJobs::Test.new do |t|
          t.project = 'Project'
          t.scheme = 'Scheme'
        end
      end

      it 'Automatically complemented' do
        expect(task.project).to eq 'Project.xcodeproj'
      end
    end

    context 'When no file extension (workspace)' do
      let!(:task) do
        XCJobs::Test.new do |t|
          t.workspace = 'Workspace'
          t.scheme = 'Scheme'
        end
      end

      it 'Automatically complemented' do
        expect(task.workspace).to eq 'Workspace.xcworkspace'
      end
    end

    describe 'test project with simulator' do
      let!(:task) do
        XCJobs::Test.new do |t|
          t.project = 'Example.xcodeproj'
          t.scheme = 'Example'
          t.configuration = 'Debug'
          destinations.each do |destination|
            t.add_destination(destination)
          end
        end
      end

      it 'configures the project' do
        expect(task.project).to eq 'Example.xcodeproj'
      end

      it 'configures the scheme' do
        expect(task.scheme).to eq 'Example'
      end

      it 'configures the build configuration' do
        expect(task.configuration).to eq 'Debug'
      end

      describe 'tasks' do
        describe 'test' do
          subject { Rake.application['test'] }

          it 'executes the appropriate commands' do
            subject.invoke
            expect(@commands).to eq ['xcodebuild test -project Example.xcodeproj -scheme Example -sdk iphonesimulator -configuration Debug -destination name=iPhone 6,OS=8.1 -destination name=iPhone 6 Plus,OS=8.1 -destination name=iPad 2,OS=7.1 -destination name=iPad Air,OS=8.1 CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO GCC_SYMBOLS_PRIVATE_EXTERN=NO']
          end
        end
      end
    end

    describe 'test workspace with simulator' do
      let!(:task) do
        XCJobs::Test.new do |t|
          t.workspace = 'Example.xcworkspace'
          t.scheme = 'Example'
          t.configuration = 'Debug'
          destinations.each do |destination|
            t.add_destination(destination)
          end
        end
      end

      it 'configures the workspace' do
        expect(task.workspace).to eq 'Example.xcworkspace'
      end

      it 'configures the scheme' do
        expect(task.scheme).to eq 'Example'
      end

      it 'configures the build configuration' do
        expect(task.configuration).to eq 'Debug'
      end

      it 'configures destinations' do
        expect(task.destinations).to eq destinations
      end

      describe 'tasks' do
        describe 'test' do
          subject { Rake.application['test'] }

          it 'executes the appropriate commands' do
            subject.invoke
            expect(@commands).to eq ['xcodebuild test -workspace Example.xcworkspace -scheme Example -sdk iphonesimulator -configuration Debug -destination name=iPhone 6,OS=8.1 -destination name=iPhone 6 Plus,OS=8.1 -destination name=iPad 2,OS=7.1 -destination name=iPad Air,OS=8.1 CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO GCC_SYMBOLS_PRIVATE_EXTERN=NO']
          end
        end
      end
    end

    describe 'test project with device' do
      let(:destination) { 'platform=iOS,id=8d18c8c4d1a6988ac4a70d370bfcbe99fef3f7b5' }

      let!(:task) do
        XCJobs::Test.new do |t|
          t.project = 'Example.xcodeproj'
          t.scheme = 'Example'
          t.configuration = 'Debug'
          t.sdk = 'iphoneos'
          t.add_destination(destination)
        end
      end

      it 'configures the project' do
        expect(task.project).to eq 'Example.xcodeproj'
      end

      it 'configures the scheme' do
        expect(task.scheme).to eq 'Example'
      end

      it 'configures the build configuration' do
        expect(task.configuration).to eq 'Debug'
      end

      it 'configures the sdk' do
        expect(task.sdk).to eq 'iphoneos'
      end

      it 'configures destinations' do
        expect(task.destinations).to eq [destination]
      end

      describe 'tasks' do
        describe 'test' do
          subject { Rake.application['test'] }

          it 'executes the appropriate commands' do
            subject.invoke
            expect(@commands).to eq ['xcodebuild test -project Example.xcodeproj -scheme Example -sdk iphoneos -configuration Debug -destination platform=iOS,id=8d18c8c4d1a6988ac4a70d370bfcbe99fef3f7b5 GCC_SYMBOLS_PRIVATE_EXTERN=NO']
          end
        end
      end
    end
  end

  describe XCJobs::Build do
    context 'when specifying build_dir' do
      subject do
        XCJobs::Build.new do |t|
          t.project = 'Example.xcodeproj'
          t.build_dir = 'build'
        end
      end

      it 'fails' do
        expect { subject }.to raise_error(RuntimeError, 'the scheme is required when specifying build_dir')
      end
    end

    context 'when both scheme and targets specified' do
      subject do
        XCJobs::Build.new do |t|
          t.project = 'Example.xcodeproj'
          t.scheme = 'Example'
          t.target = 'Example'
        end
      end

      it 'fails' do
        expect { subject.invoke }.to raise_error(RuntimeError, 'cannot specify both a scheme and targets')
      end
    end

    context 'When no file extension (project)' do
      let!(:task) do
        XCJobs::Build.new do |t|
          t.project = 'Project'
          t.scheme = 'Scheme'
        end
      end

      it 'Automatically complemented' do
        expect(task.project).to eq 'Project.xcodeproj'
      end
    end

    context 'When no file extension (workspace)' do
      let!(:task) do
        XCJobs::Build.new do |t|
          t.workspace = 'Workspace'
          t.scheme = 'Scheme'
        end
      end

      it 'Automatically complemented' do
        expect(task.workspace).to eq 'Workspace.xcworkspace'
      end
    end

    describe 'simple task with a project' do
      let!(:task) do
        XCJobs::Build.new do |t|
          t.project = 'Example.xcodeproj'
          t.target = 'Example'
          t.configuration = 'Release'
        end
      end

      it 'configures the project' do
        expect(task.project).to eq 'Example.xcodeproj'
      end

      it 'configures the target' do
        expect(task.target).to eq 'Example'
      end

      it 'configures the build configuration' do
        expect(task.configuration).to eq 'Release'
      end

      describe 'tasks' do
        describe 'build' do
          subject { Rake.application['build'] }

          it 'executes the appropriate commands' do
            subject.invoke
            expect(@commands).to eq ['xcodebuild build -project Example.xcodeproj -target Example -configuration Release']
          end
        end
      end
    end

    describe 'simple task with a workspace' do
      let(:signing_identity) { 'iPhone Developer: Katsumi Kishikawa (9NXEJ2L8Q6)' }

      let!(:task) do
        XCJobs::Build.new do |t|
          t.workspace = 'Example.xcworkspace'
          t.scheme = 'Example'
          t.configuration = 'Debug'
          t.signing_identity = signing_identity
          unless ENV['CI']
            t.provisioning_profile = './spec/profiles/development.mobileprovision'
          end
          t.build_dir = 'build'
        end
      end

      it 'configures the workspace' do
        expect(task.workspace).to eq 'Example.xcworkspace'
      end

      it 'configures the scheme' do
        expect(task.scheme).to eq 'Example'
      end

      it 'configures the build configuration' do
        expect(task.configuration).to eq 'Debug'
      end

      it 'configures the code signing identity' do
        expect(task.signing_identity).to eq signing_identity
      end

      it 'configures the build directory' do
        expect(task.build_dir).to eq('build')
      end

      describe 'tasks' do
        describe 'build' do
          subject { Rake.application['build'] }

          it 'executes the appropriate commands' do
            subject.invoke
            if ENV['CI']
              expect(@commands).to eq ['xcodebuild build -workspace Example.xcworkspace -scheme Example -configuration Debug -derivedDataPath build CONFIGURATION_TEMP_DIR=build/temp CODE_SIGN_IDENTITY=iPhone Developer: Katsumi Kishikawa (9NXEJ2L8Q6)']
            else
              expect(@commands).to eq ['xcodebuild build -workspace Example.xcworkspace -scheme Example -configuration Debug -derivedDataPath build CONFIGURATION_TEMP_DIR=build/temp CODE_SIGN_IDENTITY=iPhone Developer: Katsumi Kishikawa (9NXEJ2L8Q6) PROVISIONING_PROFILE=a55e7d27-6196-4994-ab9d-871d5d56b3fd']
            end
          end
        end
      end
    end

    describe 'unsetenv_others' do
      it 'defaults to false' do
        task = XCJobs::Build.new do |t|
          t.project = 'Example.xcodeproj'
          t.target = 'Example'
          t.configuration = 'Release'
        end

        expect(task.unsetenv_others).to eq false
      end

      it 'can be configured' do
        task = XCJobs::Build.new do |t|
          t.project = 'Example.xcodeproj'
          t.target = 'Example'
          t.configuration = 'Release'
          t.unsetenv_others = true
        end

        expect(task.unsetenv_others).to eq true
      end
    end
  end

  describe XCJobs::Archive do
    context 'when a scheme is not specified' do
      subject do
        XCJobs::Archive.new do |t|
          t.project = 'Example.xcodeproj'
        end
      end

      it 'fails' do
        expect { subject }.to raise_error(RuntimeError, 'archive action requires specifying a scheme')
      end
    end

    context 'when both scheme and targets specified' do
      subject do
        XCJobs::Archive.new do |t|
          t.project = 'Example.xcodeproj'
          t.scheme = 'Example'
          t.target = 'Example'
        end
      end

      it 'fails' do
        expect { subject.invoke }.to raise_error(RuntimeError, 'cannot specify both a scheme and targets')
      end
    end

    describe 'simple task with a project' do
      let!(:task) do
        XCJobs::Archive.new do |t|
          t.project = 'Example.xcodeproj'
          t.scheme = 'Example'
          t.configuration = 'Release'
          t.build_dir = 'build'
        end
      end

      it 'configures the project' do
        expect(task.project).to eq 'Example.xcodeproj'
      end

      it 'configures the target' do
        expect(task.scheme).to eq 'Example'
      end

      it 'configures the build configuration' do
        expect(task.configuration).to eq 'Release'
      end

      it 'configures the build directory' do
        expect(task.build_dir).to eq('build')
      end

      describe 'tasks' do
        describe 'build:archive' do
          subject { Rake.application['build:archive'] }

          it 'executes the appropriate commands' do
            subject.invoke
            expect(@commands).to eq [ 'xcodebuild archive -project Example.xcodeproj -scheme Example -configuration Release -derivedDataPath build CONFIGURATION_TEMP_DIR=build/temp -archivePath build/Example',
              '(cd build; zip -ryq dSYMs.zip Example.xcarchive/dSYMs)',
              '(cd build; zip -ryq Example.xcarchive.zip Example.xcarchive)',
            ]
          end
        end
      end
    end

    describe 'archive task with a workspace' do
      let!(:task) do
        XCJobs::Archive.new do |t|
          t.workspace = 'Example.xcworkspace'
          t.scheme = 'Example'
          t.configuration = 'Release'
          t.signing_identity = 'iPhone Distribution: kishikawa katsumi'
          unless ENV['CI']
            t.provisioning_profile = 'spec/profiles/distribution.mobileprovision'
          end
          t.build_dir = 'build'
        end
      end

      it 'configures the workspace' do
        expect(task.workspace).to eq('Example.xcworkspace')
      end

      it 'configures the scheme' do
        expect(task.scheme).to eq('Example')
      end

      it 'configures the build configuration' do
        expect(task.configuration).to eq('Release')
      end

      it 'configures the code signing identity' do
        expect(task.signing_identity).to eq('iPhone Distribution: kishikawa katsumi')
      end

      unless ENV['CI']
        it 'configures the provisioning profile' do
          expect(task.provisioning_profile).to eq('spec/profiles/distribution.mobileprovision')
        end

        it 'configures the provisioning profile name' do
          expect(task.provisioning_profile_name).to eq('Distribution Provisioning Profile')
        end

        it 'configures the provisioning profile UUID' do
          expect(task.provisioning_profile_uuid).to eq('5d09b88d-ff09-43aa-a6fd-3907f98fe467')
        end
      end

      it 'configures the build directory' do
        expect(task.build_dir).to eq('build')
      end

      describe 'tasks' do
        describe 'build:archive' do
          subject { Rake.application['build:archive'] }

          it 'executes the appropriate commands' do
            subject.invoke

            if ENV['CI']
              expect(@commands).to eq [ 'xcodebuild archive -workspace Example.xcworkspace -scheme Example -configuration Release -derivedDataPath build CONFIGURATION_TEMP_DIR=build/temp CODE_SIGN_IDENTITY=iPhone Distribution: kishikawa katsumi -archivePath build/Example',
                '(cd build; zip -ryq dSYMs.zip Example.xcarchive/dSYMs)',
                '(cd build; zip -ryq Example.xcarchive.zip Example.xcarchive)',
              ]
            else
              expect(@commands).to eq [ 'xcodebuild archive -workspace Example.xcworkspace -scheme Example -configuration Release -derivedDataPath build CONFIGURATION_TEMP_DIR=build/temp CODE_SIGN_IDENTITY=iPhone Distribution: kishikawa katsumi PROVISIONING_PROFILE=5d09b88d-ff09-43aa-a6fd-3907f98fe467 -archivePath build/Example',
                '(cd build; zip -ryq dSYMs.zip Example.xcarchive/dSYMs)',
                '(cd build; zip -ryq Example.xcarchive.zip Example.xcarchive)',
              ]
            end
          end
        end
      end
    end
  end

  describe XCJobs::Export do
    describe 'export task for IPA' do
      let!(:task) do
        XCJobs::Export.new do |t|
          t.archive_path = 'build/Example'
          t.export_format = 'IPA'
          t.export_path = 'build/Example.ipa'
          if ENV['CI']
            t.export_provisioning_profile = 'Ad Hoc Provisioning Profile'
          else
            t.export_provisioning_profile = './spec/profiles/adhoc.mobileprovision'
          end
          t.export_signing_identity = 'iPhone Distribution: kishikawa katsumi'
        end
      end

      it 'configures the archive path' do
        expect(task.archive_path).to eq 'build/Example'
      end

      it 'configures the export format' do
        expect(task.export_format).to eq 'IPA'
      end

      it 'configures the export path' do
        expect(task.export_path).to eq 'build/Example.ipa'
      end

      it 'configures the export provisioning profile' do
        expect(task.export_provisioning_profile).to eq 'Ad Hoc Provisioning Profile'
      end

      it 'configures the export signing identity' do
        expect(task.export_signing_identity).to eq 'iPhone Distribution: kishikawa katsumi'
      end

      it 'configures unsetenv_others to true by default' do
        expect(task.unsetenv_others).to be_truthy
      end

      describe 'tasks' do
        describe 'export' do
          subject { Rake.application['build:export'] }

          it 'executes the appropriate commands' do
            subject.invoke
            expect(@commands).to eq ['xcodebuild -exportArchive -archivePath build/Example -exportFormat IPA -exportPath build/Example.ipa -exportProvisioningProfile Ad Hoc Provisioning Profile -exportSigningIdentity iPhone Distribution: kishikawa katsumi']
          end
        end
      end
    end

    describe 'export task for IPA' do
      let!(:task) do
        XCJobs::Export.new do |t|
          t.archive_path = 'build/Example'
          t.export_format = 'IPA'
          t.export_path = 'build/Example.ipa'
          t.export_provisioning_profile = 'Ad Hoc Provisioning Profile'
          t.export_signing_identity = 'iPhone Distribution: kishikawa katsumi'
        end
      end

      it 'configures the archive path' do
        expect(task.archive_path).to eq 'build/Example'
      end

      it 'configures the export format' do
        expect(task.export_format).to eq 'IPA'
      end

      it 'configures the export path' do
        expect(task.export_path).to eq 'build/Example.ipa'
      end

      it 'configures the export provisioning profile' do
        expect(task.export_provisioning_profile).to eq 'Ad Hoc Provisioning Profile'
      end

      it 'configures the export signing identity' do
        expect(task.export_signing_identity).to eq 'iPhone Distribution: kishikawa katsumi'
      end

      describe 'tasks' do
        describe 'export' do
          subject { Rake.application['build:export'] }

          it 'executes the appropriate commands' do
            subject.invoke
            expect(@commands).to eq ['xcodebuild -exportArchive -archivePath build/Example -exportFormat IPA -exportPath build/Example.ipa -exportProvisioningProfile Ad Hoc Provisioning Profile -exportSigningIdentity iPhone Distribution: kishikawa katsumi']
          end
        end
      end
    end

    describe 'export task for IPA' do
      let!(:task) do
        XCJobs::Export.new do |t|
          t.archive_path = 'build/Example'
          t.export_format = nil
          t.export_path = 'build'
        end
      end

      it 'configures the export_format to be nil' do
        expect(task.export_format).to be_nil
      end

      describe 'tasks' do
        describe 'export' do
          subject { Rake.application['build:export'] }

          it 'executes the appropriate commands' do
            subject.invoke
            expect(@commands).to eq ['xcodebuild -exportArchive -archivePath build/Example -exportPath build']
          end
        end
      end
    end

    describe 'export task for IPA' do
      let!(:task) do
        XCJobs::Export.new do |t|
          t.archive_path = 'build/Example'
          t.export_path = 'build'
        end
      end

      it 'has default export_format default to be IPA' do
        expect(task.export_format).to eq 'IPA'
      end

      describe 'tasks' do
        describe 'export' do
          subject { Rake.application['build:export'] }

          it 'executes the appropriate commands' do
            subject.invoke
            expect(@commands).to eq ['xcodebuild -exportArchive -archivePath build/Example -exportFormat IPA -exportPath build']
          end
        end
      end
    end

    describe 'export task for IPA' do
      let!(:task) do
        XCJobs::Export.new do |t|
          t.archive_path = 'build/Example'
          t.export_format = nil
          t.export_path = 'build'
          t.options_plist = 'options.plist'
        end
      end

      it 'configures the export options plist' do
        expect(task.options_plist).to eq 'options.plist'
      end

      describe 'tasks' do
        describe 'export' do
          subject { Rake.application['build:export'] }

          it 'executes the appropriate commands' do
            subject.invoke
            expect(@commands).to eq ['xcodebuild -exportArchive -exportOptionsPlist options.plist -archivePath build/Example -exportPath build']
          end
        end
      end
    end

    describe 'export task for PKG' do
      let!(:task) do
        XCJobs::Export.new do |t|
          t.archive_path = 'build/Example'
          t.export_format = 'PKG'
          t.export_path = 'build/Example.pkg'
          t.export_signing_identity = 'Developer ID Application'
          t.export_installer_identity = 'Developer ID Installer'
        end
      end

      it 'configures the archive path' do
        expect(task.archive_path).to eq 'build/Example'
      end

      it 'configures the export format' do
        expect(task.export_format).to eq 'PKG'
      end

      it 'configures the export path' do
        expect(task.export_path).to eq 'build/Example.pkg'
      end

      it 'configures the export signing identity' do
        expect(task.export_signing_identity).to eq 'Developer ID Application'
      end

      it 'configures the export installer identity' do
        expect(task.export_installer_identity).to eq 'Developer ID Installer'
      end

      describe 'tasks' do
        describe 'export' do
          subject { Rake.application['build:export'] }

          it 'executes the appropriate commands' do
            subject.invoke
            expect(@commands).to eq ['xcodebuild -exportArchive -archivePath build/Example -exportFormat PKG -exportPath build/Example.pkg -exportSigningIdentity Developer ID Application -exportInstallerIdentity Developer ID Installer']
          end
        end
      end
    end
  end
end
