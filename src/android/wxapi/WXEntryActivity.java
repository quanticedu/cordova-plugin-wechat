package xu.li.cordova.wechat.wxapi;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;

import com.tencent.mm.opensdk.constants.ConstantsAPI;
import com.tencent.mm.opensdk.modelbase.BaseReq;
import com.tencent.mm.opensdk.modelbase.BaseResp;
import com.tencent.mm.opensdk.modelmsg.SendAuth;
import com.tencent.mm.opensdk.openapi.IWXAPIEventHandler;

import org.apache.cordova.CallbackContext;
import org.json.JSONException;
import org.json.JSONObject;


import xu.li.cordova.wechat.Wechat;

/**
 * Created by xu.li<AthenaLightenedMyPath@gmail.com> on 9/1/15.
 */
public class WXEntryActivity extends Activity implements IWXAPIEventHandler {

    @Override
    public void onCreate(Bundle savedInstanceState) {
        Log.d(Wechat.TAG, "WXEntryActivity onCreate");
        super.onCreate(savedInstanceState);
        Wechat.wxAPI.handleIntent(getIntent(), this);
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        Wechat.wxAPI.handleIntent(getIntent(), this);
    }

    @Override
    public void onResp(BaseResp resp) {
        Log.d(Wechat.TAG, String.format("onResp is called. Response: %s.", resp.toString()));

        CallbackContext ctx = Wechat.currentCallbackContext;

        if (ctx == null) {
            Log.e(Wechat.TAG, "Wechat.currentCallbackContext null in onResp!");
            return;
        }

        switch (resp.errCode) {
            case BaseResp.ErrCode.ERR_OK:
                switch (resp.getType()) {
                    case ConstantsAPI.COMMAND_SENDAUTH:
                        auth(resp);
                        break;
                    default:
                        ctx.success();
                        break;
                }
                break;
            case BaseResp.ErrCode.ERR_USER_CANCEL:
                ctx.error(Wechat.ERROR_WECHAT_RESPONSE_USER_CANCEL);
                break;
            case BaseResp.ErrCode.ERR_AUTH_DENIED:
                ctx.error(Wechat.ERROR_WECHAT_RESPONSE_AUTH_DENIED);
                break;
            case BaseResp.ErrCode.ERR_SENT_FAILED:
                ctx.error(Wechat.ERROR_WECHAT_RESPONSE_SENT_FAILED);
                break;
            case BaseResp.ErrCode.ERR_UNSUPPORT:
                ctx.error(Wechat.ERROR_WECHAT_RESPONSE_UNSUPPORT);
                break;
            case BaseResp.ErrCode.ERR_COMM:
                ctx.error(Wechat.ERROR_WECHAT_RESPONSE_COMMON);
                break;
            default:
                ctx.error(Wechat.ERROR_WECHAT_RESPONSE_UNKNOWN);
                break;
        }

        finish();
    }

    @Override
    public void onReq(BaseReq req) {
        // Noop
        finish();
    }

    protected void auth(BaseResp resp) {
        SendAuth.Resp res = ((SendAuth.Resp) resp);

        Log.d(Wechat.TAG, res.toString());

        JSONObject response = new JSONObject();
        try {
            response.put("code", res.code);
            response.put("state", res.state);
            response.put("country", res.country);
            response.put("lang", res.lang);
        } catch (JSONException e) {
            Log.e(Wechat.TAG, e.getMessage());
        }

        Wechat.currentCallbackContext.success(response);
    }
}