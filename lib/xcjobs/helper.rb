module XCJobs
  module Helper
    def self.extract_provisioning_profile(provisioning_profile)
      if File.file?(provisioning_profile)
        provisioning_profile_path = provisioning_profile
      else
        path = File.join("#{Dir.home}/Library/MobileDevice/Provisioning Profiles/", provisioning_profile)
        if File.file?(path)
          provisioning_profile_path = path
        end
      end
      if provisioning_profile_path
        out, status = Open3.capture2 %[/usr/libexec/PlistBuddy -c Print:UUID /dev/stdin <<< $(security cms -D -i "#{provisioning_profile_path}")]
        provisioning_profile_uuid = out.strip if status.success?

        out, status = Open3.capture2 %[/usr/libexec/PlistBuddy -c Print:Name /dev/stdin <<< $(security cms -D -i "#{provisioning_profile_path}")]
        provisioning_profile_name = out.strip if status.success?
      else
        provisioning_profile_name = provisioning_profile
      end
      [provisioning_profile_path, provisioning_profile_uuid, provisioning_profile_name]
    end
  end
end
