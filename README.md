# cordova-plugin-wechat

A Capacitor-compatible Cordova plugin, a JS version of Wechat SDK

## Features

* check wechat client is installed;
* open wechat auth;

## Install

* Run the following in the appropriate Capacitor directory:

  ```shell
  yarn add cordova-plugin-wechat@github:quanticedu/cordova-plugin-wechat
  ```

* Configure appropriate variables in `capacitor.config.json`:

  ```json
  {
    ...
    "cordova": {
      "preferences": {
        ...
        "WECHATAPPID": "<your_wechat-app_id>",
        "UNIVERSALLINK": "<your_universal_link>",
        ...
      }
    },
    ...
  }
  ```

* Run `yarn cap sync` in the appopriate Capacitor directory

### !!!IMPORTANT NOTE FOR ANDROID!!!

* If using a version of Capacitor less than v6.1, the `capacitor:sync:before` hook that executes `./scripts/android-install.js` in this plugin won't get executed automatically. For this reason, we export an `android-install` execute via the `bin` property in this project's `package.json`.
* In your Capacitor project's `package.json` file, you'll want to manually add a `capacitor:sync:before` hook that executes `android-install`, like so:

  ```json
    {
      ...
      "scripts": {
        ...
        "capacitor:sync:before": "android-install",
        ...
      }
      ...
    }
  ```

  * You can choose to commit the resultant `android/app/src/main/java/com/package/name/wxapi/WXEntryActivity.java` to version control, or not. 

## Usage

### Check if wechat is installed

```Javascript
Wechat.isInstalled(function (installed) {
    alert("Wechat installed: " + (installed ? "Yes" : "No"));
}, function (reason) {
    alert("Failed: " + reason);
});
```

### Authenticate using Wechat

```Javascript
var scope = "snsapi_userinfo",
    state = "_" + (+new Date());
Wechat.auth(scope, state, function (response) {
    // you may use response.code to get the access token.
    alert(JSON.stringify(response));
}, function (reason) {
    alert("Failed: " + reason);
});
```

## LICENSE

[MIT LICENSE](http://opensource.org/licenses/MIT)
