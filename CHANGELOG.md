# 修改记录

## 2026-10-29 划线颜色扩到上游 15 色并加自定义取色器（r266）

- 划线/笔记编辑面板的预设色此前只有 6 个（`#63C37D` 等），上游 `MarkingSheet.kt:449-464` 的 `MarkingPresetColors` 是 15 个。现逐条对齐换成 15 色，`#63C37D` 仍是新建标记的默认色（与上游 `DEFAULT_COLOR` 一致），所以已有标记的默认外观不变。
- 预设色行尾新增「自定义色」按钮，对齐上游 `MarkingSheet.kt:305-310`：未选中自定义色时显示 `+`，选中后显示该色与 `✓`。点它展开内联取色面板（上游是独立 `ColorPickerSheet`，本地没有独立 sheet 机制，改为同一面板内展开）。
- 取色面板包含 8 行 × 12 列色板（`paletteColor()` 按色相每列 30°、明度每行递减 0.075 生成，对齐上游 `rows = 8` / `hueColumns = 12`）与手输色值框。手输支持 `#RRGGBB` 与 `#AARRGGBB`，`normalizeColorText()` 只认这两种长度，非法输入不写入（实测输入 `#607D8B19CACA` 后保存，存储仍是上一个合法值）。
- **同时修掉一个可用性缺陷**：取色面板展开后内容超出一屏，面板本身没有滚动容器，底部「删除/取消/保存」被挤出到屏幕外（实测面板根 `Column` 到 `y=2692`，而「笔记」输入框渲染在 `[112,2811][1168,2832]`，保存按钮完全不可达）。现把标题之后的正文区包进 `Scroll`（`layoutWeight(1)` + `scrollBar(BarState.Off)`），按钮行固定在面板底部，外层 `Column` 加 `constraintSize({ maxHeight: '100%' })` 兜底。
- N 端设备验证：展开取色器后「保存」位于 `[964,2521][1168,2636]`（修复前在屏幕外）；点色板选色并保存 → `legado_reader_markings` 落盘 `#607D8B`；手输 `19CACA` 追加在已有值后成为非法串 → 保存不污染存储；收起面板后重进，颜色回显一致。

## 2026-10-29 自定义书签角标图片（r265）

- 上一轮遗留的「选择书签标记图片」此前是占位（`onUnavailableAction('图片选择与角标保存尚未迁移')`），「恢复默认」也只清一个私有预览状态。现对齐上游 `BookmarkBadgeDelegate.applyBadgeImage/clearBadgeImage` 补齐整条链路。
- 新增 `entry/src/main/ets/data/ReaderBookmarkBadgeRepository.ets`：`chooseImage()` 走 `picker.DocumentSelectOptions`（图片后缀过滤、单选），把用户选中的图片复制进应用私有目录 `filesDir/bookmark-badge/`，复制后校验字节数与原始文件一致，失败回滚删除；`removeImage()` 删除副本。**目标文件名带时间戳与随机数，每次选图都换新名**——阅读页按路径字符串缓存图片，沿用同名旧文件会画回旧图。
- `ReaderSettingsSnapshot` 增 `bookmarkBadgeImage`（默认空串，对齐上游 `ReadSettings.bookmarkBadgeImage`），load/save 同步；`Index.ets` 增 `@State readerBookmarkBadgeImage` 与 `pickReaderBookmarkBadgeImage()` / `resetReaderBookmarkBadgeImage()`，5 处挂载点全部透传。
- `ReaderPage` 与 `ReaderSettingsPage` 的自定义图分支改用新增的 `badgeImageSource()` 补 `file://` 前缀。**踩坑记录**：`Image()` 只接受 `file://` URI，直接传沙箱绝对路径会渲染成完全空白——且因为走了自定义分支，默认丝带也不会兜底，表现为「两种角标都不显示」。这与 `BookGroupRepository`/`BookRepository` 存封面图的约定一致（设置里存裸路径、渲染时补前缀），所以修在渲染侧而不是存储侧。
- `ReaderSettingsPage`「书签标记」行的 detail 由 `bookmarkBadgeImage.length > 0` 决定显示「自定义图片」或「默认」；面板预览区有自定义图时画真实图片，并新增「恢复默认」行；两处 `MenuSettingOption` 都补了 `migrated: true`（不加右侧会显示「尚未迁移」）。
- 角标右边距由固定的 6 改为 `paddingSettings.paddingRight + 6`，对齐上游 `ReaderBookmarkBadge.kt:26-38` 的 `leftPx = pageWidthPx - contentRightPaddingPx - 6 * density - width`。
- 备份侧一并补上 `readingAnchorEnabled` / `swipeToAddBookmark` / `bookmarkBadgeSize` / `bookmarkBadgeImage` 四项写 `config.xml`（前三项此前只有恢复侧读、备份侧不写，属半接通）；恢复侧读回 `bookmarkBadgeImage` 时先 `fileIo.accessSync` 校验，Android 私有目录路径在本机不存在则保留本机值。
- N 端设备验证：默认丝带黄色像素 1145（bbox `1174,218`–`1196,346`）；选图后自动复制到 `files/bookmark-badge/badge-…png`，偏好落盘该路径；修好 `file://` 前缀后阅读页出现青色/洋红像素 637/543（测试图为青洋红棋盘），设置面板预览 1264/1168；点「恢复默认」后图片文件被删除、detail 回「默认」、偏好落盘为空串、阅读页回默认丝带。
- 仍未迁移：`docs/KNOWN-ISSUES.md` 里目录页「更多」入口的占位。

