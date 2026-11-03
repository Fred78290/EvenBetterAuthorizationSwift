#! /bin/sh

# <codex>
# <abstract>Script to remove everything installed by the sample.</abstract>
# </codex>

# This uninstalls everything installed by the sample.  It's useful when testing to ensure that 
# you start from scratch.

sudo launchctl unload /Library/LaunchDaemons/com.aldunelabs.com.authorization.plist
sudo rm /Library/LaunchDaemons/com.aldunelabs.com.authorization.plist
sudo rm /Library/PrivilegedHelperTools/com.aldunelabs.com.authorization

sudo security -q authorizationdb remove "com.aldunelabs.samplecode.authorization.readLicenseKey"
sudo security -q authorizationdb remove "com.aldunelabs.samplecode.authorization.writeLicenseKey"
sudo security -q authorizationdb remove "com.aldunelabs.samplecode.authorization.startWebService"

sudo defaults delete com.aldunelabs.com.authorization licenseKey
