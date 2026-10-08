# 猎户空间站 — 纯蓝图示例

将完整的 OrionBrowser 1.0.0 插件安装到工程 `Plugins/OrionBrowser`，使用 **Unreal Engine 5.8 / Win64** 打开 `OrionBrowserTemplate.uproject`。

公开示例不附带收费插件。工程自己的关卡为 `/Game/OrionStation/L_OrionStation`；可复用的空间站蓝图、界面控件与网页生产文件由已安装的插件提供。工程没有自己的 C++ 游戏模块。

等待编辑器中的 Helper 准备完成后点击 Play。界面支持简体中文和英文；任务进度、背包、偏好设置及 `OrionStationProfile` 存档由蓝图持有，网页只提交操作请求并显示状态。实验室页面展示字体、文字输入、动画、本地 three.js、Unreal 纹理和场景捕获；官网通过独立浏览器区域打开。

开始探索后，使用 **WASD** 移动、**E** 激活可见世界控件、**I** 打开背包、**P** 打开菜单或返回。宿主将 Escape 交给游戏时也可返回；PIE 中始终可以使用 P。右上角按钮和设置页都能切换语言。

[中文手册](https://github.com/IdealityCentury/OrionBrowser/blob/main/Documentation/README.zh-CN.md) · [English](README.md) · [配套工具](https://github.com/IdealityCentury/OrionBrowser/releases/tag/1.0.0)

打包时运行 `Scripts/Package-Development.ps1` 或 `Scripts/Package-Shipping.ps1`，通过 `-EngineRoot` 参数提供所用引擎根目录。脚本使用插件固定入口，在 Cook 前准备 Helper；输出位于工程 `Builds/Development` 或 `Builds/Shipping`。Studio 不进入游戏包。

分发和迁移游戏时保留完整输出目录。工具准备完成后，本地示例内容可以离线运行，只有官网访问需要联网；成品游戏不下载或修复 EXE。

请以对应发行验收报告了解实际测试的环境与输入设备。资产制作、Studio 预览和蓝图编译，与 Unreal 游玩及成品包运行分别记录。

独立示例通过 `Config/DefaultGameUserSettings.ini` 将初始游戏帧率上限设为 60，为本地浏览器和场景捕获留出 GPU 时间。已有用户设置会覆盖这个初始偏好；插件不会对其他工程强加此上限。调整场景或适配其他硬件时，请参考手册中的示例渲染预算说明。
