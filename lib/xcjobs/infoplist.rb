require "rake/tasklib"

module XCJobs
  module InfoPlist
    extend self
    attr_accessor :path

    def [](key)
      output = %x[/usr/libexec/PlistBuddy -c "Print #{key}" #{path}].strip
      raise "The key `#{key}' does not exist in `#{path}'." if output.include?('Does Not Exist')
      output
    end

    def set(key, value, file = "#{path}")
      %x[/usr/libexec/PlistBuddy -c 'Set :#{key} "#{value}"' '#{file}'].strip
    end

    def []=(key, value)
      set(key, value)
    end

    def build_version
      self['CFBundleVersion']
    end

    def build_version=(revision)
      self['CFBundleVersion'] = revision
    end

    def marketing_version
      self['CFBundleShortVersionString']
    end

    def marketing_version=(version)
      self['CFBundleShortVersionString'] = version
    end

    def bump_marketing_version_segment(segment_index)
      segments = Gem::Version.new(marketing_version).segments
      segments[segment_index] = segments[segment_index].to_i + 1
      (segment_index+1..segments.size - 1).each { |i| segments[i] = 0 }
      version = segments.map(&:to_i).join('.')

      puts "Setting marketing version to: #{version}"
      self.marketing_version = version
    end

    def marketing_and_build_version
      "#{marketing_version} (#{build_version})"
    end
  end

  module InfoPlist
    class Version < Rake::TaskLib
      include Rake::DSL if defined?(Rake::DSL)

      def initialize()
        yield self if block_given?
        define
      end

      def path
        InfoPlist.path
      end

      def path=(path)
        InfoPlist.path = path
      end

      def define
        namespace :version do
          desc "Print the current version"
          task :current do
            puts InfoPlist.marketing_and_build_version
          end

          desc "Sets build version to last git commit hash"
          task :set_build_version do
            rev = `git rev-parse --short HEAD`.strip
            puts "Setting build version to: #{rev}"
            InfoPlist.build_version = rev
          end

          desc "Sets build version to number of commits"
          task :set_build_number do
            rev = `git rev-list --count HEAD`.strip
            puts "Setting build version to: #{rev}"
            InfoPlist.build_version = rev
          end

          namespace :bump do
            desc "Bump patch version (0.0.X)"
            task :patch do
              InfoPlist.bump_marketing_version_segment(2)
            end

            desc "Bump minor version (0.X.0)"
            task :minor do
              InfoPlist.bump_marketing_version_segment(1)
            end

            desc "Bump major version (X.0.0)"
            task :major do
              InfoPlist.bump_marketing_version_segment(0)
            end
          end
        end

        desc "Print the current version"
        task :version => "version:current"
      end
    end
  end
end
