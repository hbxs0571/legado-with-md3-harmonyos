// 书源调试页（P10，任务书第十四节）。
// 对齐上游 BookSourceDebugScreen：目标 chip + 输入 + 示例 + 日志列表 + 过滤 chip + 详情浮层；
// 顶栏清除、FAB 二态开始/停止。数据来自 BookSourceDebugCoordinator（宿主打点事件总线）。
import { AppTopBar, TopBarBackButton, TopBarButton } from '../components/TopBar';
import {
  DebugEntry, DebugEventKind, DebugTarget, DebugFilter, DebugStatus,
  DEBUG_TARGETS, DEBUG_FILTERS,
  targetTitle, targetHint, filterTitle, kindTitle, matchesFilter
} from '../bookSource/BookSourceDebugModels';
import {
  DebugEventBus, BookSourceDebugCoordinator, DebugRunResult, buildDebugKey
} from '../bookSource/BookSourceDebugCoordinator';
import { BookSourceRepository } from '../data/BookSourceRepository';
import { BookSource } from '../model/BookSource';
import {
  BODY_LARGE, BODY_LARGE_LINE_HEIGHT, BODY_SMALL, LABEL_MEDIUM, LABEL_SMALL, TITLE_MEDIUM
} from '../components/typography/TypographyTokens';
import { AppFab } from '../components/booksource/AppFab';
import { AppGlyph } from '../components/AppGlyph';
import { MarkdownIntro } from '../components/MarkdownIntro';
// fadingEdge 的渐变宽度用 LengthMetrics.vp(16) 传，对齐上游 gradientWidth = 16.dp。
import { LengthMetrics } from '@kit.ArkUI';

/** 示例项（具名接口，ArkTS 禁匿名对象字面量）。 */
interface DebugExample {
  title: string;
  target: DebugTarget;
  value: string;
}

/** 空态笑脸候选：上游 EmptyMessage.kt:38-41 的七张脸。 */
const DEBUG_FACES: string[] = [
  '(；′⌒`)', '(つ﹏⊂)', '(•̀ᴗ•́)و', '(๑•́ ₃ •̀๑)',
  '(눈‸눈)', '(ಥ﹏ಥ)', '(｡•́︿•̀｡)'
];

/**
 * 单个 ToggleChip（对齐上游 ToggleChip.kt:26-108）。
 * 必须做成独立 @Component 而不是本页的 @Builder：@Builder 按值传参时，
 * 父组件状态变化不会重建 Builder 内部 UI（ArkUI 已知限制），
 * 表现为点目标 chip 后 placeholder 变了、高亮却停在原处。
 */
@Component
struct DebugChip {
  @Prop label: string = '';
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorPrimaryContainer') themeColorPrimaryContainer: string = '#354E16';
  @StorageProp('themeColorOnPrimaryContainer') themeColorOnPrimaryContainer: string = '#D5EFAD';

