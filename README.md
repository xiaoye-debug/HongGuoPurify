# HongGuoPurify

红果短剧净化插件的独立重建项目，目标 Bundle ID：`com.phoenix.video`。

## 当前状态

当前提交是可持续迭代的重建底座，不宣称与原版 1.0.1 完全等价。依据用户提供的 `红果短剧净化_1.0.1_无根.deb`，已确认其包含 arm64 与 arm64e Mach-O 动态库、Substrate Hook 入口，以及广告配置、推荐标签、下载、播放速度、清晰度和启动页相关符号/字符串线索。

首批代码只尝试安装经过运行时签名检查的无参数 BOOL 方法 Hook：
- 短视频广告请求判断
- 暂停广告与贴片广告判断
- 推荐流、侧边栏贴片、剧情触点广告开关
- 推荐理由和视频标签显示判断

Hook 会在类或方法缺失、参数数量不匹配或返回类型不匹配时跳过并记录日志，避免把未确认的 ABI 强行套用到目标进程。

## 构建

在 GitHub 仓库的 **Actions → Build HongGuoPurify → Run workflow** 运行构建。成功后在该次运行的 Artifacts 下载 `HongGuoPurify-rootless-deb`。

## 偏好文件

当前原型读取：
`/var/mobile/Library/Preferences/com.xiaoye.hongguopurify.plist`

可配置布尔键：
- `blockAds`：屏蔽已识别的广告开关（默认开启）
- `cleanUI`：隐藏推荐理由/视频标签（默认开启）

## 重要说明

这是基于可观察符号和运行时 ABI 检查的渐进式重建。二进制字符串只能证明相关名称存在，不能单独证明每个方法在所有红果版本中都存在或具有预期语义。下载、倍速、清晰度、启动页和原生设置 UI 仍需进一步验证与实现。请先在测试设备和可恢复环境中验证。
