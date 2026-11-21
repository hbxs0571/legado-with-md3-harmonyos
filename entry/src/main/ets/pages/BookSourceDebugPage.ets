// 书源调试页（P10，任务书第十四节）。
// 对齐上游 BookSourceDebugScreen：目标 chip + 输入 + 示例 + 日志列表 + 过滤 chip + 详情浮层；
// 顶栏清除、FAB 二态开始/停止。数据来自 BookSourceDebugCoordinator（宿主打点事件总线）。
import { AppTopBar, TopBarBackButton, TopBarButton } from '../components/TopBar';
import {
  DebugEntry, DebugTarget, DebugFilter, DebugStatus,
  DEBUG_TARGETS, DEBUG_FILTERS,
  targetTitle, targetHint, filterTitle, kindTitle, matchesFilter
} from '../bookSource/BookSourceDebugModels';
import {
  DebugEventBus, BookSourceDebugCoordinator, DebugRunResult, buildDebugKey
} from '../bookSource/BookSourceDebugCoordinator';
import { BookSourceRepository } from '../data/BookSourceRepository';
import { BookSource } from '../model/BookSource';
import { BODY_SMALL, LABEL_LARGE, LABEL_MEDIUM, LABEL_SMALL, TITLE_LARGE, TITLE_SMALL } from '../components/typography/TypographyTokens';
import { AppFab } from '../components/booksource/AppFab';

/** 示例项（具名接口，ArkTS 禁匿名对象字面量）。 */
interface DebugExample {
  title: string;
  target: DebugTarget;
  value: string;
}

