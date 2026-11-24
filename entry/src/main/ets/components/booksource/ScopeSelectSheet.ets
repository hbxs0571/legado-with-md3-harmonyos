/**
 * 搜索范围选择面板（多选 draft 态）。
 *
 * 逐项对齐上游 `ui/book/search/ScopeSelectSheet.kt`（240 行）：
 *   - `AppModalBottomSheet(title = search_select_group, startAction = MediumTonalButton(Settings, book_source_manage),
 *      endAction = MediumTonalButton(Check, ok))`
 *   - 顶部 `SearchBar(filterText, placeholder = screen, autoFocus = false)`
 *   - 第一项 `SelectionItemCard(all_source, containerColor = surface.copy(alpha = 0.6f), inSelectionMode = true)`
 *   - `AppTabRow([group, book_source])` 两页签
 *   - 组 / 源各一个 `LazyColumn(heightIn(max = 480.dp), spacedBy(4.dp))`，源空态 `Text(search_empty)`
 *   - 确认时回调 `ScopeSelection(groupNames, sources, isSourceScope)`
 *
 * draft 语义（上游 `draftIsAll` / `draftIsSourceScope` / `draftGroups` / `draftSourceUrls`）：
 * 面板内改的只是草稿，点确认才回写页面状态；`all_source` 被选中时另两个 draft 全部清空。
 */
import { AppGlyph } from '../AppGlyph';
import { SearchBar } from './SearchBar';
import { SelectionItemCard } from './SelectionItemCard';
import { BODY_MEDIUM, LABEL_LARGE, TITLE_SMALL } from '../typography/TypographyTokens';
import { SPACE_12, SPACE_16, SPACE_4, SPACE_8 } from '../UiTokens';

/** 面板确认后回写的选择结果；对齐上游 `ScopeSelection`。 */
export interface ScopeSelection {
  groupNames: string[];
  sources: ScopeSourceChoice[];
  isSourceScope: boolean;
}

/** 选中书源的轻量表示（上游 `SearchScope.SourceScope` 的 name + url 两字段）。 */
export interface ScopeSourceChoice {
  name: string;
  url: string;
}

@Component
export struct ScopeSelectSheet {
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#4A4C55';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceContainerLow') themeColorSurfaceContainerLow: string = '#F7F7FB';
  @StorageProp('themeColorSurface') themeColorSurface: string = '#FAF9FD';

  /** 进入面板时的现状：是否「全部书源」、是否「按书源范围」、已选组名、已选书源 URL。 */
  @Prop initialIsAll: boolean = true;
  @Prop initialIsSourceScope: boolean = false;
  @Prop initialGroupNames: string[] = [];
  @Prop initialSourceUrls: string[] = [];
  /** 可选分组名（上游 `enabledGroups`）。 */
  @Prop groups: string[] = [];
  /** 可选书源（上游 `enabledSources`，这里只取展示需要的 name/url）。 */
  @Prop sources: ScopeSourceChoice[] = [];

  /** 顶部「书源管理」按钮（上游 `onConfirm`）。 */
  onOpenSourceManage: () => void = () => {};
  /** 确认（上游 `onApplyScope`）。 */
  onApplyScope: (selection: ScopeSelection) => void = (_selection: ScopeSelection) => {};
  /** 关闭面板（标题栏关闭 / 外部点击）。 */
  onDismissRequest: () => void = () => {};

  /** draft：是否「全部书源」。 */
  @State private draftIsAll: boolean = true;
  /** draft：是否按书源范围（否则按分组）。 */
  @State private draftIsSourceScope: boolean = false;
  @State private draftGroups: string[] = [];
  @State private draftSourceUrls: string[] = [];
  /** 过滤输入框（上游 `SearchBar(filterText)`）。 */
  @State private filterText: string = '';
  /** 当前页签：0 = 分组，1 = 书源。 */
  @State private activeTab: number = 0;

  aboutToAppear(): void {
    this.draftIsAll = this.initialIsAll;
    this.draftIsSourceScope = this.initialIsSourceScope;
    this.draftGroups = this.initialGroupNames.slice();
    this.draftSourceUrls = this.initialSourceUrls.slice();
    this.activeTab = this.draftIsSourceScope ? 1 : 0;
  }

  /** 过滤后的分组名。 */
  private visibleGroups(): string[] {
    const keyword = this.filterText.trim();
    if (keyword.length === 0) {
      return this.groups;
    }
    return this.groups.filter((name: string) => name.toLowerCase().includes(keyword.toLowerCase()));
  }

  /** 过滤后的书源。 */
  private visibleSources(): ScopeSourceChoice[] {
    const keyword = this.filterText.trim();
    if (keyword.length === 0) {
      return this.sources;
    }
    return this.sources.filter((item: ScopeSourceChoice) =>
      item.name.toLowerCase().includes(keyword.toLowerCase()));
  }

  /** 点「全部书源」：清掉两个 draft（上游 `SelectAllScope`）。 */
  private selectAll(): void {
    this.draftIsAll = true;
    this.draftGroups = [];
    this.draftSourceUrls = [];
  }

