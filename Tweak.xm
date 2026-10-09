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

/*
 * MSHookMessageEx may be installed on a base class while the receiver is a
 * runtime subclass. Walk the class chain so the original IMP lookup remains
 * correct for inherited methods as well as direct instances.
 */
static IMP HGOriginalIMPForReceiver(id receiver, SEL selector) {
    Class cls = object_getClass(receiver);
    while (cls) {
        NSValue *value = gOriginalIMPs[HGHookKey(cls, selector)];
        if (value) return (IMP)value.pointerValue;
        cls = class_getSuperclass(cls);
    }
    return NULL;
}

static BOOL HGHookedBoolGetter(id self, SEL _cmd) {
    IMP original = HGOriginalIMPForReceiver(self, _cmd);
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
    NSLog(@"[HongGuoPurify] original IMP missing for %@; returning NO", selectorName);
    return NO;
}

static BOOL HGIsSupportedBoolMethod(Method method, NSString *className, NSString *selectorName) {
    if (!method) return NO;

    unsigned int argCount = method_getNumberOfArguments(method);
    char returnType[16] = {0};
    method_getReturnType(method, returnType, sizeof(returnType));

    if (argCount != 2 || (returnType[0] != 'B' && returnType[0] != 'c')) {
        NSLog(@"[HongGuoPurify] ABI mismatch, skipped: %@ %@ (%s, args=%u)",
              className, selectorName, returnType, argCount);
        return NO;
    }
    return YES;
}

static void HGInstallOnClassOrMetaclass(Class target, NSString *className,
                                         SEL selector, NSString *selectorName) {
    Method method = class_getInstanceMethod(target, selector);
    if (!HGIsSupportedBoolMethod(method, className, selectorName)) return;

    NSString *key = HGHookKey(target, selector);
    if ([gInstalledHooks containsObject:key]) return;

    IMP original = NULL;
    MSHookMessageEx(target, selector, (IMP)HGHookedBoolGetter, &original);
    if (original) {
        gOriginalIMPs[key] = [NSValue valueWithPointer:(const void *)original];
        [gInstalledHooks addObject:key];
        NSLog(@"[HongGuoPurify] hooked %@ %@%@", className,
              class_isMetaClass(target) ? @"+" : @"-", selectorName);
    } else {
        NSLog(@"[HongGuoPurify] hook failed: %@ %@%@", className,
              class_isMetaClass(target) ? @"+" : @"-", selectorName);
    }
}

static void HGInstallBoolHook(NSString *className, NSString *selectorName) {
    Class cls = NSClassFromString(className);
    SEL selector = NSSelectorFromString(selectorName);
    if (!cls) {
        NSLog(@"[HongGuoPurify] class missing: %@", className);
        return;
    }

    BOOL found = NO;
    if (class_getInstanceMethod(cls, selector)) {
        HGInstallOnClassOrMetaclass(cls, className, selector, selectorName);
        found = YES;
    }

    Class meta = object_getClass(cls);
    if (meta && class_getInstanceMethod(meta, selector)) {
        HGInstallOnClassOrMetaclass(meta, className, selector, selectorName);
        found = YES;
    }

    if (!found) NSLog(@"[HongGuoPurify] method missing (instance/class): %@ %@",
                      className, selectorName);
}

static void HGInstallHooks(void) {
    @autoreleasepool {
        gOriginalIMPs = [NSMutableDictionary dictionary];
        gInstalledHooks = [NSMutableSet set];

        // Candidate methods are present in the supplied original binary's
        // metadata/strings. Their runtime presence is checked before installation.
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
            NSLog(@"[HongGuoPurify] not Red Fruit (%@), skip", bundleID);
            return;
        }

        NSLog(@"[HongGuoPurify] injected into target app: %@", bundleID);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            HGInstallHooks();
        });
    }
}
