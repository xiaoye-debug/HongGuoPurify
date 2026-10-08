#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

static NSString * const kPrefsDomain = @"com.xiaoye.hongguopurify";
static NSMutableDictionary<NSString *, NSValue *> *gOriginalIMPs;
static NSMutableSet<NSString *> *gInstalledHooks;

static BOOL HGPreference(NSString *key, BOOL fallback) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:
        [NSHomeDirectory() stringByAppendingPathComponent:
            @"Library/Preferences/com.xiaoye.hongguopurify.plist"]];
    id value = prefs[key];
    return value ? [value boolValue] : fallback;
}

static BOOL HGHookedBoolGetter(id self, SEL _cmd) {
    NSString *selectorName = NSStringFromSelector(_cmd);
    IMP original = (IMP)[gOriginalIMPs[selectorName] pointerValue];
    BOOL isAd = [selectorName containsString:@"Ad"] ||
                [selectorName containsString:@"ad"] ||
                [selectorName containsString:@"PatchAd"] ||
                [selectorName containsString:@"PauseAd"];
    BOOL isCleanUI = [selectorName isEqualToString:@"shouldDisplayRcmdReasonView"] ||
                     [selectorName isEqualToString:@"shouldShowVideoTagInfoInTagList"];
    if (isAd && HGPreference(@"blockAds", YES)) return NO;
    if (isCleanUI && HGPreference(@"cleanUI", YES)) return NO;
    if (original) return ((BOOL (*)(id, SEL))original)(self, _cmd);
    return NO;
}

static void HGInstallBoolHook(NSString *className, NSString *selectorName) {
    Class cls = NSClassFromString(className);
    SEL selector = NSSelectorFromString(selectorName);
    if (!cls || !selector) {
        NSLog(@"[HongGuoPurify] class/selector missing: %@ %@", className, selectorName);
        return;
    }

    Method method = class_getInstanceMethod(cls, selector);
    if (!method) {
        NSLog(@"[HongGuoPurify] method missing: %@ %@", className, selectorName);
        return;
    }

    unsigned int argCount = method_getNumberOfArguments(method);
    char returnType[8] = {0};
    method_getReturnType(method, returnType, sizeof(returnType));
    if (argCount != 2 || (returnType[0] != 'B' && returnType[0] != 'c')) {
        NSLog(@"[HongGuoPurify] ABI mismatch, skipped: %@ %@ (%s, args=%u)",
              className, selectorName, returnType, argCount);
        return;
    }

    NSString *key = NSStringFromSelector(selector);
    if ([gInstalledHooks containsObject:[NSString stringWithFormat:@"%@.%@", className, key]]) return;

    IMP original = NULL;
    MSHookMessageEx(cls, selector, (IMP)HGHookedBoolGetter, &original);
    if (original) {
        gOriginalIMPs[key] = [NSValue valueWithPointer:(const void *)original];
        [gInstalledHooks addObject:[NSString stringWithFormat:@"%@.%@", className, key]];
        NSLog(@"[HongGuoPurify] hooked %@ %@", className, key);
    }
}

static void HGInstallHooks(void) {
    @autoreleasepool {
        gOriginalIMPs = [NSMutableDictionary dictionary];
        gInstalledHooks = [NSMutableSet set];

        HGInstallBoolHook(@"BDADShortVideoCommonAdManager", @"shouldRequestShortVideoAd");
        HGInstallBoolHook(@"BDADShortVideoCommonAdManager", @"shouldRequestPauseAd");
        HGInstallBoolHook(@"BDADShortVideoCommonAdManager", @"shouldRequestPatchAd");
        HGInstallBoolHook(@"SSAdShortVideoHomePageFeedAdConfig", @"enable_recommend_flow_ad");
        HGInstallBoolHook(@"SSAdShortVideoPlotTouchAdConfig", @"enable_plot_touch_ad");
        HGInstallBoolHook(@"SSAdShortVideoSideBarPatchAdConfig", @"enable_side_bar_patch_ad");
        HGInstallBoolHook(@"SSShortVideoCommentAdService", @"enableVideoAlbumAd");

        HGInstallBoolHook(@"SSShortVideoRcmdReasonViewManager", @"shouldDisplayRcmdReasonView");
        HGInstallBoolHook(@"FQVShortVideoBaseLeftContainerView", @"shouldShowVideoTagInfoInTagList");

        NSLog(@"[HongGuoPurify] initialization complete");
    }
}

%ctor {
    @autoreleasepool {
        NSString *bundleID = [NSBundle mainBundle].bundleIdentifier ?: @"(unknown)";
        NSLog(@"[HongGuoPurify] injected into process: %@", bundleID);

        // App classes may not be registered when the tweak constructor first runs.
        // Retry briefly before deciding this is not a Red Fruit process.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            BOOL looksLikeHongGuo =
                (NSClassFromString(@"BDADShortVideoCommonAdManager") != Nil) ||
                (NSClassFromString(@"FQVShortVideoBaseLeftContainerView") != Nil) ||
                (NSClassFromString(@"SSShortVideoRcmdReasonViewManager") != Nil);

            if (!looksLikeHongGuo) {
                NSLog(@"[HongGuoPurify] target classes not found; no hooks installed for: %@", bundleID);
                return;
            }

            NSLog(@"[HongGuoPurify] recognized target classes in: %@", bundleID);
            HGInstallHooks();
        });
    }
}
