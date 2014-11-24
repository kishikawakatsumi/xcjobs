# XCJobs

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
  t.workspace = "Example.xcworkspace"
  t.scheme = "Example"
  t.configuration = "Release"
  t.add_destination("name=iPad 2,OS=7.1")
  t.add_destination("name=iPad Air,OS=8.1")
  t.formatter = "xcpretty -c"
end
```

```shell
$ rake -T

rake test                       # test application
```

### Build application

```ruby
XCJobs::Build.new do |t|
  t.workspace = "Example.xcworkspace"
  t.scheme = "Example"
  t.configuration = "Release"
  t.signing_identity = "iPhone Distribution: kishikawa katsumi"
  t.build_dir = "build"
  t.formatter = "xcpretty -c"
end
```

```shell
$ rake -T

rake build                      # build application
```

### Export IPA from xcarchive

```ruby
XCJobs::Archive.new do |t|
  t.workspace = "Example.xcworkspace"
  t.scheme = "Example"
  t.configuration = "Release"
  t.signing_identity = "iPhone Distribution: kishikawa katsumi"
  t.build_dir = "build"
  t.formatter = "xcpretty -c"
end

XCJobs::Export.new do |t|
  t.archivePath = File.join("build", "Example.xcarchive")
  t.exportPath = File.join("build", "Example.ipa")
  t.exportProvisioningProfile = "Ad_Hoc.mobileprovision"
  t.formatter = "xcpretty -c"
end
```

```shell
$ rake -T

rake build:archive              # make xcarchive
rake build:export               # export from an archive
```

### Distribute (Upload to Testfligh/Crittercism)

```ruby
XCJobs::Distribute::Crittercism.new do |t|
  t.app_id = "xxx..."
  t.key = "xxx..."
  t.dsym = File.join("build", "dSYMs.zip")
end

XCJobs::Distribute::TestFlight.new do |t|
  t.file = File.join("build", "#{Example}.ipa")
  t.api_token = "xxx..."
  t.team_token = "xxx..."
  t.notify = true
  t.replace = true
  t.distribution_lists = "Dev"
  t.notes = "Uploaded: #{DateTime.now.strftime("%Y/%m/%d %H:%M:%S")}"
end
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

  t.add_profile("AppStore")
  t.add_profile("Ad Hoc")
end
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/xcjobs/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
