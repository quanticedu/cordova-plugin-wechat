# cordova-plugin-wechat

A Capacitor-compatible Cordova plugin, a JS version of Wechat SDK

## Features

* check wechat client is installed;
* open wechat auth;

## Install

In the appropriate Capacitor directory:

```shell
yarn add cordova-plugin-wechat@github:quanticedu/cordova-plugin-wechat
```

Configure appropriate variable in `capacitor.config.json`:

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

```shell
yarn cap sync
```

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
