package xu.li.cordova.wechat;

import android.util.Log;

import com.tencent.mm.opensdk.modelmsg.SendAuth;
import com.tencent.mm.opensdk.openapi.IWXAPI;
import com.tencent.mm.opensdk.openapi.WXAPIFactory;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaArgs;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaPreferences;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;
import org.json.JSONException;
import org.json.JSONObject;

import androidx.activity.result.ActivityResult;
import androidx.activity.result.ActivityResultCallback;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.app.AppCompatActivity;

import xu.li.cordova.wechat.wxapi.WXEntryActivity;

public class Wechat extends CordovaPlugin {

    public static final String TAG = "Cordova.Plugin.Wechat";

    public static final String WXAPPID_PROPERTY_KEY = "wechatappid";

    public static final String ERROR_SEND_REQUEST_FAILED = "发送请求失败";
    public static final String ERROR_WECHAT_RESPONSE_COMMON = "普通错误";
    public static final String ERROR_WECHAT_RESPONSE_USER_CANCEL = "用户点击取消并返回";
    public static final String ERROR_WECHAT_RESPONSE_SENT_FAILED = "发送失败";
    public static final String ERROR_WECHAT_RESPONSE_AUTH_DENIED = "授权失败";
    public static final String ERROR_WECHAT_RESPONSE_UNSUPPORT = "微信不支持";
    public static final String ERROR_WECHAT_RESPONSE_UNKNOWN = "未知错误";

    public static CallbackContext currentCallbackContext;
    public static IWXAPI wxAPI;
    protected static String appId;
    private static Wechat instance;
    private static AppCompatActivity cordovaActivity;
    private static String extinfo;

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);

        // save app id
        appId = getAppId(preferences);

        // init api
        wxAPI = WXAPIFactory.createWXAPI(cordova.getActivity(), appId, true);

        // register the app
        wxAPI.registerApp(appId);

        // 保存引用
        instance = this;
        cordovaActivity = cordova.getActivity();
        if (extinfo != null) {
            transmitLaunchFromWX(extinfo);
        }
        Log.d(TAG, String.format("cordova-plugin-wechat has been initialized. Wechat SDK Version: %s. WECHATAPPID: %s.", wxAPI.getWXAppSupportAPI(), appId));

        // Register the main activity to handle a result from the WXEntryActivity activity
        cordovaActivity.registerForActivityResult(
                new ActivityResultContracts.StartActivityForResult(),
                new ActivityResultCallback<ActivityResult>() {
                    public void onActivityResult(ActivityResult result) {
                        Log.i(Wechat.TAG, "ActivityResultCallback called");
                        wxAPI.handleIntent(result.getData(), new WXEntryActivity());
                    }
                });
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        currentCallbackContext = null;
        wxAPI = null;
        appId = null;
        instance = null;
        cordovaActivity = null;
        extinfo = null;
    }

    public static void transmitLaunchFromWX(String extinfo) {
        if (instance == null) {
            Log.w(Wechat.TAG, "instance is null.");
            Wechat.extinfo = extinfo;
            return;
        }
        Wechat.extinfo = null;

        JSONObject data = getLaunchFromWXObject(extinfo);
        String format = "javascript:cordova.fireDocumentEvent('%s', %s);";
        final String js = String.format(format, "wechat.launchFromWX", data);
        if (cordovaActivity != null) {
            cordovaActivity.runOnUiThread(() -> instance.webView.loadUrl(js));
        } else {
            Log.w(Wechat.TAG, "cordovaActivity is null.");
        }
    }

    private static JSONObject getLaunchFromWXObject(String extinfo) {
        JSONObject data = new JSONObject();
        try {
            data.put("extinfo", extinfo);
        } catch (JSONException e) {
            e.printStackTrace();
        }
        return data;
    }

    @Override
    public boolean execute(String action, CordovaArgs args, CallbackContext callbackContext) throws JSONException {
        Log.d(TAG, String.format("%s is called. Callback ID: %s.", action, callbackContext.getCallbackId()));

        currentCallbackContext = callbackContext;

        if (action.equals("sendAuthRequest")) {
            return sendAuthRequest(args);
        } else if (action.equals("isWXAppInstalled")) {
            return isInstalled();
        }
        return false;
    }

    protected boolean sendAuthRequest(CordovaArgs args) {
        final SendAuth.Req req = new SendAuth.Req();

        try {
            req.scope = args.getString(0);
            req.state = args.getString(1);
        } catch (JSONException e) {
            Log.e(TAG, e.getMessage());

            req.scope = "snsapi_userinfo";
            req.state = "wechat";
        }

        if (wxAPI.sendReq(req)) {
            Log.i(TAG, "Auth request has been sent successfully.");

            // send no result and keep callback
            PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
            result.setKeepCallback(true);
            currentCallbackContext.sendPluginResult(result);
        } else {
            Log.i(TAG, "Auth request has been sent unsuccessfully.");

            // send error
            currentCallbackContext.error(ERROR_SEND_REQUEST_FAILED);
        }

        return true;
    }

    protected boolean isInstalled() {
        if (!wxAPI.isWXAppInstalled()) {
            currentCallbackContext.success(0);
        } else {
            currentCallbackContext.success(1);
        }
        return true;
    }

    public static String getAppId(CordovaPreferences f_preferences) {
        if (appId == null && f_preferences != null) {
            appId = f_preferences.getString(WXAPPID_PROPERTY_KEY, "");
        }

        return appId;
    }

    public static CallbackContext getCurrentCallbackContext() {
        return currentCallbackContext;
    }

    public static IWXAPI getWXAPI() {
        return wxAPI;
    }

}
