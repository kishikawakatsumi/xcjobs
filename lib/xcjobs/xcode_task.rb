require 'rake/task'

module XCJobs
  class Task < Rake::Task
    include XCJobs::XcodebuildBase

    class << self
      def define_task(*args, &block)
        task = super
        task.enhance do |t|
          t.check_conditions if t.class.method_defined? :check_conditions
          t.run
        end
        task
      end
    end
  end

  class Task::Test < Task
    include XCJobs::XcodebuildTest
  end

  class Task::Build < Task
    include XCJobs::XcodebuildBuild
  end

  class Task::Archive < Task
    include XCJobs::XcodebuildArchive
  end

  class Task::Export < Task
    include XCJobs::XcodebuildExport
  end

end

module XCJobs
  private

  module DSL
    def xcode_task(*args, &block)
      XCJobs::Task.define_task(*args, &block)
    end

    def xcode_test(*args, &block)
      XCJobs::Task::Test.define_task(*args, &block)
    end

    def xcode_build(*args, &block)
      XCJobs::Task::Build.define_task(*args, &block)
    end

    def xcode_archive(*args, &block)
      XCJobs::Task::Archive.define_task(*args, &block)
    end

    def xcode_export(*args, &block)
      XCJobs::Task::Export.define_task(*args, &block)
    end
  end
end

self.extend XCJobs::DSL