## 2026-10-29 阅读页书签角标与「书签标记大小」设置（r264）

- 阅读页右上角此前完全没有书签角标：`ReaderPage` 只有 `hasBookmarkOnCurrentPage()` 这个判断函数，没有任何渲染代码，而「书签标记大小」设置项只改一个 `@State bookmarkBadgeSizePreview`，既不落库也不影响阅读页，属于纯装饰控件。现按上游 `ReadSettings.bookmarkBadgeSize` 补齐为真正生效的设置。
- 新增 `resources/base/media/app_bookmark_badge.svg`（12×24，`#FFFFC107` 黄色书签丝带，底部 V 形缺口）。上游用 `ic_bookmark_badge.xml` 的 VectorDrawable 直接画在正文画布上；ArkTS 侧无法在 `Canvas` 之外插绘制指令，改用等比例的 SVG 图片，宽度即 `bookmarkBadgeSize`、高度为其两倍。
- `ReaderSettingsSnapshot` 增 `bookmarkBadgeSize`（默认 10，范围 0–50，0 表示不显示）。`ReaderSettingsRepository` 的 load/save 同步补齐；`BackupRepository` 的 `readConfig` 偏好键组加 `bookmarkBadgeSize`，恢复时从 `config.xml` 读回（上游就存在这里），缺失则保留当前值。
- `ReaderPage` 增 `@Prop bookmarkBadgeSize` 与 `shouldShowBookmarkBadge()`：`<= 0` 不显示、滚动模式（`pageAnimation === 3`）不显示、非本地书籍不显示，其余走已有的 `hasBookmarkOnCurrentPage()` 页码区间判断。角标挂在正文层 `Stack({ alignContent: Alignment.TopEnd })` 内，与正文共用 `pageTurnOffsetX/Y` 与 `bookmarkPullOffset`，翻页动画和下拉偏移一并作用。
- `ReaderSettingsPage` 的 `bookmarkBadgeSizePreview` 私有预览状态删除，两处滑块（「书签标记大小」与详情面板里的「角标大小（dp）」）改为读写真实的 `bookmarkBadgeSize`，并接 `onBookmarkBadgeSizeChange` 回调即时保存；`Index.ets` 增 `setReaderBookmarkBadgeSize()`，四处 `ReaderSettingsPage` 挂载点与一处 `ReaderPage` 挂载点全部透传。
- N 端设备验证：默认 10dp 时第一页右上角出现 68×170 像素黄色区域（bbox `1172,176`–`1240,346`）；设 0 后黄色像素 0；设 30 后同一位置仍在；翻到第二页归 0、点回第一页恢复 2648 像素；冷启动读回仍为 2648；设置页拖滑块到 30 后 `legado_reader_settings` 落盘 `bookmarkBadgeSize=" value="30.000000"`。
- 仍未迁移：自定义角标图片选择（「书签标记」详情面板的「选择图片」），上游存于 `bookmarkBadgeCustom` 偏好并在画布上绘制用户图片，本地只保留默认丝带。

