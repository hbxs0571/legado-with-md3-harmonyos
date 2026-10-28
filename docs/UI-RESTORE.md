# UI 还原流程

本文是当前模块页面从 Android 原版还原到 ArkUI 的操作流程。目标与边界见[项目队列](PROJECT.md)，验收门槛见[UI 验收口径](UI-PARITY.md)，术语见[术语表](GLOSSARY.md)；本文回答「怎么做到」。

适用范围：已进入当前功能模块的页面。候选页面不因本文存在而自动展开。

## 一、读 Android 源码

输入：当前模块对应的页面名、路由或入口。

1. 先定位 Route / Screen / Contract / ViewModel 四件套，再向下读共用组件、主题、文案与导航。列出整页区域、全部标签与直接弹层的清单，写明源码路径与版本，再动代码。
2. 图标先查 `app/src/main/java/io/legado/app/ui/widget/components/icon/AppIcons.kt` 的 `ImageVector` 映射，再查 `androidx.compose.material.icons` 与 `top.yukonga.miuix.kmp.icon`，最后才查 `app/src/main/res/drawable` 的 `<vector>`。`res/drawable` 里大量条目是旧 View 体系遗留，直接扫目录会取到已废弃图标。
3. 以源码为准，不以分析文档为准。示例：Android 侧 `CLAUDE.md` 称阅读页「ReadBookActivity — still View-based」，但仓库内不存在 `ReadBookActivity.kt`，实际为 Compose 的 `ReadBookScreen.kt`。

完成标志：能说出页面由哪几个区域组成、每个区域对应哪个源码文件、哪些控件属于哪个共用组件。

## 二、核对界面、弹层、卡片、按钮与文案位置

1. 逐层读组件树：卡片尺寸、间距、圆角、颜色、按钮热区、文案位置、字体/行高/换行、权重、inset、状态分支与点击结果，注明参数来源。
2. 弹层（Android 侧 `*Sheet*.kt`）以 `AppModalBottomSheet` 为基座形态；记录开合条件、返回行为与遮罩，不用统一占位页代替。
3. 卡片与按钮按原版分类对齐：卡片为 GlassCard、SelectionItemCard、SettingCard、TextCard、HighlightTagRow；按钮为 AppButton、AppIconButton、ToggleChip、ConfirmDismissButtonsRow 及 `series/` 变体。
4. 文案取自 `app/src/main/res/values/strings.xml`（默认英文）与 `values-zh-rCN/strings.xml`（简体）。按原版当前书籍类型/状态的适用规则决定展示项，不按「HOS 已实现哪些功能」删减原版项。

完成标志：整页清单里每个区域、每张卡片、每个按钮、每条文案都能追到 Android 侧的来源。

## 三、拉取原始向量图标

三级优先，不得跳级：

1. `AppIcons.kt` 的 `ImageVector`（Compose 主源，MD3 分支的实际来源）；
2. `androidx.compose.material.icons` / `top.yukonga.miuix.kmp.icon` 的原始路径；
3. `app/src/main/res/drawable` 的 `<vector>`（仅在前两级都没有时使用，且须确认该条目在 Kotlin 中仍有引用）。

落地要求：

- 转 SVG 时保留 path / viewport / transform / fill / stroke / 裁剪 / 镜像；**不用字符或相似图标替代**。
- 经 `entry/src/main/ets/components/AppGlyph.ets` 接入，统一 `glyphSize` 与 `tint`；不经 `AppGlyph` 的 `Image` 必须显式给 `fillColor`，不依赖 SVG 内联 `fill`。
- 同一批次更新[资源许可清单](RESOURCE-LICENSES.md)与[来源哈希表](RESOURCE-SOURCES-SHA256-2026-10-26.csv)，记录来源、版本、许可及是否随安装包分发。Android 侧图标没有独立许可声明，来源不明确的不取用。

完成标志：新增图标的来源、许可、双端哈希均已登记，代码中无裸 `Image` 缺色。

## 四、还原并校准

1. ArkUI 原生实现，构建并安装到明确的目标设备。
2. 按下方七项独立验收；完整页面可见且能走查后，再做整页同态对照。
3. 同态对照要求同一书籍、章节锚点、主题/字号、控制层状态与滚动位置，并记录视口与密度；动态行为需录像，不能只凭静图。
4. 截图只在源码无法判断布局、交互有疑点或发现视觉回退时使用，指人工视觉比对。模拟器 OCR 导航所需的临时取像不作为逐页视觉验收。构建通过不能代替设备交互检查；设备不可用时记录「未验」，不补写通过。

## 七项验收

1. 入口可达
2. 页面结构完整
3. 文字可读
4. 文案与图标来源正确
5. 操作有效
6. 返回正确
7. 状态真实

动效只在影响触控、反馈或返回时作为阻塞问题处理。未迁移功能应明确标记；仅有视觉控件或动画不代表数据已保存或服务已启动。

## 禁止项

- 不用字符、相似图标或统一占位页代替原版图标与页面。
- 不伪造保存成功或实际执行；仅页面内预览须明确未保存。
- 不把分析文档完成当作功能完成，不把构建通过当作设备验收通过。
- 不把「不要求像素级 1:1」理解为可以省掉七项验收或同态对照。

## 与其他文档的关系

| 文档 | 作用 |
| --- | --- |
| [项目队列](PROJECT.md) | 功能优先顺序、页面与行为的目标表述 |
| [UI 验收口径](UI-PARITY.md) | 七项验收的公开门槛 |
| [验证记录](VALIDATION.md) | 设备与 OCR 操作规范、按日期排列的验证事实 |
| [资源许可清单](RESOURCE-LICENSES.md)、[来源哈希表](RESOURCE-SOURCES-SHA256-2026-10-26.csv) | 图标来源、许可与双端哈希 |
| [素材说明](ASSETS.md) | 资源公开范围与新增资源的前置记录要求 |
| [历史流程细节](history/project-records/WORKFLOW.md) | 2026-10-24 用户纠正的原文记录，已提升为本文 |