  build() {
    Row() {
      // 对齐上游 ToggleChip.kt:75-88：选中时才出现 16dp 的 Check，未选不占位。
      if (this.selected) {
        AppGlyph({ name: 'profileCheck', glyphSize: 16, tint: this.themeColorAccent })
          .margin({ right: 8 })
      }
      Text(this.label)
        .fontSize(LABEL_MEDIUM)
        .fontWeight(FontWeight.Medium)
        // 对齐上游 ToggleChip：选中=primaryContainer 底 + onPrimaryContainer 字，未选=surface 底 + onSurface 字。
        .fontColor(this.selected ? this.themeColorOnPrimaryContainer : this.themeColorTextPrimary)
        .maxLines(1)
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(this.selected ? this.themeColorPrimaryContainer : this.themeColorSurfaceTertiary)
    .borderRadius(12)
    .margin({ right: 8, top: 2, bottom: 2 })
    // 上游 ToggleChip.kt:45-58 的 toggleableState + stateDescription：
    // 用 ArkUI 的 accessibilityChecked 表达「可勾选 + 当前是否勾选」，
    // 用 accessibilityStateDescription 表达「已选择/未选择」（读屏会念出来）。
    .accessibilityChecked(this.selected)
    .accessibilityStateDescription(this.selected ? '已选择' : '未选择')
    .accessibilityText(this.label)
    .onClick(() => { this.onSelect(); })
  }
}

@Component
export struct BookSourceDebugPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  /** 条目底色用 surfaceContainerHigh（ThemePalette.ets:908 发布为 themeColorSurfaceElevated）。 */
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  /** 错误条目的容器色：上游 :231 errorContainer。 */
  @StorageProp('themeColorErrorContainer') themeColorErrorContainer: string = '#FFDAD6';
  // 选中 chip 的底/字色：上游 M3 ToggleChip 选中态 primaryContainer + onPrimaryContainer。
  @StorageProp('themeColorPrimaryContainer') themeColorPrimaryContainer: string = '#354E16';
  @StorageProp('themeColorOnPrimaryContainer') themeColorOnPrimaryContainer: string = '#D5EFAD';
  /** 完成条目的容器色：上游 :232 tertiaryContainer。 */
  @StorageProp('themeColorTertiaryContainer') themeColorTertiaryContainer: string = '#BCECE7';
  @StorageProp('themeColorOnTertiaryContainer') themeColorOnTertiaryContainer: string = '#1F4E4B';
  /** 错误条目文字色：上游 :238 onErrorContainer。 */
  @StorageProp('themeColorOnErrorContainer') themeColorOnErrorContainer: string = '#93000A';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;