## 2026-10-29 「所有书签」页补齐书签编辑，书签原文可改（r263）

- 「所有书签」页的书签条目此前点不开编辑，只能跳转正文，写错备注必须绕回阅读页目录才能改。现对齐上游 `AllBookmarkScreen.kt:444-449`：书签条目**点击=编辑**、**长按=跳转正文**，笔记条目仍为点击跳转划线。`AllBookmarksPage` 增 `onEditBookmark` 回调，`BookmarkEntryCard` 增 `onJump` 并挂 `LongPressGesture`，挂载点接已有的 `editReaderBookmark()`。
- 书签编辑面板的原文此前是只读 `Text`，只能改备注。对齐上游 `BookmarkEditSheet.kt:94-108` 的两个输入框：原文改为可编辑 `TextArea`，`onSave` 签名由 `(note)` 扩为 `(note, bookText)`，`saveReaderBookmarkNote()` 同步写回 `bookText`。
- `ReaderBookmarkEditor` 浮层从阅读页分支的 `Stack` 提到外层 `Stack`。原先只在阅读页分支内渲染，从「所有书签」页唤起时不会出现。
- N 端设备验证四条路径：从「所有书签」点书签条目 → 面板打开且原文带出；改原文追加 `EDITED` 保存 → `legado_reader_bookmarks` 落盘为 `这一段是占位正文EDITED`；长按条目 → 跳转阅读页正文；从阅读页目录「书签 → 编辑」→ 面板正常打开。删除后存储回 `v1\n` 空态。

## 2026-10-29 书签与笔记接入 Android ZIP 备份与恢复（r262）

- `bookmark.json` 与 `bookMarking.json` 此前只在备份类别表里有名字，备份侧从不产出、恢复侧只原样拷贝。现补齐双向映射：`createBackup()` 写出根级 JSON，`restore()` 逐条解析后合并进 `ReaderBookmarkRepository` / `ReaderMarkingRepository`。
- 新增 `ReaderBookmarkExporter.toAndroidBookmarkArray()` / `toAndroidMarkingArray()`：直接复用书签页导出用的同一份字段映射，单独留名是为了让备份调用点读起来明确「这是上游 Backup.kt 写出的文件」。
- **恢复必须先合并再落盘**：两个条目在同一次恢复里先后出现，若先写书签时用旧笔记列表、后写笔记又覆盖回去，就会互相清除。`restore()` 用 `pendingBookmarks` / `pendingMarkings` 暂存，循环结束后各写一次。
- 合并口径与替换净化规则一致：同 id 或同内容视为同一条，命中时保留本地 id 并覆盖其余字段，其余新增；找不到对应书籍的计入跳过。`RestoreResult` 增 `bookmarkAdded/Updated/Skipped`，`Index.ets` 增 `describeBookmarkRestore()` 拼入恢复摘要。
- 恢复成功后重读 `readerBookmarks` 与 `readerMarkings`，让「所有书签」页与阅读页立即看到新数据。
- N 端设备验证：有 1 条书签 + 1 条笔记时导出 `bookmark.json` 1123 字节、`bookMarking.json` 562 字节，UTF-8 中文正常；清空本地笔记后从该 ZIP 恢复，提示「书签与笔记新增 1 条、覆盖 1 条」，冷启动后「所有书签」页显示「1 条书签 · 1 条笔记」。

## 2026-10-29 高亮规则预设导入与划线笔记渲染（r260）

