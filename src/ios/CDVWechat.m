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

- (void)jumpToWechat:(CDVInvokedUrlCommand *)command
{
    // check arguments
    NSString *url = [command.arguments objectAtIndex:0];
    if (!url || ![url hasPrefix:@"weixin://"])
    {
        [self failWithCallbackID:command.callbackId withMessage:@"参数格式错误"];
        return ;
    }

    NSURL *formatUrl = [NSURL URLWithString:[url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    if ([[UIApplication sharedApplication] canOpenURL:formatUrl]) {
        NSDictionary *options = @{UIApplicationOpenURLOptionUniversalLinksOnly : @YES};
        [[UIApplication sharedApplication] openURL:formatUrl options:options completionHandler:nil];
    } else{
        [self failWithCallbackID:command.callbackId withMessage:@"未安装微信或其他错误"];
    }
    return ;
}



#pragma mark "WXApiDelegate"

-(NSString*)toJsonString: (NSDictionary *)params
{
    NSError  *error;
    NSData   *data       = [NSJSONSerialization dataWithJSONObject:params options:0 error:&error];
    NSString *jsonString = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    return jsonString;
}

/**
 * On wechat request
 */
- (void)onReq:(BaseReq *)req
{
    NSLog(@"%@", req);
    
    // 获取开放标签传递的extinfo数据逻辑
    if ([req isKindOfClass:[LaunchFromWXReq class]])
    {
        WXMediaMessage *msg = ((LaunchFromWXReq*)req).message;
        NSString *extinfo = msg.messageExt;
        
        NSLog(@"extinfo = %@", extinfo);
        if(sharedWechatPlugin) {
            NSDictionary *params = @{@"extinfo": extinfo};
            dispatch_async(dispatch_get_main_queue(), ^{
              [sharedWechatPlugin.commandDelegate evalJs:[NSString stringWithFormat:@"cordova.fireDocumentEvent('wechat.%@',%@)",
                                                         WechatDocumentEvent_LaunchFromWXReq,
                                                         [self toJsonString:params]]];
            });
        }
    }
}

- (void)onResp:(WXLaunchMiniProgramResp *)resp
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
        else if ([resp isKindOfClass:[WXLaunchMiniProgramResp class]])
        {
            NSString *extMsg = resp.extMsg;
            response = @{
                         @"extMsg": extMsg
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

- (NSData *)getNSDataFromURL:(NSString *)url
{
    NSData *data = nil;

    if ([url hasPrefix:@"http://"] || [url hasPrefix:@"https://"])
    {
        data = [NSData dataWithContentsOfURL:[NSURL URLWithString:url]];
    }
    else if ([url hasPrefix:@"data:image"])
    {
        // a base 64 string
        NSURL *base64URL = [NSURL URLWithString:url];
        data = [NSData dataWithContentsOfURL:base64URL];
    }
    else if ([url rangeOfString:@"temp:"].length != 0)
    {
        url =  [NSTemporaryDirectory() stringByAppendingPathComponent:[url componentsSeparatedByString:@"temp:"][1]];
        data = [NSData dataWithContentsOfFile:url];
    }
    else
    {
        // local file
        url = [[NSBundle mainBundle] pathForResource:[url stringByDeletingPathExtension] ofType:[url pathExtension]];
        data = [NSData dataWithContentsOfFile:url];
    }

    return data;
}

- (UIImage *)getUIImageFromURL:(NSString *)url
{
    NSData *data = [self getNSDataFromURL:url];
    UIImage *image = [UIImage imageWithData:data];

    if (image.size.width > MAX_THUMBNAIL_SIZE || image.size.height > MAX_THUMBNAIL_SIZE)
    {
        CGFloat width = 0;
        CGFloat height = 0;

        // calculate size
        if (image.size.width > image.size.height)
        {
            width = MAX_THUMBNAIL_SIZE;
            height = width * image.size.height / image.size.width;
        }
        else
        {
            height = MAX_THUMBNAIL_SIZE;
            width = height * image.size.width / image.size.height;
        }

        // scale it
        UIGraphicsBeginImageContext(CGSizeMake(width, height));
        [image drawInRect:CGRectMake(0, 0, width, height)];
        UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        return scaled;
    }

    return image;
}

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

-  (void)openMiniProgram:(CDVInvokedUrlCommand *)command
{
    NSDictionary *params = [command.arguments objectAtIndex:0];
    WXLaunchMiniProgramReq *launchMiniProgramReq = [WXLaunchMiniProgramReq object];
    launchMiniProgramReq.userName = [params objectForKey:@"userName"];  //拉起的小程序的username
    launchMiniProgramReq.path = [params objectForKey:@"path"];    //拉起小程序页面的可带参路径，不填默认拉起小程序首页
    launchMiniProgramReq.miniProgramType = (int)[[params objectForKey:@"miniprogramType"] integerValue]; //拉起小程序的类型
    [WXApi sendReq:launchMiniProgramReq completion:^(BOOL success) {
        if(success) {
             self.currentCallbackId = command.callbackId;
        } else {
            [self failWithCallbackID:command.callbackId withMessage:@"打开请求失败"];
        }
    }];
}

- (BOOL)handleUserActivity:(NSUserActivity *)userActivity {
   return [WXApi handleOpenUniversalLink:userActivity delegate:self];
}

- (BOOL)handleWechatOpenURL:(NSURL *)url  {
    return [WXApi handleOpenURL:url delegate:self];
}

@end