@Component
export struct BookSourceDebugPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  // 错误色走主题令牌（替代原错误色的渲染硬编码）。
  @StorageProp('themeColorError') themeColorError: string = '#FFB4AB';
  // 选中 chip 的底/字色：上游 M3 ToggleChip 选中态 primaryContainer + onPrimaryContainer。
  @StorageProp('themeColorPrimaryContainer') themeColorPrimaryContainer: string = '#354E16';
  @StorageProp('themeColorOnPrimaryContainer') themeColorOnPrimaryContainer: string = '#D5EFAD';
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
  /** 自动滚动开关：用户手动上滚时关闭，点「回到底部」或重新开始调试时恢复。 */
  @State private autoScrollToEnd: boolean = true;
  private logScroller: Scroller = new Scroller();

  private onBusEvent: (entries: DebugEntry[]) => void = (list: DebugEntry[]): void => {
    const before: number = this.entries.length;
    this.entries = list;
    // 对齐上游 :64-68：Running 且新条目到达时自动滚到末条；
    // 用户上滚后（autoScrollToEnd=false）不再强行拉回。
    if (this.status === 'Running' && list.length > before && this.autoScrollToEnd && list.length > 0) {
      // 对齐上游 :64-68：新条目到达时滚到 visibleEntries 末条。
      // lastLogOffset 记的是 List 第 0 项（controls）所在的 yOffset，用 scrollTo 精确落到底部。
      setTimeout(() => {
        this.logScroller.scrollToIndex(this.visibleEntries().length - 1, false, ScrollAlign.END);
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

  private selectedEntry(): DebugEntry | undefined {
    for (const entry of this.entries) {
      if (entry.id === this.selectedId) return entry;
    }
    return undefined;
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
    Text(label)
      .fontSize(LABEL_MEDIUM)
      // 对齐上游 ToggleChip：选中=primaryContainer 底 + onPrimaryContainer 字，未选=surface 底 + onSurface 字。
      .fontColor(selected ? this.themeColorOnPrimaryContainer : this.themeColorTextPrimary)
      .backgroundColor(selected ? this.themeColorPrimaryContainer : this.themeColorSurfaceTertiary)
      .borderRadius(16)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .margin({ right: 8 })
      .onClick(onSelect)
  }

  @Builder EntryCard(entry: DebugEntry) {
    Column() {
      Row() {
        Text(kindTitle(entry.kind))
          .fontSize(BODY_SMALL)
          .fontColor(entry.kind === 'Error' ? this.themeColorError : this.themeColorAccent)
        Text('+' + (entry.elapsedMs / 1000).toFixed(3) + 's')
          .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).layoutWeight(1)
          .textAlign(TextAlign.End)
      }.width('100%')
      Text(entry.message)
        .fontSize(LABEL_LARGE).fontColor(this.themeColorTextPrimary)
        .maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%').margin({ top: 6 })
      Text(new Date(entry.timestamp).toLocaleString())
        .fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary)
        .width('100%').margin({ top: 6 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.themeColorSurfaceTertiary)
    .borderRadius(10)
    .margin({ bottom: 10 })
    .onClick(() => { this.selectedId = entry.id; })
  }

  // @BuilderParam 必须传 @Builder 方法引用；内联 lambda 里直接实例化 struct 会在
  // 运行时被编译成裸构造函数调用（class constructor cannot called without 'new'）。
  @Builder debugNavSlot() {
    TopBarBackButton({ onSelect: () => this.onBack() })
  }

  @Builder debugActionsSlot() {
    // 上游 :76-80 Icons.Default.ClearAll（清空日志）。本地无 ClearAll，用最近的 delete 代替，差异写进报告。
    TopBarButton({ icon: 'delete', showDivider: false, onSelect: () => this.clear() })
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
          ListItem() {
            Column() {
              // 目标 chip 行
              Scroll() {
                Row() {
                  ForEach(DEBUG_TARGETS, (t: DebugTarget) => {
                    this.ChipBuilder(targetTitle(t), this.target === t, () => { this.target = t; })
                  }, (t: DebugTarget): string => t)
                }
              }.scrollBar(BarState.Off).width('100%').margin({ bottom: 12 })

              TextInput({ placeholder: targetHint(this.target), text: this.query })
                .width('100%')
                .fontColor(this.themeColorTextPrimary)
                .backgroundColor(this.themeColorSurfaceTertiary).borderRadius(8)
                .onChange((value: string) => { this.query = value; })

              if (this.examples.length > 0) {
                Scroll() {
                  Row() {
                    ForEach(this.examples, (ex: DebugExample) => {
                      this.ChipBuilder(ex.title, this.target === ex.target && this.query === ex.value,
                        () => { this.useExample(ex); })
                    }, (ex: DebugExample): string => ex.title)
                  }
                }.scrollBar(BarState.Off).width('100%').margin({ top: 8 })
              }

              // 开始/停止入口移到右下 FAB（对齐上游 :85-96 DebugControls 之外只有一个 FAB）；
              // 清除走顶栏 action（:163-165 已有），不再在内容区自绘按钮。

              // 过滤 chip 行
              Scroll() {
                Row() {
                  ForEach(DEBUG_FILTERS, (f: DebugFilter) => {
                    this.ChipBuilder(filterTitle(f), this.filter === f, () => { this.filter = f; })
                  }, (f: DebugFilter): string => f)
                }
              }.scrollBar(BarState.Off).width('100%').margin({ top: 16, bottom: 8 })
            }
            .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 8 })
          }

          if (this.visibleEntries().length === 0) {
            ListItem() {
              Text(this.status === 'Running' ? '等待调试日志…' : '输入内容并开始调试')
                .fontSize(TITLE_SMALL).fontColor(this.themeColorTextTertiary)
                .width('100%').textAlign(TextAlign.Center).padding(60)
            }
          } else {
            ForEach(this.visibleEntries(), (entry: DebugEntry) => {
              ListItem() { this.EntryCard(entry) }
            }, (entry: DebugEntry): string => String(entry.id))
          }
        }
        .width('100%').height('100%').scrollBar(BarState.Off)
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
          icon: this.status === 'Running' ? 'profileClose' : 'arrowForward',
          fabAccessibilityText: this.fabTooltip(),
          onFabClick: () => {
            if (this.status === 'Running') this.stop();
            else { this.autoScrollToEnd = true; this.start(); }
          }
        })
        .margin({ bottom: 24, right: 16 })
      }
      .width('100%').layoutWeight(1)

      // 详情浮层：选中条目显示完整 message
      if (this.selectedEntry() !== undefined) {
        Column() {
          Row() {
            Text(kindTitle(this.selectedEntry()!.kind))
              .fontSize(TITLE_LARGE).fontColor(this.themeColorTextPrimary).layoutWeight(1)
            Text('关闭').fontSize(LABEL_LARGE).fontColor(this.themeColorAccent)
              .onClick(() => { this.selectedId = -1; })
          }.width('100%').padding(16)
          Scroll() {
            Text(this.selectedEntry()!.message)
              .fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary).width('100%')
          }.width('100%').layoutWeight(1).padding({ left: 16, right: 16 })
        }
        .width('100%').height('60%')
        .backgroundColor(this.themeColorSurfacePrimary)
        .borderRadius({ topLeft: 16, topRight: 16 })
        .position({ x: 0, y: '40%' })
      }
    }
    .width('100%').height('100%')
    // 对齐 DiscoverPage：主题背景由 AppStorage 提供时透明透出，否则用主题面色的深色兜底。
    .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
  }
}
