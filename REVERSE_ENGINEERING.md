# 原版 1.0.1 逆向分析记录

分析对象：用户提供的 `红果短剧净化_1.0.1_无根.deb`

## 1. 包结构与注入目标（已确认）

- 包名：`hongguofn`
- 版本：`1.0.1`
- 架构：arm64、arm64e
- 动态库：`hongguofn.dylib`
- 注入过滤：`com.phoenix.video`
- 依赖：MobileSubstrate
- 原版描述：红果短剧界面净化、短剧广告控制、原生独立设置开关、时长显示及原生下载

## 2. 从原版二进制中确认的功能线索

以下是从 Objective-C 类名、选择器、偏好键和界面字符串中提取的线索。它们能证明原版二进制包含相关实现或引用，但每项的具体行为仍须结合反汇编/运行时验证，不能仅凭字符串认定已经完整还原。

### 广告及界面净化
- 广告控制相关类/方法：`BDADShortVideoCommonAdManager`、`shouldRequestShortVideoAd`、`shouldRequestPauseAd`、`shouldRequestPatchAd`、`shouldShowPauseAdWithCloseStrategy`、`SSShortVideoCommentAdService`、`enableVideoAlbumAd`、`enableShortVideoCommentAd:`
- 推荐流、侧边栏贴片、剧情触点广告配置：`SSAdShortVideoHomePageFeedAdConfig`、`SSAdShortVideoSideBarPatchAdConfig`、`SSAdShortVideoPlotTouchAdConfig`
- 推荐理由和视频标签：`SSShortVideoRcmdReasonViewManager`、`shouldDisplayRcmdReasonView`、`FQVShortVideoBaseLeftContainerView`、`shouldShowVideoTagInfoInTagList`
- 弹窗/挂件相关线索：`BDARewardedVideoAdController`、`SSWelfareListenPendantManager`、`SSWelfareGlobalPendantManager`

### 原生下载与播放控制
- 下载入口：`FQVShortVideoListDownloadConfig`、`enableDownloadItem`、`SSShortVideoDownloadVideoManager`、`checkCanShowDownloadWithVideoDataModel:`、`downloadItemRemovalReasonWithVideoDataModel:`
- 倍速：`FQVShortVideoListPlayConfig`、`defaultFastPlayRate`、`defaultPlayRate`、`playRateWithModel:`、`recordPlayRateWithModel:`、`updatePlayer:playRate:model:reasonModel:finish:`
- 清晰度：`FQVPlayerEngineDataResolutionItem`、`setForceResolutionTypeNumber:`、`setEnableNetworkSpeedToChooseResolution:`、`supportedResolutionTypes`、`updatePlayer:resolution:model:finish:`
- 原版还包含 360P、480P、540P、720P、1080P 等选项字符串。

### 界面、导航和其他功能
- 原生设置相关：`SSSettingViewController`、`SSShortVideoDefaultLandingTabSettingsView`、`SSShortVideoDefaultLandingTabSettingsCellModel`、`HGPurify.selection.footer`
- 偏好键：`HGPurify.enabled`、`HGPurify.defaultSpeed`、`HGPurify.lockResolution`、`HGPurify.startupTab`、`HGPurify.startupTop`、`HGPurify.mergedAI104`，以及 `HGPurify.feature.%lu`、`HGPurify.%@.%@`
- 启动/默认标签页：`SSShortVideoDefaultLandingBottomTabConfigManager`、`currentLandingTabType`、`userSelectedLandingTabType`、`commitFirstScreenSelectionWithServerIndex:` 等
- 红点、侧栏净化：`SSMyUserSideBarViewController`、`shouldDisplaySidebarItem:`、`filteredSidebarItemsWithItems:`、`updateSidebarItemRedDotCellType:show:` 等
- 播放界面清爽模式：`FQVShortVideoListControlConfig`、`enableCleanScreen`、`enterCleanMode`、`exitCleanMode`
- 时长显示线索：`HGProfileClipObserver`、`%lld:%02lld:%02lld`、`%02lld:%02lld`
- 原版自定义界面类：`HGSpeedControls`、`FNWeakPlaybackOwner`、`HGProfileClipObserver`

## 3. 当前重建仓库与原版的差距

当前 `Tweak.xm` 只尝试 Hook 少数 BOOL 方法，未实现原版中的原生设置界面、下载、倍速、清晰度、默认标签页、侧栏/红点净化和时长显示。现有广告 Hook 也尚未在真实红果进程中验证。

另外，当前重建代码按 selector 名称保存原始 IMP，而不是按“类 + selector”保存；若多个类有同名 selector，可能产生原始实现映射冲突。后续实现应修正此问题，并为有参数的方法使用准确的函数签名，不能把所有方法都当成无参数 BOOL getter。

## 4. 后续还原顺序

1. 进一步分析原版 Objective-C 元数据与方法实现，区分广告请求拦截、视图隐藏和 UI 设置逻辑。
2. 先还原广告控制与界面净化，并为每个 Hook 加入安装成功/跳过日志。
3. 还原独立原生设置入口、偏好持久化和功能开关。
4. 还原原生下载、倍速、清晰度、启动标签页、红点净化及时长显示。
5. 每个阶段都必须先编译，再用目标应用日志和实际界面验证；不能以编译通过替代功能验证。

## 5. 证据边界

本记录来自 DEB 控制信息、注入 plist、Mach-O 架构信息及动态库中的 Objective-C 类名/方法名/字符串。当前尚未完成逐函数反汇编，也没有在设备上运行原版与重建版做行为对照。因此，本文件是第一阶段静态分析记录，不是功能已复刻完成的声明。
