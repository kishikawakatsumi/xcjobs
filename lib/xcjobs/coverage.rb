require 'rake/tasklib'
require 'json'
require 'pathname'
require 'tempfile'
require 'open3'
require 'digest/md5'

module XCJobs
  module Coverage

    class Coveralls < Rake::TaskLib
      include Rake::DSL if defined?(Rake::DSL)

      attr_accessor :repo_token
      attr_accessor :service_name
      attr_accessor :service_job_id
      attr_accessor :service_number
      attr_accessor :service_pull_request
      attr_accessor :parallel
      attr_accessor :service_job_number
      attr_accessor :service_event_type

      def initialize()
        if ENV['TRAVIS']
          @service_name = 'travis-ci'
          @service_job_id = ENV['TRAVIS_JOB_ID']
        elsif ENV['CIRCLECI']
          @service_name = 'circleci'
          @service_number = ENV['CIRCLE_BUILD_NUM']
          @service_pull_request = (ENV['CI_PULL_REQUEST'] || "")[/(\d+)$/, 1]
          @parallel = ENV['CIRCLE_NODE_TOTAL'].to_i > 1
          @service_job_number = ENV['CIRCLE_NODE_INDEX']
        end

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
        report['service_number'] = service_number if service_number
        report['service_pull_request'] = service_pull_request if service_pull_request
        report['parallel'] = parallel if parallel
        report['service_job_number'] = service_job_number if service_job_number
        report['service_event_type'] = service_event_type if service_event_type
        report['source_files'] = []

        Dir.glob("#{base_dir}/**/*.gcov").each do |file|
          File.open(file, "r") do |handle|
            source_file = {}
            name = ''
            source_digest = nil
            coverage = []

            handle.each_line do |line|
              match = /^[ ]*([0-9]+|-|#####):[ ]*([0-9]+):(.*)/.match(line)
              next unless match.to_a.count == 4
              count, number, text = match.to_a[1..3]

              if number.to_i == 0
                key, val = /([^:]+):(.*)$/.match(text).to_a[1..2]
                if key == 'Source'
                  name = Pathname(val).relative_path_from(Pathname(base_dir)).to_s
                  if File.exist?(val)
                    source_digest = Digest::MD5.file(val).to_s
                  end
                end
              else
                coverage[number.to_i - 1] = case count.strip
                  when '-'
                    nil
                  when '#####'
                    if text.strip == '}'
                      nil
                    else
                      0
                    end
                  else count.to_i
                  end
              end
            end

            if !is_excluded_path(name) && !source_digest.nil?
              source_file['name'] = name
              source_file['source_digest'] = source_digest
              source_file['coverage'] = coverage

              report['source_files'] << source_file
            end
          end
        end

        remotes = %x[git remote -v].rstrip.split(/\r?\n/).map {|line| line.chomp }.select { |line| line.include? 'fetch'}.first.split(' ')
        report['git'] = {
          'head' => {
            'id' => %x[git --no-pager log -1 --pretty=format:%H],
            'author_name' => %x[git --no-pager log -1 --pretty=format:%aN],
            'author_email' => %x[git --no-pager log -1 --pretty=format:%ae],
            'committer_name' => %x[git --no-pager log -1 --pretty=format:%cN],
            'committer_email' => %x[git --no-pager log -1 --pretty=format:%ce],
            'message' => %x[git --no-pager log -1 --pretty=format:%s] },
          'branch' => %x[git rev-parse --abbrev-ref HEAD].strip,
          'remotes' => {'name' => remotes[0], 'remote' => remotes[1]} }

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
        tempdir = Pathname.new(Dir.tmpdir).join(SecureRandom.hex)
        FileUtils.mkdir_p(tempdir)
        tempfile = File::open(tempdir.join('coveralls.json'), "w")
        tempfile.puts(report.to_json)
        tempfile.flush
        tempfile.path
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
