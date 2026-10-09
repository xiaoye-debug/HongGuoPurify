#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import <math.h>
#import <string.h>
#import <stdlib.h>

#pragma mark - Preferences and feature catalog

static NSString * const kHGPreferencesPath = @"/var/mobile/Library/Preferences/com.xiaoye.hongguopurify.plist";
static NSString * const kHGPreferencesChanged = @"com.xiaoye.hongguopurify/preferences-changed";
static NSString * const kHGFeaturePrefix = @"feature.";

static NSArray<NSString *> *HGFeatureTitles(void) {
    static NSArray *a; static dispatch_once_t once;
    dispatch_once(&once, ^{
        a = @[
            @"阅读去广告", @"听书去广告", @"推广入口净化", @"关闭评价邀请", @"隐藏短剧金币挂件", @"隐藏章末圈子",
            @"减少通知权限提醒", @"减少小组件提醒", @"会员状态显示优化（不改变真实权益）", @"隐藏作者的话", @"隐藏本章讨论入口", @"隐藏章末圈子按钮",
            @"隐藏章末送礼物", @"隐藏最新章节三个按钮", @"隐藏底部福利导航", @"允许快速跳过激励广告", @"隐藏我的页福利卡片", @"返回标题固定为章节名",
            @"隐藏我的页推荐卡片", @"隐藏我的页发帖按钮", @"隐藏底部短剧导航", @"关闭短剧进入自动播放", @"隐藏书城发帖按钮", @"隐藏书架漫剧推荐",
            @"隐藏书架今日听读时长", @"隐藏书架导入本地书入口", @"短剧去广告", @"隐藏发送弹幕按钮", @"隐藏作者声明", @"隐藏系列剧集入口",
            @"隐藏爆剧标志", @"隐藏热评", @"隐藏剧标签", @"隐藏顶部导航", @"隐藏 AI 短剧备案号", @"隐藏我的页顶部快捷入口整组",
            @"进度条显示时长", @"允许强制本地下载", @"预留功能 38", @"预留功能 39", @"隐藏视频榜单排名", @"隐藏红点提醒",
            @"隐藏侧边栏游戏中心", @"自动使用默认倍速播放", @"播放时自动清屏", @"暂停时退出清屏模式"
        ];
    }); return a;
}

static NSArray<NSString *> *HGFeatureDetails(void) {
    static NSArray *a; static dispatch_once_t once;
    dispatch_once(&once, ^{
        a = @[
            @"尝试隐藏阅读页面的广告位。", @"尝试隐藏听书信息流广告。", @"清理小游戏、直播、商城等推广入口。", @"减少评价/评分邀请。", @"隐藏短剧金币福利挂件与引导气泡。", @"隐藏章节结束区域的圈子帖子卡片。",
            @"减少通知授权提示；不会修改系统通知授权状态。", @"减少小组件引导；不会伪造系统组件状态。", @"不伪造会员身份、不修改订阅或服务端权益。", @"隐藏章节末尾作者寄语。", @"隐藏本章讨论入口。", @"隐藏章末圈子快捷按钮。",
            @"隐藏送礼物、打赏入口。", @"隐藏章末催更下方的快捷按钮，尽量保留催更与更新历史。", @"隐藏首页底部福利入口。", @"尽可能展示并使用广告原生关闭流程；不伪造广告奖励。", @"隐藏我的页面整张福利卡片，保留下方其他内容。", @"将阅读页左上角标题调整为当前章节名（需目标版本支持）。",
            @"隐藏我的页关注推荐卡片。", @"隐藏我的页面发帖悬浮按钮。", @"隐藏首页底部短剧入口。", @"进入短剧页面时先暂停，避免自动开始播放。", @"隐藏书城发帖悬浮按钮及展开入口。", @"隐藏书架顶部改编剧/漫剧推荐横幅。",
            @"隐藏书架的今日已看/听读时长展示。", @"只隐藏导入本地书入口，不删除已导入的书。", @"尝试拦截短剧广告配置和广告装饰视图。", @"隐藏发送弹幕按钮。", @"隐藏作者声明。", @"隐藏系列剧集入口。",
            @"隐藏爆剧标志。", @"隐藏热评区域。", @"隐藏短剧标签。", @"隐藏顶部导航栏。", @"隐藏 AI 短剧备案号展示。", @"隐藏我的页顶部快捷入口组。",
            @"在进度条附近显示当前时长/总时长（需要目标版本控件支持）。", @"显示应用原生下载入口；不会绕过服务器授权或付费限制。", @"该编号在原版功能目录中没有可识别的标题。", @"该编号在原版功能目录中没有可识别的标题。", @"隐藏视频榜单排名。", @"隐藏侧栏和导航中的红点提醒。",
            @"隐藏侧边栏游戏中心入口。", @"对支持倍速配置的播放器应用默认倍速。", @"进入播放时尝试启用清爽模式。", @"暂停时尝试退出清爽模式。"
        ];
    }); return a;
}

static NSMutableDictionary *gHGPrefs;
static NSMutableDictionary<NSString *, NSValue *> *gHGOriginalIMPs;
static NSMutableDictionary<NSString *, NSNumber *> *gHGHookFeatures;
static NSMutableDictionary<NSString *, NSNumber *> *gHGHookActions;
static NSMutableSet<NSString *> *gHGInstalled;
static BOOL gHGSettingsButtonAdded;

static NSDictionary *HGDefaultPreferences(void) {
    return @{@"enabled": @YES, @"blockAds": @YES, @"cleanUI": @NO,
             @"defaultSpeed": @1.5, @"lockResolution": @0, @"lockResolutionEnabled": @NO, @"startupTab": @0, @"startupTabEnabled": @NO,
             @"startupTop": @NO, @"mergedAI104": @NO};
}

static void HGLoadPreferences(void) {
    NSDictionary *disk = [NSDictionary dictionaryWithContentsOfFile:kHGPreferencesPath];
    gHGPrefs = [NSMutableDictionary dictionaryWithDictionary:HGDefaultPreferences()];
    if ([disk isKindOfClass:NSDictionary.class]) [gHGPrefs addEntriesFromDictionary:disk];
}

static void HGSavePreferences(void) {
    if (!gHGPrefs) HGLoadPreferences();
    [NSFileManager.defaultManager createDirectoryAtPath:@"/var/mobile/Library/Preferences" withIntermediateDirectories:YES attributes:nil error:nil];
    [gHGPrefs writeToFile:kHGPreferencesPath atomically:YES];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)kHGPreferencesChanged, NULL, NULL, YES);
}

static BOOL HGConfiguredFeatureEnabled(NSInteger featureID) {
    if (featureID < 0 || featureID >= (NSInteger)HGFeatureTitles().count) return NO;
    NSString *key=[kHGFeaturePrefix stringByAppendingFormat:@"%ld",(long)featureID];
    id stored=gHGPrefs[key]; if(stored) return [stored boolValue];
    return featureID==0 || featureID==1 || featureID==26;
}

static BOOL HGEnabled(NSInteger featureID) {
    if (featureID < 0 || featureID >= (NSInteger)HGFeatureTitles().count) return NO;
    if (![gHGPrefs[@"enabled"] boolValue]) return NO;
    NSString *key = [kHGFeaturePrefix stringByAppendingFormat:@"%ld", (long)featureID];
    id stored = gHGPrefs[key];
    if (stored) return [stored boolValue];
    // Conservative defaults: ad controls on, cosmetic removals off until selected.
    return featureID == 0 || featureID == 1 || featureID == 26;
}

static NSString *HGKey(Class cls, SEL sel) {
    return [NSString stringWithFormat:@"%@::%@", NSStringFromClass(cls), NSStringFromSelector(sel)];
}

static IMP HGOriginalFor(id self, SEL sel) {
    Class cls = object_getClass(self);
    while (cls) {
        NSValue *v = gHGOriginalIMPs[HGKey(cls, sel)];
        if (v) return (IMP)v.pointerValue;
        cls = class_getSuperclass(cls);
    }
    return NULL;
}

static NSInteger HGFeatureFor(id self, SEL sel) {
    Class cls = object_getClass(self);
    while (cls) {
        NSNumber *n = gHGHookFeatures[HGKey(cls, sel)];
        if (n) return n.integerValue;
        cls = class_getSuperclass(cls);
    }
    return -1;
}

static NSInteger HGActionFor(id self, SEL sel) {
    Class cls = object_getClass(self);
    while (cls) {
        NSNumber *n = gHGHookActions[HGKey(cls, sel)];
        if (n) return n.integerValue;
        cls = class_getSuperclass(cls);
    }
    return 0;
}

enum { HGActionReturnFalse = 1, HGActionReturnTrue = 2, HGActionSkipVoid = 3, HGActionShowCloseButton = 4, HGActionExitCleanMode = 5, HGActionEnterCleanMode = 6, HGActionOverrideStartupIndex = 7, HGActionOverrideResolution = 8, HGActionFilterGameItem = 9, HGActionReturnNil = 10, HGActionForceHide = 11 };