- 新增 `data/ReaderHighlightRulePresets.ets`：对齐上游 `HighlightRulePresets` 的 11 条内置规则，规则面板加「预设规则」入口，勾选后追加进规则列表。已存在的同 id 规则标「已有」且不勾选，不覆盖用户改过样式的规则；标题作用域预设如实标「标题规则，本地暂不执行」并默认不勾。
- 与上游的三处差异逐条写在文件头注释里：`bracket_note_default` 的 `]` 补转义（上游正则在本机 `RegExp` 下编译失败）；`date_time_default` 裁到 179 字符（上游 314 超本地 256 上限，只裁纯中文数字年份与农历分支）；`title_emphasis_default` 本地不执行标题规则。
- 修复滚动模式下划线/笔记完全不渲染：`ReaderPage.markings` 变化时未递增 `readerContentRevision`，内容 `ForEach` 复用旧节点。改为 `@Watch('onMarkingsChanged')` 递增，并把标记区间并入 `getReaderHighlightTextRuns()` 的切段边界，标记优先于全局高亮规则。
- `ReaderHighlightTextRun` 增 `decorationType`/`decorationStyle`/`decorationColor`/`decorationThickness` 四个拍平字段，装饰在 run 里算好，避免 `@Builder` 内查不到最新标记。
- 修复笔记列表改样式后文案不刷新：`CatalogPage` 的 `ForEach` key 由 `marking.id` 改为 `markingItemKey()`（覆盖 effect/color/note/enabled）。
- N 端设备验证：滚动模式背景高亮 3848 绿色像素、波浪下划线渲染正常；改样式后列表文案由「背景高亮」即时变「波浪线」；删除标记后划线立即消失（491 → 0）；分页模式回归 491 像素通过。

## 2026-10-29 高亮规则接入 Android ZIP 备份与恢复（r259）

- `highlightRule.json` 此前只在备份类别表里有名字，备份侧从不产出、恢复侧只原样拷贝，属于对用户的误导。现补齐双向映射：`BackupRepository.createBackup()` 写出根级 JSON，`restore()` 逐条解析后合并进 `ReaderHighlightRuleRepository`。
- 恢复采用合并语义（同 id 或同 pattern 覆盖、其余新增、本地独有规则保留），与上游 `Restore.kt:270` 的 `replaceAll` 不同，理由是全量替换会无提示删除用户在 HarmonyOS 新建的规则。差异已在 `docs/BACKUP-RESTORE.md` 注明。
- 新增 `ReaderHighlightRuleRepository.getAll()` / `exportRules()` / `importRules()`；`RestoreResult` 增 `highlightRuleAdded/Updated/Skipped`；`Index.ets` 增 `describeHighlightRuleRestore()` 拼入恢复摘要。
- 备份写出前先 `await ReaderHighlightRuleRepository.load()`，避免缓存未填充时导出空数组。
- N 端设备验证：2 条规则导出 1349 字节 JSON，字段与上游一致；导入合成 ZIP 后新增 1、覆盖 1、跳过 1（坏正则），冷读回一致。

## 2026-10-28 阅读正文高亮规则设备验收与两处缺陷修复（r258）

- N 端在 HOS 模拟器完成 r258 高亮规则全部设备闭环：面板可达、创建、正文命中、停用、冷启读回、滚动模式连续滚动、删除，七项全部通过。E 端交接时「面板打不开」在 N 端未复现。
- 修复滚动模式高亮完全不生效：规则变化后未递增 `readerContentRevision`，内容 `ForEach` 复用旧节点导致内层 Span 不重建。修复后滚动模式红色像素由 0 变为 6596。
- 修复规则条目切换启停后文案不刷新：`ForEach` key 只用 `rule.id`，改为 `ruleItemKey()` 覆盖启停、顺序等可变字段。
- `ReaderHighlightTextRun` 拍平为五个基本类型字段，`ReaderHighlightRunSpan` 改为接收五个基本类型参数，规避 `@Builder` 按值传参丢失嵌套字段。
- N 端设备证据见 `docs/history/evidence/reader-highlight-rules-n-device-2026-10-28.md`，单独记录，不沿用 E 端验收结论。

## 2026-10-28 Android ZIP 类别门控与书架筛选（r255–r257）

- r255 从空 `config.xml` 创建兼容备份；阅读设置由 `readConfig` 类别单独控制，护眼六键由 `themeConfig` 类别单独控制。HOS 模拟器验证了两类设置分别包含或忽略的四种恢复组合。
- r256 修复隐藏分组页签后无法切换筛选项；可从分组管理选择当前可见分组。E 端验证了切换到“本地未分组”及强停冷启动读回。
- r257 在分组界面明确说明私有标记和分组刷新尚未生效。E 端完成 HAP 构建、保留数据覆盖安装和启动检查；设备没有自定义分组，因此卡片状态文案未在设备直接验证。
- `bookGroup.json` 书架分组导出/导入代码路径已接入；外部 Android ZIP 的完整分组往返尚未验。Android ZIP 阅读历史也未导入本地三层阅读记录。

## 2026-10-28 阅读设置与本地字体（r251–r254）

