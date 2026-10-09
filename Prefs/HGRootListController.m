#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

static NSString * const HGPrefsPath = @"/var/mobile/Library/Preferences/com.xiaoye.hongguopurify.plist";
static NSString * const HGChangedNotification = @"com.xiaoye.hongguopurify/preferences-changed";

@interface HGRootListController : PSListController
@end

@implementation HGRootListController

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;

    NSMutableArray *items = [NSMutableArray array];
    PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:@"红果净化"
                                                        target:nil
                                                           set:NULL
                                                           get:NULL
                                                        detail:nil
                                                          cell:PSGroupCell
                                                          edit:nil];
    [items addObject:group];

    [items addObject:[self toggle:@"启用插件" key:@"enabled" defaultValue:@YES]];
    [items addObject:[self toggle:@"广告净化" key:@"blockAds" defaultValue:@YES]];
    [items addObject:[self toggle:@"界面净化" key:@"cleanUI" defaultValue:@NO]];

    NSArray *titles = @[
        @"阅读去广告", @"听书去广告", @"推广入口净化", @"关闭评价邀请", @"隐藏短剧金币挂件", @"隐藏章末圈子",
        @"减少通知权限提醒", @"减少小组件提醒", @"会员状态显示优化（不改变真实权益）", @"隐藏作者的话", @"隐藏本章讨论入口", @"隐藏章末圈子按钮",
        @"隐藏章末送礼物", @"隐藏最新章节三个按钮", @"隐藏底部福利导航", @"允许快速跳过激励广告", @"隐藏我的页福利卡片", @"返回标题固定为章节名",
        @"隐藏我的页推荐卡片", @"隐藏我的页发帖按钮", @"隐藏底部短剧导航", @"关闭短剧进入自动播放", @"隐藏书城发帖按钮", @"隐藏书架漫剧推荐",
        @"隐藏书架今日听读时长", @"隐藏书架导入本地书入口", @"短剧去广告", @"隐藏发送弹幕按钮", @"隐藏作者声明", @"隐藏系列剧集入口",
        @"隐藏爆剧标志", @"隐藏热评", @"隐藏剧标签", @"隐藏顶部导航", @"隐藏 AI 短剧备案号", @"隐藏我的页顶部快捷入口整组",
        @"进度条显示时长", @"允许强制本地下载", @"隐藏视频榜单排名", @"隐藏红点提醒", @"隐藏侧边栏游戏中心", @"自动使用默认倍速播放",
        @"播放时自动清屏", @"暂停时退出清屏模式"
    ];

    PSSpecifier *featureGroup = [PSSpecifier preferenceSpecifierNamed:@"功能开关"
                                                              target:nil
                                                                 set:NULL
                                                                 get:NULL
                                                              detail:nil
                                                                cell:PSGroupCell
                                                                edit:nil];
    [items addObject:featureGroup];
    for (NSUInteger i = 0; i < titles.count; i++) {
        NSNumber *defaultValue = (i == 0 || i == 1 || i == 26) ? @YES : @NO;
        [items addObject:[self toggle:titles[i] key:[NSString stringWithFormat:@"feature.%lu", (unsigned long)i] defaultValue:defaultValue]];
    }

    PSSpecifier *note = [PSSpecifier preferenceSpecifierNamed:@"说明：部分功能取决于红果短剧版本中的实际类和方法；本页面只提供开关，不代表每项功能均已在真机验证。"
                                                       target:nil
                                                          set:NULL
                                                          get:NULL
                                                       detail:nil
                                                         cell:PSGroupCell
                                                         edit:nil];
    [items addObject:note];
    _specifiers = [items copy];
    return _specifiers;
}

- (PSSpecifier *)toggle:(NSString *)title key:(NSString *)key defaultValue:(NSNumber *)defaultValue {
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:title
                                                            target:self
                                                               set:@selector(setPreferenceValue:specifier:)
                                                               get:@selector(readPreferenceValue:)
                                                            detail:nil
                                                              cell:PSSwitchCell
                                                              edit:nil];
    [specifier setProperty:key forKey:@"key"];
    [specifier setProperty:defaultValue forKey:@"default"];
    return specifier;
}

- (NSMutableDictionary *)preferences {
    NSDictionary *disk = [NSDictionary dictionaryWithContentsOfFile:HGPrefsPath];
    return disk ? [disk mutableCopy] : [NSMutableDictionary dictionary];
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    NSDictionary *prefs = [self preferences];
    id value = prefs[key];
    return value ?: ([specifier propertyForKey:@"default"] ?: @NO);
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key.length) return;
    NSMutableDictionary *prefs = [self preferences];
    prefs[key] = value ?: @NO;
    [[NSFileManager defaultManager] createDirectoryAtPath:@"/var/mobile/Library/Preferences"
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    [prefs writeToFile:HGPrefsPath atomically:YES];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)HGChangedNotification,
                                         NULL, NULL, YES);
}

@end
