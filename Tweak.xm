#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

static NSString * const kPrefsPath = @"/var/mobile/Library/Preferences/com.xiaoye.hongguopurify.plist";
static NSMutableDictionary<NSString *, NSValue *> *gOriginalIMPs;
static NSMutableSet<NSString *> *gInstalledHooks;

static NSDictionary *HGReadPreferences(void) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    return [prefs isKindOfClass:[NSDictionary class]] ? prefs : @{};
}

static BOOL HGPreference(NSString *key, BOOL fallback) {
    id value = HGReadPreferences()[key];
    return value ? [value boolValue] : fallback;
}

static NSString *HGHookKey(Class cls, SEL selector) {
    return [NSString stringWithFormat:@"%@::%@", NSStringFromClass(cls), NSStringFromSelector(selector)];
}

static BOOL HGHookedBoolGetter(id self, SEL _cmd) {
    Class runtimeClass = object_getClass(self);
    NSString *key = HGHookKey(runtimeClass, _cmd);
    IMP original = (IMP)[gOriginalIMPs[key] pointerValue];

    NSString *selectorName = NSStringFromSelector(_cmd);
    BOOL isAdDecision =
        [selectorName isEqualToString:@"shouldRequestShortVideoAd"] ||
        [selectorName isEqualToString:@"shouldRequestPauseAd"] ||
        [selectorName isEqualToString:@"shouldRequestPatchAd"] ||
        [selectorName isEqualToString:@"enable_recommend_flow_ad"] ||
        [selectorName isEqualToString:@"enable_plot_touch_ad"] ||
        [selectorName isEqualToString:@"enable_side_bar_patch_ad"] ||
        [selectorName isEqualToString:@"enableVideoAlbumAd"];

    BOOL isCleanUI =
        [selectorName isEqualToString:@"shouldDisplayRcmdReasonView"] ||
        [selectorName isEqualToString:@"shouldShowVideoTagInfoInTagList"];

    if (isAdDecision && HGPreference(@"blockAds", YES)) return NO;
    if (isCleanUI && HGPreference(@"cleanUI", YES)) return NO;

    if (original) return ((BOOL (*)(id, SEL))original)(self, _cmd);
    NSLog(@"[HongGuoPurify] original IMP not found for %@; preserving safe default", key);
    return NO;
}

static void HGInstallBoolHook(NSString *className, NSString *selectorName) {
    Class cls = NSClassFromString(className);
    SEL selector = NSSelectorFromString(selectorName);

    if (!cls || !class_getInstanceMethod(cls, selector)) {
        NSLog(@"[HongGuoPurify] class/method missing: %@ %@", className, selectorName);
        return;
    }

    Method method = class_getInstanceMethod(cls, selector);
    unsigned int argCount = method_getNumberOfArguments(method);
    char returnType[8] = {0};
    method_getReturnType(method, returnType, sizeof(returnType));
    if (argCount != 2 || (returnType[0] != 'B' && returnType[0] != 'c')) {
        NSLog(@"[HongGuoPurify] ABI mismatch, skipped: %@ %@ (%s, args=%u)",
              className, selectorName, returnType, argCount);
        return;
    }

    NSString *key = HGHookKey(cls, selector);
    if ([gInstalledHooks containsObject:key]) return;

    IMP original = NULL;
    MSHookMessageEx(cls, selector, (IMP)HGHookedBoolGetter, &original);
    if (original) {
        gOriginalIMPs[key] = [NSValue valueWithPointer:(const void *)original];
        [gInstalledHooks addObject:key];
        NSLog(@"[HongGuoPurify] hooked %@ %@", className, selectorName);
    } else {
        NSLog(@"[HongGuoPurify] hook failed: %@ %@", className, selectorName);
    }
}

static void HGInstallHooks(void) {
    @autoreleasepool {
        gOriginalIMPs = [NSMutableDictionary dictionary];
        gInstalledHooks = [NSMutableSet set];

        // These candidates are confirmed by strings in the supplied original binary,
        // but still require runtime verification against the installed Red Fruit version.
        HGInstallBoolHook(@"BDADShortVideoCommonAdManager", @"shouldRequestShortVideoAd");
        HGInstallBoolHook(@"BDADShortVideoCommonAdManager", @"shouldRequestPauseAd");
        HGInstallBoolHook(@"BDADShortVideoCommonAdManager", @"shouldRequestPatchAd");
        HGInstallBoolHook(@"SSAdShortVideoHomePageFeedAdConfig", @"enable_recommend_flow_ad");
        HGInstallBoolHook(@"SSAdShortVideoPlotTouchAdConfig", @"enable_plot_touch_ad");
        HGInstallBoolHook(@"SSAdShortVideoSideBarPatchAdConfig", @"enable_side_bar_patch_ad");
        HGInstallBoolHook(@"SSShortVideoCommentAdService", @"enableVideoAlbumAd");
        HGInstallBoolHook(@"SSShortVideoRcmdReasonViewManager", @"shouldDisplayRcmdReasonView");
        HGInstallBoolHook(@"FQVShortVideoBaseLeftContainerView", @"shouldShowVideoTagInfoInTagList");

        NSLog(@"[HongGuoPurify] hook pass complete; installed=%lu",
              (unsigned long)gInstalledHooks.count);
    }
}

%ctor {
    @autoreleasepool {
        NSString *bundleID = [NSBundle mainBundle].bundleIdentifier ?: @"(unknown)";
        if (![bundleID isEqualToString:@"com.phoenix.video"]) {
            NSLog(@"[HongGuoPurify] not Red Fruit (%@), skip injection logic", bundleID);
            return;
        }

        NSLog(@"[HongGuoPurify] injected into target app: %@", bundleID);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            HGInstallHooks();
        });
    }
}