  /** 切分组：离开「全部」态，按名字增删。 */
  private toggleGroup(name: string): void {
    const next: string[] = this.draftGroups.slice();
    const index = next.indexOf(name);
    if (index >= 0) {
      next.splice(index, 1);
    } else {
      next.push(name);
    }
    this.draftGroups = next;
    this.draftSourceUrls = [];
    this.draftIsSourceScope = false;
    this.draftIsAll = next.length === 0;
  }

  /** 切书源：离开「全部」态，按 url 增删。 */
  private toggleSource(url: string): void {
    const next: string[] = this.draftSourceUrls.slice();
    const index = next.indexOf(url);
    if (index >= 0) {
      next.splice(index, 1);
    } else {
      next.push(url);
    }
    this.draftSourceUrls = next;
    this.draftGroups = [];
    this.draftIsSourceScope = true;
    this.draftIsAll = next.length === 0;
  }

  private apply(): void {
    const chosenSources: ScopeSourceChoice[] = this.sources.filter((item: ScopeSourceChoice) =>
      this.draftSourceUrls.includes(item.url));
    this.onApplyScope({
      groupNames: this.draftGroups.slice(),
      sources: chosenSources,
      isSourceScope: this.draftIsSourceScope
    });
  }

  @Builder
  private TabButton(index: number, label: string) {
    Text(label)
      .fontSize(LABEL_LARGE)
      .fontColor(this.activeTab === index ? this.themeColorAccent : this.themeColorTextTertiary)
      .layoutWeight(1)
      .textAlign(TextAlign.Center)
      .padding({ top: SPACE_8, bottom: SPACE_8 })
      .border({
        width: { bottom: this.activeTab === index ? 2 : 0 },
        color: this.themeColorAccent
      })
      .onClick(() => { this.activeTab = index; })
  }

  build() {
    Column() {
      // 标题栏：左「书源管理」，中标题，右「确认」（上游 startAction / title / endAction）。
      Row() {
        Text('书源管理')
          .fontSize(LABEL_LARGE)
          .fontColor(this.themeColorAccent)
          .onClick(() => { this.onOpenSourceManage(); })
        Blank()
        Text('选择书源分组')
          .fontSize(TITLE_SMALL)
          .fontColor(this.themeColorTextPrimary)
        Blank()
        Text('确认')
          .fontSize(LABEL_LARGE)
          .fontColor(this.themeColorAccent)
          .onClick(() => { this.apply(); })
      }
      .width('100%')
      .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_12, bottom: SPACE_8 })

      SearchBar({
        query: this.filterText,
        placeholder: '筛选',
        autoFocus: false,
        onQueryChange: (value: string) => { this.filterText = value; }
      })
        .margin({ left: SPACE_16, right: SPACE_16 })

      // 「全部书源」项：上游 `SelectionItemCard(all_source, surface.copy(alpha = 0.6f), inSelectionMode = true)`。
      SelectionItemCard({
        title: '全部书源',
        isSelected: this.draftIsAll,
        inSelectionMode: true,
        containerColor: this.themeColorSurface,
        onToggleSelection: () => { this.selectAll(); }
      })
        .margin({ left: SPACE_16, right: SPACE_16, bottom: SPACE_8 })

      // 两页签：分组 / 书源。
      Row() {
        this.TabButton(0, '分组')
        this.TabButton(1, '书源')
      }
      .width('100%')
      .padding({ left: SPACE_16, right: SPACE_16 })

      if (this.activeTab === 0) {
        if (this.visibleGroups().length === 0) {
          Text('没有内容哦')
            .fontSize(BODY_MEDIUM)
            .fontColor(this.themeColorTextTertiary)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: SPACE_16, bottom: SPACE_16 })
        } else {
          List({ space: SPACE_4 }) {
            ForEach(this.visibleGroups(), (name: string) => {
              ListItem() {
                SelectionItemCard({
                  title: name,
                  isSelected: this.draftGroups.includes(name),
                  inSelectionMode: true,
                  onToggleSelection: () => { this.toggleGroup(name); }
                })
              }
            }, (name: string) => name)
          }
          .width('100%')
          .constraintSize({ maxHeight: 480 })
          .padding({ left: SPACE_16, right: SPACE_16 })
          .scrollBar(BarState.Off)
        }
      } else {
        if (this.visibleSources().length === 0) {
          Text('没有内容哦')
            .fontSize(BODY_MEDIUM)
            .fontColor(this.themeColorTextTertiary)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: SPACE_16, bottom: SPACE_16 })
        } else {
          List({ space: SPACE_4 }) {
            ForEach(this.visibleSources(), (item: ScopeSourceChoice) => {
              ListItem() {
                SelectionItemCard({
                  title: item.name,
                  subtitle: item.url,
                  isSelected: this.draftSourceUrls.includes(item.url),
                  inSelectionMode: true,
                  onToggleSelection: () => { this.toggleSource(item.url); }
                })
              }
            }, (item: ScopeSourceChoice) => item.url)
          }
          .width('100%')
          .constraintSize({ maxHeight: 480 })
          .padding({ left: SPACE_16, right: SPACE_16 })
          .scrollBar(BarState.Off)
        }
      }
      Blank()
        .layoutWeight(1)
      // 上游 `Spacer(20.dp)` 之后的底部留白。
      Blank()
        .height(SPACE_16)
    }
    .width('100%')
    .backgroundColor(this.themeColorSurfaceTertiary)
  }
}
