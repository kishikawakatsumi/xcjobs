# XCJobs
[![Gem Version](https://badge.fury.io/rb/xcjobs.svg)](http://badge.fury.io/rb/xcjobs) [![Build Status](https://travis-ci.org/kishikawakatsumi/xcjobs.svg?branch=master)](https://travis-ci.org/kishikawakatsumi/xcjobs) [![Coverage Status](https://img.shields.io/coveralls/kishikawakatsumi/xcjobs.svg)](https://coveralls.io/r/kishikawakatsumi/xcjobs?branch=master) [![Code Climate](https://codeclimate.com/github/kishikawakatsumi/xcjobs/badges/gpa.svg)](https://codeclimate.com/github/kishikawakatsumi/xcjobs) [![Dependency Status](https://gemnasium.com/kishikawakatsumi/xcjobs.svg)](https://gemnasium.com/kishikawakatsumi/xcjobs)

Support the automation of release process of iOS/OSX apps with CI

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'xcjobs'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install xcjobs

## Usage

### Test application

```ruby
XCJobs::Test.new do |t|
  t.workspace = 'Example'
  t.scheme = 'Example'
  t.configuration = 'Release'
  t.add_destination('name=iPad 2,OS=7.1')
  t.add_destination('name=iPad Air,OS=8.1')
  t.formatter = 'xcpretty -c'
end
```

```shell
$ rake -T

rake test                       # test application
```

```shell
$ rake test

xcodebuild test -workspace Example.xcworkspace -scheme Example -sdk iphonesimulator -configuration Release -destination name=iPad 2,OS=7.1 -destination -destination name=iPad Air,OS=8.1 CODE_SIGN_IDENTITY="" GCC_SYMBOLS_PRIVATE_EXTERN=NO
```

### Build application

```ruby
XCJobs::Build.new do |t|
  t.workspace = 'Example'
  t.scheme = 'Example'
  t.configuration = 'Release'
  t.signing_identity = 'iPhone Distribution: Katsumi Kishikawa'
  t.build_dir = 'build'
  t.formatter = 'xcpretty -c'
end
```

```shell
$ rake -T

rake build                      # build application
```

```shell
$ rake build

xcodebuild build -workspace Example.xcworkspace -scheme Example -configuration Release -derivedDataPath build CONFIGURATION_TEMP_DIR=build/temp CODE_SIGN_IDENTITY=iPhone Distribution: kishikawa katsumi
```

### Export IPA from xcarchive

```ruby
XCJobs::Archive.new do |t|
  t.workspace = 'Example'
  t.scheme = 'Example'
  t.configuration = 'Release'
  t.signing_identity = 'iPhone Distribution: Katsumi Kishikawa'
  t.build_dir = 'build'
  t.formatter = 'xcpretty -c'
end

XCJobs::Export.new do |t|
  t.archive_path = File.join('build', 'Example.xcarchive')
  t.export_path = File.join('build', 'Example.ipa')
  t.export_provisioning_profile = 'Ad_Hoc.mobileprovision'
  t.formatter = 'xcpretty -c'
end
```

```shell
$ rake -T

rake build:archive              # make xcarchive
rake build:export               # export from an archive
```

```shell
$ bundle exec rake build:archive

xcodebuild archive -workspace Example.xcworkspace -scheme Example -configuration Release -archivePath build/Example -derivedDataPath build CONFIGURATION_TEMP_DIR=build/temp CODE_SIGN_IDENTITY=iPhone Distribution: kishikawa katsumi
```

```shell
$ bundle exec rake build:export

xcodebuild -exportArchive -exportFormat IPA -archivePath build/Example.xcarchive -exportPath build/Example.ipa -exportProvisioningProfile Ad Hoc Provisioning Profile
```

### Distribute (Upload to TestFlight/Crittercism)

```ruby
XCJobs::Distribute::Crittercism.new do |t|
  t.app_id = 'xxx...'
  t.key = 'xxx...'
  t.dsym = File.join('build', 'dSYMs.zip')
end

XCJobs::Distribute::TestFlight.new do |t|
  t.file = File.join('build', "#{Example}.ipa")
  t.api_token = 'xxx...'
  t.team_token = 'xxx...'
  t.notify = true
  t.replace = true
  t.distribution_lists = 'Dev'
  t.notes = "Uploaded: #{DateTime.now.strftime("%Y/%m/%d %H:%M:%S")}"
end

XCJobs::Distribute::DeployGate.new do |t|
  t.owner_name = 'kishikawakatsumi'
    t.file = File.join('build', "#{Example}.ipa")
  t.token = 'xxx...'
  t.message = "Uploaded: #{DateTime.now.strftime("%Y/%m/%d %H:%M:%S")}" # optional
  t.distribution_key = 'xxx...' # optional
  t.release_note = '...' # optional
  t.disable_notify = false # optional
  t.visibility = 'public' # optional
end
```

```shell
$ rake -T

rake distribute:crittercism     # upload dSYMs to Crittercism
rake distribute:testflight      # upload IPA to TestFlight
rake distribute:deploygate      # upload IPA to DeployGate
```

### Install/Remove certificates (For Travis CI)

```ruby
XCJobs::Certificate.new do |t|
  passphrase = "password1234"

  t.add_certificate('./certificates/apple.cer')
  t.add_certificate('./certificates/appstore.cer')
  t.add_certificate('./certificates/appstore.p12', passphrase)
  t.add_certificate('./certificates/adhoc.cer')
  t.add_certificate('./certificates/adhoc.p12', passphrase)

  t.add_profile('AppStore')
  t.add_profile('Ad Hoc')
end
```

```shell
$ rake -T

rake profiles:install           # install provisioning profiles

rake certificates:install       # install certificates
rake certificates:remove        # remove certificates
```

### Bumping version

```ruby
XCJobs::InfoPlist::Version.new do |t|
  t.path = File.join('Example', 'Info.plist')
end
```

```shell
$ rake -T

rake version                    # Print the current version
rake version:bump:major         # Bump major version (X.0.0)
rake version:bump:minor         # Bump minor version (0.X.0)
rake version:bump:patch         # Bump patch version (0.0.X)
rake version:current            # Print the current version
rake version:set_build_number   # Sets build version to number of commits
rake version:set_build_version  # Sets build version to last git commit hash
```

### Measuring code coverage

```ruby
XCJobs::Test.new('test:ios') do |t|
  t.workspace = 'Example'
  t.scheme = 'Example'
  t.configuration = 'Release'
  t.add_destination('name=iPhone 5s,OS=8.1')
  t.coverage = true # enable code coverage
  t.formatter = 'xcpretty -c'
end
```

### Send coverage report to Coveralls

```ruby
XCJobs::Coverage::Coveralls.new() do |t|
  t.add_extension('.m')
  t.add_exclude('Example')
end
```

## Automate with Travis CI

```ruby
# Gemfile
source 'https://rubygems.org'

gem 'rake'
gem 'cocoapods'
gem 'xcpretty'
gem 'xcjobs'
```

```yaml
# .travis.yml
language: objective-c
osx_image: xcode61
cache:
  directories:
    - vendor/bundle
    - Pods
install:
  - bundle install --path=vendor/bundle --binstubs=vendor/bin
  - bundle exec pod install
script:
  - bundle exec rake ${ACTION}
env:
  global:
    - LANG=en_US.UTF-8
    - LC_ALL=en_US.UTF-8
  matrix:
    - ACTION=test
    - ACTION="profiles:install certificates:install version:set_build_version build:archive build:export distribute:crittercism distribute:testflight certificates:remove"
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/xcjobs/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