- 加入系统字体选择、本地 TTF/OTF 导入入口和阅读排版设置；对齐、正文效果和部分阴影/下划线设置在 E 端 HOS 模拟器进行了记录范围内的检查。
- r254 验证了阴影/下划线颜色设置、阅读页效果和冷启动读回；恢复了默认显示设置。自定义字体文件导入、CJK fallback、EPUB 字体以及 API 12 真机仍待验证。

## 2026-10-28 书架布局与排序（r250）

- 书架增加列表/网格、列数、标题行数、封面阴影、分组页签样式、隐藏空分组及全局排序设置，并使用本地偏好保存。
- 书籍 v15 新增最近更新、最近阅读时间和书架顺序字段，继续兼容 v1–v14；Android ZIP 配置增加书架布局配置键映射。
- E 端已核验保留数据覆盖安装、旧 v14 书目在 v15 下显示、列表布局冷启动读回和恢复默认网格。排序全量结果、分组自定义排序覆盖及 ZIP 配置往返仍未逐项验收，详见 `docs/VALIDATION.md`。

## 2026-10-28 书架分组网格管理

- 对照上游 `GroupManageSheet`/`GroupEditSheet` 重做分组管理：自适应两列网格卡片（封面/名称/排序与私有副标题/显示开关）、卡片点入编辑表单（封面选图与清除、名称、排序方式 7 档、下拉刷新开关、私有分组开关、删除两击确认）、`ForEach.onMove` 拖拽排序与新建表单。
- `BookGroup` 增加 `cover` 字段并透传全部序列化路径；分组封面复制到应用文件目录，清除时同步删除副本。修复了 `normalize` 重建对象丢失封面的问题。
- 分组显示开关与书架筛选页签联动；重命名分组时同步改写书籍的分组字段。
- N 端模拟器验证单独记录，不作为 E 端结论。E 端 r245 以 HDC/OCR 核验分组管理/编辑、排序菜单、刷新设置与私有标记保存读回，临时分组已清理；封面实际读回、拖拽、排序改变书目列表和私有访问控制未验，详见 `docs/KNOWN-ISSUES.md`。
- r243 “允许选择正文”设置与 ReaderPage selectable 行为已接入并在 E 端核验；其持久化使用本地 `selectText` 偏好。

## 2026-10-28 E 端 r242 阅读交互与日汇总

- 同步 E 端 r242 对阅读记录汇总按 `details.date` 分日显示的修正；阅读时间线继续按会话开始日，不拆分会话。
- E 端隔离 HOS 样例验证跨午夜分日展示；跨行选区、标注样式/备注 CRUD、目录定位冷启、书签增改/冷启/定位/删除及删除顺序互不影响均按记录检查。
- 公开进度区分已验 UI 样例与未验的真实跨午夜持久化；不包含测试书名、截图、HAP 或本机材料。API 12 真机未验，N 端 API 26 结果不计作 E 端证明。

## 2026-10-28 阅读记录三层整合

- 从 E 端 r241 稳定检查点同步阅读记录会话、按日明细、按书汇总及旧 v1 本地记录迁移；接入 `Index`、阅读记录页和阅读器会话生命周期。
- 保留公开副本既有 TXT 目录规则和书架数据；删除已迁移的旧 `ReadTimeRepository`，旧键在派生层重建后清理。
- E 端构建、覆盖安装和冷启动通过；旧记录迁移不重复、新 TXT 会话读回、清空确认取消及开关恢复启用已检查。摘要不公开书名、时间和原始记录数。
- 共享页面含仍在开发的标注/笔记切片，未作为完成项验收。跨午夜、扫描修复、字数统计、别名合并、API 12 及 Android ZIP 原生映射均保持未完成或未验证状态。

## 2026-10-28 TXT 目录规则 E 端整合

