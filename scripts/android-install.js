#!/usr/bin/env node

// The purpose of this script is to take the src/android/WXEntryActivity.java and place it under the 
// parent Capacitor's project namespace at, e.g. com.package.wxapi.WXEntryActivity.java. It also replaces
// __PACKAGE_NAME__ with the parent Capacitor project's appId (package name).
// 
// NOTE: this script will NOT get executed by the `capacitor:sync:before` script in package.json UNLESS
//       the parent Capacitor project is on @capacitor v6.1+!

var fs = require('fs');
var path = require('path');

// Nothing to do here...
if (process.env.CAPACITOR_PLATFORM_NAME != 'android') {
    return;
}

var { appId } = JSON.parse(process.env.CAPACITOR_CONFIG);
var appIdToDirectory = appId.replace(/\./g, '/'); // com.package.name to com/package/name
var destination = path.join(process.env.CAPACITOR_ROOT_DIR, 'android', 'app', 'src', 'main', 'java', appIdToDirectory, 'wxapi');
var fileName = 'WXEntryActivity.java';
var sourcePath = path.join(__dirname, '..', 'src', 'android', fileName);

// Read the src/android/WXEntryActivity.java file and replace __PACKAGE_NAME__ with the parent
// Capacitor project's package name.
const mutatedFileContents = fs.readFileSync(sourcePath, 'utf8').replace(/__PACKAGE_NAME__/g, appId);

// Write the file to the parent Capacitor project's directory / namespace.
if (!fs.existsSync(destination)) {
    fs.mkdirSync(destination, { recursive: true });
}
fs.writeFileSync(path.join(destination, fileName), mutatedFileContents)