  @Prop sourceUrl: string = '';
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};

  @State private sourceName: string = '';
  @State private query: string = '';
  @State private target: DebugTarget = 'Search';
  @State private filter: DebugFilter = 'All';
  @State private status: DebugStatus = 'Idle';
  @State private entries: DebugEntry[] = [];
  @State private examples: DebugExample[] = [];
  @State private selectedId: number = -1;
  /** 详情弹层的显隐：上游用 MarkdownSheet(show = selectedEntry != null) 控制，见 :142-148。 */
  @State private detailSheetVisible: boolean = false;
  /** 自动滚动开关：用户手动上滚时关闭，点「回到底部」或重新开始调试时恢复。 */
  @State private autoScrollToEnd: boolean = true;
  /** 空态笑脸：上游 EmptyMessage.kt:44 `faces.random()`，点一下换一张。 */
  @State private face: string = DEBUG_FACES[Math.floor(Math.random() * DEBUG_FACES.length)];
  private logScroller: Scroller = new Scroller();

  private onBusEvent: (entries: DebugEntry[]) => void = (list: DebugEntry[]): void => {
    const before: number = this.entries.length;
    this.entries = list;
    // 对齐上游 :64-68：Running 且新条目到达时自动滚到末条；
    // 用户上滚后（autoScrollToEnd=false）不再强行拉回。
    if (this.status === 'Running' && list.length > before && this.autoScrollToEnd && list.length > 0) {
      setTimeout(() => {
        // 上游是 animateScrollToItem（带动画），对应 scrollToIndex 的 smooth=true。
        // List 第 0 项是 controls，条目从第 1 项起，所以末条的 index = 可见条目数。
        this.logScroller.scrollToIndex(this.visibleEntries().length, true, ScrollAlign.END);
      }, 0);
    }
  };

  aboutToAppear(): void {
    this.loadSource();
    DebugEventBus.subscribe(this.onBusEvent);
    this.entries = DebugEventBus.snapshot();
  }

  aboutToDisappear(): void {
    DebugEventBus.unsubscribe(this.onBusEvent);
    DebugEventBus.stop();
  }

  /**
   * 对齐上游 BookSourceDebugViewModel.kt:49-77 load()：
   * 关键字取 ruleSearch.checkKeyWord（空则「我的」），示例 = [关键字→搜索, 系统→搜索, 各发现分类→发现]，
   * 去重后把**首个示例的值**灌进 query 作为初值（:72）。本地此前没这一步，
   * 导致进页后 FAB 只弹「调试内容不能为空」。
   */
  private loadSource(): void {
    const all: BookSource[] = BookSourceRepository.getAll();
    let src: BookSource | undefined = undefined;
    for (const item of all) {
      if (item.bookSourceUrl === this.sourceUrl) {
        src = item;
        break;
      }
    }
    if (src === undefined) {
      this.status = 'Failed';
      this.onUnavailableAction('未获取到书源');
      return;
    }
    this.sourceName = src.bookSourceName;
    const root: Record<string, Object> | undefined = this.parseSourceJson(src.sourceJson);
    const configured: string = root === undefined ? '' : this.readString(root, 'ruleSearch.checkKeyWord');
    const keyword: string = configured.trim().length === 0 ? '我的' : configured;
    const ex: DebugExample[] = [];
    ex.push({ title: keyword, target: 'Search', value: keyword });
    ex.push({ title: '系统', target: 'Search', value: '系统' });
    const exploreUrl: string = root === undefined ? '' : this.readString(root, 'exploreUrl');
    for (const kind of this.parseExploreKinds(exploreUrl)) {
      ex.push({ title: kind.title, target: 'Explore', value: kind.value });
    }
    this.examples = this.distinctExamples(ex);
    this.query = this.examples.length > 0 ? this.examples[0].value : '';
  }

  private parseSourceJson(sourceJson: string): Record<string, Object> | undefined {
    try {
      const parsed = JSON.parse(sourceJson) as Object;
      if (parsed === null || typeof parsed !== 'object') return undefined;
      return parsed as Record<string, Object>;
    } catch (_) {
      return undefined;
    }
  }

  /** 读 JSON 里的字符串字段（支持 'a.b' 路径），与编辑页 readPath 同口径。 */
  private readString(root: Record<string, Object>, path: string): string {
    const parts: string[] = path.split('.');
    let cur: Object | undefined = root;
    for (let i = 0; i < parts.length; i++) {
      if (cur === undefined || cur === null || typeof cur !== 'object') return '';
      cur = (cur as Record<string, Object>)[parts[i]];
    }
    return typeof cur === 'string' ? cur : '';
  }

  /**
   * 解析 exploreUrl 里的发现分类（上游 BookSourceExtensions.kt exploreKinds()）：
   * 普通 JSON 数组形态直接取 title/url；<js> / @js: 动态规则本地无法求值，返回空。
   */
  private parseExploreKinds(exploreUrl: string): DebugExample[] {
    const raw: string = exploreUrl.trim();
    const result: DebugExample[] = [];
    if (raw.length === 0) return result;
    if (!raw.startsWith('[')) return result;
    try {
      const kinds = JSON.parse(raw) as Object[];
      for (const kind of kinds) {
        if (kind === null || typeof kind !== 'object') continue;
        const item = kind as Record<string, Object>;
        const title = item['title'];
        const url = item['url'];
        if (typeof title !== 'string' || title.length === 0) continue;
        if (typeof url !== 'string' || url.trim().length === 0) continue;
        result.push({ title: title, target: 'Explore', value: url.trim() });
      }
    } catch (_) {
      return result;
    }
    return result;
  }

  /** 上游 :68 `.distinctBy { it.target to it.value }`。 */
  private distinctExamples(list: DebugExample[]): DebugExample[] {
    const seen: string[] = [];
    const result: DebugExample[] = [];
    for (const item of list) {
      const key: string = item.target + '::' + item.value;
      if (seen.indexOf(key) >= 0) continue;
      seen.push(key);
      result.push(item);
    }
    return result;
  }

  private visibleEntries(): DebugEntry[] {
    const result: DebugEntry[] = [];
    for (const entry of this.entries) {
      if (matchesFilter(entry, this.filter)) result.push(entry);
    }
    return result;
  }

  /**
   * 示例 chip：对齐上游 BookSourceDebugScreen.kt:156-158
   * `state.examples.filter { it.target == state.target }.take(8)`。
   */
  private visibleExamples(): DebugExample[] {
    const result: DebugExample[] = [];
    for (const example of this.examples) {
      if (example.target === this.target && result.length < 8) result.push(example);
    }
    return result;
  }

  private selectedEntry(): DebugEntry | undefined {
    for (const entry of this.entries) {
      if (entry.id === this.selectedId) return entry;
    }
    return undefined;
  }

  /** 详情弹层标题：上游 BookSourceDebugScreen.kt:145 `selectedEntry?.kind?.title.orEmpty()`。 */
  private detailTitle(): string {
    const entry: DebugEntry | undefined = this.selectedEntry();
    return entry === undefined ? '' : kindTitle(entry.kind);
  }

  /** 详情弹层正文：上游 :146 `selectedEntry?.message.orEmpty()`。 */
  private detailContent(): string {
    const entry: DebugEntry | undefined = this.selectedEntry();
    return entry === undefined ? '' : entry.message;
  }

  private async start(): Promise<void> {
    if (this.query.trim().length === 0) {
      this.onUnavailableAction('调试内容不能为空');
      return;
    }
    // 对齐上游 ViewModel.kt:90：开始前清空日志（entries = persistentListOf()）。
    DebugEventBus.clear();
    this.entries = [];
    this.selectedId = -1;
    this.status = 'Running';
    const result: DebugRunResult = await BookSourceDebugCoordinator.run(
      this.sourceUrl, this.target, this.query);
    this.status = result.status;
  }

  private stop(): void {
    DebugEventBus.stop();
    if (this.status === 'Running') this.status = 'Cancelled';
  }

  private clear(): void {
    DebugEventBus.clear();
    this.entries = [];
    this.selectedId = -1;
    this.status = 'Idle';
  }

  private useExample(example: DebugExample): void {
    this.target = example.target;
    this.query = example.value;
  }

  /**
   * 条目容器色：对齐上游 BookSourceDebugScreen.kt:225-233 按 kind 分支。
   */
  private entryContainer(kind: DebugEventKind): string {
    if (kind === 'Message') return this.themeColorSurfaceElevated;
    if (kind === 'Error') return this.themeColorErrorContainer;
    if (kind === 'Completed') return this.themeColorTertiaryContainer;
    return this.themeColorPrimaryContainer;
  }

  /** 条目强调色（标题与正文）：对齐上游 :234-242 的 accentColor。 */
  private entryAccent(kind: DebugEventKind): string {
    if (kind === 'Message') return this.themeColorTextSecondary;
    if (kind === 'Error') return this.themeColorOnErrorContainer;
    if (kind === 'Completed') return this.themeColorOnTertiaryContainer;
    return this.themeColorOnPrimaryContainer;
  }

  /**
   * 日志时间戳：上游 LogUtils.kt:27-28 TIME_PATTERN = "yy-MM-dd HH:mm:ss.SSS"。
   * 不能用 toLocaleString()——那会随系统区域变格式，与上游固定格式对不上。
   */
  private formatLogTime(timestamp: number): string {
    const d: Date = new Date(timestamp);
    const p2 = (v: number): string => v < 10 ? '0' + v : String(v);
    const p3 = (v: number): string => v < 10 ? '00' + v : (v < 100 ? '0' + v : String(v));
    return p2(d.getFullYear() % 100) + '-' + p2(d.getMonth() + 1) + '-' + p2(d.getDate())
      + ' ' + p2(d.getHours()) + ':' + p2(d.getMinutes()) + ':' + p2(d.getSeconds())
      + '.' + p3(d.getMilliseconds());
  }

  @Builder EntryCard(entry: DebugEntry) {
    Column({ space: 4 }) {
      Row() {
        // 上游 :257-261 kind 标题 labelMediumEmphasized（13sp + Medium 字重）。
        Text(kindTitle(entry.kind))
          .fontSize(LABEL_MEDIUM)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.entryAccent(entry.kind))
        // 上游 :262-266 耗时 labelSmall（11sp）。
        Text('+' + (entry.elapsedMs / 1000).toFixed(3) + 's')
          .fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).layoutWeight(1)
          .textAlign(TextAlign.End)
      }.width('100%')
      // 上游 :268-273 消息 bodySmall（12sp），maxLines4 省略；没给 color，继承 GlassCard 的
      // contentColor（= accentColor），所以正文同样是强调色。
      Text(entry.message)
        .fontSize(BODY_SMALL).fontColor(this.entryAccent(entry.kind))
        .maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      // 上游 :274-278 时间戳 labelSmall + onSurfaceVariant。
      Text(this.formatLogTime(entry.timestamp))
        .fontSize(LABEL_SMALL).fontColor(this.themeColorTextSecondary)
        .width('100%')
    }
    .width('100%')
    // 上游 :249-251 padding horizontal12 / vertical10。
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(this.entryContainer(entry.kind))
    .borderRadius(12)
    // 条目间距由 List({ space: 10 }) 统一给（上游 LazyColumn verticalArrangement = spacedBy(10.dp)），
    // 条目本身不再带 margin，否则会变成 20。
    .onClick(() => {
      this.selectedId = entry.id;
      this.detailSheetVisible = true;
    })
  }

  // @BuilderParam 必须传 @Builder 方法引用；内联 lambda 里直接实例化 struct 会在
  // 运行时被编译成裸构造函数调用（class constructor cannot called without 'new'）。
  @Builder debugNavSlot() {
    TopBarBackButton({ onSelect: () => this.onBack() })
  }

  @Builder debugActionsSlot() {
    // 上游 :76-80 Icons.Default.ClearAll（清空日志）。图标已按上游 ic_clear_all.xml 补齐为 clearAll。
    // contentDescription = "清空日志"（:79 硬编码），本地走 accessibilityLabel 补上。
    TopBarButton({ icon: 'clearAll', showDivider: false, accessibilityLabel: '清空日志', onSelect: () => this.clear() })
  }

  /** 调试状态文案：Running→停止，其余→开始调试（上游 Screen.kt:94 硬编码）。 */
  private fabTooltip(): string {
    return this.status === 'Running' ? '停止' : '开始调试';
  }

  build() {
    Column() {
      AppTopBar({
        // 上游 BookSourceDebugScreen.kt:73 title = "调试"，不带源名（源名在 controls 卡片里居中显示）。
        title: '调试',
        hasNavigation: true,
        navigationIcon: () => { this.debugNavSlot() },
        actions: () => { this.debugActionsSlot() }
      })

      Stack({ alignContent: Alignment.BottomEnd }) {
        List({ space: 10, scroller: this.logScroller }) {
          // 上游 :109-111 item("controls") = DebugControls。
          // 开始/停止入口只有右下 FAB（:85-96），清除只有顶栏 action（:76-80），内容区不自绘按钮。
          ListItem() {
            Column({ space: 8 }) {
              // 上游 :164-173 顶部一行居中显示当前源名（labelMediumEmphasized）。
              Row() {
                Text(this.sourceName)
                  .fontSize(LABEL_MEDIUM).fontWeight(FontWeight.Medium)
                  .fontColor(this.themeColorTextPrimary)
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              }.width('100%').justifyContent(FlexAlign.Center)

              // 上游 :174-182 目标 chip 行。
              Scroll() {
                Row() {
                  ForEach(DEBUG_TARGETS, (t: DebugTarget) => {
                    DebugChip({
                      label: targetTitle(t),
                      selected: this.target === t,
                      onSelect: () => { this.target = t; }
                    })
                  }, (t: DebugTarget): string => t)
                }
              }.scrollBar(BarState.Off).width('100%')
              // 上游 :209-216 DebugChipRow 的 fadingEdge(gradientWidth = 16.dp)：横向滚动时两端渐变淡出。
              .fadingEdge(true, { fadingEdgeLength: LengthMetrics.vp(16) })

              // 上游 :183-190 AppTextField(label=target.hint, maxLines=4, Loading 时禁用)；
              // 底色取 AppTextField 默认的 surfaceContainerHigh，比卡片壳高一档。
              // text 必须绑 this.query：否则点示例 chip 后输入框不跟着变（上游是 TextFieldState 受控）。
              TextInput({ text: this.query, placeholder: targetHint(this.target) })
                .width('100%')
                .fontColor(this.themeColorTextPrimary)
                .backgroundColor(this.themeColorSurfaceElevated).borderRadius(8)
                .maxLines(4)
                .enabled(this.status !== 'Loading')
                .onChange((value: string) => { this.query = value; })

              // 上游 :191-201 示例 chip 行：只显示当前 target 的示例，最多 8 个。
              if (this.visibleExamples().length > 0) {
                Scroll() {
                  Row() {
                    ForEach(this.visibleExamples(), (ex: DebugExample) => {
                      DebugChip({
                        label: ex.title,
                        selected: this.target === ex.target && this.query === ex.value,
                        onSelect: () => { this.useExample(ex); }
                      })
                    }, (ex: DebugExample): string => ex.title)
                  }
                }.scrollBar(BarState.Off).width('100%')
                // 同上：示例 chip 行也对齐上游 DebugChipRow 的渐变边缘。
                .fadingEdge(true, { fadingEdgeLength: LengthMetrics.vp(16) })
              }
            }
            // 上游 :159-163 GlassCard{ Column(padding 12, spacedBy 8) }。
            // 本地无 GlassCard 组件，用 surfaceContainer(=themeColorSurfaceTertiary) + 圆角 16 做等价壳。
            .width('100%').padding(12)
            .backgroundColor(this.themeColorSurfaceTertiary)
            .borderRadius(16)
          }

          // 上游 :112-122 filters 是 controls 之外的独立 item。
          ListItem() {
            Scroll() {
              Row() {
                ForEach(DEBUG_FILTERS, (f: DebugFilter) => {
                  DebugChip({
                    label: filterTitle(f),
                    selected: this.filter === f,
                    onSelect: () => { this.filter = f; }
                  })
                }, (f: DebugFilter): string => f)
              }
            }.scrollBar(BarState.Off).width('100%')
            // 过滤 chip 行同样对齐上游 DebugChipRow 的渐变边缘。
            .fadingEdge(true, { fadingEdgeLength: LengthMetrics.vp(16) })
          }

          if (this.visibleEntries().length === 0) {
            ListItem() {
              // 上游 :123-131 空态用 EmptyMessage：笑脸 + 消息居中、高度 240dp。
              Column({ space: 8 }) {
                // 上游 EmptyMessage.kt:38-72：七张脸里随机取一张，点一下换一张。
                Text(this.face)
                  .fontSize(32).fontColor(this.themeColorTextTertiary)
                  .textAlign(TextAlign.Center)
                  .onClick(() => { this.face = DEBUG_FACES[Math.floor(Math.random() * DEBUG_FACES.length)]; })
                Text(this.status === 'Running' ? '等待调试日志…' : '输入内容并开始调试')
                  .fontSize(LABEL_MEDIUM).fontWeight(FontWeight.Medium)
                  .fontColor(this.themeColorTextTertiary)
                  .textAlign(TextAlign.Center).maxLines(2)
                  .constraintSize({ maxWidth: 240 })
              }
              .width('100%').height(240)
              .justifyContent(FlexAlign.Center)
            }
          } else {
            ForEach(this.visibleEntries(), (entry: DebugEntry) => {
              ListItem() { this.EntryCard(entry) }
            }, (entry: DebugEntry): string => String(entry.id))
          }
        }
        .width('100%').height('100%').scrollBar(BarState.Off)
        // 对齐上游 :101-106 contentPadding：左右 16、顶 12、底部 96（避开右下 FAB）。
        .padding({ left: 16, right: 16, top: 12 })
        .contentEndOffset(96)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false })
        .onScrollFrameBegin((offset: number) => {
          // 用户主动上翻看更早日志（offset<0）时停止自动跟随，避免新日志把视线强行拉回底部；
          // 恢复跟随由「开始调试」按钮和 FAB 点击显式触发。
          if (offset < 0) {
            this.autoScrollToEnd = false;
          }
          return { offsetRemain: offset };
        })

        // 右下 FAB：开始/停止二态，与编辑页共用批3的 AppFab。
        AppFab({
          icon: this.status === 'Running' ? 'stop' : 'playArrow',
          fabAccessibilityText: this.fabTooltip(),
          onFabClick: () => {
            if (this.status === 'Running') this.stop();
            else { this.autoScrollToEnd = true; this.start(); }
          }
        })
        .margin({ bottom: 24, right: 16 })
      }
      .width('100%').layoutWeight(1)

      // 详情浮层：上游 :142-148 用 MarkdownSheet(show = selectedEntry != null, title = kind.title,
      // content = entry.message)，即 AppModalBottomSheet + SelectionContainer + MarkdownBlock。
      // 本地用 bindSheet 承载同一个形态：抓手由 dragBar 提供，标题/正文见 DetailSheetBuilder。
    }
    .width('100%').height('100%')
    // 对齐 DiscoverPage：主题背景由 AppStorage 提供时透明透出，否则用主题面色的深色兜底。
    .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
    .bindSheet($$this.detailSheetVisible, this.DetailSheetBuilder(), {
      // 上游 heightIn(max = 容器高 * 0.8) + animateContentSize：内容多高就多高，上限 80%。
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      // 上游 AboutSheets.kt:33-60 的 MarkdownSheet 只有标题 + 内容，没有右上关闭按钮；
      // ArkUI bindSheet 的 showClose 默认 true 会多画一个 ×，故显式关掉（下滑与点外部仍可关）。
      showClose: false,
      enableOutsideInteractive: true,
      onDisappear: () => { this.selectedId = -1; }
    })
  }

  /**
   * 详情弹层内容，对应上游 MarkdownSheet（AboutSheets.kt:33-60）+ AppModalBottomSheet
   * 的 header/内容内边距（AppModalBottomSheet.kt:155-205）：
   * 头部标题 titleMediumEmphasized 居中（左右各留 56 给两侧 action），内容区 16 内边距，
   * 正文 MarkdownBlock 默认 bodyLarge（17sp），末尾 Spacer(min 16dp)。
   */
  @Builder DetailSheetBuilder() {
    Column() {
      Text(this.detailTitle())
        .fontSize(TITLE_MEDIUM)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColorTextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding({ left: 56, right: 56, bottom: 16 })
      // 上游 SelectionContainer：详情文本可长按选中复制。
      Scroll() {
        Column() {
          MarkdownIntro({
            source: this.detailContent(),
            textColor: this.themeColorTextPrimary,
            bodySize: BODY_LARGE,
            bodyLineHeight: BODY_LARGE_LINE_HEIGHT
          })
          // 上游 AboutSheets.kt:56 Spacer(heightIn(min = 16.dp))。
          Row().height(16)
        }.width('100%')
      }
      .width('100%')
      .scrollBar(BarState.Auto)
      // 整体上限 80%：上游 heightIn(max = containerHeight * 0.8f)。
      .constraintSize({ maxHeight: '80%' })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 16 })
  }
}
