# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'xcjobs/version'

Gem::Specification.new do |spec|
  spec.name          = "xcjobs"
  spec.version       = XCJobs::VERSION
  spec.authors       = ["kishikawa katsumi"]
  spec.email         = ["kishikawakatsumi@mac.com"]
  spec.summary       = %q{Support the automation of release process of iOS/OSX apps with CI}
  spec.description   = %q{Provides rake tasks for Xcode build}
  spec.homepage      = "http://github.com/kishikawakatsumi/xcjobs"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "coveralls"
end