#pragma mark - ABI-typed hook replacements

static BOOL HGBoolNoArg(id self, SEL _cmd) {
    IMP orig = HGOriginalFor(self, _cmd); NSInteger f = HGFeatureFor(self, _cmd); NSInteger a = HGActionFor(self, _cmd);
    if (f >= 0 && HGEnabled(f)) { if (a == HGActionReturnFalse) return NO; if (a == HGActionReturnTrue) return YES; }
    return orig ? ((BOOL(*)(id,SEL))orig)(self,_cmd) : NO;
}

static NSString *HGDescriptionForModel(id item) {
    if (!item || item == NSNull.null) return @"";
    NSMutableArray *parts=[NSMutableArray arrayWithObject:NSStringFromClass([item class]) ?: @""];
    NSString *desc=[item description]; if(desc.length)[parts addObject:desc];
    for (NSString *prop in @[@"titleString",@"title",@"name",@"schema",@"jumpUrl",@"cellName",@"type",@"redDotId",@"cellType",@"identifier",@"itemId"]) {
        SEL getter=NSSelectorFromString(prop); if(![item respondsToSelector:getter]) continue;
        @try { id value=((id(*)(id,SEL))objc_msgSend)(item,getter); if(value && value!=NSNull.null)[parts addObject:[value description]]; } @catch (__unused NSException *e) {}
    }
    return [[parts componentsJoinedByString:@" "] lowercaseString];
}

static BOOL HGIsGameSidebarItem(id item) {
    NSString *text=HGDescriptionForModel(item);
    return [text containsString:@"game_center"] || [text containsString:@"gamecenter"] || [text containsString:@"游戏中心"] || [text containsString:@"小游戏"] || [text containsString:@"游戏"];
}

static BOOL HGBoolObjectArg(id self, SEL _cmd, id arg) {
    IMP orig = HGOriginalFor(self, _cmd); NSInteger f = HGFeatureFor(self, _cmd); NSInteger a = HGActionFor(self, _cmd);
    if (f >= 0 && HGEnabled(f)) { if (a == HGActionReturnFalse) return NO; if (a == HGActionReturnTrue) return YES; }
    if (f == 42 && a == HGActionFilterGameItem && HGEnabled(42) && HGIsGameSidebarItem(arg)) return NO;
    return orig ? ((BOOL(*)(id,SEL,id))orig)(self,_cmd,arg) : NO;
}

static BOOL HGBoolBoolArg(id self, SEL _cmd, BOOL value) {
    IMP orig = HGOriginalFor(self, _cmd); NSInteger f = HGFeatureFor(self, _cmd); NSInteger a = HGActionFor(self, _cmd);
    if (f >= 0 && HGEnabled(f)) { if (a == HGActionReturnFalse) return NO; if (a == HGActionReturnTrue) return YES; }
    return orig ? ((BOOL(*)(id,SEL,BOOL))orig)(self,_cmd,value) : NO;
}

static BOOL HGBoolIntegerBoolArg(id self, SEL _cmd, NSInteger item, BOOL show) {
    IMP orig=HGOriginalFor(self,_cmd);
    if (HGEnabled(41)) return NO;
    return orig ? ((BOOL(*)(id,SEL,NSInteger,BOOL))orig)(self,_cmd,item,show) : NO;
}

static BOOL HGBoolObjectAndInteger(id self, SEL _cmd, id obj, NSInteger value) {
    IMP orig = HGOriginalFor(self, _cmd); NSInteger f = HGFeatureFor(self, _cmd); NSInteger a = HGActionFor(self, _cmd);
    if (f >= 0 && HGEnabled(f)) { if (a == HGActionReturnFalse) return NO; if (a == HGActionReturnTrue) return YES; }
    return orig ? ((BOOL(*)(id,SEL,id,NSInteger))orig)(self,_cmd,obj,value) : NO;
}

static BOOL HGLooksLikeCloseButton(UIButton *button) {
    if (!button) return NO;
    NSMutableArray *parts=[NSMutableArray array];
    if (NSStringFromClass([button class])) [parts addObject:NSStringFromClass([button class])];
    if (button.currentTitle) [parts addObject:button.currentTitle];
    if (button.accessibilityLabel) [parts addObject:button.accessibilityLabel];
    if (button.accessibilityIdentifier) [parts addObject:button.accessibilityIdentifier];
    UIView *parent=button.superview;
    for (NSUInteger depth=0; parent && depth<4; depth++, parent=parent.superview) {
        [parts addObject:NSStringFromClass([parent class]) ?: @""];
        if (parent.accessibilityLabel) [parts addObject:parent.accessibilityLabel];
    }
    NSString *text=[[parts componentsJoinedByString:@" "] lowercaseString];
    return [text containsString:@"close"] || [text containsString:@"skip"] ||
           [text containsString:@"关闭"] || [text containsString:@"跳过"] ||
           [text containsString:@"closebtn"] || [text containsString:@"skipbutton"] ||
           [text containsString:@"×"] || [text containsString:@"✕"];
}

static void HGVoidNoArg(id self, SEL _cmd) {
    IMP orig = HGOriginalFor(self, _cmd); NSInteger f = HGFeatureFor(self, _cmd); NSInteger a = HGActionFor(self, _cmd);
    if (f >= 0 && HGEnabled(f) && a == HGActionSkipVoid) return;
    if (orig) ((void(*)(id,SEL))orig)(self,_cmd);
    if (f >= 0 && HGEnabled(f) && a == HGActionShowCloseButton) {
        id target = self;
        if ([target respondsToSelector:@selector(view)]) target = ((id(*)(id,SEL))objc_msgSend)(target,@selector(view));
        if ([target isKindOfClass:UIView.class]) {
            NSMutableArray *stack=[NSMutableArray arrayWithObject:target];
            while (stack.count) { UIView *v=stack.lastObject; [stack removeLastObject];
                if ([v isKindOfClass:UIButton.class] && HGLooksLikeCloseButton((UIButton *)v)) { v.hidden=NO; ((UIButton *)v).enabled=YES; v.userInteractionEnabled=YES; }
                [stack addObjectsFromArray:v.subviews];
            }
        }
    } else if ((f == 45 && HGEnabled(45) && a == HGActionExitCleanMode) || (f == 44 && HGEnabled(44) && a == HGActionEnterCleanMode)) {
        SEL actionSel = (f == 45) ? NSSelectorFromString(@"exitCleanMode") : NSSelectorFromString(@"enterCleanMode");
        if ([self respondsToSelector:actionSel]) { ((void(*)(id,SEL))objc_msgSend)(self,actionSel); return; }
        for (NSString *name in @[@"controlComponent", @"control", @"owner", @"viewController"]) {
            SEL getter=NSSelectorFromString(name);
            if (![self respondsToSelector:getter]) continue;
            id related=((id(*)(id,SEL))objc_msgSend)(self,getter);
            if (related && [related respondsToSelector:actionSel]) { ((void(*)(id,SEL))objc_msgSend)(related,actionSel); return; }
        }
    }
}

static void HGVoidObjectArg(id self, SEL _cmd, id arg) {
    IMP orig = HGOriginalFor(self, _cmd); NSInteger f = HGFeatureFor(self, _cmd); NSInteger a = HGActionFor(self, _cmd);
    if (f >= 0 && HGEnabled(f) && a == HGActionSkipVoid) return;
    if (f == 42 && a == HGActionFilterGameItem && HGEnabled(42) && [arg isKindOfClass:NSArray.class]) {
        NSMutableArray *filtered=[NSMutableArray array]; for(id item in (NSArray *)arg) if(!HGIsGameSidebarItem(item))[filtered addObject:item];
        if(orig)((void(*)(id,SEL,id))orig)(self,_cmd,filtered); return;
    }
    if (orig) ((void(*)(id,SEL,id))orig)(self,_cmd,arg);
}

static id HGObjectObjectArg(id self, SEL _cmd, id arg) {
    IMP orig = HGOriginalFor(self, _cmd); NSInteger f = HGFeatureFor(self, _cmd);
    id result = orig ? ((id(*)(id,SEL,id))orig)(self,_cmd,arg) : arg;
    if (f == 42 && HGEnabled(42) && [result isKindOfClass:NSArray.class]) {
        NSMutableArray *filtered = [NSMutableArray array];
        for (id item in (NSArray *)result) {
            if (HGIsGameSidebarItem(item)) continue;
            [filtered addObject:item];
        }
        return filtered;
    }
    return result;
}

