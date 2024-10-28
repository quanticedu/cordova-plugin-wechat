//
//  CDVWechat.m
//  cordova-plugin-wechat
//
//  Created by xu.li on 12/23/13.
//
//

#import "CDVWechat.h"

static int const MAX_THUMBNAIL_SIZE = 320;

@implementation CDVWechat

#pragma mark "API"
- (void)pluginInitialize {
    NSString* appId = [[self.commandDelegate settings] objectForKey:@"wechatappid"];
    NSString* universalLink = [[self.commandDelegate settings] objectForKey:@"universallink"];
    
    if (appId && ![appId isEqualToString:self.wechatAppId]) {
        self.wechatAppId = appId;
        [WXApi registerApp: appId universalLink: universalLink];
        // Register the handleOpenURL selector to handle async notifications coming from the WXAPI.
        // When we receive an async notification, self.handleOpenURL will call WXApi.handleOpenURL,
        // which will in turn call self.onResp which is responsible for sending the plugin result
        // to the native app.
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleOpenURL:) name:CDVPluginHandleOpenURLNotification object:nil];
        
        NSLog(@"cordova-plugin-wechat has been initialized. Wechat SDK Version: %@. WECHATAPPID: %@. UNIVERSALLINK: %@", [WXApi getApiVersion], appId, universalLink);
    }

    sharedWechatPlugin = self;
}

- (void)isWXAppInstalled:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:[WXApi isWXAppInstalled]];

    [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
}

- (void)sendAuthRequest:(CDVInvokedUrlCommand *)command
{

    SendAuthReq* req =[[SendAuthReq alloc] init];

    // scope
    if ([command.arguments count] > 0)
    {
        req.scope = [command.arguments objectAtIndex:0];
    }
    else
    {
        req.scope = @"snsapi_userinfo";
    }

    // state
    if ([command.arguments count] > 1)
    {
        req.state = [command.arguments objectAtIndex:1];
    }

    [WXApi sendAuthReq:req viewController:self.viewController delegate:self completion:^(BOOL success) {
        if(success) {
            self.currentCallbackId = command.callbackId;
        } else {
            [self failWithCallbackID:command.callbackId withMessage:@"发送请求失败"];
        }
    }];
}



#pragma mark "WXApiDelegate"

/**
 * On wechat request
 */
- (void)onReq:(BaseReq *)req
{
    // Noop
    NSLog(@"%@", req);
}

- (void)onResp:(BaseResp *)resp
{
    BOOL success = NO;
    NSString *message = @"Unknown";
    NSDictionary *response = nil;

    switch (resp.errCode)
    {
        case WXSuccess:
            success = YES;
            break;

        case WXErrCodeCommon:
            message = @"普通错误";
            break;

        case WXErrCodeUserCancel:
            message = @"用户点击取消并返回";
            break;

        case WXErrCodeSentFail:
            message = @"发送失败";
            break;

        case WXErrCodeAuthDeny:
            message = @"授权失败";
            break;

        case WXErrCodeUnsupport:
            message = @"微信不支持";
            break;

        default:
            message = @"未知错误";
    }

    if (success)
    {
        if ([resp isKindOfClass:[SendAuthResp class]])
        {
            // fix issue that lang and country could be nil for iPhone 6 which caused crash.
            SendAuthResp* authResp = (SendAuthResp*)resp;
            response = @{
                         @"code": authResp.code != nil ? authResp.code : @"",
                         @"state": authResp.state != nil ? authResp.state : @"",
                         @"lang": authResp.lang != nil ? authResp.lang : @"",
                         @"country": authResp.country != nil ? authResp.country : @"",
                         };
            CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:response];

            [self.commandDelegate sendPluginResult:commandResult callbackId:self.currentCallbackId];
        }
        else
        {
            [self successWithCallbackID:self.currentCallbackId];
        }
    }
    else
    {
        [self failWithCallbackID:self.currentCallbackId withMessage:message];
    }

    [self pluginInitialize];
    self.currentCallbackId = nil;
}

#pragma mark "CDVPlugin Overrides"

- (void)handleOpenURL:(NSNotification *)notification
{
    NSURL* url = [notification object];

    if ([url isKindOfClass:[NSURL class]] && [url.scheme isEqualToString:self.wechatAppId])
    {
        [WXApi handleOpenURL:url delegate:self];
    }
}

#pragma mark "Private methods"

- (void)successWithCallbackID:(NSString *)callbackID
{
    [self successWithCallbackID:callbackID withMessage:@"OK"];
}

- (void)successWithCallbackID:(NSString *)callbackID withMessage:(NSString *)message
{
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:message];
    [self.commandDelegate sendPluginResult:commandResult callbackId:callbackID];
}

- (void)failWithCallbackID:(NSString *)callbackID withError:(NSError *)error
{
    [self failWithCallbackID:callbackID withMessage:[error localizedDescription]];
}

- (void)failWithCallbackID:(NSString *)callbackID withMessage:(NSString *)message
{
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
    [self.commandDelegate sendPluginResult:commandResult callbackId:callbackID];
}

- (BOOL)handleUserActivity:(NSUserActivity *)userActivity {
   return [WXApi handleOpenUniversalLink:userActivity delegate:self];
}

- (BOOL)handleWechatOpenURL:(NSURL *)url  {
    return [WXApi handleOpenURL:url delegate:self];
}

@end
