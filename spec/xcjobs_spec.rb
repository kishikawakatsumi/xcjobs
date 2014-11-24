require "spec_helper"

describe XCJobs do
  it "has a version number" do
    expect(XCJobs::VERSION).not_to be nil
  end
end

describe XCJobs::Xcodebuild do
  before(:each) do
    allow_any_instance_of(XCJobs::Xcodebuild).to receive(:run) do |object, command|
      @commands = command.join(" ")
    end

    Rake.application = rake
  end

  let(:rake) { Rake::Application.new }

  describe 'simple task with a project' do
    let!(:task) do
      XCJobs::Build.new do |t|
        t.project = "Example"
        t.target = "Example"
        t.configuration = "Release"
        t.signing_identity = "iPhone Distribution: kishikawa katsumi"
        t.build_dir = "build"
      end
    end

    it "configures the project" do
      expect(task.project).to eq("Example")
    end

    it "configures the target" do
      expect(task.target).to eq("Example")
    end

    it "configures the build configuration" do
      expect(task.configuration).to eq("Release")
    end

    it "configures the code signing identity" do
      expect(task.signing_identity).to eq("iPhone Distribution: kishikawa katsumi")
    end

    it "configures the build directory" do
      expect(task.build_dir).to eq("build")
    end

    describe "tasks" do
      describe "build" do
        subject { Rake.application["build"] }

        it "executes the appropriate commands" do
          subject.invoke
          expect(@commands).to eq("xcodebuild build -project Example -target Example -configuration Release -derivedDataPath build CONFIGURATION_TEMP_DIR=build/temp CODE_SIGN_IDENTITY=iPhone Distribution: kishikawa katsumi")
        end
      end
    end
  end

  describe "simple task with a workspace" do
    let!(:task) do
      XCJobs::Build.new do |t|
        t.workspace = "Example.xcworkspace"
        t.scheme = "Example"
        t.configuration = "Release"
        t.signing_identity = "iPhone Distribution: kishikawa katsumi"
        t.build_dir = "build"
      end
    end

    it "configures the workspace" do
      expect(task.workspace).to eq("Example.xcworkspace")
    end

    it "configures the scheme" do
      expect(task.scheme).to eq("Example")
    end

    it "configures the build configuration" do
      expect(task.configuration).to eq("Release")
    end

    it "configures the code signing identity" do
      expect(task.signing_identity).to eq("iPhone Distribution: kishikawa katsumi")
    end

    it "configures the build directory" do
      expect(task.build_dir).to eq("build")
    end

    describe "tasks" do
      describe "build" do
        subject { Rake.application["build"] }

        it "executes the appropriate commands" do
          subject.invoke
          expect(@commands).to eq("xcodebuild build -workspace Example.xcworkspace -scheme Example -configuration Release -derivedDataPath build CONFIGURATION_TEMP_DIR=build/temp CODE_SIGN_IDENTITY=iPhone Distribution: kishikawa katsumi")
        end
      end
    end
  end
end
