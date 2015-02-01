require 'rake/tasklib'
require 'json'
require 'pathname'
require 'tempfile'
require 'open3'

module XCJobs
  module Coverage

    def self.run_gcov(configuration_temp_dir)
      Dir.glob("#{configuration_temp_dir}/**/*.gcda").each do |file|
        system %[(cd "#{File.dirname(file)}" && gcov -l "#{file}")]
      end
    end

    class Coveralls < Rake::TaskLib
      include Rake::DSL if defined?(Rake::DSL)

      attr_accessor :repo_token
      attr_accessor :service_name
      attr_accessor :service_job_id

      def initialize()
        @service_name = 'travis-ci'
        @service_job_id = ENV['TRAVIS_JOB_ID']

        @extensions = []
        @excludes = []
        @exclude_patterns = []

        yield self if block_given?
        define
      end

      def add_extension(extension)
        @extensions << extension
      end

      def add_exclude(exclude)
        @excludes << exclude
      end

      def add_exclude_pattern(exclude_pattern)
        if !exclude_pattern.kind_of?(Regexp)
          exclude_pattern = Regexp.new(exclude_pattern)
        end
        @exclude_patterns << exclude_pattern
      end

      private

      def define
        namespace :coverage do
          desc 'send coverage report to Coveralls'
          task :coveralls do
            root = %x[git rev-parse --show-toplevel].strip
            report = collect(root)
            file = write_report(report)
            upload(file)
          end
        end
      end

      def collect(base_dir)
        report = {}
        report['repo_token'] = repo_token if repo_token
        report['service_name'] = service_name if service_name
        report['service_job_id'] = service_job_id if service_job_id
        report['source_files'] = []

        Dir.glob("#{base_dir}/**/*.gcov").each do |file|
          File.open(file, "r") do |handle|
            source_file = {}
            name = ''
            source = ''
            coverage = []

            handle.each_line do |line|
              match = /^[ ]*([0-9]+|-|#####):[ ]*([0-9]+):(.*)/.match(line)
              next unless match.to_a.count == 4
              count, number, text = match.to_a[1..3]

              if number.to_i == 0
                key, val = /([^:]+):(.*)$/.match(text).to_a[1..2]
                if key == 'Source'
                  name = Pathname(val).relative_path_from(Pathname(base_dir)).to_s
                end
              else
                source << text + '\n'
                coverage[number.to_i - 1] = case count.strip
                  when "-"
                    nil
                  when "#####"
                    if text.strip == '}'
                      nil
                    else
                      0
                    end
                  else count.to_i
                  end
              end
            end

            if !is_excluded_path(name)
              source_file['name'] = name
              source_file['source'] = source
              source_file['coverage'] = coverage

              report['source_files'] << source_file
            end
          end
        end

        report
      end

      def is_excluded_path(filepath)
        if filepath.start_with?('..')
          return true
        end
        @excludes.each do |exclude|
          if filepath.start_with?(exclude)
            return true
          end
        end
        @exclude_patterns.each do |pattern|
          if filepath.match(pattern)
            return true
          end
        end
        if !@extensions.empty?
          @extensions.each do |extension|
            if File.extname(filepath) == extension
              return false
            end
          end
          return true
        else
          return false
        end
      end

      def write_report(report)
        temp = Tempfile.new('report')
        temp.puts(report.to_json)
        temp.path
      end

      def upload(json_file)
        curl_options = ['curl', '-sSf', '-F', "json_file=@#{json_file}", 'https://coveralls.io/api/v1/jobs']
        puts curl_options.join(' ')
        Open3.popen2e(*curl_options) do |stdin, stdout_err, wait_thr|
          output = ''
          while line = stdout_err.gets
            puts line
            output << line
          end

          status = wait_thr.value
          if !status.success?
            fail "upload failed (exited with status: #{status.exitstatus})"
          end
        end
      end
    end
  end
end