static id HGObjectNoArg(id self, SEL _cmd) {
    IMP orig=HGOriginalFor(self,_cmd); NSInteger f=HGFeatureFor(self,_cmd); NSInteger a=HGActionFor(self,_cmd);
    id result=orig ? ((id(*)(id,SEL))orig)(self,_cmd) : nil;
    if (f>=0 && HGEnabled(f) && a==HGActionReturnNil) return nil;
    if (f==40 && HGEnabled(40)) return nil;
    if (f==-4 && a==12 && [result isKindOfClass:NSArray.class]) {
        NSMutableArray *filtered=[NSMutableArray array];
        for(id item in (NSArray *)result) {
            NSString *t=HGDescriptionForModel(item); BOOL hide=NO;
            if(HGEnabled(31) && ([t containsString:@"hotcomment"] || [t containsString:@"热评"] || [t containsString:@"rcmdreason"])) hide=YES;
            if(HGEnabled(32) && ([t containsString:@"tagview"] || [t containsString:@"标签"] || [t containsString:@"taglist"])) hide=YES;
            if(HGEnabled(29) && ([t containsString:@"series"] || [t containsString:@"parallelworld"] || [t containsString:@"系列剧集"])) hide=YES;
            if(HGEnabled(34) && ([t containsString:@"aiusage"] || [t containsString:@"ailogo"] || [t containsString:@"备案号"])) hide=YES;
            if(!hide)[filtered addObject:item];
        }
        return filtered;
    }
    return result;
}

static double HGDoubleBoolArg(id self, SEL _cmd, BOOL value) {
    IMP orig=HGOriginalFor(self,_cmd); NSInteger f=HGFeatureFor(self,_cmd);
    if(f==32 && HGEnabled(32)) return 0.0;
    return orig ? ((double(*)(id,SEL,BOOL))orig)(self,_cmd,value) : 0.0;
}

static NSInteger HGIntegerObjectArg(id self, SEL _cmd, id model) {
    IMP orig=HGOriginalFor(self,_cmd); NSInteger f=HGFeatureFor(self,_cmd);
    if(f==37 && HGEnabled(37)) return 0;
    return orig ? ((NSInteger(*)(id,SEL,id))orig)(self,_cmd,model) : 0;
}

static void HGVoidIntegerBoolArg(id self, SEL _cmd, NSInteger item, BOOL show) {
    IMP orig=HGOriginalFor(self,_cmd); NSInteger f=HGFeatureFor(self,_cmd);
    if(f==41 && HGEnabled(41)) show=NO;
    if(orig)((void(*)(id,SEL,NSInteger,BOOL))orig)(self,_cmd,item,show);
}

static void HGVoidBoolIntegerArg(id self, SEL _cmd, BOOL show, NSInteger item) {
    IMP orig=HGOriginalFor(self,_cmd); NSInteger f=HGFeatureFor(self,_cmd);
    if(f==41 && HGEnabled(41)) show=NO;
    if(orig)((void(*)(id,SEL,BOOL,NSInteger))orig)(self,_cmd,show,item);
}

static void HGVoidObjectBoolArg(id self, SEL _cmd, id item, BOOL forceHide) {
    IMP orig=HGOriginalFor(self,_cmd); NSInteger f=HGFeatureFor(self,_cmd); NSInteger a=HGActionFor(self,_cmd);
    if(f==41 && HGEnabled(41) && a==HGActionForceHide) forceHide=YES;
    if(orig)((void(*)(id,SEL,id,BOOL))orig)(self,_cmd,item,forceHide);
}

static void HGVoidDoubleBoolArg(id self, SEL _cmd, double time, BOOL refresh) {
    IMP orig=HGOriginalFor(self,_cmd); NSInteger f=HGFeatureFor(self,_cmd); NSInteger a=HGActionFor(self,_cmd);
    if(f==29 && HGEnabled(29) && a==HGActionSkipVoid) return;
    if(orig)((void(*)(id,SEL,double,BOOL))orig)(self,_cmd,time,refresh);
}

static float HGFloatNoArg(id self, SEL _cmd) {
    IMP orig = HGOriginalFor(self, _cmd); NSInteger f = HGFeatureFor(self, _cmd);
    if (f == 43 && HGEnabled(43)) return [gHGPrefs[@"defaultSpeed"] floatValue];
    return orig ? ((float(*)(id,SEL))orig)(self,_cmd) : 1.0f;
}

static double HGDoubleNoArg(id self, SEL _cmd) {
    IMP orig = HGOriginalFor(self, _cmd); NSInteger f = HGFeatureFor(self, _cmd);
    if (f == 43 && HGEnabled(43)) return [gHGPrefs[@"defaultSpeed"] doubleValue];
    return orig ? ((double(*)(id,SEL))orig)(self,_cmd) : 1.0;
}

static double HGDoubleObjectArg(id self, SEL _cmd, id model) {
    IMP orig = HGOriginalFor(self, _cmd); NSInteger f = HGFeatureFor(self, _cmd);
    if (f == 43 && HGEnabled(43)) return [gHGPrefs[@"defaultSpeed"] doubleValue];
    return orig ? ((double(*)(id,SEL,id))orig)(self,_cmd,model) : 1.0;
}

static NSString *HGFormatTime(double seconds) {
    if (!isfinite(seconds) || seconds < 0) seconds = 0;
    long long total = (long long)seconds; return [NSString stringWithFormat:@"%02lld:%02lld", total/60, total%60];
}

