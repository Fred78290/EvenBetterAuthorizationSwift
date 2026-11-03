#! /bin/sh

# <codex>
# <abstract>Script to remove everything installed by the sample.</abstract>
# </codex>

# This uninstalls everything installed by the sample.  It's useful when testing to ensure that 
# you start from scratch.

# The helper is a launch daemon registered with SMAppService, so there is nothing to delete from
# /Library/LaunchDaemons or /Library/PrivilegedHelperTools.  Stop it if it's running.
sudo launchctl bootout system/com.aldunelabs.samplecode.authorization

sudo security -q authorizationdb remove "com.aldunelabs.samplecode.authorization.readLicenseKey"
sudo security -q authorizationdb remove "com.aldunelabs.samplecode.authorization.writeLicenseKey"
sudo security -q authorizationdb remove "com.aldunelabs.samplecode.authorization.startWebService"

sudo defaults delete com.aldunelabs.samplecode.authorization licenseKey

# Finally, remove the app's background item in System Settings > General > Login Items & Extensions
# (or run "sudo sfltool resetbtm" to reset all background items).