- 同步 E 端整合后的 TXT 目录规则模型、仓储、规则管理页、内置 JSON 与 Android ZIP 映射；保留 v13 书架分组/元数据和 v14 `chapterVolumes`/`tocRule` 字段布局，同时兼容 N 端旧规则字段位置。
- E 端已验证 27 条内置规则导入并重启保留、JSON 导出/重新导入；临时规则用于 TXT 导入后，分卷识别、卷头折叠与阅读进度持久化通过，测试数据已清理。
- 合成 Android ZIP 的单条 `txtTocRule.json` 恢复后冷启动读回通过；空规则应用备份读回通过。测试后原有书架条目和阅读进度保留。
- 内置规则 JSON 与上游文件逐字节一致，来源和 GPL-3.0 许可见 `docs/RESOURCE-LICENSES.md`。
- 隐私政策同步说明 TXT 目录规则在本机保存，并按用户选择文件导入/导出。
- 尚未验证书架更新目录设备行为、完整 CRUD/批量操作、非空规则应用备份恢复及 API 12 真机；详细边界见 `docs/KNOWN-ISSUES.md`。

## 2026-10-28 替换净化整合源码同步

- 以 E 端整合源码同步规则导入器、仓储、备份映射、阅读页面与规则管理 UI；同时保留书架 v12 元数据、眼保设置和阅读进度改动。
- 修正规则导入 ID 冲突处理；规则列表与阅读处理面板共用稳定行键；按书开关与阅读页面的替换规则状态连通。
- 备份未排除规则类别时总写出当前规则快照，包括空数组，防止从旧归档夹带已删除规则；恢复逐条导入、按 ID/pattern 合并并保留本地 ID 和顺序，非法正则跳过。
- E 端 HAP 构建/覆盖安装后，用 OCR/HDC 到达“我的→替换净化”空列表。未在 E 端创建规则或完成文件导入/导出、ZIP 规则恢复全往返。
- 记录未解决限制：timeoutMillisecond 未限制同步正则运行；快速并发写入未做压力验证；恢复提示标点需再次 UI 核验；API 12 真机未验。

## 2026-10-27 安全双机共同基线

- 按白名单将最新源码、必要构建配置和许可资源同步到独立公开副本；212 个文件通过复制前后 SHA-256 核对，包含 60 个 ArkTS 文件，其中 7 个相对前一公开版本有改动；保留现有已审查的公开 NOTICE。
- 增加机器无关的项目队列、模块状态、备份兼容、UI 验收、术语、资源和发行说明；保留现有构建、许可、隐私、使用协议与免责声明。
- 不包含本机 CURRENT、历史诊断目录、私人资源、用户书籍、备份归档、签名材料或构建产物。
- 独立公开副本 clean 后构建成功；仅生成未签名调试 HAP，未随仓库上传。

## 2026-10-26 当前进度同步

- 同步五个阅读相关路由当前实现状态：目录定位/设置持久化、书内搜索与朗读返回逻辑仍需设备验收；TTS 播放未接入。
- 补充图片点击模式和封面预览记录；章节内嵌图片场景未验证，设置恢复默认值。
- 媒体资源更新至 133 个 SVG；完成对此前 10 个待核图标的来源映射：8 个取自原 Android 实际使用的 AndroidX Material Icons 1.7.8，2 个排序方向图标转换自原项目上下箭头并按 GPL-3.0 记录为近似映射。
- 当前源码 clean 构建成功并安装到 HOS 模拟器；无签名配置，未上传 HAP。

## 2026-10-25 当前进度同步

- 同步当前 HarmonyOS Stage 源码：阅读器顶栏/底栏 28 项配置、书签、正文处理/替换规则/按书重分段、订阅源管理页等增量。
- 更新 P1–P4 当前状态与下一项验收范围；新增本地可公开的进度摘要。
- 隐私说明补充用户主动粘贴规则时的系统剪贴板读取/写入行为，并同步更新应用内隐私声明。
- 资源清单更新至 118 个 SVG；48 个与 Android drawable 路径精确匹配，27 个新增图标来源待确认。
- 官方 npm registry 配置下 Hvigor clean 构建成功；未签名 HAP 未作为发行文件上传。

## 2026-10-24 开发预览源码

- 独立导出 HarmonyOS Stage 工程，保留当前 ArkTS/ArkUI、本地 TXT/EPUB 阅读与 Android ZIP 兼容实现。
- 首次整理面向公开仓库的进度、构建、隐私、使用协议、免责声明与资源来源资料。
- 不包含 Android 主工程、用户文件、私人开发过程记录、参考素材包和签名凭据。
- 当前阅读器 UI 及全流程验收未完成，本次源码公开不代表 P1–P4 全部完成。
- 未提供正式签名安装包；构建验证与设备验证分别记录。
