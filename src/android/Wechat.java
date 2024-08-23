package xu.li.cordova.wechat;

import android.app.Activity;
import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;

import com.tencent.mm.opensdk.modelmsg.SendAuth;
import com.tencent.mm.opensdk.openapi.IWXAPI;
import com.tencent.mm.opensdk.openapi.WXAPIFactory;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaArgs;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaPreferences;
import org.apache.cordova.PluginResult;
import org.json.JSONException;
import org.json.JSONObject;

public class Wechat extends CordovaPlugin {

    public static final String TAG = "Cordova.Plugin.Wechat";

    public static final String PREFS_NAME = "Cordova.Plugin.Wechat";
    public static final String WXAPPID_PROPERTY_KEY = "wechatappid";
    
    public static final String ERROR_SEND_REQUEST_FAILED = "发送请求失败";
    public static final String ERROR_WECHAT_RESPONSE_COMMON = "普通错误";
    public static final String ERROR_WECHAT_RESPONSE_USER_CANCEL = "用户点击取消并返回";
    public static final String ERROR_WECHAT_RESPONSE_SENT_FAILED = "发送失败";
    public static final String ERROR_WECHAT_RESPONSE_AUTH_DENIED = "授权失败";
    public static final String ERROR_WECHAT_RESPONSE_UNSUPPORT = "微信不支持";
    public static final String ERROR_WECHAT_RESPONSE_UNKNOWN = "未知错误";

    protected static CallbackContext currentCallbackContext;
    protected static IWXAPI wxAPI;
    protected static String appId;
    protected static CordovaPreferences wx_preferences;
    private static Wechat instance;
    private static Activity cordovaActivity;
    private static String extinfo;

    @Override
    protected void pluginInitialize() {

        super.pluginInitialize();

        String id = getAppId(preferences);

        // save app id
        saveAppId(cordova.getActivity(), id);

        // init api
        initWXAPI();

        // 保存引用
        instance = this;
        cordovaActivity = cordova.getActivity();
        if (extinfo != null) {
            transmitLaunchFromWX(extinfo);
        }

        Log.d(TAG, "plugin initialized.");
    }

    protected void initWXAPI() {
        IWXAPI api = getWxAPI(cordova.getActivity());
        if (wx_preferences == null) {
            wx_preferences = preferences;
        }
        if (api != null) {
            api.registerApp(getAppId(preferences));
        }
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        instance = null;
        cordovaActivity = null;
    }

    /**
     * Get weixin api
     *
     * @param ctx
     * @return
     */
    public static IWXAPI getWxAPI(Context ctx) {
        if (wxAPI == null) {
            String appId = getSavedAppId(ctx);

            if (!appId.isEmpty()) {
                wxAPI = WXAPIFactory.createWXAPI(ctx, appId, true);
            }
        }

        return wxAPI;
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

        this.currentCallbackContext = callbackContext;

        if (action.equals("sendAuthRequest")) {
            sendAuthRequest(args);
            return true;
        } else if (action.equals("isWXAppInstalled")) {
            isInstalled();
            return true;
        } 
        return false;
    }

    protected boolean sendAuthRequest(CordovaArgs args) {
        final IWXAPI api = getWxAPI(cordova.getActivity());

        final SendAuth.Req req = new SendAuth.Req();
        try {
            req.scope = args.getString(0);
            req.state = args.getString(1);
        } catch (JSONException e) {
            Log.e(TAG, e.getMessage());

            req.scope = "snsapi_userinfo";
            req.state = "wechat";
        }

        if (api.sendReq(req)) {
            Log.i(TAG, "Auth request has been sent successfully.");

            // send no result
            sendNoResultPluginResult();
        } else {
            Log.i(TAG, "Auth request has been sent unsuccessfully.");

            // send error
            this.callbackContext.error(ERROR_SEND_REQUEST_FAILED);
        }
    }

    protected boolean isInstalled() {
        final IWXAPI api = getWxAPI(cordova.getActivity());

        if (!api.isWXAppInstalled()) {
            this.callbackContext.success(0);
        } else {
            this.callbackContext.success(1);
        }
    }

    public static String getAppId(CordovaPreferences f_preferences) {
        if (appId == null) {
            if (f_preferences != null) {
                appId = f_preferences.getString(WXAPPID_PROPERTY_KEY, "");
            } else if (wx_preferences != null) {
                appId = wx_preferences.getString(WXAPPID_PROPERTY_KEY, "");
            }
        }

        return appId;
    }

    /**
     * Get saved app id
     *
     * @param ctx
     * @return
     */
    public static String getSavedAppId(Context ctx) {
        SharedPreferences settings = ctx.getSharedPreferences(PREFS_NAME, 0);
        return settings.getString(WXAPPID_PROPERTY_KEY, "");
    }

    /**
     * Save app id into SharedPreferences
     *
     * @param ctx
     * @param id
     */
    public static void saveAppId(Context ctx, String id) {
        if (id != null && id.isEmpty()) {
            return;
        }

        SharedPreferences settings = ctx.getSharedPreferences(PREFS_NAME, 0);
        SharedPreferences.Editor editor = settings.edit();
        editor.putString(WXAPPID_PROPERTY_KEY, id);
        editor.commit();
    }

    public static CallbackContext getCurrentCallbackContext() {
        return this.currentCallbackContext;
    }

    private void sendNoResultPluginResult() {
        // send no result and keep callback
        PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
        result.setKeepCallback(true);
        this.currentCallbackContext.sendPluginResult(result);
    }

}