static void HGAttachDurationLabel(UIView *view, double current, double duration) {
    if (![view isKindOfClass:UIView.class]) return;
    UILabel *label = objc_getAssociatedObject(view, @selector(HGAttachDurationLabel));
    if (!label) {
        label = [[UILabel alloc] initWithFrame:CGRectZero]; label.font=[UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightMedium];
        label.textColor=UIColor.whiteColor; label.backgroundColor=[UIColor colorWithWhite:0 alpha:0.55]; label.textAlignment=NSTextAlignmentCenter;
        label.layer.cornerRadius=4; label.clipsToBounds=YES; label.userInteractionEnabled=NO; label.autoresizingMask=UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleTopMargin;
        [view addSubview:label]; objc_setAssociatedObject(view,@selector(HGAttachDurationLabel),label,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    label.text=[NSString stringWithFormat:@"%@ / %@",HGFormatTime(current),HGFormatTime(duration)];
    label.frame=CGRectMake(MAX(0,view.bounds.size.width-104),-18,100,16); label.hidden=NO;
}

static void HGVoidBoolArg(id self, SEL _cmd, BOOL value) {
    IMP orig=HGOriginalFor(self,_cmd);
    if ([gHGPrefs[@"enabled"] boolValue] && [gHGPrefs[@"lockResolutionEnabled"] boolValue] && [NSStringFromSelector(_cmd) isEqualToString:@"setEnableNetworkSpeedToChooseResolution:"]) value=NO;
    if (orig) ((void(*)(id,SEL,BOOL))orig)(self,_cmd,value);
}

static NSUInteger HGResolutionFinalType(id self, SEL _cmd, id supported, id model) {
    IMP orig=HGOriginalFor(self,_cmd);
    NSUInteger fallback=orig ? ((NSUInteger(*)(id,SEL,id,id))orig)(self,_cmd,supported,model) : 0;
    if (![gHGPrefs[@"enabled"] boolValue] || ![gHGPrefs[@"lockResolutionEnabled"] boolValue]) return fallback;
    NSInteger selected=[gHGPrefs[@"lockResolution"] integerValue];
    if (selected<=0) return fallback;
    NSArray *items=[supported isKindOfClass:NSArray.class] ? supported : nil;
    if (!items.count) return fallback;
    const NSUInteger codes[]={((NSUInteger)-1),0,1,8,2,3};
    NSUInteger target=codes[MIN(MAX(selected,0),5)];
    for (id item in items) {
        if ([item isKindOfClass:NSNumber.class] && [(NSNumber *)item unsignedIntegerValue]==target) return target;
        NSMutableArray *parts=[NSMutableArray arrayWithObject:[item description] ?: @""];
        for (NSString *prop in @[@"resolutionName",@"title",@"name",@"resolution",@"resolutionType",@"type",@"value"]) {
            SEL getter=NSSelectorFromString(prop);
            if ([item respondsToSelector:getter]) { @try { id v=((id(*)(id,SEL))objc_msgSend)(item,getter); if (v) [parts addObject:[v description]]; } @catch (__unused NSException *e) {} }
        }
        NSString *desc=[[parts componentsJoinedByString:@" "] lowercaseString];
        NSInteger pixel=selected==1?360:selected==2?480:selected==3?540:selected==4?720:selected==5?1080:0;
        if (pixel>0 && [desc containsString:[NSString stringWithFormat:@"%ld",(long)pixel]]) {
            if ([item isKindOfClass:NSNumber.class]) return [(NSNumber *)item unsignedIntegerValue];
            for (NSString *prop in @[@"resolutionType",@"type",@"value"]) { SEL getter=NSSelectorFromString(prop); if ([item respondsToSelector:getter]) { @try { id v=((id(*)(id,SEL))objc_msgSend)(item,getter); if ([v respondsToSelector:@selector(unsignedIntegerValue)]) return [v unsignedIntegerValue]; } @catch (__unused NSException *e) {} } }
        }
    }
    return fallback;
}

static void HGVoidIntegerArg(id self, SEL _cmd, NSInteger value) {
    IMP orig=HGOriginalFor(self,_cmd); NSInteger f=HGFeatureFor(self,_cmd); NSInteger a=HGActionFor(self,_cmd);
    if (f == -3 && a == HGActionOverrideStartupIndex && [gHGPrefs[@"enabled"] boolValue] && [gHGPrefs[@"startupTabEnabled"] boolValue]) {
        NSInteger tab=[gHGPrefs[@"startupTab"] integerValue]; if (tab>0) value=tab-1;
    }
    if (f == -2 && a == HGActionOverrideResolution && [gHGPrefs[@"enabled"] boolValue] && [gHGPrefs[@"lockResolutionEnabled"] boolValue]) {
        NSInteger selected=[gHGPrefs[@"lockResolution"] integerValue]; const NSInteger codes[]={-1,0,1,8,2,3}; if(selected>=0 && selected<6) value=codes[selected];
    }
    if (orig) ((void(*)(id,SEL,NSInteger))orig)(self,_cmd,value);
    if (f==45 && HGEnabled(45) && a==HGActionExitCleanMode) {
        SEL sel=NSSelectorFromString(@"exitCleanMode");
        if ([self respondsToSelector:sel]) ((void(*)(id,SEL))objc_msgSend)(self,sel);
        else if ([self respondsToSelector:NSSelectorFromString(@"controlComponent")]) { id c=((id(*)(id,SEL))objc_msgSend)(self,NSSelectorFromString(@"controlComponent")); if ([c respondsToSelector:sel]) ((void(*)(id,SEL))objc_msgSend)(c,sel); }
    }
}

static void HGVoidDoubleDouble(id self, SEL _cmd, double current, double duration) {
    IMP orig=HGOriginalFor(self,_cmd); NSInteger f=HGFeatureFor(self,_cmd);
    if (orig) ((void(*)(id,SEL,double,double))orig)(self,_cmd,current,duration);
    if (f==36 && HGEnabled(36) && [self isKindOfClass:UIView.class]) HGAttachDurationLabel((UIView *)self,current,duration);
}

static NSInteger HGIntegerNoArg(id self, SEL _cmd) {
    IMP orig = HGOriginalFor(self, _cmd);
    return orig ? ((NSInteger(*)(id,SEL))orig)(self,_cmd) : 0;
}

static void HGInstallTypedHook(NSString *className, NSString *selectorName, NSInteger featureID, NSInteger action, NSInteger kind, BOOL classMethod) {
    Class cls = NSClassFromString(className);
    if (!cls) { NSLog(@"[HongGuoPurify] missing class %@", className); return; }
    if (classMethod) cls = object_getClass(cls);
    SEL sel = NSSelectorFromString(selectorName);
    Method method = class_getInstanceMethod(cls, sel);
    if (!method) { NSLog(@"[HongGuoPurify] missing %@ %@", className, selectorName); return; }
    unsigned int argc = method_getNumberOfArguments(method);
    char rt[16] = {0}; method_getReturnType(method, rt, sizeof(rt));
    char a2[16]={0}, a3[16]={0};
    if (argc>2) { char *t=method_copyArgumentType(method,2); if(t){strlcpy(a2,t,sizeof(a2)); free(t);} }
    if (argc>3) { char *t=method_copyArgumentType(method,3); if(t){strlcpy(a3,t,sizeof(a3)); free(t);} }
    BOOL arg2Object = a2[0]=='@'; BOOL arg2Bool = a2[0]=='B' || a2[0]=='c';
    BOOL arg3Integer = a3[0]=='q' || a3[0]=='i' || a3[0]=='Q' || a3[0]=='I';
    IMP replacement = NULL;
    BOOL abiOK = NO;
    switch (kind) {
        case 1: abiOK = argc == 2 && (rt[0]=='B' || rt[0]=='c'); replacement = (IMP)HGBoolNoArg; break;
        case 2: abiOK = argc == 3 && (rt[0]=='B' || rt[0]=='c') && arg2Object; replacement = (IMP)HGBoolObjectArg; break;
        case 3: abiOK = argc == 4 && (rt[0]=='B' || rt[0]=='c') && arg2Object && arg3Integer; replacement = (IMP)HGBoolObjectAndInteger; break;
        case 4: abiOK = argc == 2 && rt[0]=='v'; replacement = (IMP)HGVoidNoArg; break;
        case 5: abiOK = argc == 3 && rt[0]=='v' && arg2Object; replacement = (IMP)HGVoidObjectArg; break;
        case 6: abiOK = argc == 3 && rt[0]=='@' && arg2Object; replacement = (IMP)HGObjectObjectArg; break;
        case 7: abiOK = argc == 2 && rt[0]=='f'; replacement = (IMP)HGFloatNoArg; break;
        case 8: abiOK = argc == 2 && rt[0]=='d'; replacement = (IMP)HGDoubleNoArg; break;
        case 9: abiOK = argc == 2 && (rt[0]=='q' || rt[0]=='i' || rt[0]=='Q' || rt[0]=='I'); replacement = (IMP)HGIntegerNoArg; break;
        case 10: abiOK = argc == 3 && (rt[0]=='B' || rt[0]=='c') && arg2Bool; replacement = (IMP)HGBoolBoolArg; break;
        case 11: abiOK = argc == 4 && rt[0]=='v' && a2[0]=='d' && a3[0]=='d'; replacement = (IMP)HGVoidDoubleDouble; break;
        case 12: abiOK = argc == 3 && rt[0]=='d' && arg2Object; replacement = (IMP)HGDoubleObjectArg; break;
        case 13: abiOK = argc == 3 && rt[0]=='v' && (a2[0]=='q' || a2[0]=='i' || a2[0]=='Q' || a2[0]=='I'); replacement = (IMP)HGVoidIntegerArg; break;
        case 14: abiOK = argc == 3 && rt[0]=='v' && arg2Bool; replacement = (IMP)HGVoidBoolArg; break;
        case 15: abiOK = argc == 3 && rt[0]=='d' && arg2Bool; replacement = (IMP)HGDoubleBoolArg; break;
        case 16: abiOK = argc == 2 && rt[0]=='@'; replacement = (IMP)HGObjectNoArg; break;
        case 17: abiOK = argc == 3 && (rt[0]=='q' || rt[0]=='i' || rt[0]=='Q' || rt[0]=='I') && arg2Object; replacement = (IMP)HGIntegerObjectArg; break;
        case 18: abiOK = argc == 4 && rt[0]=='v' && arg3Integer==NO && (a2[0]=='q'||a2[0]=='i'||a2[0]=='Q'||a2[0]=='I') && (a3[0]=='B'||a3[0]=='c'); replacement = (IMP)HGVoidIntegerBoolArg; break;
        case 19: abiOK = argc == 4 && rt[0]=='v' && arg2Bool && (a3[0]=='i'||a3[0]=='q'||a3[0]=='I'||a3[0]=='Q'); replacement = (IMP)HGVoidBoolIntegerArg; break;
        case 20: abiOK = argc == 4 && (rt[0]=='B'||rt[0]=='c') && (a2[0]=='i'||a2[0]=='q'||a2[0]=='I'||a2[0]=='Q') && (a3[0]=='B'||a3[0]=='c'); replacement = (IMP)HGBoolIntegerBoolArg; break;
        case 21: abiOK = argc == 4 && rt[0]=='v' && a2[0]=='d' && (a3[0]=='B'||a3[0]=='c'); replacement = (IMP)HGVoidDoubleBoolArg; break;
        case 22: abiOK = argc == 4 && rt[0]=='v' && arg2Object && arg3Integer==NO && (a3[0]=='B'||a3[0]=='c'); replacement = (IMP)HGVoidObjectBoolArg; break;
    }
    if (!abiOK) { NSLog(@"[HongGuoPurify] ABI skipped %@ %@ ret=%s args=%u", className, selectorName, rt, argc); return; }
    NSString *key = HGKey(cls, sel); if ([gHGInstalled containsObject:key]) return;
    gHGHookFeatures[key] = @(featureID); gHGHookActions[key] = @(action);
    IMP original = NULL; MSHookMessageEx(cls, sel, replacement, &original);
    if (original) { gHGOriginalIMPs[key] = [NSValue valueWithPointer:(const void *)original]; [gHGInstalled addObject:key]; NSLog(@"[HongGuoPurify] hooked %@ %@", className, selectorName); }
    else NSLog(@"[HongGuoPurify] hook failed %@ %@", className, selectorName);
}

#pragma mark - Generic view cleanup

static NSString *HGTextForView(UIView *view) {
    NSMutableArray *parts = [NSMutableArray arrayWithObject:NSStringFromClass(view.class) ?: @""];
    if ([view isKindOfClass:UILabel.class]) { NSString *s=((UILabel *)view).text; if (s.length) [parts addObject:s]; }
    if ([view isKindOfClass:UIButton.class]) { NSString *s=((UIButton *)view).currentTitle; if (s.length) [parts addObject:s]; }
    if ([view respondsToSelector:@selector(accessibilityLabel)]) { NSString *s=view.accessibilityLabel; if (s.length) [parts addObject:s]; }
    return [[parts componentsJoinedByString:@" "] lowercaseString];
}

static BOOL HGViewMatchesFeature(UIView *v, NSInteger f) {
    NSString *s = HGTextForView(v);
    switch (f) {
        case 0: case 1: case 26:
            return ([s containsString:@"adview"] || [s containsString:@"advert"] || [s containsString:@"adcontainer"] || [s containsString:@"广告"] || [s containsString:@"推广"]);
        case 2: return ([s containsString:@"小游戏"] || [s containsString:@"游戏中心"] || [s containsString:@"商城"] || [s containsString:@"直播入口"]);
        case 3: return ([s containsString:@"评分"] || [s containsString:@"评价"] || [s containsString:@"rateus"] || [s containsString:@"reviewinvite"]);
        case 6: return ([s containsString:@"通知权限"] || [s containsString:@"开启通知"] || [s containsString:@"开启推送"] || [s containsString:@"notificationpermission"]);
        case 7: return ([s containsString:@"小组件"] || [s containsString:@"添加到桌面"] || [s containsString:@"widgetguide"]);
        case 4: return ([s containsString:@"pendant"] || [s containsString:@"福利挂件"] || [s containsString:@"金币挂件"] || [s containsString:@"rewardbubble"]);
        case 5: case 10: case 11: return ([s containsString:@"本章讨论"] || [s containsString:@"圈子"] || [s containsString:@"discussion"]);
        case 9: return ([s containsString:@"作者的话"] || [s containsString:@"作者寄语"] || [s containsString:@"authornote"]);
        case 12: return ([s containsString:@"送礼物"] || [s containsString:@"打赏"] || [s containsString:@"gift"]);
        case 13: return ([s containsString:@"催更"] || [s containsString:@"更新历史"] || [s containsString:@"章末快捷"]);
        case 14: return ([s containsString:@"福利"] && ([s containsString:@"tab"] || [s containsString:@"导航"] || [s containsString:@"bottom"]));
        case 16: return ([s containsString:@"福利卡"] || [s containsString:@"金币"] || [s containsString:@"提现"]);
        case 18: return ([s containsString:@"推荐卡"] || [s containsString:@"recommendcard"] || [s containsString:@"关注推荐"]);
        case 19: case 22: return ([s containsString:@"发帖"] || [s containsString:@"publish"] || [s containsString:@"compose"]);
        case 20: return ([s containsString:@"短剧"] && ([s containsString:@"tab"] || [s containsString:@"导航"] || [s containsString:@"bottom"]));
        case 23: return ([s containsString:@"漫剧"] || [s containsString:@"改编剧"] || [s containsString:@"adapted"]);
        case 24: return ([s containsString:@"听读时长"] || [s containsString:@"今日已看"] || [s containsString:@"readingtime"]);
        case 25: return ([s containsString:@"导入本地书"] || [s containsString:@"importbook"]);
        case 27: return ([s containsString:@"弹幕"] || [s containsString:@"barrage"]);
        case 28: return ([s containsString:@"作者声明"] || [s containsString:@"声明"]);
        case 29: return ([s containsString:@"系列剧集"] || [s containsString:@"seriesentry"]);
        case 30: return ([s containsString:@"爆剧"] || [s containsString:@"hotdrama"]);
        case 31: return ([s containsString:@"热评"] || [s containsString:@"hotcomment"]);
        case 32: return ([s containsString:@"tagview"] || [s containsString:@"剧标签"] || [s containsString:@"标签列表"]);
        case 33: return ([s containsString:@"topnavigation"] || [s containsString:@"顶部导航"] || [s containsString:@"navigationheader"] || [s containsString:@"topbar"] || [s containsString:@"navbar"] || [s containsString:@"navigationbar"]);
        case 34: return ([s containsString:@"备案号"] || [s containsString:@"aiusage"] || [s containsString:@"ai备案"]);
        case 35: return ([s containsString:@"快捷入口"] || [s containsString:@"shortcutgroup"] || [s containsString:@"minequick"]);
        case 40: return ([s containsString:@"榜单排名"] || [s containsString:@"ranknumber"] || [s containsString:@"ranking"]);
        case 41: return ([s containsString:@"reddot"] || [s containsString:@"redpoint"] || [s containsString:@"红点"] || [s containsString:@"红点提醒"]);
        case 42: return ([s containsString:@"游戏中心"] || [s containsString:@"gamecenter"] || [s containsString:@"小游戏"]);
        default: return NO;
    }
}

static char kHGOriginalHiddenKey;
static void HGApplyViewCleanup(UIView *view) {
    if (!view) return;
    for (NSInteger f=0; f<HGFeatureTitles().count; f++) {
        if (f==8 || f==38 || f==39 || f==36 || f==37 || f==43 || f==44 || f==45) continue;
        BOOL featureOn=HGEnabled(f); if (f==33 && [gHGPrefs[@"startupTop"] boolValue] && [gHGPrefs[@"enabled"] boolValue]) featureOn=YES;
        if (featureOn && HGViewMatchesFeature(view,f)) {
            if (!objc_getAssociatedObject(view,&kHGOriginalHiddenKey)) objc_setAssociatedObject(view,&kHGOriginalHiddenKey,@(view.hidden),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            view.hidden = YES;
            break;
        } else if (objc_getAssociatedObject(view,&kHGOriginalHiddenKey)) {
            view.hidden = [objc_getAssociatedObject(view,&kHGOriginalHiddenKey) boolValue];
            objc_setAssociatedObject(view,&kHGOriginalHiddenKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    for (UIView *sub in view.subviews.copy) HGApplyViewCleanup(sub);
}

static IMP gOriginalViewDidLayoutSubviews;
static void HGViewDidLayoutSubviews(id self, SEL _cmd) {
    if (gOriginalViewDidLayoutSubviews) ((void(*)(id,SEL))gOriginalViewDidLayoutSubviews)(self,_cmd);
    if ([self respondsToSelector:@selector(view)] && [self view]) {
        UIView *root=[self view]; HGApplyViewCleanup(root);
        if (HGEnabled(17) && [self isKindOfClass:UIViewController.class]) {
            NSMutableArray *stack=[NSMutableArray arrayWithObject:root]; NSString *chapter=nil;
            while(stack.count && !chapter){UIView *v=stack.lastObject;[stack removeLastObject]; if([v isKindOfClass:UILabel.class]){NSString *t=((UILabel *)v).text; if(t.length && [t hasPrefix:@"第"] && ([t containsString:@"章"] || [t containsString:@"集"])) chapter=t;} [stack addObjectsFromArray:v.subviews];}
            if(chapter.length) ((UIViewController *)self).navigationItem.title=chapter;
        }
    }
}

#pragma mark - In-app settings panel

@interface HGFeatureCell : UITableViewCell
@property(nonatomic,strong) UISwitch *hgSwitch;
@property(nonatomic,assign) NSInteger featureID;
@end
@implementation HGFeatureCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self=[super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier])) {
        self.textLabel.numberOfLines=2; self.detailTextLabel.numberOfLines=3; self.detailTextLabel.font=[UIFont systemFontOfSize:11];
        _hgSwitch=[UISwitch new]; [_hgSwitch addTarget:self action:@selector(hgChanged:) forControlEvents:UIControlEventValueChanged]; self.accessoryView=_hgSwitch;
    } return self;
}
- (void)hgChanged:(UISwitch *)sender {
    if (!gHGPrefs) HGLoadPreferences();
    gHGPrefs[[kHGFeaturePrefix stringByAppendingFormat:@"%ld",(long)self.featureID]]=@(sender.on); HGSavePreferences();
}
@end

@interface HGSettingsController : UITableViewController
@end
@implementation HGSettingsController
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=@"红果净化"; self.tableView.rowHeight=76; self.tableView.estimatedRowHeight=76;
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"总开关" style:UIBarButtonItemStylePlain target:self action:@selector(hgToggleMaster)];
}
- (void)hgToggleMaster {
    if (!gHGPrefs) HGLoadPreferences(); BOOL next=![gHGPrefs[@"enabled"] boolValue]; gHGPrefs[@"enabled"]=@(next); HGSavePreferences();
    self.navigationItem.rightBarButtonItem.title=next?@"总开关（开）":@"总开关（关）"; [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 5; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[@"阅读与听书",@"短剧播放",@"页面与导航",@"播放控制",@"通用设置"][section];
}
- (NSArray<NSNumber *> *)hgIDsForSection:(NSInteger)section {
    switch(section) {
        case 0:return @[@0,@1,@2,@3,@4,@5,@6,@7,@8,@9,@10,@11,@12,@13,@14,@16,@17,@18,@19,@22,@23,@24,@25];
        case 1:return @[@15,@20,@21,@26,@27,@28,@29,@30,@31,@32,@34];
        case 2:return @[@33,@35,@40,@41,@42];
        case 3:return @[@36,@37,@43,@44,@45];
        default:return @[];
    }
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return [self hgIDsForSection:section].count + (section==4?6:0); }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section==4) {
        UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"hgsetting"];
        if (!cell) cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"hgsetting"];
        cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
        if (indexPath.row==0) { cell.textLabel.text=@"默认倍速"; cell.detailTextLabel.text=[NSString stringWithFormat:@"%.2gx",[gHGPrefs[@"defaultSpeed"] doubleValue]]; }
        if (indexPath.row==1) { NSArray *r=@[@"自动",@"360P",@"480P",@"540P",@"720P",@"1080P"]; NSInteger n=[gHGPrefs[@"lockResolution"] integerValue]; cell.textLabel.text=@"清晰度偏好"; cell.detailTextLabel.text=r[MIN(MAX(n,0),5)]; }
        if (indexPath.row==2) { NSArray *r=@[@"默认",@"书城",@"书架",@"短剧"]; NSInteger n=[gHGPrefs[@"startupTab"] integerValue]; cell.textLabel.text=@"默认启动页"; cell.detailTextLabel.text=r[MIN(MAX(n,0),3)]; }
        if (indexPath.row==3) { cell.textLabel.text=@"启用清晰度锁定"; cell.detailTextLabel.text=@"对支持的清晰度选择器固定所选清晰度"; cell.accessoryType=UITableViewCellAccessoryNone; UISwitch *sw=[UISwitch new]; sw.on=[gHGPrefs[@"lockResolutionEnabled"] boolValue]; [sw addTarget:self action:@selector(hgLockResolution:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView=sw; }
        if (indexPath.row==4) { cell.textLabel.text=@"启用默认启动页"; cell.detailTextLabel.text=@"仅在目标版本支持对应首页标签枚举时生效"; cell.accessoryType=UITableViewCellAccessoryNone; UISwitch *sw=[UISwitch new]; sw.on=[gHGPrefs[@"startupTabEnabled"] boolValue]; [sw addTarget:self action:@selector(hgStartupTabEnabled:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView=sw; }
        if (indexPath.row==5) { cell.textLabel.text=@"启动时隐藏顶部导航"; cell.detailTextLabel.text=@"在支持的页面尝试隐藏顶部导航栏"; cell.accessoryType=UITableViewCellAccessoryNone; UISwitch *sw=[UISwitch new]; sw.on=[gHGPrefs[@"startupTop"] boolValue]; [sw addTarget:self action:@selector(hgStartupTop:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView=sw; }
        return cell;
    }
    HGFeatureCell *cell=[tableView dequeueReusableCellWithIdentifier:@"hgfeature"];
    if (!cell) cell=[[HGFeatureCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"hgfeature"];
    NSInteger fid=[self hgIDsForSection:indexPath.section][indexPath.row].integerValue; cell.featureID=fid;
    cell.textLabel.text=HGFeatureTitles()[fid]; cell.detailTextLabel.text=HGFeatureDetails()[fid]; cell.hgSwitch.on=HGConfiguredFeatureEnabled(fid); cell.hgSwitch.enabled=YES;
    if (fid==8) { cell.hgSwitch.enabled=NO; cell.detailTextLabel.text=@"为避免误导或绕过付费权益，本重建版不伪造会员身份。"; cell.hgSwitch.on=NO; }
    if (fid==38 || fid==39) { cell.hgSwitch.enabled=NO; cell.hgSwitch.on=NO; }
    return cell;
}
- (void)hgStartupTop:(UISwitch *)sw { gHGPrefs[@"startupTop"]=@(sw.on); HGSavePreferences(); }
- (void)hgLockResolution:(UISwitch *)sw { gHGPrefs[@"lockResolutionEnabled"]=@(sw.on); HGSavePreferences(); }
- (void)hgStartupTabEnabled:(UISwitch *)sw { gHGPrefs[@"startupTabEnabled"]=@(sw.on); HGSavePreferences(); }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES]; if (indexPath.section!=4 || indexPath.row>2) return;
    if (indexPath.row==0) {
        UIAlertController *a=[UIAlertController alertControllerWithTitle:@"默认倍速" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        for (NSNumber *n in @[@0.5,@0.75,@1.0,@1.25,@1.5,@1.75,@2.0,@3.0]) [a addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%.2gx",n.doubleValue] style:UIAlertActionStyleDefault handler:^(UIAlertAction *act){ gHGPrefs[@"defaultSpeed"]=n; HGSavePreferences(); [self.tableView reloadData]; }]];
        [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]]; if (a.popoverPresentationController) a.popoverPresentationController.sourceView=self.view; [self presentViewController:a animated:YES completion:nil];
    } else if (indexPath.row==1) {
        UIAlertController *a=[UIAlertController alertControllerWithTitle:@"清晰度偏好" message:@"仅对应用支持的清晰度选择生效" preferredStyle:UIAlertControllerStyleActionSheet]; NSArray *r=@[@"自动",@"360P",@"480P",@"540P",@"720P",@"1080P"];
        for (NSInteger i=0;i<r.count;i++) { NSInteger v=i; [a addAction:[UIAlertAction actionWithTitle:r[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction *act){ gHGPrefs[@"lockResolution"]=@(v); HGSavePreferences(); [self.tableView reloadData]; }]]; }
        [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]]; if (a.popoverPresentationController) a.popoverPresentationController.sourceView=self.view; [self presentViewController:a animated:YES completion:nil];
    } else if (indexPath.row==2) {
        UIAlertController *a=[UIAlertController alertControllerWithTitle:@"默认启动页" message:@"页面类型枚举随红果版本变化，选择会保存为偏好，只有支持该配置的版本才会生效。" preferredStyle:UIAlertControllerStyleActionSheet]; NSArray *r=@[@"默认",@"书城",@"书架",@"短剧"];
        for (NSInteger i=0;i<r.count;i++) { NSInteger v=i; [a addAction:[UIAlertAction actionWithTitle:r[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction *act){ gHGPrefs[@"startupTab"]=@(v); HGSavePreferences(); [self.tableView reloadData]; }]]; }
        [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]]; if (a.popoverPresentationController) a.popoverPresentationController.sourceView=self.view; [self presentViewController:a animated:YES completion:nil];
    }
}
@end

static void HGPresentSettings(id host) {
    UIViewController *vc=nil;
    if ([host isKindOfClass:UIViewController.class]) vc=(UIViewController *)host;
    if (!vc || !vc.view.window) return;
    UIViewController *top=vc;
    while (top.presentedViewController) top=top.presentedViewController;
    HGSettingsController *settings=[HGSettingsController new]; UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:settings]; nav.modalPresentationStyle=UIModalPresentationPageSheet;
    [top presentViewController:nav animated:YES completion:nil];
}

static IMP gOriginalSettingsDidAppear;
static void HGSettingsDidAppear(id self, SEL _cmd, BOOL animated) {
    if (gOriginalSettingsDidAppear) ((void(*)(id,SEL,BOOL))gOriginalSettingsDidAppear)(self,_cmd,animated);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![self isKindOfClass:UIViewController.class]) return;
        UIViewController *vc=(UIViewController *)self;
        NSString *name=NSStringFromClass(vc.class);
        if (![name containsString:@"SSSettingViewController"]) return;
        UIBarButtonItem *item=[[UIBarButtonItem alloc] initWithTitle:@"红果净化" style:UIBarButtonItemStylePlain target:vc action:@selector(hgOpenHongGuoPurify)];
        objc_setAssociatedObject(vc, @selector(hgOpenHongGuoPurify), item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        NSMutableArray *items=[vc.navigationItem.rightBarButtonItems mutableCopy] ?: [NSMutableArray array];
        BOOL exists=NO; for (UIBarButtonItem *it in items) if ([it.title isEqualToString:@"红果净化"]) exists=YES;
        if (!exists) { [items insertObject:item atIndex:0]; vc.navigationItem.rightBarButtonItems=items; }
    });
}

