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

/** 示例项（具名接口，ArkTS 禁匿名对象字面量）。 */
interface DebugExample {
  title: string;
  target: DebugTarget;
  value: string;
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

  private loadSource(): void {
    const all: BookSource[] = BookSourceRepository.getAll();
    for (const src of all) {
      if (src.bookSourceUrl === this.sourceUrl) {
        this.sourceName = src.bookSourceName;
        break;
      }
    }
    const ex: DebugExample[] = [];
    ex.push({ title: '我的', target: 'Search', value: '我的' });
    ex.push({ title: '系统', target: 'Search', value: '系统' });
    this.examples = ex;
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

  @Builder ChipBuilder(label: string, selected: boolean, onSelect: () => void) {
    Row() {
      // 对齐上游 ToggleChip.kt:75-88：选中时才出现 16dp 的 Check，未选不占位。
      if (selected) {
        AppGlyph({ name: 'profileCheck', glyphSize: 16, tint: this.themeColorAccent })
          .margin({ right: 8 })
      }
      Text(label)
        .fontSize(LABEL_MEDIUM)
        .fontWeight(FontWeight.Medium)
        // 对齐上游 ToggleChip：选中=primaryContainer 底 + onPrimaryContainer 字，未选=surface 底 + onSurface 字。
        .fontColor(selected ? this.themeColorOnPrimaryContainer : this.themeColorTextPrimary)
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(selected ? this.themeColorPrimaryContainer : this.themeColorSurfaceTertiary)
    .borderRadius(12)
    .margin({ right: 8, top: 2, bottom: 2 })
    .onClick(onSelect)
  }

  /** 条目容器色：对齐上游 BookSourceDebugScreen.kt:225-233 按 kind 分支。 */
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
    .margin({ bottom: 10 })
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
    TopBarButton({ icon: 'clearAll', showDivider: false, onSelect: () => this.clear() })
  }

  /** 调试状态文案：Running→停止，其余→开始调试（上游 Screen.kt:94 硬编码）。 */
  private fabTooltip(): string {
    return this.status === 'Running' ? '停止' : '开始调试';
  }

  build() {
    Column() {
      AppTopBar({
        title: '调试 · ' + this.sourceName,
        hasNavigation: true,
        navigationIcon: () => { this.debugNavSlot() },
        actions: () => { this.debugActionsSlot() }
      })

      Stack({ alignContent: Alignment.BottomEnd }) {
        List({ scroller: this.logScroller }) {
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
                    this.ChipBuilder(targetTitle(t), this.target === t, () => { this.target = t; })
                  }, (t: DebugTarget): string => t)
                }
              }.scrollBar(BarState.Off).width('100%')

              // 上游 :183-190 AppTextField(label=target.hint, maxLines=4, Loading 时禁用)；
              // 底色取 AppTextField 默认的 surfaceContainerHigh，比卡片壳高一档。
              TextInput({ placeholder: targetHint(this.target), text: this.query })
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
                      this.ChipBuilder(ex.title, this.target === ex.target && this.query === ex.value,
                        () => { this.useExample(ex); })
                    }, (ex: DebugExample): string => ex.title)
                  }
                }.scrollBar(BarState.Off).width('100%')
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
                  this.ChipBuilder(filterTitle(f), this.filter === f, () => { this.filter = f; })
                }, (f: DebugFilter): string => f)
              }
            }.scrollBar(BarState.Off).width('100%')
          }

          if (this.visibleEntries().length === 0) {
            ListItem() {
              // 上游 :123-131 空态用 EmptyMessage：笑脸 + 消息居中、高度 240dp。
              Column({ space: 8 }) {
                Text('(๑•́ ₃ •̀๑)')
                  .fontSize(32).fontColor(this.themeColorTextTertiary)
                  .textAlign(TextAlign.Center)
                Text(this.status === 'Running' ? '等待调试日志…' : '输入内容并开始调试')
                  .fontSize(LABEL_MEDIUM).fontWeight(FontWeight.Medium)
                  .fontColor(this.themeColorTextTertiary)
                  .textAlign(TextAlign.Center).maxLines(2)
                  .width('100%')
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