static void HGOpenSettingsAction(id self, SEL _cmd) { HGPresentSettings(self); }

#pragma mark - Feature hook map

static void HGInstallFeatureHooks(void) {
    // Short-drama ad configuration/request paths (feature 26).
    HGInstallTypedHook(@"BDADShortVideoCommonAdManager", @"shouldRequestShortVideoAd", 26, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"BDADShortVideoCommonAdManager", @"shouldRequestPauseAd", 26, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"BDADShortVideoCommonAdManager", @"shouldRequestPatchAd", 26, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"BDADShortVideoCommonAdManager", @"shouldShowPauseAdWithCloseStrategy", 26, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"BDADShortVideoCommonAdManager", @"pauseAdRequestEnable", 26, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"BDADShortVideoCommonAdManager", @"shouldReqWithSeriesId:episodeIndex:", 26, HGActionReturnFalse, 3, NO);
    HGInstallTypedHook(@"SSAdShortVideoHomePageFeedAdConfig", @"enable_recommend_flow_ad", 26, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSAdShortVideoPlotTouchAdConfig", @"enable_plot_touch_ad", 26, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSAdShortVideoSideBarPatchAdConfig", @"enable_side_bar_patch_ad", 26, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSShortVideoCommentAdService", @"enableVideoAlbumAd", 26, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSShortVideoCommentAdService", @"enableShortVideoCommentAd:", 26, HGActionReturnFalse, 10, NO);
    HGInstallTypedHook(@"SSShortVideoAboveLeftContainerViewManager", @"configureDanmakuViewWithModel:", 27, HGActionSkipVoid, 5, NO);
    HGInstallTypedHook(@"SSShortVideoAiUsageView", @"configureSeriesAIEntranceViewWithModel:", 34, HGActionSkipVoid, 5, NO);

    // Reward and coin pendant controls (feature 4), plus use the native ad close path (feature 15).
    HGInstallTypedHook(@"SSWelfareListenPendantManager", @"canShowPendantInVC:", 4, HGActionReturnFalse, 2, NO);
    HGInstallTypedHook(@"SSWelfareListenPendantManager", @"tryShowPendant:", 4, HGActionSkipVoid, 5, NO);
    HGInstallTypedHook(@"SSWelfareListenPendantManager", @"addHoverView", 4, HGActionSkipVoid, 4, NO);
    HGInstallTypedHook(@"SSWelfareListenPendantManager", @"refreshHoverView", 4, HGActionSkipVoid, 4, NO);
    HGInstallTypedHook(@"SSWelfareListenPendantManager", @"triggerKmpPendantIfNeededWithAttachView:", 4, HGActionSkipVoid, 5, NO);
    HGInstallTypedHook(@"SSWelfareListenPendantManager", @"tryShowAssetAwarenessBubble", 4, HGActionSkipVoid, 4, NO);
    HGInstallTypedHook(@"SSWelfareListenPendantManager", @"tryShowLimitTimeDoubleBubble", 4, HGActionSkipVoid, 4, NO);
    HGInstallTypedHook(@"SSWelfareListenPendantManager", @"tryShowTodayMaxRewardBubble", 4, HGActionSkipVoid, 4, NO);
    HGInstallTypedHook(@"SSWelfareListenPendantManager", @"tryShowRewardNoticeBubble", 4, HGActionSkipVoid, 4, NO);
    HGInstallTypedHook(@"SSWelfareListenPendantManager", @"tryShowDaily1MinTipsBubble", 4, HGActionSkipVoid, 4, NO);
    HGInstallTypedHook(@"SSWelfareGlobalPendantManager", @"tryShowPendant", 4, HGActionSkipVoid, 4, NO);
    HGInstallTypedHook(@"SSWelfareGlobalPendantManager", @"showAfterHidingTemp", 4, HGActionSkipVoid, 4, NO);
    HGInstallTypedHook(@"SSWelfareGlobalPendantManager", @"addHoverView", 4, HGActionSkipVoid, 4, NO);
    HGInstallTypedHook(@"SSWelfareGlobalPendantManager", @"refreshHoverView", 4, HGActionSkipVoid, 4, NO);
    HGInstallTypedHook(@"SSWelfareGlobalPendantManager", @"triggerKmpPendantIfNeededWithAttachView:", 4, HGActionSkipVoid, 5, NO);
    HGInstallTypedHook(@"SSWelfareGlobalPendantManager", @"isCommonCouldShowBubble", 4, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSWelfareGlobalPendantManager", @"tryShowDaily1MinBubble", 4, HGActionSkipVoid, 4, NO);
    HGInstallTypedHook(@"SSWelfareGlobalPendantManager", @"tryShowAssetAwarenessBubble", 4, HGActionSkipVoid, 4, NO);
    HGInstallTypedHook(@"BDARewardedVideoAdController", @"layoutCloseBtn", 15, HGActionShowCloseButton, 4, NO);
    HGInstallTypedHook(@"BDARewardedVideoAdController", @"closeBtnClick:", 15, 0, 5, NO);

    // Entering the short-drama page should not start playback without user input (feature 21).
    HGInstallTypedHook(@"SSShortVideoFeedColdPlayManager", @"canShowVideoFeedColdPlayVC", 21, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSShortVideoFeedColdPlayManager", @"prepareVideoFeedColdPlayerIfNeeded", 21, HGActionSkipVoid, 4, NO);
    HGInstallTypedHook(@"SSShortVideoFeedColdPlayManager", @"showVideoFeedColdPlayVCWithContainerVC:", 21, HGActionSkipVoid, 5, NO);
    HGInstallTypedHook(@"SSVideoFeedContainerViewController", @"tryExitInterruptInitialModelPlayIfNeed", 21, HGActionSkipVoid, 4, NO);
    HGInstallTypedHook(@"SSVideoSeriesFeedViewController", @"resumeVideoPlayIfNeeded", 21, HGActionSkipVoid, 4, NO);

    // Ad/recommendation decorations and tag cleanup.
    HGInstallTypedHook(@"SSShortVideoRcmdReasonViewManager", @"shouldDisplayRcmdReasonView", 31, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSShortVideoBelowLeftContainerViewManager", @"shouldAddAiUsageView", 34, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSShortVideoOutterMultiGenreFeedLeftContainerViewModel", @"shouldShowVideoTagInfoInTagList", 32, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSShortVideoParallelWorldEntryViewModel", @"shouldAddParallelWorldEntryView", 29, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSShortVideoLeftContainerHotCommentViewModel", @"hasVisibleHotComment", 31, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSShortVideoLeftContainerHotCommentViewModel", @"showHotComment", 31, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSShortVideoLeftContainerHotCommentViewModel", @"showHotCommentWithVideoTagList", 31, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSShortVideoBaseLeftContainerView", @"canShowTagView", 32, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"FQVShortVideoBaseLeftContainerView", @"showSecondaryInfoTagList", 32, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"FQVShortVideoBaseLeftContainerView", @"showTagList", 32, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"FQVShortVideoBaseLeftContainerView", @"hasVisibleSecondaryInfoLine", 32, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"FQVShortVideoBaseLeftContainerView", @"videoTagListViewHiddenWithHorizontalScrollEnabled:", 32, HGActionReturnTrue, 10, NO);
    HGInstallTypedHook(@"FQVShortVideoBaseLeftContainerView", @"titleScrollViewTopOffsetTags:", 32, 0, 15, NO);
    HGInstallTypedHook(@"SSShortVideoOutterMultiGenreFeedLeftContainerView", @"refreshTagsViewIfNeedWithVideoTagList", 32, HGActionSkipVoid, 5, NO);
    HGInstallTypedHook(@"SSShortVideoOutterMultiGenreFeedLeftContainerViewModel", @"hotComment", 31, HGActionReturnNil, 16, NO);
    HGInstallTypedHook(@"SSShortVideoRcmdReasonViewManager", @"orderedAboveLeftViewsForCurrentState", -4, 12, 16, NO);
    HGInstallTypedHook(@"SSShortVideoRcmdReasonViewManager", @"candidateLayoutItemsForCurrentState", -4, 12, 16, NO);
    HGInstallTypedHook(@"FQVShortVideoPlayerMaskDecorationDelegate", @"recordNumberLabel", 40, HGActionReturnNil, 16, NO);
    HGInstallTypedHook(@"SSShortVideoOutterSeriesLeftContainerView", @"updateVisibilityAtPlaybackTime:refreshLayout:", 29, HGActionSkipVoid, 21, NO);
    HGInstallTypedHook(@"SSShortVideoInnerSeriesLeftContainerView", @"updateVisibilityAtPlaybackTime:refreshLayout:", 29, HGActionSkipVoid, 21, NO);
    HGInstallTypedHook(@"SSShortVideoPostVideoLeftContainerView", @"updateVisibilityAtPlaybackTime:refreshLayout:", 29, HGActionSkipVoid, 21, NO);
    HGInstallTypedHook(@"SSShortVideoSingleSeriesInfoLeftContainerView", @"updateVisibilityAtPlaybackTime:refreshLayout:", 29, HGActionSkipVoid, 21, NO);
    HGInstallTypedHook(@"SSShortVideoBindSeriesLeftContainerView", @"updateVisibilityAtPlaybackTime:refreshLayout:", 29, HGActionSkipVoid, 21, NO);
    HGInstallTypedHook(@"SSShortVideoDerivateLeftContainerView", @"updateVisibilityAtPlaybackTime:refreshLayout:", 29, HGActionSkipVoid, 21, NO);

    // Sidebar and red dots.
    HGInstallTypedHook(@"SSMyUserSideBarViewController", @"shouldDisplaySidebarItem:", 42, HGActionFilterGameItem, 2, NO);
    HGInstallTypedHook(@"SSMyUserSideBarViewController", @"filteredSidebarItemsWithItems:", 42, 0, 6, NO);
    HGInstallTypedHook(@"SSBizGameColdStartManager", @"tryShowMyTabGameRedDot", 41, HGActionSkipVoid, 4, NO);
    HGInstallTypedHook(@"SSBizGameColdStartManager", @"canShowRedDot", 41, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSBookStoreCategorySignView", @"showRedDot", 41, HGActionSkipVoid, 4, NO);
    HGInstallTypedHook(@"SSBookStoreContinueTabRedDotModel", @"shouldShowRedDot", 41, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSUserCell2Model", @"isShowRedPoint", 41, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSMyUserJGZoneFollowUpdateDataModel", @"shouldShowRedDot", 41, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSRedDot", @"shouldShow", 41, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSRedDot", @"checkCanShowRecursively", 41, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSRedDot", @"canShow", 41, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSUserProfileGoldenLineItemInfoData", @"needShowRedDot", 41, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSFreeGuideAbData", @"hasReddot", 41, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSMinePageKMPDepend", @"updateSidebarItemRedDotForCellType:show:", 41, 0, 18, NO);
    HGInstallTypedHook(@"SSTabBarController", @"configRedDotShow:item:", 41, 0, 19, NO);
    HGInstallTypedHook(@"SSMyUserBar", @"shouldShowRedDotItem:isShow:", 41, 0, 20, NO);
    HGInstallTypedHook(@"SSMyUserBar", @"configRedDot:", 41, HGActionSkipVoid, 5, NO);
    HGInstallTypedHook(@"SSMyUserBar", @"configSideBarButtonRedDot:forceHide:", 41, HGActionForceHide, 22, NO);
    HGInstallTypedHook(@"RKMPIOSMinePageControllerHandle", @"updateSidebarItemRedDotCellType:show:", 41, 0, 18, NO);

    // Mine-page cards and shortcut group.
    HGInstallTypedHook(@"SSVipSettingServiceImpl", @"mineIsVipCardShow", 16, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSMyUser621BaseViewController", @"showShortcut", 35, HGActionSkipVoid, 4, NO);
    HGInstallTypedHook(@"SSMyUser621BaseViewController", @"setupShortcutData", 35, HGActionSkipVoid, 4, NO);
    HGInstallTypedHook(@"SSMyUser330CollectionViewController", @"updateCell3View", 18, HGActionSkipVoid, 4, NO);
    HGInstallTypedHook(@"SSMyUserCell3Model", @"canShowAiLogo", 34, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSMyUserShopAndMiniGameEntranceCellModel", @"canShow", 2, HGActionReturnFalse, 1, NO);
    HGInstallTypedHook(@"SSVipSettingService", @"mineIsVipCardShow", 16, HGActionReturnFalse, 1, NO);

    // Download entry point: expose the app's native control where the target version supports it.
    HGInstallTypedHook(@"FQVShortVideoListDownloadConfig", @"enableDownloadItem", 37, HGActionReturnTrue, 1, NO);
    HGInstallTypedHook(@"SSShortVideoDownloadVideoManager", @"checkCanShowDownloadWithVideoDataModel:", 37, HGActionReturnTrue, 2, NO);
    HGInstallTypedHook(@"SSShortVideoDownloadVideoManager", @"downloadItemRemovalReasonWithVideoDataModel:", 37, 0, 17, NO);

    // Playback controls. Return type is checked before any hook is installed.
    HGInstallTypedHook(@"FQVShortVideoListPlayConfig", @"defaultFastPlayRate", 43, 0, 7, NO);
    HGInstallTypedHook(@"FQVShortVideoListPlayConfig", @"defaultPlayRate", 43, 0, 7, NO);
    HGInstallTypedHook(@"FQVShortVideoListVCPlayerComponent", @"longPressPlayRate", 43, 0, 7, NO);
    HGInstallTypedHook(@"FQVShortVideoListVCPlayerComponent", @"playRateWithModel:", 43, 0, 12, NO);
    HGInstallTypedHook(@"FQVShortVideoProgressView", @"updateSliderTime:duration:", 36, 0, 11, NO);
    HGInstallTypedHook(@"FQVShortVideoLandscapeProgressView", @"updateProgressBarWithSliderTime:progressTotalTime:", 36, 0, 11, NO);
    HGInstallTypedHook(@"FQVShortVideoListControlConfig", @"enableCleanScreen", 44, HGActionReturnTrue, 1, NO);
    HGInstallTypedHook(@"FQVShortVideoListVCPlayComponent", @"play", 44, HGActionEnterCleanMode, 4, NO);
    HGInstallTypedHook(@"FQVShortVideoListVCPlayerComponent", @"pause", 45, HGActionExitCleanMode, 4, NO);
    HGInstallTypedHook(@"FQVShortVideoListVCPlayerComponent", @"pauseWithType:", 45, HGActionExitCleanMode, 13, NO);

    // The app's first-screen selector is a q-typed argument; only override it when explicitly enabled.
    HGInstallTypedHook(@"SSVideoSeriesFeedViewModel", @"commitFirstScreenSelectionWithServerIndex:", -3, HGActionOverrideStartupIndex, 13, NO);

    // Startup navigation and top/bottom navigation visibility. Enum meanings vary by app version.
}

static void HGInstallResolutionHook(void) {
    Class cls=NSClassFromString(@"FQVPlayerEngineDataResolutionItem"); SEL sel=NSSelectorFromString(@"finalResolutionTypeWithSupportResolutions:videoModel:");
    Method m=cls?class_getInstanceMethod(cls,sel):NULL; if (!m) { NSLog(@"[HongGuoPurify] resolution selector missing"); return; }
    char rt[16]={0}; method_getReturnType(m,rt,sizeof(rt)); unsigned int argc=method_getNumberOfArguments(m);
    char *a2=method_copyArgumentType(m,2); char *a3=method_copyArgumentType(m,3);
    BOOL ok=argc==4 && rt[0]=='Q' && a2 && a2[0]=='@' && a3 && a3[0]=='@'; if(a2)free(a2); if(a3)free(a3);
    if(!ok){NSLog(@"[HongGuoPurify] resolution selector ABI skipped");return;}
    NSString *key=HGKey(cls,sel); IMP original=NULL; MSHookMessageEx(cls,sel,(IMP)HGResolutionFinalType,&original);
    if(original){gHGOriginalIMPs[key]=[NSValue valueWithPointer:(const void *)original];gHGHookFeatures[key]=@(-2);[gHGInstalled addObject:key];NSLog(@"[HongGuoPurify] hooked resolution selection");}
    HGInstallTypedHook(@"FQVPlayerEngineDataResolutionItem", @"setEnableNetworkSpeedToChooseResolution:", -2, 0, 14, NO);
    HGInstallTypedHook(@"FQVPlayerEngineDataResolutionItem", @"setForceResolutionTypeNumber:", -2, HGActionOverrideResolution, 13, NO);
}

static void HGInstallUIHooks(void) {
    Class vc = NSClassFromString(@"SSSettingViewController");
    SEL appear = @selector(viewDidAppear:);
    if (vc && class_getInstanceMethod(vc, appear)) {
        IMP orig=NULL; MSHookMessageEx(vc, appear, (IMP)HGSettingsDidAppear, &orig); gOriginalSettingsDidAppear=orig;
    }
    // Install an action selector on the target settings controller at runtime.
    if (vc && !class_getInstanceMethod(vc, @selector(hgOpenHongGuoPurify))) {
        class_addMethod(vc, @selector(hgOpenHongGuoPurify), (IMP)HGOpenSettingsAction, "v@:");
    }
    Class base=UIViewController.class; SEL layout=@selector(viewDidLayoutSubviews);
    if (class_getInstanceMethod(base,layout)) { IMP orig=NULL; MSHookMessageEx(base,layout,(IMP)HGViewDidLayoutSubviews,&orig); gOriginalViewDidLayoutSubviews=orig; }
}

static void HGPreferencesDidChange(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    HGLoadPreferences();
}

%ctor {
    @autoreleasepool {
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier ?: @"";
        if (![bundleID isEqualToString:@"com.phoenix.video"]) return;
        HGLoadPreferences();
        gHGOriginalIMPs=[NSMutableDictionary dictionary]; gHGHookFeatures=[NSMutableDictionary dictionary]; gHGHookActions=[NSMutableDictionary dictionary]; gHGInstalled=[NSMutableSet set];
        NSLog(@"[HongGuoPurify] loaded for %@", bundleID);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(2.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            HGInstallFeatureHooks(); HGInstallResolutionHook(); HGInstallUIHooks();
            NSLog(@"[HongGuoPurify] feature hook pass finished (%lu installed)",(unsigned long)gHGInstalled.count);
        });
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), &gHGSettingsButtonAdded, HGPreferencesDidChange, (__bridge CFStringRef)kHGPreferencesChanged, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    }
}
