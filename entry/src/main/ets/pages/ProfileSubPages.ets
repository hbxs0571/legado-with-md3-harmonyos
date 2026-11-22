import { DURATION_FADE, HEADER_COLLAPSE_THRESHOLD, HEADER_EXPAND_THRESHOLD, SPACE_8 } from '../components/UiTokens';
/** “我的”菜单下与 Android 页面结构对应的二级页面。 */
import curves from '@ohos.curves';
import { bundleManager } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { SourceHttp } from '../bookSource/SourceHttp';
import { BookSourceImporter } from '../data/BookSourceImporter';
import { BookSourceImportKeep } from '../data/BookSourceRepository';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { ReadRecordHeatmap } from '../components/ReadRecordHeatmap';
import { BookCover } from '../components/BookCover';
import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';
import { AppTopBar, TopBarBackButton, TopBarButton } from '../components/TopBar';
import { ThemeItemDivider } from '../components/ThemeItemDivider';
import {
  PROFILE_PAGE_SUBTITLE_SIZE,
  PROFILE_PAGE_TITLE_SIZE,
  PROFILE_ROW_DETAIL_SIZE,
  PROFILE_ROW_TITLE_SIZE,
  PROFILE_ROW_VERTICAL_PADDING
} from '../components/ProfileUiMetrics';
import { Book, BookChapter, ProfileRoute } from '../model/Book';
import { BookGroup } from '../model/BookGroup';
import { BookSource } from '../model/BookSource';
import { BookSourceRepository } from '../data/BookSourceRepository';
import { BookGroupRepository } from '../data/BookGroupRepository';
import { isPrivateBook } from '../data/PrivateAccessRepository';
import { BookCacheStat, CacheStatsRepository } from '../data/CacheStatsRepository';
import { BookRepository } from '../data/BookRepository';
import { ChapterDownloadQueue, DownloadState } from '../bookSource/ChapterDownloadQueue';
import { LocalBookRestorePlanner } from '../data/LocalBookRestorePlanner';
import { ReplaceRule, replaceRuleRowKey } from '../model/ReplaceRule';
import { ReplaceRulePreviewLine, ReplaceRuleRepository } from '../data/ReplaceRuleRepository';
import { ReadRecordDetail, ReadRecordSession, ReadRecordSummary, ReadTimeRecord } from '../model/ReadRecord';
import { ReadRecordRepository } from '../data/ReadRecordRepository';
import { TxtTocRule } from '../model/TxtTocRule';
import { TxtTocRuleRepository } from '../data/TxtTocRuleRepository';
import { UiMenuItem, UiMenuPanel } from '../components/UiMenu';
import { SourceCheckSheet, SourceCheckOptions } from '../components/booksource/SourceCheckSheet';
import { SourceCheckRunSheet } from '../components/booksource/SourceCheckRunSheet';
import {
  BookSourceCheckCoordinator, BookSourceCheckState, defaultCheckOptions
} from '../bookSource/BookSourceCheckCoordinator';
import { UiSwitchControl } from '../components/UiSwitchControl';
import { UiAction } from '../components/settings/UiAction';
import { BODY_LARGE, BODY_MEDIUM, BODY_SMALL, HEADLINE_LARGE, HEADLINE_MEDIUM, HEADLINE_SMALL, LABEL_LARGE, LABEL_LARGE_EMPHASIZED, LABEL_MEDIUM, LABEL_SMALL, TITLE_LARGE, TITLE_MEDIUM, TITLE_SMALL, TITLE_SMALL_EMPHASIZED } from '../components/typography/TypographyTokens';

/** 卡片式菜单的统一宽度，与书架页、详情页同口径。 */
const PROFILE_MENU_WIDTH: number = 260;

/**
 * P4 书源行的派生数据：源本体 + 列表展示所需的三个派生字段。
 * 域名从 sourceJson.bookSourceUrl 解析，'#' 时按上游规则不显示。
 */
class SourceRow {
  source: BookSource;
  domain: string;
  hasLogin: boolean;
  hasExplore: boolean;
  exploreEnabled: boolean;
  /**
   * 校验结果文案。上游 BookSourceScreen.kt:653-684 的 supportingContent 里 group 与
   * checkMessage 是两行并列显示，且 checkMessage 是 UI 派生量（BookSourceViewModel.kt:215-232
   * 由 check.results[id].displayMessage() 现算，不是实体字段）——本地同口径，运行时派生。
   */
  checkMessage: string;

  constructor(source: BookSource, domain: string, hasLogin: boolean,
    hasExplore: boolean, exploreEnabled: boolean, checkMessage: string) {
    this.source = source;
    this.domain = domain;
    this.hasLogin = hasLogin;
    this.hasExplore = hasExplore;
    this.exploreEnabled = exploreEnabled;
    this.checkMessage = checkMessage;
  }
}

/**
 * 列表项联合：按域名分组时，在每组第一条数据行前插一个标题项。
 * 上游 BookSourceScreen.kt:594-605 用 contentType="domain-header" 区分两种 item；
 * LazyForEach 的 keyGenerator 必须逐项唯一，标题项用 "domain:" 前缀避免与书源 URL 冲突。
 */
interface DomainHeaderItem {
  kind: string;
  domain: string;
}

interface SourceDataItem {
  kind: string;
  row: SourceRow;
}

type BookSourceListItem = DomainHeaderItem | SourceDataItem;

// ArkTS 不支持 is 类型谓词（arkts-no-is），只返回 boolean，取值处用 as 强转。
function isDomainHeader(item: BookSourceListItem): boolean {
  return (item as DomainHeaderItem).kind === 'domain';
}

/** 书源列表的惰性数据源（904 条用 LazyForEach，本仓 CatalogPage:38 先例）。 */
class SourceDataSource implements IDataSource {
  private items: BookSourceListItem[] = [];
  private listeners: DataChangeListener[] = [];
  totalCount(): number { return this.items.length; }
  getData(index: number): BookSourceListItem { return this.items[index]; }
  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) { this.listeners.push(listener); }
  }
  unregisterDataChangeListener(listener: DataChangeListener): void {
    const position = this.listeners.indexOf(listener);
    if (position >= 0) { this.listeners.splice(position, 1); }
  }
  setItems(items: BookSourceListItem[]): void {
    this.items = items;
    this.listeners.forEach((listener: DataChangeListener) => listener.onDataReloaded());
  }
}

/**
 * LazyForEach 的 key 生成器：把「会影响这一行渲染的字段」全部拼进去。
 * 只拼 bookSourceUrl 时，同一 URL 的行内容变了（启用发现、分组、校验文案、启用开关）
 * key 不变，LazyForEach 复用旧组件不重建，界面上表现为「点了没反应」。
 */
function ProfileSubPagesSourceKey(item: SourceDataItem): string {
  const row = item.row;
  return [
    row.source.bookSourceUrl,
    row.source.enabled ? '1' : '0',
    row.source.bookSourceName,
    row.source.bookSourceGroup ?? '',
    row.hasExplore ? '1' : '0',
    row.exploreEnabled ? '1' : '0',
    row.checkMessage
  ].join('|');
}

@Component
export struct BookSourceManagePage {
  @State moreMenuVisible: boolean = false;
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  /** M3 AlertDialog 的描边色（OutlinedButton / OutlinedTextField 用 outlineVariant）。 */
  @StorageProp('themeColorOutlineVariant') themeColorOutlineVariant: string = '#C4C6D0';
  /** filled Button 的文字色（onPrimary）。 */
  @StorageProp('themeColorOnPrimary') themeColorOnPrimary: string = '#FFFFFF';
  /** 选择底栏主按钮（FilledIconButton）的容器/内容色，上游取 secondaryContainer/onSecondaryContainer。 */
  @StorageProp('themeColorSecondaryContainer') themeColorSecondaryContainer: string = '#404A33';
  @StorageProp('themeColorOnSecondaryContainer') themeColorOnSecondaryContainer: string = '#DCE7C8';
  // 分组筛选项选中态用（上游 GroupFilterItem :1015-1029 的 primaryContainer / onPrimaryContainer）。
  @StorageProp('themeColorPrimaryContainer') themeColorPrimaryContainer: string = '#2B4B8C';
  @StorageProp('themeColorOnPrimaryContainer') themeColorOnPrimaryContainer: string = '#DCE3FF';
  /** 系统状态栏高度（vp），由 pages/Index.ets 的 publishAppTopInset() 广播；顶栏据此下移。 */
  @StorageProp('appTopInset') appTopInset: number = 0;
  /** 系统底部导航区高度（vp），由 pages/Index.ets 的 publishAppBottomInset() 广播；浮动工具栏据此上移。 */
  @StorageProp('appBottomInset') appBottomInset: number = 0;
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  /** 上游 SearchBar.kt:55 默认 backgroundColor = surfaceContainerLow，对应本地 themeColorSurfaceSecondary。 */
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#EDEEF2';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @Prop groups: string[] = [];
  @State @Watch('onListInputChanged') selectedGroup: string = '';
  @State showSearch: boolean = false;
  @State @Watch('onListInputChanged') searchQuery: string = '';
  @State showGroupFilter: boolean = false;
  @State groupFilterQuery: string = '';
  /** 分组管理弹层（上游 GroupManageBottomSheet）。 */
  @State private groupManageVisible: boolean = false;
  /** 分组管理选择态：标题变「已选 N 个」、行首换选择框、底部出全选/删除两钮。 */
  @State private groupManageSelectionMode: boolean = false;
  @State private groupManageSelected: Set<string> = new Set<string>();
  /** 非空表示该分组行处于行内重命名展开态（上游 GroupItem 的 expanded）。 */
  @State private groupManageEditing: string = '';
  @State private groupManageEditText: string = '';
  @State @Watch('onListInputChanged') groupByDomain: boolean = false;
  @State @Watch('onListInputChanged') sortMode: string = '手动排序';
  @State @Watch('onListInputChanged') sortDescending: boolean = false;

  private onListInputChanged(): void {
    this.rebuildVisibleSources();
  }
  // P4：书源列表。allSources 是从仓储读出的全量，visibleSources 经搜索/筛选/排序后驱动列表。
  @State private allSources: BookSource[] = [];
  @State private visibleSourceRows: SourceRow[] = [];
  private sourceDataSource: SourceDataSource = new SourceDataSource();
  /** 多选模式与选中集合（按 bookSourceUrl）。 */
  @State private selectionMode: boolean = false;
  @State private selectedUrls: Set<string> = new Set<string>();
  @State private batchPanelVisible: boolean = false;
  /** 校验配置弹层：上游 CheckSourceBottomSheet（运行中改写草稿，确认后回到运行弹层）。 */
  @State private checkSheetVisible: boolean = false;
  /** 校验「运行」弹层：上游 CheckBookSourceSheet（关键字 + 设置/确认两个 action）。 */
  @State private checkRunSheetVisible: boolean = false;
  /** 校验草稿选项：上游 checkOptionsDraft。 */
  @State private checkOptions: SourceCheckOptions = defaultCheckOptions();
  /** 本次要校验的书源 URL：上游 checkSourceIds。 */
  @State private checkTargetUrls: string[] = [];
  /** 逐源校验结果文案：url → displayMessage，驱动行内 checkMessage。 */
  @State private checkMessages: Map<string, string> = new Map<string, string>();
  private sourceScroller: Scroller = new Scroller();
  /** 当前打开条目菜单的行。 */
  @State private menuRowUrl: string = '';
  /** 自定义源分组对话框：文本 + 「添加分组」开关（对齐上游 BookSourceImportGroupDialog）。 */
  @State private promptText: string = '';
  @State private promptAddGroup: boolean = true;
  private promptAction: (value: string, add: boolean) => void = (_value: string, _add: boolean) => {};
  private promptDialogBuilder: CustomBuilder | undefined = undefined;
  private promptDialogId: number = -1;
  /** 搜索跳转回调（P4 条目菜单「搜索」）。 */
  onOpenSourceSearch: (keyword: string, sourceUrl: string) => void = (_keyword: string, _sourceUrl: string) => {};
  /** 打开书源编辑页（P5）。sourceUrl 为空表示新建。 */
  onOpenSourceEdit: (sourceUrl: string) => void = (_sourceUrl: string) => {};
  /** 打开书源登录页（P9）。 */
  onOpenSourceLogin: (sourceUrl: string) => void = (_sourceUrl: string) => {};
  /** 打开书源调试页（P10）。 */
  onOpenSourceDebug: (sourceUrl: string) => void = (_sourceUrl: string) => {};
  // P6 导入：导入对话框状态。importStage='options' 显示三个保留开关，'online' 收 URL。
  @State private importVisible: boolean = false;
  @State private importStage: string = 'options';
  @State private importOnlineUrl: string = '';
  @State private keepName: boolean = false;
  @State private keepGroup: boolean = false;
  @State private keepEnabled: boolean = false;
  /** 待落库的解析结果；选完保留项后调 importRules。 */
  private pendingImportRules: BookSource[] = [];
  private pendingImportSkipped: number = 0;

  aboutToAppear(): void {
    this.reloadSources();
    BookSourceCheckCoordinator.subscribe(this.onCheckStateChanged);
  }

  aboutToDisappear(): void {
    BookSourceCheckCoordinator.unsubscribe(this.onCheckStateChanged);
  }

  /**
   * 校验状态变化：把逐源 displayMessage 搬到 checkMessages，行上的 checkMessage 随之刷新。
   * 上游 BookSourceViewModel.kt:215-232 也是从 check.results 现算再拼进 uiState。
   */
  private onCheckStateChanged: (state: BookSourceCheckState) => void = (state: BookSourceCheckState): void => {
    this.checkMessages = BookSourceCheckCoordinator.messages();
    this.rebuildVisibleSources();
    // 全部跑完给一条汇总（上游 book_source_check_completed「校验完成，成功 %1$d，失败 %2$d」）。
    if (!state.isRunning && state.total > 0 && state.completed >= state.total) {
      let succeeded: number = 0;
      let failed: number = 0;
      state.results.forEach((result) => {
        if (result.status === 'Succeeded') succeeded += 1;
        else if (result.status === 'Failed') failed += 1;
      });
      this.onUnavailableAction('校验完成，成功 ' + succeeded + '，失败 ' + failed);
    }
  };

  /**
   * 开始校验：上游 BookSourceViewModel.kt:295-308 StartCheck。
   * 运行中再点只提示「正在校验书源,请稍后」（source_already_checking），不重复投递。
   */
  private async runCheck(keyword: string): Promise<void> {
    if (BookSourceCheckCoordinator.currentState().isRunning) {
      this.onUnavailableAction('正在校验书源,请稍后');
      return;
    }
    const targets: BookSource[] = [];
    for (const source of this.allSources) {
      if (this.checkTargetUrls.indexOf(source.bookSourceUrl) >= 0) targets.push(source);
    }
    if (targets.length === 0) return;
    this.onUnavailableAction('开始校验 ' + targets.length + ' 个书源');
    await BookSourceCheckCoordinator.check(this.checkTargetUrls, keyword, this.checkOptions);
  }

  /** 从仓储读全量书源，重建可见列表。 */
  private async reloadSources(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    await BookSourceRepository.load(context);
    this.allSources = BookSourceRepository.getAll();
    this.rebuildVisibleSources();
  }

  /** 把仓储改动（启停/排序/批量）整表写回并刷新可见列表。 */
  private async commitSources(next: BookSource[]): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      this.allSources = await BookSourceRepository.save(context, next);
      this.rebuildVisibleSources();
    } catch (error) {
      this.onUnavailableAction('书源保存失败：' + (error instanceof Error ? error.message : String(error)));
    }
  }

  /** 解析 sourceJson 里的字段（书源的派生字段都在 JSON 里，仓储列只是子集）。 */
  private static sourceField(json: string, key: string): string {
    try {
      const parsed = JSON.parse(json) as Record<string, Object>;
      const value = parsed[key];
      return typeof value === 'string' ? value : '';
    } catch (_) {
      return '';
    }
  }

  /**
   * 读 sourceJson 里的布尔字段。
   * 不能复用 sourceField：那个只认字符串，而本地写回 enabledExplore 时存的是 JSON 布尔值，
   * 读出来会永远是空串（表现为「启用发现」点了没反应、圆点不换色）。
   */
  private static sourceBoolField(json: string, key: string, fallback: boolean): boolean {
    try {
      const parsed = JSON.parse(json) as Record<string, Object>;
      const value = parsed[key];
      if (typeof value === 'boolean') { return value; }
      if (typeof value === 'string') { return value === 'true'; }
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  /** 域名：从 sourceJson.bookSourceUrl 取 host，'#' 与无协议头的不显示。 */
  private static domainOf(source: BookSource): string {
    const url = BookSourceManagePage.sourceField(source.sourceJson, 'bookSourceUrl');
    if (url.length === 0 || url === '#') { return ''; }
    // ArkTS 无全局 URL 类，按字符串取协议后的 host（到第一个 / 或 ? 为止）。
    const scheme = url.indexOf('://');
    if (scheme < 0) { return ''; }
    const rest = url.substring(scheme + 3);
    const end = rest.search(/[/?#]/);
    return end < 0 ? rest : rest.substring(0, end);
  }

  /** 由全量 + 搜索词 + 分组筛选 + 排序，算出可见行。 */
  private rebuildVisibleSources(): void {
    const query = this.searchQuery.trim().toLowerCase();
    let list = this.allSources.filter((source: BookSource) => {
      if (query.length > 0 &&
        !source.bookSourceName.toLowerCase().includes(query) &&
        !source.bookSourceUrl.toLowerCase().includes(query)) { return false; }
      const group = source.bookSourceGroup ?? '';
      const selected = this.selectedGroup;
      if (selected.length === 0 || selected === '全部') { return true; }
      if (selected === '启用') { return source.enabled; }
      if (selected === '禁用') { return !source.enabled; }
      if (selected === '未分组') { return group.length === 0; }
      if (selected === '需要登录') {
        return BookSourceManagePage.sourceField(source.sourceJson, 'loginUrl').length > 0;
      }
      if (selected === '发现已启用') {
        return BookSourceManagePage.sourceBoolField(source.sourceJson, 'enabledExplore', true);
      }
      if (selected === '发现未启用') {
        return BookSourceManagePage.sourceField(source.sourceJson, 'exploreUrl').length > 0 &&
          !BookSourceManagePage.sourceBoolField(source.sourceJson, 'enabledExplore', true);
      }
      return group === selected;
    });
    // 排序逐档照上游 BookSourceViewModel.kt:736-743 的 sortFor：
    // Name→bookSourceName、Url→bookSourceUrl、Weight→weight、Update→lastUpdateTime **降序**、
    // Respond→respondTime、Enable→enabled 降序再按名称、Default→customOrder；
    // 最后统一按 ascending 正/反序（本地 sortDescending 即 !ascending）。
    const desc = this.sortDescending ? -1 : 1;
    list = [...list].sort((a: BookSource, b: BookSource) => {
      let cmp = 0;
      if (this.sortMode === '名称排序') { cmp = a.bookSourceName.localeCompare(b.bookSourceName); }
      else if (this.sortMode === 'URL 排序') { cmp = a.bookSourceUrl.localeCompare(b.bookSourceUrl); }
      else if (this.sortMode === '按启用状态排序') {
        // 上游 compareByDescending { enabled }.thenBy { bookSourceName }
        cmp = Number(b.enabled) - Number(a.enabled);
        if (cmp === 0) { cmp = a.bookSourceName.localeCompare(b.bookSourceName); }
      } else if (this.sortMode === '按更新时间排序') {
        // 上游 compareByDescending { lastUpdateTime }
        cmp = BookSourceManagePage.sourceNumberField(b.sourceJson, 'lastUpdateTime', 0) -
          BookSourceManagePage.sourceNumberField(a.sourceJson, 'lastUpdateTime', 0);
      } else if (this.sortMode === '按响应时间排序') {
        cmp = BookSourceManagePage.sourceNumberField(a.sourceJson, 'respondTime', 180000) -
          BookSourceManagePage.sourceNumberField(b.sourceJson, 'respondTime', 180000);
      } else if (this.sortMode === '权重排序') {
        // 上游 BookSourceSort.Weight -> compareBy { it.weight }，不是 customOrder。
        cmp = BookSourceManagePage.sourceNumberField(a.sourceJson, 'weight', 0) -
          BookSourceManagePage.sourceNumberField(b.sourceJson, 'weight', 0);
      } else { cmp = a.customOrder - b.customOrder; } // 手动排序 Default -> customOrder
      return cmp === 0 ? 0 : cmp * desc;
    });
    // 按域名分组：以 host 为主键再排一次（每行仍显示自己的域名列）。
    if (this.groupByDomain) {
      list = [...list].sort((a: BookSource, b: BookSource) =>
        BookSourceManagePage.domainOf(a).localeCompare(BookSourceManagePage.domainOf(b)));
    }
    const rows: SourceRow[] = [];
    const items: BookSourceListItem[] = [];
    let lastDomain: string | undefined = undefined;
    for (const source of list) {
      const domain = BookSourceManagePage.domainOf(source);
      const loginUrl = BookSourceManagePage.sourceField(source.sourceJson, 'loginUrl');
      const exploreUrl = BookSourceManagePage.sourceField(source.sourceJson, 'exploreUrl');
      // 上游 BookSource.kt:54 `var enabledExplore: Boolean = true`：字段缺失时默认 true，
      // 所以这里 fallback 也是 true（本地旧实现按字符串读，永远读成 false，圆点恒为红）。
      const enabledExplore = BookSourceManagePage.sourceBoolField(source.sourceJson, 'enabledExplore', true);
      const checkMessage = this.checkMessages.get(source.bookSourceUrl) ?? '';
      const row = new SourceRow(source, domain, loginUrl.length > 0, exploreUrl.length > 0, enabledExplore, checkMessage);
      rows.push(row);
      // 上游 BookSourceScreen.kt:594：分组开启且本行域名与上一行不同，先插一个域名标题项。
      if (this.groupByDomain && domain !== lastDomain) {
        items.push({ kind: 'domain', domain: domain } as DomainHeaderItem);
        lastDomain = domain;
      }
      items.push({ kind: 'source', row: row } as SourceDataItem);
    }
    this.visibleSourceRows = rows;
    this.sourceDataSource.setItems(items);
  }

  // ---------- P4 条目与批量操作 ----------

  /** 只有手动排序、非按域名分组、非多选时才允许拖拽。 */
  private canReorder(): boolean {
    return this.sortMode === '手动排序' && !this.groupByDomain && !this.selectionMode;
  }

  /** 侧滑删/编辑按钮。 */
  @Builder
  private SourceSwipeEnd(row: SourceRow) {
    Row() {
      Text('删除').fontSize(LABEL_MEDIUM).fontColor('#FFFFFF').padding({ left: 16, right: 16 })
        .backgroundColor('#C62828').height('100%')
        .onClick(() => this.deleteSource(row.source))
    }
  }

  /** 复制一条书源（ArkTS 禁对象展开，显式逐字段拷贝）。 */
  private static cloneSource(item: BookSource): BookSource {
    return {
      bookSourceUrl: item.bookSourceUrl,
      bookSourceName: item.bookSourceName,
      bookSourceGroup: item.bookSourceGroup,
      bookSourceType: item.bookSourceType,
      enabled: item.enabled,
      customOrder: item.customOrder,
      sourceJson: item.sourceJson
    };
  }

  /** 切换单条启停，整表写回。 */
  private async toggleSource(source: BookSource, enabled: boolean): Promise<void> {
    const next = this.allSources.map((item: BookSource) => {
      if (item.bookSourceUrl !== source.bookSourceUrl) { return item; }
      const copy = BookSourceManagePage.cloneSource(item);
      copy.enabled = enabled;
      return copy;
    });
    await this.commitSources(next);
  }

  /** 置顶/置底：把 urls 里的行移到列表首尾，并按新顺序重排 customOrder。 */
  private async moveToEdge(urls: string[], toTop: boolean): Promise<void> {
    const moving = this.allSources.filter((item: BookSource) => urls.includes(item.bookSourceUrl));
    const rest = this.allSources.filter((item: BookSource) => !urls.includes(item.bookSourceUrl));
    const reordered: BookSource[] = [];
    if (toTop) {
      moving.forEach((item: BookSource) => reordered.push(item));
      rest.forEach((item: BookSource) => reordered.push(item));
    } else {
      rest.forEach((item: BookSource) => reordered.push(item));
      moving.forEach((item: BookSource) => reordered.push(item));
    }
    const next = reordered.map((item: BookSource, index: number) => {
      const copy = BookSourceManagePage.cloneSource(item);
      copy.customOrder = index + 1;
      return copy;
    });
    await this.commitSources(next);
  }

  /** 拖拽重排：from/to 是 visibleSourceRows 的下标，把该行对应源移到目标位置。 */
  private async onSourceMove(from: number, to: number): Promise<void> {
    const fromRow = this.visibleSourceRows[from];
    const toRow = this.visibleSourceRows[to];
    if (fromRow === undefined || toRow === undefined || from === to) { return; }
    const reordered = this.allSources.slice();
    const fromIndex = reordered.findIndex((item: BookSource) => item.bookSourceUrl === fromRow.source.bookSourceUrl);
    const toIndex = reordered.findIndex((item: BookSource) => item.bookSourceUrl === toRow.source.bookSourceUrl);
    if (fromIndex < 0 || toIndex < 0) { return; }
    const moved = reordered.splice(fromIndex, 1)[0];
    if (moved === undefined) { return; }
    reordered.splice(toIndex, 0, moved);
    const base = reordered.reduce((min: number, item: BookSource) => Math.min(min, item.customOrder), 0);
    const next = reordered.map((item: BookSource, index: number) => {
      const copy = BookSourceManagePage.cloneSource(item);
      copy.customOrder = base + index;
      return copy;
    });
    await this.commitSources(next);
  }

  /** 置顶/置底/开关/发现/分组的批量实现。 */
  private async setEnabledForSelection(enabled: boolean): Promise<void> {
    const next = this.allSources.map((item: BookSource) => {
      if (!this.selectedUrls.has(item.bookSourceUrl)) { return item; }
      const copy = BookSourceManagePage.cloneSource(item);
      copy.enabled = enabled;
      return copy;
    });
    await this.commitSources(next);
  }

  private async setExploreForSelection(enabled: boolean): Promise<void> {
    const next = this.allSources.map((item: BookSource) => {
      if (!this.selectedUrls.has(item.bookSourceUrl)) { return item; }
      const parsed = BookSourceManagePage.parseJson(item.sourceJson);
      parsed['enabledExplore'] = enabled;
      const copy = BookSourceManagePage.cloneSource(item);
      copy.sourceJson = JSON.stringify(parsed);
      return copy;
    });
    await this.commitSources(next);
  }

  private async setGroupForSelection(group: string, add: boolean): Promise<void> {
    const next = this.allSources.map((item: BookSource) => {
      if (!this.selectedUrls.has(item.bookSourceUrl)) { return item; }
      const groups = (item.bookSourceGroup ?? '').split(',').map((g: string) => g.trim()).filter((g: string) => g.length > 0);
      let result: string[];
      if (add) {
        result = groups.includes(group) ? groups.slice() : groups.concat([group]);
      } else {
        result = groups.filter((g: string) => g !== group);
      }
      const copy = BookSourceManagePage.cloneSource(item);
      copy.bookSourceGroup = result.join(',');
      return copy;
    });
    await this.commitSources(next);
  }

  /**
   * 重命名分组：对齐上游 BookSourceViewModel.kt:388-396 updateGroup ——
   * 逐条把 bookSourceGroup 拆成集合，删掉旧名、非空则加新名，再用 "," 拼回。
   */
  private async renameGroup(oldName: string, newName: string): Promise<void> {
    const target = newName.trim();
    if (target.length === 0) {
      this.onUnavailableAction('分组名称不能为空');
      return;
    }
    if (target === oldName) { return; }
    const next = this.allSources.map((item: BookSource) => {
      const groups = (item.bookSourceGroup ?? '')
        .split(/[,;，；]/).map((part: string) => part.trim()).filter((part: string) => part.length > 0);
      if (!groups.includes(oldName)) { return item; }
      const result = groups.filter((group: string) => group !== oldName);
      if (!result.includes(target)) { result.push(target); }
      const copy = BookSourceManagePage.cloneSource(item);
      copy.bookSourceGroup = result.join(',');
      return copy;
    });
    await this.commitSources(next);
  }

  /**
   * 删除若干分组：对齐上游 BookSourceViewModel.kt:398-413 deleteGroups ——
   * 一次把多个分组名从每条书源的分组集合里全部移除后写回。
   */
  private async deleteGroups(names: string[]): Promise<void> {
    if (names.length === 0) { return; }
    const toRemove = new Set<string>(names);
    const next = this.allSources.map((item: BookSource) => {
      const groups = (item.bookSourceGroup ?? '')
        .split(/[,;，；]/).map((part: string) => part.trim()).filter((part: string) => part.length > 0);
      if (groups.every((group: string) => !toRemove.has(group))) { return item; }
      const copy = BookSourceManagePage.cloneSource(item);
      copy.bookSourceGroup = groups.filter((group: string) => !toRemove.has(group)).join(',');
      return copy;
    });
    await this.commitSources(next);
  }

  /**
   * 从 sourceJson 读数值字段：上游 lastUpdateTime/respondTime/weight 都是实体上的数值列
   * （BookSource.kt:77/79/81），本地只有 sourceJson 这一份真值，所以按 JSON 里的数值读。
   */
  private static sourceNumberField(json: string, key: string, fallback: number): number {
    try {
      const obj = JSON.parse(json) as Record<string, Object>;
      const value = obj[key];
      if (typeof value === 'number') { return value as number; }
      if (typeof value === 'string') {
        const parsed = Number(value as string);
        return Number.isFinite(parsed) ? parsed : fallback;
      }
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  private static parseJson(json: string): Record<string, Object> {
    try {
      return JSON.parse(json) as Record<string, Object>;
    } catch (_) {
      return {} as Record<string, Object>;
    }
  }

  /** 改某条的发现开关。 */
  private async toggleExplore(source: BookSource): Promise<void> {
    const parsed = BookSourceManagePage.parseJson(source.sourceJson);
    parsed['enabledExplore'] = !BookSourceManagePage.sourceBoolField(source.sourceJson, 'enabledExplore', true);
    const next = this.allSources.map((item: BookSource) => {
      if (item.bookSourceUrl !== source.bookSourceUrl) { return item; }
      const copy = BookSourceManagePage.cloneSource(item);
      copy.sourceJson = JSON.stringify(parsed);
      return copy;
    });
    await this.commitSources(next);
  }

  /** 删除一条（确认后）。 */
  private async deleteSource(source: BookSource): Promise<void> {
    const next = this.allSources.filter((item: BookSource) => item.bookSourceUrl !== source.bookSourceUrl);
    await this.commitSources(next);
  }

  /** 选中首尾之间的区间。 */
  private selectInterval(): void {
    const urls = this.visibleSourceRows.map((row: SourceRow) => row.source.bookSourceUrl);
    const selectedIndices: number[] = [];
    urls.forEach((url: string, index: number) => {
      if (this.selectedUrls.has(url)) { selectedIndices.push(index); }
    });
    if (selectedIndices.length === 0) { return; }
    const first = Math.min(...selectedIndices);
    const last = Math.max(...selectedIndices);
    const next = new Set<string>(this.selectedUrls);
    for (let i = first; i <= last; i++) { next.add(urls[i]); }
    this.selectedUrls = next;
  }

  /**
   * 全选：上游 SelectionBottomBar.kt:175-180 的 leadingContent 第一个按钮（SelectAll）。
   * 范围与「全选当前筛选结果」一致——只选用户眼前列表里的书源，不含被筛选掉的行。
   */
  private selectAllSources(): void {
    const next = new Set<string>(this.selectedUrls);
    this.visibleSourceRows.forEach((row: SourceRow) => next.add(row.source.bookSourceUrl));
    this.selectedUrls = next;
  }

  /**
   * 反选：上游 SelectionBottomBar.kt:181-186 的 leadingContent 第二个按钮（Refresh）。
   * 在当前筛选结果内取差集，与列表范围保持一致。
   */
  private invertSelectionSources(): void {
    const next = new Set<string>();
    this.visibleSourceRows.forEach((row: SourceRow) => {
      const url = row.source.bookSourceUrl;
      if (!this.selectedUrls.has(url)) { next.add(url); }
    });
    this.selectedUrls = next;
  }

  /**
   * 批量删除确认：上游 RuleListScaffold.kt:40-52 的 AppAlertDialog
   * （title=delete「删除」、text=sure_del「是否确认删除?」、confirm=ok、dismiss=cancel），
   * 确认后才真正删除所选书源。
   */
  private confirmDeleteSelection(): void {
    const count = this.selectedUrls.size;
    if (count === 0) { return; }
    this.getUIContext().showAlertDialog({
      title: '删除',
      message: '是否确认删除?',
      autoCancel: true,
      primaryButton: {
        value: '确认',
        action: () => { this.deleteSelection(); }
      },
      secondaryButton: {
        value: '取消',
        fontColor: this.themeColorTextTertiary,
        action: () => {}
      }
    });
  }

  /** 删除所有选中书源，完成后退出多选。 */
  private async deleteSelection(): Promise<void> {
    const next = this.allSources.filter((item: BookSource) => !this.selectedUrls.has(item.bookSourceUrl));
    await this.commitSources(next);
    this.exitSelectionMode();
  }

  /** 批量导出为 JSON 文件。 */
  private async exportSelection(): Promise<void> {
    const selected = this.allSources.filter((item: BookSource) => this.selectedUrls.has(item.bookSourceUrl));
    if (selected.length === 0) { this.onUnavailableAction('请先选择要导出的书源'); return; }
    const text = BookSourceRepository.exportRules(selected);
    try {
      const context = this.getUIContext().getHostContext();
      if (context === undefined) { return; }
      const file = fileIo.openSync(`${context.filesDir}/book_sources_export.json`,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try { fileIo.writeSync(file.fd, text); } finally { fileIo.closeSync(file); }
      this.onUnavailableAction(`已导出 ${selected.length} 条书源到应用文件目录`);
    } catch (error) {
      this.onUnavailableAction('导出失败：' + (error instanceof Error ? error.message : String(error)));
    }
  }

  /** P6 本地导入：DocumentViewPicker 选 json/txt → 解析 → 导入选项对话框。 */
  private async importFromLocalFile(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 10;
      options.fileSuffixFilters = ['书源 JSON|.json', '文本文件|.txt'];
      const uris = await new picker.DocumentViewPicker(context).select(options);
      if (uris.length === 0) { return; }
      const texts: string[] = [];
      for (let i = 0; i < uris.length; i++) {
        // picker 返回 file uri，readTextSync 只认沙箱路径，先 copyFileSync 到 filesDir 再读。
        const tempPath = `${context.filesDir}/booksource-import-${Date.now()}-${i}.json`;
        try {
          const f = fileIo.openSync(uris[i], fileIo.OpenMode.READ_ONLY);
          try { fileIo.copyFileSync(f.fd, tempPath); } finally { fileIo.closeSync(f); }
          texts.push(fileIo.readTextSync(tempPath));
        } catch (_) { /* 单个文件读失败跳过，其余继续 */ }
        finally { if (fileIo.accessSync(tempPath)) { fileIo.unlinkSync(tempPath); } }
      }
      if (texts.length === 0) {
        this.onUnavailableAction('读取文件失败，未导入数据');
        return;
      }
      this.acceptImportText(texts.join('\n'));
    } catch (error) {
      this.onUnavailableAction('本地导入失败：' + (error instanceof Error ? error.message : String(error)));
    }
  }

  /** P6 网络导入：用 P2 的 HttpClient 拉文本 → 解析 → 导入选项对话框。 */
  private async importFromOnlineUrl(): Promise<void> {
    const url = this.importOnlineUrl.trim();
    if (url.length === 0) {
      this.onUnavailableAction('请输入书源订阅地址');
      return;
    }
    this.onUnavailableAction('正在从网络拉取书源…');
    try {
      const resp = await SourceHttp.getClient().execute({
        url: url, method: 'GET', headers: {}, useCookieJar: false
      });
      if (!resp.success || resp.statusCode < 200 || resp.statusCode >= 300) {
        this.onUnavailableAction(`网络导入失败：HTTP ${resp.statusCode} ${resp.error ?? ''}`);
        return;
      }
      this.acceptImportText(resp.body);
    } catch (error) {
      this.onUnavailableAction('网络导入失败：' + (error instanceof Error ? error.message : String(error)));
    }
  }

  /** P6 二维码导入：本机 SDK 无 ScanKit 声明（探针证据见任务计划），明确告知不可适配。 */
  private importFromQrcode(): void {
    this.onUnavailableAction('二维码导入：当前设备 SDK 未提供 @kit.ScanKit/startScanForResult 能力，暂无法适配，请用本地导入或在线导入');
  }

  /** 解析导入文本；有条目则打开保留项对话框，否则如实反馈。 */
  private acceptImportText(text: string): void {
    const parsed = BookSourceImporter.parse(text);
    if (parsed.rules.length === 0) {
      this.onUnavailableAction(`未解析到有效书源（跳过 ${parsed.skipped} 条），请检查文件格式`);
      return;
    }
    this.pendingImportRules = parsed.rules;
    this.pendingImportSkipped = parsed.skipped;
    this.keepName = false;
    this.keepGroup = false;
    this.keepEnabled = false;
    this.importStage = 'options';
    this.importVisible = true;
  }

  /** 用户确认保留项后真正落库。 */
  private async commitImport(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { this.importVisible = false; return; }
    const keep: BookSourceImportKeep = {
      keepName: this.keepName, keepGroup: this.keepGroup, keepEnabled: this.keepEnabled
    };
    try {
      const outcome = await BookSourceRepository.importRules(context, this.pendingImportRules, keep);
      this.onUnavailableAction(`导入完成：新增 ${outcome.added}、更新 ${outcome.updated}、跳过 ${outcome.skipped + this.pendingImportSkipped}`);
      await this.reloadSources();
    } catch (error) {
      this.onUnavailableAction('导入失败：' + (error instanceof Error ? error.message : String(error)));
    }
    this.importVisible = false;
  }

  /** 导出全部书源到用户选择的文件（区别于选中导出的 exportSelection）。 */
  private async exportAllSources(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const all = BookSourceRepository.getAll();
    if (all.length === 0) { this.onUnavailableAction('没有可导出的书源'); return; }
    const text = BookSourceRepository.exportRules(all);
    try {
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = ['bookSource.json'];
      const uris = await new picker.DocumentViewPicker(context).save(options);
      if (uris.length === 0) { return; }
      // 照 TxtTocRuleRepository:528-546：直接 writeSync 传字符串，勿先 encodeInto（模拟器会写出 0 字节）。
      const f = fileIo.openSync(uris[0], fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try { fileIo.writeSync(f.fd, text); } finally { fileIo.closeSync(f); }
      this.onUnavailableAction(`已导出 ${all.length} 条书源`);
    } catch (error) {
      this.onUnavailableAction('导出失败：' + (error instanceof Error ? error.message : String(error)));
    }
  }

  /** 条目菜单动作分发。 */
  private onSourceRowAction(key: string, row: SourceRow): void {
    const source = row.source;
    if (key === 'top' || key === 'bottom') {
      this.moveToEdge([source.bookSourceUrl], key === 'top');
    } else if (key === 'login') {
      this.onOpenSourceLogin(source.bookSourceUrl);
    } else if (key === 'search') {
      this.onOpenSourceSearch(source.bookSourceName, source.bookSourceUrl);
    } else if (key === 'edit') {
      this.onOpenSourceEdit(source.bookSourceUrl);
    } else if (key === 'debug') {
      this.onOpenSourceDebug(source.bookSourceUrl);
    } else if (key === 'delete') {
      this.deleteSource(source);
    } else if (key === 'explore') {
      this.toggleExplore(source);
    }
    this.menuRowUrl = '';
  }

  /** 批量动作完成后收起面板并退出多选，避免面板残留在已关闭多选的列表上。 */
  private exitSelectionMode(): void {
    this.batchPanelVisible = false;
    this.selectionMode = false;
    this.selectedUrls = new Set<string>();
  }

  /** 多选面板动作分发。面板与多选状态由这里统一收口，onClick 只做分发。 */
  private onBatchAction(key: string): void {
    if (key === 'enable') { this.setEnabledForSelection(true); this.exitSelectionMode(); }
    else if (key === 'disable') { this.setEnabledForSelection(false); this.exitSelectionMode(); }
    else if (key === 'explore_on') { this.setExploreForSelection(true); this.exitSelectionMode(); }
    else if (key === 'explore_off') { this.setExploreForSelection(false); this.exitSelectionMode(); }
    else if (key === 'group_add' || key === 'group_remove') {
      // 上游是一个「自定义源分组」对话框，带「添加分组」开关（initialAdd）。
      // 两个入口分别预置开关初值：添加=true、移除=false，用户仍可在对话框里切换。
      this.promptText = '';
      this.promptAddGroup = key === 'group_add';
      this.promptAction = (value: string, add: boolean) => { this.setGroupForSelection(value, add); };
      this.batchPanelVisible = false;
      this.openPromptDialog();
    } else if (key === 'top') { this.moveToEdge(Array.from(this.selectedUrls), true); this.exitSelectionMode(); }
    else if (key === 'bottom') { this.moveToEdge(Array.from(this.selectedUrls), false); this.exitSelectionMode(); }
    else if (key === 'interval') { this.selectInterval(); this.batchPanelVisible = false; }
    else if (key === 'check') {
      // 上游 BookSourceScreen.kt:513-518：先记下选中书源，再打开「运行」弹层
      // （CheckSheet.Run），并清空多选。配置弹层只从运行弹层的设置按钮进。
      this.batchPanelVisible = false;
      this.checkTargetUrls = Array.from(this.selectedUrls);
      this.exitSelectionMode();
      this.checkRunSheetVisible = true;
    }
    else if (key === 'export') { this.exportSelection(); this.exitSelectionMode(); }
  }

  @Builder
  private MoreMenu() {
    UiMenuPanel({
      items: this.srcMoreItems(),
      panelWidth: PROFILE_MENU_WIDTH,
      onSelect: (key: string) => { this.moreMenuVisible = false; this.onSrcMoreSelect(key); }
    })
  }

  /**
   * 更多菜单：逐项照抄上游 BookSourceScreen.kt:528-581 的 dropDownMenuContent 顺序与文案。
   * 上游共 5 项功能 + PillDivider + 8 项排序，无「导出全部」（上游导出只在批量选择里，:519-522）。
   * 文案取自 values-zh-rCN/strings.xml：网络导入/按域名分组显示/智能排序/地址排序/
   * 更新时间排序/响应时间排序/是否启用/反序。
   */
  private srcMoreItems(): UiMenuItem[] {
    return [
      { key: 'groups', title: '分组管理' },
      { key: 'import_local', title: '本地导入' },
      { key: 'import_qrcode', title: '二维码导入' },
      { key: 'import_online', title: '网络导入' },
      // 上游是「固定文案 + isSelected」，不是切换文案。
      { key: 'group_by_domain', title: '按域名分组显示', selected: this.groupByDomain },
      // 对齐上游 PillDivider()（:555）：插在功能项与排序项之间。
      { key: 'divider', title: '', divider: true },
      { key: 'sort_manual', title: '手动排序', selected: this.sortMode === '手动排序' },
      { key: 'sort_weight', title: '智能排序', selected: this.sortMode === '权重排序' },
      { key: 'sort_name', title: '名称排序', selected: this.sortMode === '名称排序' },
      { key: 'sort_url', title: '地址排序', selected: this.sortMode === 'URL 排序' },
      { key: 'sort_update', title: '更新时间排序', selected: this.sortMode === '按更新时间排序' },
      { key: 'sort_response', title: '响应时间排序', selected: this.sortMode === '按响应时间排序' },
      { key: 'sort_enabled', title: '是否启用', selected: this.sortMode === '按启用状态排序' },
      // 上游 isSelected = !state.sortAscending，本地 sortDescending 即降序。
      { key: 'descending', title: '反序', selected: this.sortDescending }
    ];
  }

  private onSrcMoreSelect(key: string): void {
    // 分隔线项不可点（UiMenuPanel 里也只画线），这里兜底忽略。
    if (key === 'divider') {
      return;
    } else if (key === 'groups') {
      // 上游 BookSourceScreen.kt:529-531：分组管理打开 GroupManageBottomSheet。
      this.groupManageSelected = new Set<string>();
      this.groupManageSelectionMode = false;
      this.groupManageEditing = '';
      this.groupManageVisible = true;
    } else if (key === 'import_local') {
      this.importFromLocalFile();
    } else if (key === 'import_qrcode') {
      this.importFromQrcode();
    } else if (key === 'import_online') {
      this.importOnlineUrl = '';
      this.importStage = 'online';
      this.importVisible = true;
    } else if (key === 'group_by_domain') {
      this.groupByDomain = !this.groupByDomain;
    } else if (key === 'sort_manual') {
      this.sortMode = '手动排序';
    } else if (key === 'sort_weight') {
      this.sortMode = '权重排序';
    } else if (key === 'sort_name') {
      this.sortMode = '名称排序';
    } else if (key === 'sort_url') {
      this.sortMode = 'URL 排序';
    } else if (key === 'sort_update') {
      this.sortMode = '按更新时间排序';
    } else if (key === 'sort_response') {
      this.sortMode = '按响应时间排序';
    } else if (key === 'sort_enabled') {
      this.sortMode = '按启用状态排序';
    } else if (key === 'descending') {
      this.sortDescending = !this.sortDescending;
    }
  }

  // ---------- P4 UI Builders ----------

  /** 两个面板（分组筛选、导入）合并到一个 bindSheet 的内容。 */
  @Builder
  private SourceSheetContent() {
    if (this.importVisible) {
      this.ImportDialog()
    } else if (this.showGroupFilter) {
      this.GroupFilterSheet()
    } else if (this.groupManageVisible) {
      this.GroupManageSheet()
    }
    // 批量菜单改挂 SelectionBottomBar 的 MoreVert bindPopup（见 build 里的浮动工具栏），不再占这个 bindSheet。
    // 自定义源分组对话框改用系统 openCustomDialog（见 PromptDialogContent），也不占这个 bindSheet。
  }

  /**
   * 分组管理弹层：照上游 GroupManageBottomSheet.kt:52-251。
   * 标题在「分组管理」与「已选 N 个」之间切换；选择态左侧换 Close、右侧换全选；
   * 非选择态右侧是 Checklist 图标（进入选择态）。每行是 GlassCard 形态的可展开项：
   * 尾部编辑/删除两个图标，点编辑展开行内输入框 + 确认按钮。
   */
  @Builder
  private GroupManageSheet() {
    Column() {
      // 头部：左 action（选择态才有 Close）+ 居中标题 + 右 action（Checklist / SelectAll）。
      Row() {
        if (this.groupManageSelectionMode) {
          Stack({ alignContent: Alignment.Center }) {
            AppGlyph({ name: 'profileClose', glyphSize: 20, tint: this.themeColorTextSecondary })
          }.width(56).height(40)
            .accessibilityText('取消')
            .onClick(() => {
              this.groupManageSelectionMode = false;
              this.groupManageSelected = new Set<string>();
            })
        } else {
          Blank().width(56)
        }
        Text(this.groupManageSelectionMode ? `已选 ${this.groupManageSelected.size} 个` : '分组管理')
          .fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium)
          .fontColor(this.themeColorTextPrimary)
          .textAlign(TextAlign.Center).layoutWeight(1).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.groupManageSelectionMode) {
          Stack({ alignContent: Alignment.Center }) {
            AppGlyph({ name: 'selectAll', glyphSize: 20, tint: this.themeColorAccent })
          }.width(56).height(40)
            .accessibilityText(this.groupManageSelected.size === this.allGroupNames().length && this.allGroupNames().length > 0 ? '全不选' : '全选')
            .onClick(() => {
              const all = this.allGroupNames();
              this.groupManageSelected = this.groupManageSelected.size === all.length
                ? new Set<string>() : new Set<string>(all);
            })
        } else if (this.allGroupNames().length > 0) {
          Stack({ alignContent: Alignment.Center }) {
            AppGlyph({ name: 'list', glyphSize: 20, tint: this.themeColorAccent })
          }.width(56).height(40)
            .accessibilityText('选择模式')
            .onClick(() => { this.groupManageSelectionMode = true; })
        } else {
          Blank().width(56)
        }
      }.width('100%').padding({ top: 20, bottom: 16 })
      Scroll() {
        Column() {
          ForEach(this.allGroupNames(), (group: string) => {
            Column() {
              Row() {
                if (this.groupManageSelectionMode) {
                  // 选择态行首是 M3 Checkbox（上游 AppCheckbox），行尾不再出编辑/删除。
                  Row().width(20).height(20).borderRadius(2)
                    .border({ width: this.groupManageSelected.has(group) ? 0 : 2, color: this.themeColorTextSecondary })
                    .backgroundColor(this.groupManageSelected.has(group) ? this.themeColorAccent : Color.Transparent)
                    .margin({ right: 12 })
                  if (this.groupManageSelected.has(group)) {
                    AppGlyph({ name: 'profileCheck', glyphSize: 14, tint: this.themeColorOnPrimary })
                      .margin({ right: -26, left: 3 })
                  }
                }
                Text(group).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary)
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
                if (!this.groupManageSelectionMode) {
                  AppGlyph({ name: 'edit', glyphSize: 18, tint: this.themeColorTextSecondary })
                    .margin({ left: 8 })
                    .accessibilityText('编辑')
                    .onClick(() => {
                      if (this.groupManageEditing === group) {
                        this.groupManageEditing = '';
                        this.groupManageEditText = '';
                      } else {
                        this.groupManageEditing = group;
                        this.groupManageEditText = group;
                      }
                    })
                  AppGlyph({ name: 'delete', glyphSize: 18, tint: this.themeColorTextSecondary })
                    .margin({ left: 12 })
                    .accessibilityText('删除')
                    .onClick(() => this.confirmDeleteGroup(group))
                }
              }.width('100%').alignItems(VerticalAlign.Center)
              if (!this.groupManageSelectionMode && this.groupManageEditing === group) {
                TextInput({ text: this.groupManageEditText, placeholder: '编辑' })
                  .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary)
                  .placeholderColor(this.themeColorTextTertiary)
                  .height(48).width('100%').margin({ top: 8 })
                  .backgroundColor(this.themeColorSurfacePrimary).borderRadius(4)
                  .padding({ left: 12, right: 12 })
                  .onChange((value: string) => { this.groupManageEditText = value; })
                Row() {
                  Blank().layoutWeight(1)
                  Row() {
                    AppGlyph({ name: 'profileCheck', glyphSize: 16, tint: this.themeColorAccent })
                    Text('确认').fontSize(LABEL_LARGE).fontColor(this.themeColorAccent).margin({ left: 4 })
                  }.padding({ left: 8, right: 8, top: 6, bottom: 6 })
                    .onClick(async () => {
                      await this.renameGroup(group, this.groupManageEditText);
                      this.groupManageEditing = '';
                      this.groupManageEditText = '';
                    })
                }.width('100%').margin({ top: 4 })
              }
            }.width('100%').alignItems(HorizontalAlign.Start)
              .padding({ left: 16, right: 16, top: 13, bottom: 13 })
              .backgroundColor(this.groupManageSelectionMode && this.groupManageSelected.has(group)
                ? this.themeColorSecondaryContainer : this.themeColorSurfacePrimary)
              .borderRadius(12).margin({ bottom: 8 })
              .accessibilityText(this.groupManageSelectionMode
                ? group + (this.groupManageSelected.has(group) ? '，已选择' : '，未选择') : group)
              .onClick(() => {
                if (!this.groupManageSelectionMode) { return; }
                const next = new Set<string>(this.groupManageSelected);
                if (next.has(group)) { next.delete(group); } else { next.add(group); }
                this.groupManageSelected = next;
              })
              .gesture(LongPressGesture().onAction(() => {
                if (!this.groupManageSelectionMode) {
                  this.groupManageSelectionMode = true;
                  this.groupManageSelected = new Set<string>([group]);
                }
              }))
          }, (group: string) => group)
          // 选择态底部：全选/全不选 + 删除所选（上游 GroupManageBottomSheet.kt:209-249）。
          if (this.groupManageSelectionMode) {
            Row({ space: 8 }) {
              Row() {
                AppGlyph({ name: 'selectAll', glyphSize: 18, tint: this.themeColorAccent })
                Text(this.groupManageSelected.size === this.allGroupNames().length && this.allGroupNames().length > 0 ? '全不选' : '全选')
                  .fontSize(LABEL_LARGE).fontColor(this.themeColorAccent).margin({ left: 4 })
              }.layoutWeight(1).height(40).justifyContent(FlexAlign.Center)
                .border({ width: 1, color: this.themeColorOutlineVariant }).borderRadius(20)
                .onClick(() => {
                  const all = this.allGroupNames();
                  this.groupManageSelected = this.groupManageSelected.size === all.length
                    ? new Set<string>() : new Set<string>(all);
                })
              Row() {
                AppGlyph({ name: 'delete', glyphSize: 18, tint: this.groupManageSelected.size > 0 ? this.themeColorOnSecondaryContainer : this.themeColorTextTertiary })
                Text(this.groupManageSelected.size > 0 ? `删除所选 (${this.groupManageSelected.size})` : '删除所选')
                  .fontSize(LABEL_LARGE)
                  .fontColor(this.groupManageSelected.size > 0 ? this.themeColorOnSecondaryContainer : this.themeColorTextTertiary)
                  .margin({ left: 4 })
              }.layoutWeight(1).height(40).justifyContent(FlexAlign.Center)
                .backgroundColor(this.groupManageSelected.size > 0 ? this.themeColorSecondaryContainer : Color.Transparent)
                .borderRadius(20)
                .onClick(() => {
                  if (this.groupManageSelected.size === 0) { return; }
                  this.confirmDeleteGroups();
                })
            }.width('100%').margin({ top: 8 })
          }
        }.width('100%').padding({ bottom: 8 })
      }.constraintSize({ maxHeight: 640 }).scrollBar(BarState.Auto)
    }.width('100%').padding({ left: 16, right: 16 })
  }

  /** 单个分组删除确认（上游 GroupManageBottomSheet.kt:88-100）。 */
  private confirmDeleteGroup(group: string): void {
    this.getUIContext().showAlertDialog({
      title: '删除',
      message: '是否确认删除?',
      autoCancel: true,
      primaryButton: {
        value: '确认',
        action: async () => {
          await this.deleteGroups([group]);
          this.groupManageEditing = '';
        }
      },
      secondaryButton: {
        value: '取消',
        fontColor: this.themeColorTextTertiary,
        action: () => {}
      }
    });
  }

  /** 批量删除确认（上游 GroupManageBottomSheet.kt:102-121）。 */
  private confirmDeleteGroups(): void {
    const names: string[] = [];
    this.groupManageSelected.forEach((name: string) => names.push(name));
    this.getUIContext().showAlertDialog({
      title: '删除',
      message: '是否确认删除?',
      autoCancel: true,
      primaryButton: {
        value: '确认',
        action: async () => {
          await this.deleteGroups(names);
          this.groupManageSelected = new Set<string>();
          this.groupManageSelectionMode = false;
        }
      },
      secondaryButton: {
        value: '取消',
        fontColor: this.themeColorTextTertiary,
        action: () => {}
      }
    });
  }

  /**
   * 域名分组标题：照抄上游 BookSourceScreen.kt:595-604 的
   * titleSmall + colorScheme.primary + padding(horizontal=16.dp, vertical=8.dp) + semantics{heading()}。
   * ArkUI SDK 无 accessibilityHeading 属性（声明文件零命中），故以文本本身作为无障碍标题朗读。
   */
  @Builder
  private DomainHeaderView(domain: string) {
    Text(domain)
      .fontSize(TITLE_SMALL)
      .fontColor(this.themeColorAccent)
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .accessibilityText(domain)
  }

  /**
   * 行无障碍摘要：逐项照抄上游 BookSourceScreen.kt:625-633 的 listOfNotNull 顺序——
   * name / domain(!="#" 才取) / group / enabledState / discoveryState / checkMessage / reorderHint，
   * 去空后用 ", " 连接（Kotlin joinToString() 默认分隔符）。
   * 本地 SourceRow 无 checkMessage 字段，该项跳过（不改数据层，见报告「没做」）。
   */
  private rowAccessibilitySummary(row: SourceRow): string {
    const name = row.source.bookSourceName;
    const domain = row.domain === '#' ? '' : row.domain;
    const group = row.source.bookSourceGroup ?? '';
    const enabledState = row.source.enabled ? '已启用' : '已禁用';
    const discoveryState = row.hasExplore ? (row.exploreEnabled ? '已启用发现' : '已禁用发现') : '';
    const reorderHint = this.canReorder() ? '长按并拖动可排序' : '';
    // 上游 :625-633 的 listOfNotNull 顺序里 checkMessage 在 discoveryState 之后、reorderHint 之前。
    return [name, domain, group, enabledState, discoveryState, row.checkMessage, reorderHint]
      .filter((part: string) => part.length > 0)
      .join(', ');
  }

  /** 条目行：书名、域名、分组、发现态圆点、启停开关；长按进多选。 */
  @Builder
  private SourceRowView(row: SourceRow, index: number) {
    Row() {
      if (this.selectionMode) {
        // 上游 SelectionItemCard.kt:160-183 的选择框是 AppCheckbox，其 M3 分支（AppCheckbox.kt:39-44）
        // 直接用 androidx.compose.material3.Checkbox：20dp 方形容器、圆角 2dp、未选 2dp onSurfaceVariant 边框、
        // 选中填 primary 且勾为 onPrimary。本地此前自绘成圆形（圆角 10、1.5dp 边框、勾用 textPrimary），形状与色位都不对。
        Stack({ alignContent: Alignment.Center }) {
          Row().width(20).height(20).borderRadius(2)
            .border({
              width: this.selectedUrls.has(row.source.bookSourceUrl) ? 0 : 2,
              color: this.themeColorTextSecondary
            })
            .backgroundColor(this.selectedUrls.has(row.source.bookSourceUrl) ? this.themeColorAccent : Color.Transparent)
          if (this.selectedUrls.has(row.source.bookSourceUrl)) {
            AppGlyph({ name: 'profileCheck', glyphSize: 14, tint: this.themeColorOnPrimary })
          }
        }.width(24).margin({ right: 10 })
          .accessibilityChecked(this.selectedUrls.has(row.source.bookSourceUrl))
          .accessibilityText('选择 ' + (row.source.bookSourceName.length > 0 ? row.source.bookSourceName : row.source.bookSourceUrl))
          .onClick(() => {
            const next = new Set<string>(this.selectedUrls);
            if (next.has(row.source.bookSourceUrl)) { next.delete(row.source.bookSourceUrl); }
            else { next.add(row.source.bookSourceUrl); }
            this.selectedUrls = next;
          })
      }
      Column() {
        Row() {
          // 上游 SelectionItemCard.kt:191/226 行标题用 LegadoTheme.typography.titleSmall；
          // Typography.kt:30 里 titleSmall = miuixStyles.subtitle「14.sp, Bold」，即字号 14 且加粗。
          // 本地此前用 TITLE_MEDIUM(16) 且无字重，两处都不对。
          Text(row.source.bookSourceName.length > 0 ? row.source.bookSourceName : row.source.bookSourceUrl)
            .fontSize(TITLE_SMALL).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        }.width('100%')
        // 上游 BookSourceScreen.kt:653-684 supportingContent：Row(spacedBy6) 首位是 DiscoveryIndicator，
        // 其后 Column 竖排 group 与 checkMessage；渲染条件是 group/checkMessage/hasExploreUrl 任一非空。
        // 上游行内**不显示域名**（域名只用于 groupByDomain 的分组头），故本地也不画。
        // 圆点颜色直接取上游 colors_material_design.xml 的 md_green_500(#4CAF50) / md_red_400(#EF5350)
        // （:826-838 绿=已启用发现 / 红=已禁用发现），本地同名资源见 resources/*/element/color.json。
        if ((row.source.bookSourceGroup ?? '').length > 0 || row.hasExplore || row.checkMessage.length > 0) {
          Row({ space: 6 }) {
            if (row.hasExplore) {
              Row().width(8).height(8).borderRadius(4)
                .backgroundColor(row.exploreEnabled ? $r('app.color.md_green_500') : $r('app.color.md_red_400'))
                .accessibilityText(row.exploreEnabled ? '已启用发现' : '已禁用发现')
            }
            Column() {
              if ((row.source.bookSourceGroup ?? '').length > 0) {
                Text(row.source.bookSourceGroup as string).fontSize(BODY_SMALL)
                  .fontColor(this.themeColorTextTertiary).maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              // 上游 :673-678 checkMessage 与 group 并列、同为 bodySmall：校验结果文案常驻行上。
              if (row.checkMessage.length > 0) {
                Text(row.checkMessage).fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary)
                  .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
              }
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }.width('100%').alignItems(VerticalAlign.Center).margin({ top: 5 })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      // 上游 SelectionItemCardContent 的右侧 Row 是 `spacedBy(8) + padding(end = 8.dp)`
      // （SelectionItemCard.kt:240-247），本地此前是左侧逐个 margin left 4，累计间距不等。
      Row({ space: 8 }) {
        UiSwitchControl({ checked: row.source.enabled, interactive: false, scaleValue: 0.8 })
          .onClick(() => this.toggleSource(row.source, !row.source.enabled))
        // 上游 BookSourceScreen.kt:700-704 行尾编辑快捷按钮，点击复用已有 edit 分发。
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'edit', glyphSize: 18, tint: this.themeColorTextTertiary })
        }.width(40).height(40)
          .accessibilityText('编辑')
          .onClick(() => this.onSourceRowAction('edit', row))
        AppGlyph({ name: 'more', glyphSize: 18, tint: this.themeColorTextTertiary })
          .onClick(() => { this.menuRowUrl = row.source.bookSourceUrl; })
          .accessibilityText('菜单')
          .bindPopup(this.menuRowUrl === row.source.bookSourceUrl, {
            builder: () => { this.SourceRowMenu(row); },
            placement: Placement.BottomRight,
            popupColor: this.themePureBlack ? '#17181E' : this.themeColorSurfaceElevated,
            enableArrow: false,
            autoCancel: true,
            width: PROFILE_MENU_WIDTH,
            onStateChange: (event: PopupStateChangeParam) => {
              if (!event.isVisible) { this.menuRowUrl = ''; }
            }
          })
      }.padding({ right: 8 })
      // 上游 M3 ListItemDefaults.contentPadding = 水平 16 / 垂直 12（SelectionItemCard.kt:208-232 的
      // ListItem 用它，GlassCard 本身无内边距），本地此前是 16/12/11/11，垂直少 1。
    }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
      // 上游 SelectionItemCard.kt:82-91：未选=surfaceContainerLow(M3)/surfaceContainer(Miuix)，
      // 选中=secondaryContainer；本地此前选中态与普通态同色，看不出选中。
      .backgroundColor(this.selectedUrls.has(row.source.bookSourceUrl)
        ? this.themeColorSecondaryContainer
        : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated))
      .borderRadius(12)
      .accessibilityText(this.rowAccessibilitySummary(row))
      .gesture(LongPressGesture().onAction(() => {
        if (!this.selectionMode) { this.selectionMode = true; }
        const next = new Set<string>(this.selectedUrls);
        next.add(row.source.bookSourceUrl);
        this.selectedUrls = next;
      }))
  }

  /**
   * 条目菜单：照上游 BookSourceScreen.kt:844-899 的 BookSourceItemMenu 六项顺序。
   * 「编辑」上游不在菜单里（行尾 SmallPlainButton，批 1 已做），此处移除；
   * 删除排第 6（原先被「编辑」挤到第 7）。删除项上游未传 error 色，保持普通项。
   * 壳从自绘 Column 换成 UiMenuPanel（对齐 M3 RoundDropdownMenu 的圆角浮层）。
   */
  @Builder
  private SourceRowMenu(row: SourceRow) {
    UiMenuPanel({
      items: this.sourceRowMenuItems(row),
      panelWidth: PROFILE_MENU_WIDTH,
      onSelect: (key: string) => {
        this.menuRowUrl = '';
        this.onSourceRowAction(key, row);
      }
    })
  }

  /** 行菜单项，顺序与条件严格对齐上游 BookSourceScreen.kt:865-896。 */
  private sourceRowMenuItems(row: SourceRow): UiMenuItem[] {
    const items: UiMenuItem[] = [];
    // 上游 :865-872：仅 canMoveToEdge（本地等价 canReorder，多选/分组/非手动时隐藏）。
    if (this.canReorder()) {
      items.push({ key: 'top', title: '置顶' });
      items.push({ key: 'bottom', title: '置底' });
    }
    // 上游 :873-877：仅 hasLoginUrl。
    if (row.hasLogin) {
      items.push({ key: 'login', title: '登录' });
    }
    // 上游 :878-886：搜索、调试、删除常显。
    items.push({ key: 'search', title: '搜索' });
    items.push({ key: 'debug', title: '调试' });
    items.push({ key: 'delete', title: '删除' });
    // 上游 :887-896：仅 hasExploreUrl，文案随 enabledExplore 切换。
    if (row.hasExplore) {
      items.push({ key: 'explore', title: row.exploreEnabled ? '禁用发现' : '启用发现' });
    }
    return items;
  }

  /**
   * 多选批量面板：11 项一项不删（上游 selectionSecondaryActions，BookSourceScreen.kt:455-523）。
   * 上游是从 SelectionBottomBar 的 MoreVert 弹出 RoundDropdownMenu，菜单里**只有这 11 项**，
   * 没有「已选 N 项」标题（计数显示在顶栏 list_selected_count），故本地也去掉该标题。
   */
  @Builder
  private BatchPanel() {
    UiMenuPanel({
      items: this.batchMenuItems(),
      panelWidth: PROFILE_MENU_WIDTH,
      onSelect: (key: string) => {
        this.batchPanelVisible = false;
        this.onBatchAction(key);
      }
    }).width('100%')
  }

  /** 批量动作 11 项，顺序照上游 BookSourceScreen.kt:455-523 的 selectionSecondaryActions。 */
  private batchMenuItems(): UiMenuItem[] {
    return [
      { key: 'enable', title: '启用所选' },
      { key: 'disable', title: '禁用所选' },
      { key: 'explore_on', title: '启用发现' },
      { key: 'explore_off', title: '禁用发现' },
      { key: 'group_add', title: '添加分组' },
      { key: 'group_remove', title: '移除分组' },
      { key: 'top', title: '置顶所选' },
      { key: 'bottom', title: '置底所选' },
      { key: 'interval', title: '选中所选区间' },
      { key: 'check', title: '校验书源' },
      { key: 'export', title: '导出' }
    ];
  }

  /**
   * 自定义源分组对话框：对齐上游 BookSourceImportGroupDialog（BookSourceScreen.kt:743-778）。
   * showAlertDialog 带不了输入框（见 ThemeManagePage.ets:105 的既有结论），
   * 故用 SDK 的 openCustomDialog + builder（@ohos.promptAction.d.ts:1274-1290，可内嵌输入框）。
   * 标题/输入框标签/开关/按钮文案照抄上游 strings.xml：
   * diy_source_group=自定义源分组、group_name=分组名称、add_group=添加分组、ok=确认、cancel=取消。
   */
  @Builder
  private PromptDialogContent() {
    // 对齐上游 BookSourceImportGroupDialog（BookSourceScreen.kt:743-778）：
    // AppAlertDialog(title=diy_source_group「自定义源分组」, content=AppTextField(group_name「分组名称」)
    //   + SwitchSettingItem(add_group「添加分组」), confirmText=ok「确定」, dismissText=cancel「取消」)。
    // AppAlertDialog 的 M3 分支（AppAlertDialog.kt:100-151）= Material3 AlertDialog：
    //   containerColor=surfaceContainer、titleContentColor=onSurface、textContentColor=onSurfaceVariant、
    //   确认按钮 PrimaryButton(filled)、取消按钮 SecondaryButton(outlined)，文字 labelLarge。
    // ArkUI 的 showAlertDialog 带不了输入框（ThemeManagePage.ets:105 既有结论），
    // 所以仍用 openCustomDialog 承载，但把容器/标题/按钮重排成 M3 Dialog 形态。
    Column() {
      Text('自定义源分组')
        .fontSize(HEADLINE_SMALL).fontColor(this.themeColorTextPrimary)
        .width('100%')
      // M3 AlertDialog 的 content 区：verticalScroll + 与标题的间距。
      Column({ space: SPACE_8 }) {
        // AppTextField(label=group_name, singleLine)：M3 OutlinedTextField 形态（描边 + 圆角 4）。
        Column() {
          TextInput({ placeholder: '分组名称', text: this.promptText })
            .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary)
            .backgroundColor(Color.Transparent)
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .onChange((value: string) => this.promptText = value)
        }
        .width('100%')
        .border({ width: 1, color: this.themeColorOutlineVariant })
        .borderRadius(4)
        // SwitchSettingItem(add_group)：标题左、开关右。
        Row() {
          Text('添加分组').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).layoutWeight(1)
          UiSwitchControl({
            checked: this.promptAddGroup,
            scaleValue: 0.8,
            onChange: (checked: boolean) => { this.promptAddGroup = checked; }
          })
        }.width('100%').height(48)
      }
      .width('100%')
      .margin({ top: 16 })
      // 底部按钮行：M3 AlertDialog 是 dismissButton(左) + confirmButton(右)，各占一半、间距 12。
      Row({ space: 12 }) {
        // SecondaryButton = OutlinedButton（描边 + primary 文字）。
        Button('取消')
          .type(ButtonType.Normal)
          .layoutWeight(1)
          .height(40)
          .fontSize(LABEL_LARGE)
          .fontColor(this.themeColorAccent)
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: this.themeColorOutlineVariant })
          .borderRadius(20)
          .onClick(() => { this.closePromptDialog(); })
        // PrimaryButton = filled Button（primary 底 + onPrimary 文字）。
        Button('确定')
          .type(ButtonType.Normal)
          .layoutWeight(1)
          .height(40)
          .fontSize(LABEL_LARGE)
          .fontColor(this.themeColorOnPrimary)
          .backgroundColor(this.themeColorAccent)
          .borderRadius(20)
          .onClick(() => {
            const value = this.promptText.trim();
            if (value.length > 0) {
              this.promptAction(value, this.promptAddGroup);
            }
            this.closePromptDialog();
            this.selectionMode = false;
          })
      }.width('100%').margin({ top: 24 })
    }
    // M3 AlertDialog：minWidth 280vp、padding 24、圆角 28、底色 surfaceContainer。
    .width(312)
    .padding(24)
    .backgroundColor(this.themeColorSurfaceTertiary)
    .borderRadius(28)
  }

  /** 打开自定义源分组对话框（系统自定义对话框，能承载输入框）。 */
  private openPromptDialog(): void {
    this.promptDialogBuilder = (): void => { this.PromptDialogContent(); };
    this.getUIContext().getPromptAction().openCustomDialog({
      builder: this.promptDialogBuilder,
      autoCancel: false,
      alignment: DialogAlignment.Center,
      onWillDismiss: () => { this.promptDialogId = -1; }
    }).then((dialogId: number) => {
      this.promptDialogId = dialogId;
    }).catch((error: Error) => {
      console.warn('打开自定义源分组对话框失败:', error);
    });
  }

  /** 关闭自定义源分组对话框；重复关闭是安全调用。 */
  private closePromptDialog(): void {
    if (this.promptDialogId >= 0) {
      this.getUIContext().getPromptAction().closeCustomDialog(this.promptDialogId);
      this.promptDialogId = -1;
    }
  }

  /** P6 导入对话框：online 收 URL，options 三个保留开关。 */
  @Builder
  private ImportDialog() {
    Column() {
      if (this.importStage === 'online') {
        Text('在线导入').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        TextInput({ placeholder: '输入书源订阅地址（http/https）', text: this.importOnlineUrl })
          .fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary)
          .onChange((value: string) => this.importOnlineUrl = value)
          .margin({ top: 14 })
        Text('使用书源引擎的 HttpClient 拉取，支持重定向与 Cookie。')
          .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 8 })
        Row() {
          Text('取消').fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary).layoutWeight(1)
            .onClick(() => this.importVisible = false)
          Text('拉取').fontSize(LABEL_LARGE).fontColor(this.themeColorAccent).layoutWeight(1)
            .onClick(() => this.importFromOnlineUrl())
        }.width('100%').margin({ top: 18 })
      } else {
        Text('导入选项').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        Text(`解析到 ${this.pendingImportRules.length} 条书源，选择保留项后导入。`)
          .fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary).margin({ top: 10 })
        Column() {
          this.ImportToggleRow('保留原名', this.keepName, (v: boolean) => { this.keepName = v; })
          this.ImportToggleRow('保留分组', this.keepGroup, (v: boolean) => { this.keepGroup = v; })
          this.ImportToggleRow('保留启用状态', this.keepEnabled, (v: boolean) => { this.keepEnabled = v; })
        }.width('100%').margin({ top: 12 })
        Row() {
          Text('取消').fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary).layoutWeight(1)
            .onClick(() => this.importVisible = false)
          Text('导入').fontSize(LABEL_LARGE).fontColor(this.themeColorAccent).layoutWeight(1)
            .onClick(() => this.commitImport())
        }.width('100%').margin({ top: 18 })
      }
    }.padding(20).backgroundColor(this.themePureBlack ? '#17181E' : this.themeColorSurfaceElevated)
      .borderRadius(16)
  }

  @Builder
  private ImportToggleRow(label: string, checked: boolean, onChange: (value: boolean) => void) {
    Row() {
      Text(label).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).layoutWeight(1)
      UiSwitchControl({ checked: checked, interactive: false, scaleValue: 0.8 })
        .onClick(() => onChange(!checked))
    }.width('100%').padding({ top: 10, bottom: 10 })
  }

  /**
   * 分组筛选：照上游 BookSourceScreen.kt:916-985 的 BookSourceGroupFilterSheet。
   * 上游形态 = AppModalBottomSheet(title=menu_action_group「分组」) 内
   * SearchBar(placeholder=search_placeholder「搜索…」) + LazyVerticalGrid(2 列, 水平间距 8, 垂直间距 6)，
   * 两个分区标题「默认分组」(:966 book_source_default_groups) 与「其他分组」(:976 book_source_other_groups)，
   * 每项 GroupFilterItem(:1001-1035) = 高 min 48 / 圆角 12 / 选中 primaryContainer + onPrimaryContainer /
   * 未选 onSheetContent(=surface) + onSurface / 文字 labelMediumEmphasized 居中。
   * 本地原先是一列自绘列表（选中底色 '#41485D'、右侧打勾、带「清除」按钮），与上游不同，此处重做。
   * 上游没有「清除」按钮（点「全部」即清除筛选），故移除。
   */
  @Builder
  private GroupFilterSheet() {
    // 上游 BookSourceGroupFilterSheet(:916-985) 走 AppModalBottomSheet，其 M3 分支
    // （AppModalBottomSheet.kt:155-205）给内容统一加 padding start/end/bottom 16，
    // 标题是 header 里的 titleMediumEmphasized(16sp/Medium)、居中、左右各留 56 给 action。
    // 本地原先标题用 HEADLINE_SMALL 左对齐且无左右内边距，故「默认分组」会贴到屏幕边。
    Column() {
      Text('分组').fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium)
        .fontColor(this.themeColorTextPrimary).width('100%').textAlign(TextAlign.Center)
        .padding({ left: 56, right: 56, top: 20, bottom: 16 })
      // 上游 SearchBar.kt:132-155：圆角 32 的 Surface + 前置搜索图标 + placeholder「搜索…」。
      Row() {
        AppGlyph({ name: 'search', glyphSize: 18, tint: this.themeColorTextTertiary }).margin({ right: 9 })
        TextInput({ placeholder: '搜索…', text: this.groupFilterQuery })
          .fontSize(LABEL_LARGE).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
          .backgroundColor(Color.Transparent).layoutWeight(1)
          .onChange((value: string) => this.groupFilterQuery = value)
      }.margin({ bottom: 8 }).padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .backgroundColor(this.themeColorSurfaceElevated).borderRadius(22)
      Scroll() {
        Column() {
          if (this.defaultFilterOptions().length > 0) {
            // 上游 GroupFilterSectionTitle(:988-998)：labelMedium / onSurfaceVariant / padding 水平4 垂直6。
            Text('默认分组').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextSecondary)
              .width('100%').padding({ left: 4, right: 4, top: 6, bottom: 6 })
              .accessibilityText('默认分组')
            Grid() {
              ForEach(this.defaultFilterOptions(), (option: string) => {
                GridItem() { this.GroupFilterItemView(option) }
              }, (option: string) => option)
            }
            .columnsTemplate('1fr 1fr').columnsGap(8).rowsGap(6).width('100%')
          }
          if (this.otherFilterOptions().length > 0) {
            Text('其他分组').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextSecondary)
              .width('100%').padding({ left: 4, right: 4, top: 6, bottom: 6 })
              .accessibilityText('其他分组')
            Grid() {
              ForEach(this.otherFilterOptions(), (option: string) => {
                GridItem() { this.GroupFilterItemView(option) }
              }, (option: string) => option)
            }
            .columnsTemplate('1fr 1fr').columnsGap(8).rowsGap(6).width('100%')
          }
        }.width('100%').padding({ top: 4, bottom: 22 })
      }.edgeEffect(EdgeEffect.None).scrollBar(BarState.Off)
      // 上游 heightIn(max = 容器高 * 0.8)：分组很多时列表自己滚，最多占容器 80%。
      .constraintSize({ maxHeight: 640 })
    }.width('100%').padding({ left: 16, right: 16 })
      .backgroundColor('#17181E')
  }

  /** 单个筛选项：上游 GroupFilterItem(:1001-1035) 的等价物。 */
  @Builder
  private GroupFilterItemView(option: string) {
    Text(option)
      .fontSize(LABEL_MEDIUM).fontWeight(FontWeight.Medium)
      .fontColor(this.selectedGroup === option ? this.themeColorOnPrimaryContainer : this.themeColorTextPrimary)
      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).textAlign(TextAlign.Center)
      .width('100%').constraintSize({ minHeight: 48 })
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor(this.selectedGroup === option ? this.themeColorPrimaryContainer : this.themeColorSurfacePrimary)
      .borderRadius(12)
      .accessibilityText(this.selectedGroup === option ? option + '，已选择' : option)
      .onClick(() => {
        this.selectedGroup = option === '全部' ? '' : option;
        this.showGroupFilter = false;
      })
  }

  /**
   * 从全量书源聚合出分组清单，对齐上游 BookSourceDao.kt:386-406 的 dealGroups：
   * 每条的 bookSourceGroup 按 AppPattern.splitGroupRegex（`[,;，；]`）拆开、去空、去重，
   * 最后按中文排序。上游是 DAO 的 flow 里聚合，本地数据层没有分组表，故在页面里算。
   */
  private allGroupNames(): string[] {
    const set = new Set<string>();
    this.allSources.forEach((source: BookSource) => {
      (source.bookSourceGroup ?? '')
        .split(/[,;，；]/)
        .map((part: string) => part.trim())
        .filter((part: string) => part.length > 0)
        .forEach((part: string) => set.add(part));
    });
    const list: string[] = [];
    set.forEach((name: string) => list.push(name));
    return list.sort((a: string, b: string) => a.localeCompare(b, 'zh-Hans-CN'));
  }

  /** 上游 :923-931 defaultOptions 的七项固定筛选。 */
  private defaultFilterOptions(): string[] {
    const all: string[] = ['全部', '启用', '禁用', '需要登录', '未分组', '发现已启用', '发现未启用'];
    const query = this.groupFilterQuery.trim().toLowerCase();
    if (query.length === 0) { return all; }
    return all.filter((option: string) => option.toLowerCase().includes(query));
  }

  /** 上游 :932-934 otherOptions = 书源自带的各分组。 */
  private otherFilterOptions(): string[] {
    const groups = this.allGroupNames();
    const query = this.groupFilterQuery.trim().toLowerCase();
    if (query.length === 0) { return groups; }
    return groups.filter((group: string) => group.toLowerCase().includes(query));
  }

  build() {
    Column() {
      Row() {
        // 上游 DynamicTopAppBar.kt:84-93：选择态导航图标换成 Close（contentDescription=cancel_select
        // 「取消选择」），点击清空选择；非选择态是返回。
        Stack({ alignContent: Alignment.Center }) {
          Row().width(36).height(36).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(18)
          if (this.selectionMode) {
            AppGlyph({ name: 'profileClose', glyphSize: 20, tint: this.themeColorTextSecondary })
          } else {
            Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.themeColorTextSecondary)
          }
        }.width(40).height(40)
          .accessibilityText(this.selectionMode ? '取消选择' : '返回')
          .onClick(() => { if (this.selectionMode) { this.exitSelectionMode(); } else { this.onBack(); } })
        Column() {
          // 上游 :73-82 选择态标题换成 list_selected_count「已选择 %1$d/%2$d」。
          Text(this.selectionMode
            ? `已选择 ${this.selectedUrls.size}/${this.allSources.length}`
            : '书源')
            .fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
          if (!this.selectionMode) {
            Text(this.selectedGroup.length === 0 ? '全部' : this.selectedGroup)
              .fontSize(PROFILE_PAGE_SUBTITLE_SIZE).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
          }
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        // 上游 DynamicTopAppBar.kt:97 选择态默认收起整个 actions 区（keepActionsInSelection=false）。
        if (!this.selectionMode) {
          // 顶栏按钮顺序照上游 DynamicTopAppBar.kt:95-123：搜索 → 分组(Filter) → 更多。
          Stack({ alignContent: Alignment.Center }) {
            Row().width(36).height(36).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(18)
            AppGlyph({ name: 'search', glyphSize: 19, tint: this.themeColorTextSecondary })
          }.width(40).height(40)
            .accessibilityText('搜索')
            .onClick(() => { this.showSearch = !this.showSearch; if (!this.showSearch) { this.searchQuery = ''; } })
          Stack({ alignContent: Alignment.Center }) {
            Row().width(36).height(36).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(18)
            AppGlyph({ name: 'profileFilterAlt', glyphSize: 19, tint: this.themeColorTextSecondary })
          }.width(40).height(40)
            .accessibilityText('分组')
            .onClick(() => { this.groupFilterQuery = ''; this.showGroupFilter = true; })
          Stack({ alignContent: Alignment.Center }) {
            Row().width(36).height(36).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(18)
            AppGlyph({ name: 'more', glyphSize: 18, tint: this.themeColorTextSecondary })
          }.width(40).height(40)
            .accessibilityText('更多菜单')
            .onClick(() => { this.moreMenuVisible = !this.moreMenuVisible; })
.bindPopup(this.moreMenuVisible, {
  builder: this.MoreMenu,
  placement: Placement.BottomRight,
  popupColor: '#00000000',
  enableArrow: false,
  autoCancel: true,
  width: PROFILE_MENU_WIDTH,
  onStateChange: (event: PopupStateChangeParam) => { this.moreMenuVisible = event.isVisible; }
})
        }
      }.width('100%').padding({ left: 12, right: 12, top: 11 + this.appTopInset, bottom: 9 })

      // 搜索行照上游 SearchBar.kt:132-155 的 M3 分支：
      // Surface(fillMaxWidth, padding bottom 4, RoundedCornerShape(32.dp), color = surfaceContainerLow)
      // 内 AppDenseTextField(backgroundColor=Transparent, leadingIcon 左右各 12, contentPadding 上4下4左右12, heightIn min 48)。
      // 上游 placeholder 取 R.string.search_book_source「搜索书源」。
      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 20, tint: this.themeColorTextSecondary }).padding({ left: 12, right: 12 })
          TextInput({ placeholder: '搜索书源', text: this.searchQuery })
            .fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
            .backgroundColor(Color.Transparent).layoutWeight(1).padding({ right: 12 })
            .onChange((value: string) => this.searchQuery = value)
        }.width('100%').constraintSize({ minHeight: 48 })
          .margin({ left: 16, right: 16, bottom: 4 })
          .backgroundColor(this.themePureBlack ? '#1A1B1F' : this.themeColorSurfaceSecondary).borderRadius(32)
      }

      // 上游 ListScaffold.kt 无空态分支（列表为空就是空白）；本地原有的 ModuleEmpty 空态属自加，已移除。
      Stack({ alignContent: Alignment.BottomEnd }) {
        List({ space: 8, scroller: this.sourceScroller }) {
          LazyForEach(this.sourceDataSource, (item: BookSourceListItem, index: number) => {
            if (isDomainHeader(item)) {
              ListItem() {
                this.DomainHeaderView((item as DomainHeaderItem).domain)
              }
            } else {
              ListItem() {
                this.SourceRowView((item as SourceDataItem).row, index)
              }
              .swipeAction({ end: this.SourceSwipeEnd((item as SourceDataItem).row) })
            }
          }, (item: BookSourceListItem) => isDomainHeader(item)
            ? ('domain:' + (item as DomainHeaderItem).domain)
            // key 里必须带上会影响行渲染的字段：LazyForEach 只在 key 变化时重建条目，
            // 只用 URL 时「启用/禁用发现」「分组」「校验文案」改了都不会重绘（实测点了没反应）。
            : ProfileSubPagesSourceKey(item as SourceDataItem))
          // onMove 挂在 ForEach/LazyForEach 上，仅手动排序非分组时可拖。
          .onMove(this.canReorder() ? (from: number, to: number) => this.onSourceMove(from, to) : undefined)
        }.layoutWeight(1).width('100%')
          // 上游 BookSourceScreen.kt:582-620 contentPadding bottom = 底部内边距 + 120.dp，
          // 给 FAB / 浮动工具栏留出空间，最后一行不会被盖住。
          .contentEndOffset(120)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).scrollBar(BarState.Off)

        // 上游 ListScaffold.kt:70-148：FAB 用 animateFloatingActionButton(visible = selectedIds.isEmpty())，
        // 选择态下 FAB 整个隐藏；底部改为 SelectionBottomBar（见下方浮动工具栏）。
        if (!this.selectionMode) {
          Row() {
            Image($r('app.media.app_add')).width(18).height(18).fillColor(this.themeColorTextPrimary)
            Text('添加书源').fontSize(LABEL_LARGE).fontColor(this.themeColorTextPrimary).margin({ left: 7 })
          }.justifyContent(FlexAlign.Center).padding({ left: 20, right: 20, top: 13, bottom: 13 })
            .backgroundColor(this.themeColorAccent).borderRadius(28)
            .margin({ right: 20, bottom: 18 + this.appBottomInset })
            .onClick(() => this.onOpenSourceEdit(''))
        }

        // 上游 SelectionBottomBar.kt:170-247 M3 分支 = HorizontalFloatingToolbar：
        // leadingContent 全选(SelectAll) + 反选(Refresh)，trailingContent MoreVert 弹 secondaryActions，
        // content 是 64vp 宽的 FilledIconButton（containerColor=secondaryContainer）承载 primaryAction。
        // 这里按同一形态自绘浮动工具栏；定位对齐 ListScaffold.kt 的 align(BottomCenter) + padding(bottom 16)。
        if (this.selectionMode) {
          Row({ space: 4 }) {
            Stack({ alignContent: Alignment.Center }) {
              AppGlyph({ name: 'selectAll', glyphSize: 20, tint: this.themeColorTextPrimary })
            }.width(48).height(48).borderRadius(24)
              .accessibilityText('全选')
              .onClick(() => this.selectAllSources())
            Stack({ alignContent: Alignment.Center }) {
              AppGlyph({ name: 'profileRefresh', glyphSize: 20, tint: this.themeColorTextPrimary })
            }.width(48).height(48).borderRadius(24)
              .accessibilityText('反选')
              .onClick(() => this.invertSelectionSources())
            // primaryAction：上游 RuleListScaffold.kt:44-52 传 ActionItem(delete「删除」, Icons.Default.Delete)。
            Row() {
              AppGlyph({ name: 'delete', glyphSize: 20, tint: this.themeColorOnSecondaryContainer })
            }.width(64).height(48).justifyContent(FlexAlign.Center)
              .backgroundColor(this.themeColorSecondaryContainer).borderRadius(24)
              .accessibilityText('删除')
              .onClick(() => this.confirmDeleteSelection())
            // secondaryActions：MoreVert 打开 11 项批量菜单（上游 batchMenuItems 已对齐）。
            Stack({ alignContent: Alignment.Center }) {
              AppGlyph({ name: 'more', glyphSize: 20, tint: this.themeColorTextPrimary })
            }.width(48).height(48).borderRadius(24)
              .accessibilityText('更多菜单')
              .onClick(() => { this.batchPanelVisible = true; })
              .bindPopup(this.batchPanelVisible, {
                builder: this.BatchPanel,
                placement: Placement.Top,
                popupColor: '#00000000',
                enableArrow: false,
                autoCancel: true,
                width: PROFILE_MENU_WIDTH,
                onStateChange: (event: PopupStateChangeParam) => { this.batchPanelVisible = event.isVisible; }
              })
          }.padding({ left: 8, right: 8, top: 8, bottom: 8 })
            .backgroundColor(this.themeColorSurfaceElevated).borderRadius(28)
            .shadow({ radius: 12, color: '#33000000', offsetY: 2 })
            // 上游 SelectionBottomBar 的 safeModifier 含 windowInsetsPadding(navigationBars)，
            // 底栏要抬到系统导航区之上；上游 ListScaffold 的 padding(bottom = 16.dp + ScreenOffset) 也一并照做。
            .margin({ bottom: 16 + this.appBottomInset })
        }
      }.layoutWeight(1)
      // 校验配置弹层：自带 bindSheet；确认后把草稿写回 checkOptions，并回到「运行」弹层
      // （上游 :379-382 onConfirm → UpdateCheckOptions + checkSheet = CheckSheet.Run）。
      SourceCheckSheet({
        visible: $checkSheetVisible,
        options: this.checkOptions,
        onConfirm: (options: SourceCheckOptions) => {
          this.checkOptions = options;
          this.checkRunSheetVisible = true;
        }
      })
      // 校验「运行」弹层：上游 CheckBookSourceSheet（关键字 + 设置/确认）。
      SourceCheckRunSheet({
        visible: $checkRunSheetVisible,
        sourceCount: this.checkTargetUrls.length,
        onOpenSettings: () => {
          this.checkRunSheetVisible = false;
          this.checkSheetVisible = true;
        },
        onConfirm: (keyword: string) => {
          this.checkRunSheetVisible = false;
          this.runCheck(keyword);
        }
      })
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      // 一个组件只能挂一个 bindSheet（本项目已踩坑），分组筛选与导入合并按状态切换内容。
      // 批量菜单走 SelectionBottomBar 的 MoreVert bindPopup（对齐上游 RoundDropdownMenu），不占这个 bindSheet；
      // 自定义源分组对话框走系统 openCustomDialog，也不占这个 bindSheet。
      .bindSheet(this.showGroupFilter || this.importVisible || this.groupManageVisible,
        this.SourceSheetContent(), {
          // 上游 AppModalBottomSheet.kt:155-168 是 heightIn(max = 容器高 * 0.8) + animateContentSize：
          // 内容少时 sheet 只占内容高度，最多 80%。本地原先分组筛选固定 SheetSize.LARGE（全屏），
          // 七项筛选下面会留一大片空白，与上游不符；改为 FIT_CONTENT，由内容自己撑，Scroll 再封顶 80%。
          height: SheetSize.FIT_CONTENT,
          dragBar: true,
          // 上游 BookSourceGroupFilterSheet 与导入弹层都走 AppModalBottomSheet，
          // 其 M3 分支（AppModalBottomSheet.kt:145-153）只有 DragHandle，没有右上关闭按钮。
          showClose: false,
          backgroundColor: this.themePureBlack ? '#17181E' : this.themeColorSurfaceElevated,
          onDisappear: () => {
            this.showGroupFilter = false;
            this.batchPanelVisible = false;
            this.importVisible = false;
            this.groupManageVisible = false;
          }
        })
  }
}

@Component
export struct ReplaceRulesPage {
  @State replaceRuleMenuVisible: boolean = false;
  @State ruleRowMenuVisible: boolean = false;
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('appTopInset') appTopInset: number = 0;
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onOpenEditor: () => void = () => {};
  onToggleRule: (id: number, enabled: boolean) => void = (_id: number, _enabled: boolean) => {};
  onRemoveRule: (id: number) => void = (_id: number) => {};
  /** 点击规则条目进入编辑。 */
  onEditRule: (id: number) => void = (_id: number) => {};
  /** 长按菜单里的置顶/置底。 */
  onMoveRule: (id: number, toTop: boolean) => void = (_id: number, _toTop: boolean) => {};
  /** 分组管理：重命名 / 删除。返回 Promise 便于面板等落盘后刷新。
   *  上游分组面板只有改、删两个入口（GroupManageBottomSheet 无 onAddGroup），故此处不提供新增。 */
  onRenameGroup: (oldName: string, newName: string) => Promise<void> = async (_o: string, _n: string) => {};
  onRemoveGroup: (name: string) => Promise<void> = async (_name: string) => {};
  /** 排序模式持久化。 */
  onSortModeChange: (mode: string) => void = (_mode: string) => {};
  /** 从文件或剪贴板文本导入；返回是否成功，供面板关闭。 */
  onImportRules: (text: string, source: string) => void = (_text: string, _source: string) => {};
  /** 导出当前筛选结果；空数组表示没有可导出内容。 */
  onExportRules: (rules: ReplaceRule[]) => void = (_rules: ReplaceRule[]) => {};
  /** 选择模式下的批量启用/停用。 */
  onSetEnabledBatch: (ids: number[], enabled: boolean) => void = (_ids: number[], _enabled: boolean) => {};
  /** 选择模式下的批量删除。 */
  onRemoveBatch: (ids: number[]) => void = (_ids: number[]) => {};
  /** 选择模式下的批量置顶/置底。 */
  onMoveBatch: (ids: number[], toTop: boolean) => void = (_ids: number[], _toTop: boolean) => {};
  /** 拖拽排序：把 fromId 这条规则挪到 toId 的位置。 */
  onReorderRule: (fromId: number, toId: number) => void = (_f: number, _t: number) => {};
  @Prop rules: ReplaceRule[] = [];
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @Prop groups: string[] = [];
  /** 由外部传入的持久化排序模式，切换时同步回写。 */
  @Prop sortMode: string = 'asc';
  @State selectedGroup: string = '';
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State ruleActionSheet: string = '';
  /** 手动输入面板里的规则文本。 */
  @State manualInput: string = '';
  /** 选择模式：进入后点击条目变为切换选中，底部出现批量操作条。 */
  @State selectionMode: boolean = false;
  @State selectedRuleIds: number[] = [];
  /**
   * 待确认删除的规则 id。批量删除与长按菜单的单条删除共用同一个确认面板，
   * 只在这里记下待删对象，确认后才真正回调删除。
   */
  @State pendingDeleteIds: number[] = [];

  /** 切换单条规则的选中状态。 */
  private toggleSelectedRule(id: number): void {
    this.selectedRuleIds = this.selectedRuleIds.includes(id)
      ? this.selectedRuleIds.filter((selectedId: number) => selectedId !== id)
      : [...this.selectedRuleIds, id];
  }

  /** 全选当前筛选结果，而不是全部规则：筛选态下「全选」应符合用户看到的列表。 */
  private selectAllVisible(): void {
    this.selectedRuleIds = this.filteredReplaceRules().map((rule: ReplaceRule) => rule.id);
  }

  /**
   * 反选：在当前筛选结果内取差集，与上游 invertSelection() 一致。
   * 用筛选结果而不是全部规则，保证「反选」与用户眼前的列表范围一致。
   */
  private invertSelection(): void {
    this.selectedRuleIds = this.filteredReplaceRules()
      .map((rule: ReplaceRule) => rule.id)
      .filter((id: number) => !this.selectedRuleIds.includes(id));
  }

  /** 退出选择模式并清空选中，避免下次进入时残留上一次的选择。 */
  private exitSelection(): void {
    this.selectionMode = false;
    this.selectedRuleIds = [];
  }


  @Builder
  private ReplaceRuleMenu() {
    UiMenuPanel({
      items: this.replaceMenuItems(),
      panelWidth: PROFILE_MENU_WIDTH,
      onSelect: (key: string) => { this.replaceRuleMenuVisible = false; this.onReplaceMenuSelect(key); }
    })
  }

  private replaceMenuItems(): UiMenuItem[] {
    return [
      { key: 'import', title: '导入' },
      { key: 'export', title: '导出' },
      { key: 'groups', title: '分组管理' },
      { key: 'selection', title: '选择模式' },
      { key: 'sort_asc', title: '旧的在前' },
      { key: 'sort_desc', title: '新的在前' },
      { key: 'sort_name_asc', title: '名称升序' },
      { key: 'sort_name_desc', title: '名称降序' }
    ];
  }

  private onReplaceMenuSelect(key: string): void {
    if (key === 'import') {
      this.ruleActionSheet = 'import';
    } else if (key === 'export') {
      this.onExportRules(this.filteredReplaceRules());
    } else if (key === 'groups') {
      this.ruleActionSheet = 'groups';
    } else if (key === 'selection') {
      if (this.selectionMode) {
        this.exitSelection();
      } else {
        this.selectionMode = true;
        this.selectedRuleIds = [];
      }
    } else if (key === 'sort_asc') {
      this.onSortModeChange('asc');
    } else if (key === 'sort_desc') {
      this.onSortModeChange('desc');
    } else if (key === 'sort_name_asc') {
      this.onSortModeChange('name_asc');
    } else if (key === 'sort_name_desc') {
      this.onSortModeChange('name_desc');
    }
  }

  /** 规则条目长按菜单：置顶、置底、删除（与上游条目下拉的三项一致）。 */
  @Builder
  private RuleRowMenu(rule: ReplaceRule) {
    UiMenuPanel({
      items: this.replaceRowItems(rule),
      panelWidth: PROFILE_MENU_WIDTH,
      onSelect: (key: string) => { this.ruleRowMenuVisible = false; this.onReplaceRowSelect(rule, key); }
    })
  }

  private replaceRowItems(_rule: ReplaceRule): UiMenuItem[] {
    return [
      { key: 'top', title: '置顶' },
      { key: 'bottom', title: '置底' },
      { key: 'delete', title: '删除' }
    ];
  }

  private onReplaceRowSelect(rule: ReplaceRule, key: string): void {
    if (key === 'top') {
      this.onMoveRule(rule.id, true);
    } else if (key === 'bottom') {
      this.onMoveRule(rule.id, false);
    } else if (key === 'delete') {
      this.requestDelete([rule.id]);
    }
  }

  @Builder
  private RuleActionSheet() {
    if (this.ruleActionSheet === 'groups') {
      // 分组面板与编辑页共用同一份实现，避免同一功能出现两种行为。
      ReplaceRuleGroupSheet({
        groups: this.groups,
        onRenameGroup: (oldName: string, newName: string) => this.onRenameGroup(oldName, newName),
        onRemoveGroup: (name: string) => this.onRemoveGroup(name),
        onClose: () => this.ruleActionSheet = '',
        onUnavailableAction: (message: string) => this.onUnavailableAction(message)
      })
    } else if (this.ruleActionSheet === 'confirmDelete') {
      // 删除确认：批量删除与长按菜单的单条删除共用，确认前不动数据。
      Column() {
        Text('删除规则').fontSize(HEADLINE_SMALL).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
          .width('100%').padding({ left: 18, right: 18, top: 16, bottom: 10 })
        Text(this.pendingDeleteIds.length > 1
          ? `确定删除选中的 ${this.pendingDeleteIds.length} 条替换规则？删除后可通过导入恢复。`
          : '确定删除这条替换规则？删除后可通过导入恢复。')
          .fontSize(TITLE_SMALL).fontColor(this.themeColorTextTertiary)
          .width('100%').padding({ left: 18, right: 18, bottom: 20 })
        Row() {
          Text('取消').fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary).layoutWeight(1).textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 14 })
            .onClick(() => this.cancelDelete())
          Text('删除').fontSize(LABEL_LARGE).fontColor('#D99AA5').layoutWeight(1).textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 14 })
            .onClick(() => this.confirmDelete())
        }.width('100%').padding({ left: 8, right: 8, bottom: 12 })
      }.width('100%').alignItems(HorizontalAlign.Start).backgroundColor('#17181E')
    } else {
      Column() {
        Row() {
          Text(this.ruleActionSheet === 'manual' ? '手动输入规则' : '导入替换规则')
            .fontSize(HEADLINE_SMALL).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).layoutWeight(1)
          Stack({ alignContent: Alignment.Center }) {
            AppGlyph({ name: 'profileClose', glyphSize: 20, tint: this.themeColorTextSecondary })
          }.width(40).height(40).onClick(() => this.ruleActionSheet = '')
        }.width('100%').padding({ left: 18, right: 12, top: 14, bottom: 12 })
        if (this.ruleActionSheet === 'manual') {
          Column() {
            Text('粘贴规则文本').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary).margin({ bottom: 8 })
            TextArea({ placeholder: '粘贴 JSON 规则数组或单条规则对象', text: this.manualInput })
              .fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
              .backgroundColor('#22232A').borderRadius(12)
              .width('100%').height(220).padding(12)
              .onChange((value: string) => this.manualInput = value)
            Row() {
              Text('清空').fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary).layoutWeight(1)
                .onClick(() => this.manualInput = '')
              Text('取消').fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary).layoutWeight(1)
                .onClick(() => { this.manualInput = ''; this.ruleActionSheet = 'import'; })
              Text('导入').fontSize(LABEL_LARGE).fontColor(this.manualInput.trim().length > 0 ? this.themeColorAccent : '#5C5E68')
                .onClick(() => this.submitManualImport())
            }.width('100%').margin({ top: 12 })
          }.width('100%').padding({ left: 16, right: 16, bottom: 20 })
        } else {
          Column() {
            Row() {
              AppGlyph({ name: 'folder', glyphSize: 20, tint: this.themeColorAccent }).margin({ right: 12 })
              Column() {
                Text('选择本地文件').fontSize(LABEL_LARGE).fontColor(this.themeColorTextPrimary)
                Text('支持 JSON、TXT 规则文件').fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
              }.alignItems(HorizontalAlign.Start)
            }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .backgroundColor('#22232A').borderRadius(12)
              .onClick(() => this.onImportRules('', 'file'))
            Row() {
              AppGlyph({ name: 'edit', glyphSize: 20, tint: this.themeColorAccent }).margin({ right: 12 })
              Column() {
                Text('手动输入').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary)
                Text('粘贴规则文本或链接').fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
              }.alignItems(HorizontalAlign.Start)
            }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .backgroundColor('#22232A').borderRadius(12).margin({ top: 8, bottom: 18 })
              .onClick(() => { this.ruleActionSheet = 'manual'; })
          }.width('100%').padding({ left: 16, right: 16 })
        }
      }.width('100%').height('100%').backgroundColor('#17181E')
    }
  }

  /** 提交手动输入的规则文本。 */
  private submitManualImport(): void {
    const text = this.manualInput.trim();
    if (text.length === 0) {
      this.onUnavailableAction('规则文本为空');
      return;
    }
    this.onImportRules(text, 'manual');
    this.manualInput = '';
    this.ruleActionSheet = '';
  }

  /** 批量启用/停用：未选中时提示而不是静默无反应。 */
  private submitBatchEnabled(enabled: boolean): void {
    if (this.selectedRuleIds.length === 0) {
      this.onUnavailableAction('请先选择规则');
      return;
    }
    this.onSetEnabledBatch(this.selectedRuleIds, enabled);
  }

  /** 批量置顶/置底：与单条一致，退出选择模式，让用户看到移动结果。 */
  private submitBatchMove(toTop: boolean): void {
    if (this.selectedRuleIds.length === 0) {
      this.onUnavailableAction('请先选择规则');
      return;
    }
    this.onMoveBatch(this.selectedRuleIds, toTop);
    this.exitSelection();
  }

  /** 批量删除：先弹确认面板，确认后才真正删除。 */
  private submitBatchRemove(): void {
    if (this.selectedRuleIds.length === 0) {
      this.onUnavailableAction('请先选择规则');
      return;
    }
    this.requestDelete(this.selectedRuleIds);
  }

  /**
   * 请求删除：只记录待删对象并打开确认面板，不直接删。
   * 批量删除与长按菜单的单条删除都走这里，保证两条路径行为一致。
   */
  private requestDelete(ids: number[]): void {
    if (ids.length === 0) {
      return;
    }
    this.pendingDeleteIds = ids;
    this.ruleActionSheet = 'confirmDelete';
  }

  /** 确认面板里点「删除」：单条走单条回调，多条走批量回调，然后关闭面板。 */
  private confirmDelete(): void {
    const ids = this.pendingDeleteIds;
    this.pendingDeleteIds = [];
    this.ruleActionSheet = '';
    if (ids.length === 1) {
      this.onRemoveRule(ids[0]);
      // 单条删除后若仍在选择模式，把该条从选中集合里摘掉，避免底部条计数虚高。
      this.selectedRuleIds = this.selectedRuleIds.filter((id: number) => id !== ids[0]);
      return;
    }
    this.onRemoveBatch(ids);
    this.exitSelection();
  }

  /** 取消删除：只清空待删对象，不动选择模式。 */
  private cancelDelete(): void {
    this.pendingDeleteIds = [];
    this.ruleActionSheet = '';
  }

  /** 选择模式下导出：导出的应是选中的规则，而不是当前筛选结果的全部。 */
  private submitBatchExport(): void {
    if (this.selectedRuleIds.length === 0) {
      this.onUnavailableAction('请先选择规则');
      return;
    }
    const selected = this.rules.filter((rule: ReplaceRule) => this.selectedRuleIds.includes(rule.id));
    if (selected.length === 0) {
      this.onUnavailableAction('所选规则已不存在');
      return;
    }
    this.onExportRules(selected);
  }

  /**
   * 是否允许拖拽排序。
   * 与上游 ReplaceRuleScreen.kt:143 的 canReorder 一致：只有按顺序排序（旧的在前 / 新的在前）
   * 时拖拽才有意义；名称排序下顺序由名称决定，拖拽改了也不会体现在界面上。
   */
  private canReorder(): boolean {
    return this.sortMode === 'asc' || this.sortMode === 'desc';
  }

  /**
   * 处理拖拽换位。
   *
   * onMove 给的是「当前筛选列表」里的下标，而存储数组可能被搜索或分组筛选过，
   * 所以这里先换算成规则 id 再回调，由仓储按 id 定位真实位置，避免筛选态下改错规则。
   */
  private handleReorder(from: number, to: number): void {
    if (!this.canReorder()) {
      this.onUnavailableAction('名称排序下不能拖拽排序，请先切换到按顺序排序');
      return;
    }
    const visible = this.filteredReplaceRules();
    if (from < 0 || to < 0 || from >= visible.length || to >= visible.length || from === to) {
      return;
    }
    this.onReorderRule(visible[from].id, visible[to].id);
  }

  private filteredReplaceRules(): ReplaceRule[] {
    const query = this.searchQuery.trim().toLowerCase();
    const filtered = this.rules.filter((rule: ReplaceRule) => {
      // 一条规则可以属于多个分组（group 存的是逗号分隔的多值串），
      // 所以这里判断「包含」而不是整串相等。
      const matchesGroup = this.selectedGroup.length === 0 ||
        ReplaceRuleRepository.groupContains(rule.group, this.selectedGroup);
      const matchesQuery = query.length === 0 || rule.name.toLowerCase().includes(query) ||
        rule.pattern.toLowerCase().includes(query) || rule.replacement.toLowerCase().includes(query);
      return matchesGroup && matchesQuery;
    });
    filtered.sort((left: ReplaceRule, right: ReplaceRule) => {
      if (this.sortMode === 'name_asc') {
        return left.name.localeCompare(right.name);
      }
      if (this.sortMode === 'name_desc') {
        return right.name.localeCompare(left.name);
      }
      return this.sortMode === 'desc' ? right.order - left.order : left.order - right.order;
    });
    return filtered;
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
          Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.themeColorTextSecondary)
        }.width(40).height(40).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
          AppGlyph({ name: 'search', glyphSize: 20, tint: this.themeColorTextSecondary })
        }.width(40).height(40)
          .onClick(() => { this.showSearch = !this.showSearch; if (!this.showSearch) { this.searchQuery = ''; } })
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
          AppGlyph({ name: 'more', glyphSize: 20, tint: this.themeColorTextSecondary })
        }.width(40).height(40)
          .onClick(() => { this.replaceRuleMenuVisible = !this.replaceRuleMenuVisible; })
.bindPopup(this.replaceRuleMenuVisible, {
  builder: this.ReplaceRuleMenu,
  placement: Placement.BottomRight,
  popupColor: '#00000000',
  enableArrow: false,
  autoCancel: true,
  width: PROFILE_MENU_WIDTH,
  onStateChange: (event: PopupStateChangeParam) => { this.replaceRuleMenuVisible = event.isVisible; }
})
      }.width('100%').height(40).padding({ left: 11, right: 12 })
        .margin({ top: this.appTopInset - 8 })

      Text(this.selectionMode ? `已选择 ${this.selectedRuleIds.length} 项` : '替换净化')
        .fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor(this.themeColorTextPrimary)
        .width('100%').padding({ left: 12, right: 18, top: 12 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '搜索', text: this.searchQuery })
            .fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).placeholderColor(this.themeColorTextTertiary)
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .id('my_replace_rule_search')
            .onAppear(() => focusControl.requestFocus('my_replace_rule_search'))
            .onChange((value: string) => this.searchQuery = value)
        }.width('calc(100% - 32vp)').height(48).padding({ left: 14, right: 14 })
          .margin({ left: 16, right: 16, top: 8, bottom: 4 }).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(24)
          .transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE, curve: Curve.EaseInOut }))
      }

      if (this.groups.length > 0) {
        Scroll() {
          Row() {
            ModuleTab({ label: '全部', selected: this.selectedGroup.length === 0, onSelect: () => this.selectedGroup = '' })
            ForEach(this.groups, (group: string) => {
              ModuleTab({ label: group, selected: this.selectedGroup === group, onSelect: () => this.selectedGroup = group })
            })
          }.width('100%').padding({ left: 16, right: 9, top: 8, bottom: 12 })
        }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).scrollBar(BarState.Off)
      }

      if (this.filteredReplaceRules().length === 0) {
        ModuleEmpty({
          icon: 'profileFindReplace',
          title: this.rules.length === 0 ? '暂无替换净化规则' : '没有匹配的替换净化规则',
          detail: this.rules.length === 0 ? '添加规则后会按顺序应用到本地书籍正文' : '调整搜索词或分组筛选后重试'
        })
          .layoutWeight(1)
      } else {
        // 用 List 而不是 Scroll+Column：拖拽排序（ForEach.onMove）只在 List 内生效。
        List({ space: 8 }) {
          ForEach(this.filteredReplaceRules(), (rule: ReplaceRule) => {
            ListItem() {
              Row() {
                if (this.selectionMode) {
                  AppGlyph({
                    name: this.selectedRuleIds.includes(rule.id) ? 'profileCheck' : 'profileClose',
                    glyphSize: 20, tint: this.selectedRuleIds.includes(rule.id) ? this.themeColorAccent : this.themeColorTextTertiary
                  }).margin({ right: 12 })
                }
                Column() {
                  Text(rule.name.length > 0 ? rule.name : rule.pattern).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`${rule.group} · ${rule.scopeContent ? '正文' : ''}${rule.scopeTitle ? ' 标题' : ''}`)
                    .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 4 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                if (!this.selectionMode) {
                  UiSwitchControl({
                    checked: rule.isEnabled,
                    onChange: (enabled: boolean) => this.onToggleRule(rule.id, enabled)
                  })
                  // 长按手势留给拖拽排序，条目操作改由「更多」图标触发，与上游条目右侧的更多按钮一致。
                  Stack({ alignContent: Alignment.Center }) {
                    AppGlyph({ name: 'more', glyphSize: 18, tint: this.themeColorTextTertiary })
                  }.width(32).height(32).margin({ left: 4 })
                    .onClick(() => { this.ruleRowMenuVisible = !this.ruleRowMenuVisible; })
.bindPopup(this.ruleRowMenuVisible, {
  builder: () => { this.RuleRowMenu(rule) },
  placement: Placement.BottomRight,
  popupColor: '#00000000',
  enableArrow: false,
  autoCancel: true,
  width: PROFILE_MENU_WIDTH,
  onStateChange: (event: PopupStateChangeParam) => { this.ruleRowMenuVisible = event.isVisible; }
})
                }
              }.width('100%').padding({ left: 16, right: 16, top: 13, bottom: 13 })
                .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(14)
                .onClick(() => this.selectionMode ? this.toggleSelectedRule(rule.id) : this.onEditRule(rule.id))
            }
          }, (rule: ReplaceRule) => replaceRuleRowKey(rule))
            // 长按条目进入拖拽排序。名称排序下顺序由名称决定，与上游 canReorder 一致不挂载拖拽。
            .onMove(this.canReorder() ? (from: number, to: number) => this.handleReorder(from, to) : undefined)
        }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
          .padding({ left: 16, right: 16, top: 10, bottom: 80 })
      }
      if (this.selectionMode) {
        Row() {
          Text(this.selectedRuleIds.length === 0 ? '取消' : `已选择 ${this.selectedRuleIds.length} 项`)
            .fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).layoutWeight(1)
            .onClick(() => this.exitSelection())
          Text('全选').fontSize(TITLE_SMALL).fontColor(this.themeColorAccent).padding({ left: 10, right: 10 })
            .onClick(() => this.selectAllVisible())
          Text('反选').fontSize(TITLE_SMALL).fontColor(this.themeColorAccent).padding({ left: 0, right: 10 })
            .onClick(() => this.invertSelection())
        }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 4 })
        Row() {
          Text('启用').fontSize(TITLE_SMALL)
            .fontColor(this.selectedRuleIds.length > 0 ? this.themeColorAccent : '#5C5E68')
            .onClick(() => this.submitBatchEnabled(true))
          Text('停用').fontSize(TITLE_SMALL).margin({ left: 18 })
            .fontColor(this.selectedRuleIds.length > 0 ? this.themeColorAccent : '#5C5E68')
            .onClick(() => this.submitBatchEnabled(false))
          Text('置顶').fontSize(TITLE_SMALL).margin({ left: 18 })
            .fontColor(this.selectedRuleIds.length > 0 ? this.themeColorAccent : '#5C5E68')
            .onClick(() => this.submitBatchMove(true))
          Text('置底').fontSize(TITLE_SMALL).margin({ left: 18 })
            .fontColor(this.selectedRuleIds.length > 0 ? this.themeColorAccent : '#5C5E68')
            .onClick(() => this.submitBatchMove(false))
          Text('导出').fontSize(TITLE_SMALL).margin({ left: 18 })
            .fontColor(this.selectedRuleIds.length > 0 ? this.themeColorAccent : '#5C5E68')
            .onClick(() => this.submitBatchExport())
          Blank().layoutWeight(1)
          Text('删除').fontSize(TITLE_SMALL)
            .fontColor(this.selectedRuleIds.length > 0 ? '#D99AA5' : '#5C5E68')
            .onClick(() => this.submitBatchRemove())
        }.width('100%').padding({ left: 16, right: 16, top: 2, bottom: 10 })
      }
      Stack({ alignContent: Alignment.Center }) {
        AppGlyph({ name: 'add', glyphSize: 22, tint: this.themeColorAccent })
      }.width(50).height(50).backgroundColor('#454F70').borderRadius(14)
        .visibility(this.selectionMode ? Visibility.None : Visibility.Visible)
        .onClick(() => this.onOpenEditor())
        .margin({ right: 16, bottom: 16 }).alignSelf(ItemAlign.End)
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      .bindSheet(this.ruleActionSheet.length > 0, this.RuleActionSheet(), {
        // 删除确认只有几行文字，用内容自适应高度，避免半屏空白。
        height: this.ruleActionSheet === 'confirmDelete' ? SheetSize.FIT_CONTENT : SheetSize.MEDIUM,
        dragBar: true,
        showClose: false,
        backgroundColor: '#17181E',
        onDisappear: () => this.ruleActionSheet = ''
      })
  }
}

@Component
export struct ReplaceRuleEditPage {
  @State ruleActionsMenuVisible: boolean = false;
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @State groupMenuVisible: boolean = false;
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('appTopInset') appTopInset: number = 0;
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  onSaveRule: (rule: ReplaceRule) => void = (_rule: ReplaceRule) => {};
  /** 传入已有规则时进入编辑模式；为空表示新建。 */
  @Prop editingRule: ReplaceRule | undefined = undefined;
  /** :220 划词「替换」带进来的 pattern 草稿；仅新建时预填，上游是预填让用户手跑替换。 */
  @Prop seedPattern: string = '';
  @Prop groups: string[] = [];
  /** 分组管理：与列表页共用同一个面板，这里接的是同一批仓储方法。
   *  上游面板无新增分组入口，故只有重命名与删除。 */
  onRenameGroup: (oldName: string, newName: string) => Promise<void> = async (_o: string, _n: string) => {};
  onRemoveGroup: (name: string) => Promise<void> = async (_name: string) => {};
  @State name: string = '';
  @State group: string = '默认';
  @State pattern: string = '';
  @State replacement: string = '';
  @State scopeTitle: boolean = false;
  // 与上游 ReplaceRule 保持一致：新建规则默认作用于正文，
  // 否则保存后既不参与正文替换也不会出现在试跑结果里。
  @State scopeContent: boolean = true;
  @State isRegex: boolean = false;
  @State scope: string = '';
  @State excludeScope: string = '';
  @State timeout: string = '3000';
  @State keyboardVisible: boolean = false;
  @State showPasteAuthorization: boolean = false;
  /**
   * 当前打开的半模态面板：'' 表示关闭，'group' 为分组管理，'test' 为规则试跑。
   * ArkUI 一个组件只能绑定一个 bindSheet，后绑定的会覆盖先绑定的，
   * 因此两个面板合并成一个 bindSheet，用本字段切换内容。
   */
  @State activeSheet: string = '';
  @State activeField: string = 'pattern';
  @State isEnabled: boolean = true;
  /** 规则试跑：样例文本、结果与是否已跑过。 */
  @State testSource: string = '';
  @State testOutput: string = '';
  @State testError: string = '';
  @State testHasRun: boolean = false;
  /** 记录被编辑规则的 id 与 order，保存时原样带回，避免新建语义覆盖。 */
  @State editingId: number = 0;
  @State editingOrder: number = 0;
  @State initialized: boolean = false;

  aboutToAppear(): void {
    this.applyEditingRule();
  }

  /** @Prop 变化时（切换编辑目标）重新回填。 */
  onDidBuild(): void {
    if (!this.initialized) {
      this.applyEditingRule();
    }
  }

  private applyEditingRule(): void {
    const rule = this.editingRule;
    if (rule === undefined || rule === null) {
      // :220 新建模式：有划词带进来的 pattern 就预填，避免覆盖其他字段的默认值。
      if (this.seedPattern.length > 0) {
        this.pattern = this.seedPattern;
      }
      this.initialized = true;
      return;
    }
    this.name = rule.name;
    this.group = typeof rule.group === 'string' && rule.group.length > 0 ? rule.group : '默认';
    this.pattern = rule.pattern;
    this.replacement = rule.replacement;
    this.scope = rule.scope;
    this.scopeTitle = rule.scopeTitle;
    this.scopeContent = rule.scopeContent;
    this.excludeScope = rule.excludeScope;
    this.isRegex = rule.isRegex;
    this.isEnabled = rule.isEnabled;
    this.timeout = `${rule.timeoutMillisecond}`;
    this.editingId = rule.id;
    this.editingOrder = rule.order;
    this.initialized = true;
  }

  private availableGroups(): string[] {
    const options: string[] = ['默认'];
    this.groups.forEach((group: string) => {
      if (group.length > 0 && group !== '默认' && !options.includes(group)) { options.push(group); }
    });
    return options;
  }

  @Builder
  private RuleActionsMenu() {
    UiMenuPanel({
      items: this.replaceEditActionItems(),
      panelWidth: PROFILE_MENU_WIDTH,
      onSelect: (key: string) => { this.ruleActionsMenuVisible = false; this.onReplaceEditActionSelect(key); }
    })
  }

  private replaceEditActionItems(): UiMenuItem[] {
    return [
      { key: 'copy', title: '拷贝规则' },
      { key: 'paste', title: '粘贴规则' },
      { key: 'test', title: '测试规则' }
    ];
  }

  private onReplaceEditActionSelect(key: string): void {
    if (key === 'copy') {
      this.copyRule();
    } else if (key === 'paste') {
      this.showPasteAuthorization = true;
    } else if (key === 'test') {
      this.activeSheet = 'test';
    }
  }

  /**
   * 用样例文本试跑已保存并启用的规则，展示每条规则是否真的改动了文本。
   * 只跑已保存的规则：编辑页里尚未保存的改动不在仓库缓存中，
   * 这里如实说明，避免用户以为改动已生效。
   */
  private runRuleTest(): void {
    if (this.testSource.trim().length === 0) {
      this.testError = '样例文本不能为空';
      this.testOutput = '';
      this.testHasRun = true;
      return;
    }
    const result = ReplaceRuleRepository.previewContent(this.testSource);
    this.testOutput = result.text;
    const changed = result.lines.filter((line: ReplaceRulePreviewLine) => line.changed).length;
    this.testError = result.lines.length === 0 ? '当前没有启用中的正文规则，样例文本未被改动'
      : `共 ${result.lines.length} 条正文规则，其中 ${changed} 条改动了样例文本`;
    this.testHasRun = true;
  }

  private clearRuleTest(): void {
    this.testOutput = '';
    this.testError = '';
    this.testHasRun = false;
  }

  @Builder
  private RuleTestSheet() {
    Column() {
      // 「清空」「试跑」放在标题栏里：键盘弹出时半模态面板被压到很矮，
      // 只有标题栏始终可见，放在底部或滚动区内都会被裁掉点不到。
      Row() {
        Text('测试规则').fontSize(HEADLINE_SMALL).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Text('清空').fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary).margin({ right: 18 })
          .onClick(() => { this.testSource = ''; this.clearRuleTest(); })
        Text('试跑').fontSize(LABEL_LARGE).fontColor(this.testSource.trim().length > 0 ? this.themeColorAccent : '#5C5E68')
          .margin({ right: 8 })
          .onClick(() => this.runRuleTest())
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileClose', glyphSize: 20, tint: this.themeColorTextSecondary })
        }.width(40).height(40).onClick(() => this.activeSheet = '')
      }.width('100%').padding({ left: 18, right: 12, top: 14, bottom: 8 })
      Text('只对已保存并启用的正文规则试跑，编辑中的改动需要先保存')
        .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).width('100%').padding({ left: 18, right: 18, bottom: 10 })
      Scroll() {
        Column() {
          TextArea({ placeholder: '粘贴一段正文用于试跑', text: this.testSource })
            .fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
            .backgroundColor('#22232A').borderRadius(12)
            .width('100%').height(140).padding(12)
            .onChange((value: string) => { this.testSource = value; this.clearRuleTest(); })
          if (this.testHasRun) {
            Text(this.testError).fontSize(LABEL_MEDIUM)
              .fontColor(this.testError.startsWith('当前没有') ? this.themeColorTextTertiary : this.themeColorTextSecondary)
              .width('100%').textAlign(TextAlign.Start).margin({ top: 16 })
            if (this.testOutput.length > 0) {
              Text(this.testOutput).fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary)
                .width('100%').textAlign(TextAlign.Start).padding(12).margin({ top: 10 })
                .backgroundColor('#22232A').borderRadius(12)
            }
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, bottom: 20 })
      }.edgeEffect(EdgeEffect.None).layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#17181E')
  }

  @Builder
  private GroupMenu() {
    UiMenuPanel({
      items: this.groupMenuItems(),
      panelWidth: PROFILE_MENU_WIDTH,
      onSelect: (key: string) => { this.groupMenuVisible = false; this.group = key; }
    })
  }

  private groupMenuItems(): UiMenuItem[] {
    return this.availableGroups().map((group: string) => {
      const item: UiMenuItem = { key: group, title: group, selected: this.group === group };
      return item;
    });
  }

  private clipboardJson(): string {
    return JSON.stringify({
      id: Date.now(), name: this.name, group: this.group, pattern: this.pattern,
      replacement: this.replacement, scope: this.scope, scopeTitle: this.scopeTitle,
      scopeContent: this.scopeContent, excludeScope: this.excludeScope,
      isEnabled: true, isRegex: this.isRegex,
      timeoutMillisecond: Number(this.timeout) || 3000, order: -2147483648
    });
  }

  private async copyRule(): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.clipboardJson());
      await pasteboard.getSystemPasteboard().setData(data);
      this.onUnavailableAction('规则已复制到剪贴板');
    } catch (_error) {
      this.onUnavailableAction('复制规则失败');
    }
  }

  private async pasteRule(result: PasteButtonOnClickResult): Promise<void> {
    this.showPasteAuthorization = false;
    if (result !== PasteButtonOnClickResult.SUCCESS) {
      this.onUnavailableAction('未获得读取剪贴板授权');
      return;
    }
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      if (data.getRecordCount() === 0) {
        this.onUnavailableAction('剪贴板为空');
        return;
      }
      const parsed: ReplaceRuleClipboardData = JSON.parse(data.getRecord(0).toPlainText());
      if (typeof parsed.name !== 'string' || typeof parsed.pattern !== 'string' ||
        typeof parsed.replacement !== 'string') {
        this.onUnavailableAction('剪贴板规则格式无效');
        return;
      }
      this.name = parsed.name;
      this.group = typeof parsed.group === 'string' ? parsed.group : '默认';
      this.pattern = parsed.pattern;
      this.replacement = parsed.replacement;
      this.scope = typeof parsed.scope === 'string' ? parsed.scope : '';
      this.scopeTitle = parsed.scopeTitle === true;
      this.scopeContent = parsed.scopeContent !== false;
      this.excludeScope = typeof parsed.excludeScope === 'string' ? parsed.excludeScope : '';
      this.isRegex = parsed.isRegex !== false;
      this.timeout = typeof parsed.timeoutMillisecond === 'number' ? `${parsed.timeoutMillisecond}` : '3000';
      this.onUnavailableAction('规则已从剪贴板填入');
    } catch (_error) {
      this.onUnavailableAction('剪贴板规则格式无效');
    }
  }

  private insertQuickText(value: string): void {
    if (this.activeField === 'name') { this.name += value; }
    else if (this.activeField === 'replacement') { this.replacement += value; }
    else if (this.activeField === 'scope') { this.scope += value; }
    else if (this.activeField === 'excludeScope') { this.excludeScope += value; }
    else if (this.activeField === 'timeout') { this.timeout += value; }
    else { this.pattern += value; }
  }

  private saveRule(): void {
    if (this.pattern.trim().length === 0) {
      this.onUnavailableAction('替换规则为空或者不满足正则表达式要求');
      return;
    }
    if (this.isRegex) {
      try {
        new RegExp(this.pattern);
        if (this.pattern.endsWith('|') && !this.pattern.endsWith('\\|')) {
          this.onUnavailableAction('替换规则为空或者不满足正则表达式要求');
          return;
        }
      } catch (_error) {
        this.onUnavailableAction('替换规则为空或者不满足正则表达式要求');
        return;
      }
    }
    const rule: ReplaceRule = {
      id: this.editingId > 0 ? this.editingId : Date.now(), name: this.name.trim(), group: this.group,
      pattern: this.pattern, replacement: this.replacement, scope: this.scope, scopeTitle: this.scopeTitle,
      scopeContent: this.scopeContent, excludeScope: this.excludeScope, isEnabled: this.isEnabled,
      isRegex: this.isRegex, timeoutMillisecond: Math.max(1, Number(this.timeout) || 3000),
      order: this.editingId > 0 ? this.editingOrder : 0
    };
    this.onSaveRule(rule);
  }

  @Builder
  private RuleField(label: string, value: string, field: string, placeholder: string) {
    Column() {
      Text(label).fontSize(LABEL_LARGE_EMPHASIZED).fontColor('#C3C5CD').margin({ left: 14, bottom: 3 })
      TextInput({ placeholder: placeholder, text: value })
        .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
        .height(52).backgroundColor('#24252C').borderRadius(8).padding({ left: 14, right: 14 })
        .width('100%')
        .onFocus(() => { this.activeField = field; this.keyboardVisible = true; })
        .onBlur(() => this.keyboardVisible = false)
        .onChange((text: string) => {
          if (field === 'name') { this.name = text; }
          else if (field === 'pattern') { this.pattern = text; }
          else if (field === 'replacement') { this.replacement = text; }
          else if (field === 'scope') { this.scope = text; }
          else if (field === 'excludeScope') { this.excludeScope = text; }
          else if (field === 'timeout') { this.timeout = text; }
        })
    }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 4 })
  }

  /**
   * 半模态面板的统一入口。ArkUI 同一组件只能绑定一个 bindSheet，
   * 所以按 activeSheet 分支渲染，而不是叠加多个 bindSheet。
   */
  @Builder
  private EditPageSheet() {
    if (this.activeSheet === 'group') {
      this.GroupManagerSheet()
    } else if (this.activeSheet === 'test') {
      this.RuleTestSheet()
    }
  }

  @Builder
  private GroupManagerSheet() {
    // 与列表页共用同一份分组管理实现，这里只负责传回调。
    ReplaceRuleGroupSheet({
      groups: this.availableGroups(),
      onRenameGroup: (oldName: string, newName: string) => this.onRenameGroup(oldName, newName),
      onRemoveGroup: (name: string) => this.onRemoveGroup(name),
      onClose: () => this.activeSheet = '',
      onUnavailableAction: (message: string) => this.onUnavailableAction(message)
    })
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
          Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.themeColorTextSecondary)
        }.width(40).height(40).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        if (this.keyboardVisible) {
          Stack({ alignContent: Alignment.Center }) {
            Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
            AppGlyph({ name: 'profileSave', glyphSize: 20, tint: this.themeColorTextSecondary })
          }.width(40).height(40).margin({ right: 8 })
            .onClick(() => this.saveRule())
        }
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
          AppGlyph({ name: 'more', glyphSize: 20, tint: this.themeColorTextSecondary })
        }.width(40).height(40)
          .onClick(() => { this.ruleActionsMenuVisible = !this.ruleActionsMenuVisible; })
.bindPopup(this.ruleActionsMenuVisible, {
  builder: this.RuleActionsMenu,
  placement: Placement.BottomRight,
  popupColor: '#00000000',
  enableArrow: false,
  autoCancel: true,
  width: PROFILE_MENU_WIDTH,
  onStateChange: (event: PopupStateChangeParam) => { this.ruleActionsMenuVisible = event.isVisible; }
})
      }.width('100%').height(40).padding({ left: 11, right: 12 })
        .margin({ top: this.appTopInset - 8 })
      Text(this.editingId > 0 ? '编辑替换' : '新建替换').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor(this.themeColorTextPrimary)
        .width('100%').padding({ left: 14, right: 0, top: 12, bottom: 0 })
      Scroll() {
        Column() {
          this.RuleField('规则名称', this.name, 'name', '')
          Row() {
            Column() {
              Row() {
                Blank().width(14)
                Text('分组').fontSize(LABEL_LARGE_EMPHASIZED).fontColor('#C3C5CD').textAlign(TextAlign.Start)
              }.width('100%')
              Row() {
                Blank().width(14)
                Text(this.group).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).layoutWeight(1)
                AppGlyph({ name: 'profileExpandMore', glyphSize: 20, tint: this.themeColorTextSecondary })
                Blank().width(14)
              }.width('100%')
              Row().width('calc(100% - 4vp)').height(1).backgroundColor('#898B94').margin({ left: 2, right: 2 })
            }.width('calc(100% - 40vp)').height(56).justifyContent(FlexAlign.Center)
              .backgroundColor('#24252C').borderRadius(8)
              .onClick(() => { this.groupMenuVisible = !this.groupMenuVisible; })
.bindPopup(this.groupMenuVisible, {
  builder: this.GroupMenu,
  placement: Placement.BottomRight,
  popupColor: '#00000000',
  enableArrow: false,
  autoCancel: true,
  width: PROFILE_MENU_WIDTH,
  onStateChange: (event: PopupStateChangeParam) => { this.groupMenuVisible = event.isVisible; }
})
            Stack({ alignContent: Alignment.Center }) {
              AppGlyph({ name: 'profileSettings', glyphSize: 20, tint: this.themeColorTextSecondary })
            }.width(48).height(56).onClick(() => { this.activeSheet = 'group'; })
          }.width('100%')
          Blank().height(12)
          this.RuleField('匹配规则', this.pattern, 'pattern', '输入正则表达式或关键字')
          this.RuleField('替换为', this.replacement, 'replacement', '输入替换内容或捕获组')
          Row() {
            ReplaceScopeChip({ label: '标题', selected: this.scopeTitle,
              onSelect: () => this.scopeTitle = !this.scopeTitle })
            ReplaceScopeChip({ label: '内容', selected: this.scopeContent,
              onSelect: () => this.scopeContent = !this.scopeContent })
            Blank().layoutWeight(1)
            ReplaceScopeChip({ label: '正则', selected: this.isRegex,
              onSelect: () => this.isRegex = !this.isRegex })
          }.width('100%').margin({ top: 12, bottom: 15 })
          this.RuleField('特定范围', this.scope, 'scope', '指定规则适用的范围')
          this.RuleField('排除范围', this.excludeScope, 'excludeScope', '指定规则不适用的范围')
          Column() {
            Text('超时 (ms)').fontSize(LABEL_LARGE_EMPHASIZED).fontColor('#C3C5CD').width('100%').textAlign(TextAlign.Start)
            TextInput({ text: this.timeout, placeholder: '3000' })
              .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).backgroundColor(Color.Transparent)
              .height(30).padding({ left: 0, right: 0 }).width('100%')
              .onFocus(() => { this.activeField = 'timeout'; this.keyboardVisible = true; })
              .onBlur(() => this.keyboardVisible = false)
              .onChange((text: string) => this.timeout = text)
            Row().width('100%').height(1).backgroundColor('#898B94')
          }.width('100%').height(56).alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Center)
            .padding({ left: 14, right: 14 }).backgroundColor('#24252C').borderRadius(8)
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, top: 0, bottom: 140 })
          .layoutWeight(1)
      }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).layoutWeight(1).scrollBar(BarState.Off)
      if (this.keyboardVisible) {
        Scroll() {
          Row() {
            ForEach(['.*', '\\d+', '\\w+', '[]', '()', '^', '$', '|', '{}', '<>'], (symbol: string) => {
              Text(symbol).fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).padding({ left: 10, right: 10, top: 7, bottom: 7 })
                .backgroundColor('#303139').borderRadius(18).margin({ right: 7 })
                .onClick(() => this.insertQuickText(symbol))
            })
          }.padding({ left: 16, right: 16, top: 8, bottom: 8 })
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      }
      Row() {
        if (this.showPasteAuthorization) {
          PasteButton({ text: PasteDescription.PASTE, buttonType: ButtonType.Capsule })
            .onClick(async (_event: ClickEvent, result: PasteButtonOnClickResult) => await this.pasteRule(result))
        }
        Blank()
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileSave', glyphSize: 20, tint: this.themeColorAccent })
        }.width(50).height(50).backgroundColor('#454F70').borderRadius(14)
          .visibility(this.keyboardVisible ? Visibility.Hidden : Visibility.Visible)
          .onClick(() => this.saveRule())
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 16 })
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      .bindSheet(this.activeSheet.length > 0, this.EditPageSheet(), {
        height: SheetSize.MEDIUM,
        dragBar: true,
        showClose: false,
        backgroundColor: '#17181E',
        onDisappear: () => this.activeSheet = ''
      })
  }
}

/**
 * 替换规则的分组管理面板。
 * 规则列表页与规则编辑页共用这一份实现：此前两处各写一套，
 * 列表页能用而编辑页的「删除选中」仍是占位提示，同一功能出现两种行为。
 */
@Component
export struct ReplaceRuleGroupSheet {
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  /**
   * 初始分组清单。面板是 bindSheet 的 builder 内容，打开期间不会随父级重新构建，
   * 因此不能只靠这个入参刷新，增删改之后由 reloadGroups() 从仓储重新取。
   */
  @Prop groups: string[] = [];
  /** 回调返回 Promise，面板等它落盘后再刷新列表，避免用固定延时猜时机。
   *  上游分组面板只有改、删两个入口（GroupManageBottomSheet 无 onAddGroup 参数），
   *  新增分组只能由规则编辑器里输入新分组名产生，故这里不提供新增回调。 */
  onRenameGroup: (oldName: string, newName: string) => Promise<void> = async (_o: string, _n: string) => {};
  onRemoveGroup: (name: string) => Promise<void> = async (_name: string) => {};
  onClose: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  /** 面板内实际渲染的分组，操作后自行刷新，不等父级重建。 */
  @State localGroups: string[] = [];
  @State groupInput: string = '';
  /** 非空表示正在重命名该分组；上游是点开某一条后行内展开输入框。 */
  @State groupEditing: string = '';

  aboutToAppear(): void {
    this.reloadGroups();
  }

  /** 从仓储读最新分组；仓储已是内存缓存，直接读不会产生额外 IO。 */
  private reloadGroups(): void {
    this.localGroups = ReplaceRuleRepository.getGroups();
  }

  /** 除「默认」之外的分组；默认分组不允许重命名或删除。 */
  private customGroups(): string[] {
    return this.localGroups.filter((group: string) => group.length > 0 && group !== '默认');
  }

  /** 收起行内编辑态，清掉草稿。 */
  private cancelEditing(): void {
    this.groupEditing = '';
    this.groupInput = '';
  }

  /** 提交重命名：落盘后刷新列表，与上游 GroupItem 的确认按钮语义一致。 */
  private async submitRename(): Promise<void> {
    const name = this.groupInput.trim();
    if (name.length === 0) {
      this.onUnavailableAction('分组名称不能为空');
      return;
    }
    if (name === this.groupEditing) {
      this.cancelEditing();
      return;
    }
    await this.onRenameGroup(this.groupEditing, name);
    this.cancelEditing();
    this.reloadGroups();
  }

  /** 删除分组：等落盘完成再刷新，保证列表与实际存储一致。 */
  private async removeGroup(name: string): Promise<void> {
    await this.onRemoveGroup(name);
    this.reloadGroups();
  }

  build() {
    Column() {
      Row() {
        Text('分组管理').fontSize(HEADLINE_SMALL).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileClose', glyphSize: 20, tint: this.themeColorTextSecondary })
        }.width(40).height(40).onClick(() => this.onClose())
      }.width('100%').padding({ left: 18, right: 12, top: 14, bottom: 12 })
      Scroll() {
        Column() {
          ForEach(this.customGroups(), (group: string) => {
            Column() {
              Row() {
                Text(group).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).layoutWeight(1)
                AppGlyph({ name: 'edit', glyphSize: 18, tint: this.themeColorAccent }).margin({ right: 18 })
                  .onClick(() => {
                    if (this.groupEditing === group) {
                      this.cancelEditing();
                    } else {
                      this.groupEditing = group;
                      this.groupInput = group;
                    }
                  })
                  .accessibilityText('编辑')
                AppGlyph({ name: 'delete', glyphSize: 18, tint: '#D99AA5' })
                  .onClick(() => this.removeGroup(group))
                  .accessibilityText('删除')
              }.width('100%')
              if (this.groupEditing === group) {
                Row() {
                  TextInput({ placeholder: '输入新的分组名称', text: this.groupInput })
                    .fontSize(LABEL_LARGE).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
                    .backgroundColor(Color.Transparent).layoutWeight(1).height(44)
                    .onChange((value: string) => this.groupInput = value)
                  Text('取消').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary).padding({ left: 8, right: 8 })
                    .onClick(() => this.cancelEditing())
                  Text('保存')
                    .fontSize(LABEL_MEDIUM).fontColor(this.groupInput.trim().length > 0 ? this.themeColorAccent : '#5C5E68')
                    .padding({ left: 8 })
                    .onClick(() => this.submitRename())
                }.width('100%')
              }
            }.width('100%').padding({ left: 16, right: 16, top: 13, bottom: 13 })
              .backgroundColor('#22232A').borderRadius(12).margin({ bottom: 7 })
          }, (group: string) => group)
        }.width('100%').padding({ left: 16, right: 16, bottom: 10 })
      }.edgeEffect(EdgeEffect.None).layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#17181E')
  }
}

@Component
struct ReplaceScopeChip {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @Prop label: string = '';
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Row() {
      if (this.selected) {
        AppGlyph({ name: 'profileCheck', glyphSize: 16, tint: this.themeColorTextSecondary }).margin({ right: 5 })
      }
      Text(this.label).fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary)
    }.padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .backgroundColor(this.selected ? '#3A4054' : Color.Transparent).borderRadius(12)
      .border({ width: 1, color: '#51535D' }).margin({ right: 8 }).onClick(() => this.onSelect())
  }
}

interface ReplaceRuleClipboardData {
  name?: string;
  group?: string | null;
  pattern?: string;
  replacement?: string;
  scope?: string | null;
  scopeTitle?: boolean;
  scopeContent?: boolean;
  excludeScope?: string | null;
  isRegex?: boolean;
  timeoutMillisecond?: number;
}

export interface RuleListEntry {
  id: string;
  title: string;
  detail: string;
  enabled: boolean;
}

@Component
struct RuleListBody {
  @State rowMenuVisible: boolean = false;
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop rules: RuleListEntry[] = [];
  @Prop query: string = '';
  @Prop selectedIds: string[] = [];
  @Prop selectionMode: boolean = false;
  @Prop sortMode: boolean = false;
  @Prop emptyMessage: string = '暂无规则';
  onOpen: (id: string) => void = (_id: string) => {};
  onToggle: (id: string) => void = (_id: string) => {};
  onLongSelect: (id: string) => void = (_id: string) => {};
  onMove: (id: string, direction: number) => void = (_id: string, _direction: number) => {};
  /** 条目右侧开关；不传时按不可用处理，避免点了没反应。 */
  onEnabledChange: (id: string, enabled: boolean) => void = (_id: string, _enabled: boolean) => {};
  /** 条目菜单的置顶/置底。 */
  onMoveToEdge: (id: string, toTop: boolean) => void = (_id: string, _toTop: boolean) => {};
  /** 条目菜单的删除；由父组件弹确认面板，这里只上报意图。 */
  onDelete: (id: string) => void = (_id: string) => {};

  /** 条目右侧「更多」菜单：置顶、置底、删除，与上游条目下拉三项一致。 */
  @Builder
  private RowMenu(rule: RuleListEntry) {
    UiMenuPanel({
      items: this.ruleListMenuItems(),
      panelWidth: PROFILE_MENU_WIDTH,
      onSelect: (key: string) => { this.rowMenuVisible = false; this.onRuleListMenuSelect(rule, key); }
    })
  }

  private ruleListMenuItems(): UiMenuItem[] {
    return [
      { key: 'top', title: '置顶' },
      { key: 'bottom', title: '置底' },
      { key: 'delete', title: '删除' }
    ];
  }

  private onRuleListMenuSelect(rule: RuleListEntry, key: string): void {
    if (key === 'top') {
      this.onMoveToEdge(rule.id, true);
    } else if (key === 'bottom') {
      this.onMoveToEdge(rule.id, false);
    } else if (key === 'delete') {
      this.onDelete(rule.id);
    }
  }

  private visibleRules(): RuleListEntry[] {
    const query = this.query.trim().toLocaleLowerCase();
    return query.length === 0 ? this.rules : this.rules.filter((rule: RuleListEntry) =>
      rule.title.toLocaleLowerCase().includes(query) || rule.detail.toLocaleLowerCase().includes(query));
  }

  build() {
    if (this.visibleRules().length === 0) {
      Column() {
        Text('(；′⌒`)').fontSize(HEADLINE_LARGE).fontColor(this.themeColorTextPrimary)
        Text(this.query.length > 0 ? '没有匹配的规则' : this.emptyMessage)
          .fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).margin({ top: 8 })
      }.width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    } else {
      Scroll() {
        Column() {
          ForEach(this.visibleRules(), (rule: RuleListEntry) => {
            Row() {
              if (this.selectionMode) {
                AppGlyph({ name: this.selectedIds.includes(rule.id) ? 'profileCheck' : 'profileClose',
                  glyphSize: 20, tint: this.selectedIds.includes(rule.id) ? this.themeColorAccent : this.themeColorTextTertiary })
                  .margin({ right: 12 })
              }
              Column() {
                Text(rule.title).fontSize(BODY_MEDIUM).fontColor(rule.enabled ? this.themeColorTextPrimary : this.themeColorTextTertiary)
                Text(rule.detail).fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary).margin({ top: 4 }).maxLines(2)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              if (this.sortMode) {
                Image($r('app.media.reader_reorder_up')).width(18).height(18).fillColor(this.themeColorAccent)
                  .margin({ right: 12 }).onClick(() => this.onMove(rule.id, -1))
                Image($r('app.media.reader_reorder_down')).width(18).height(18).fillColor(this.themeColorAccent)
                  .onClick(() => this.onMove(rule.id, 1))
              } else if (!this.selectionMode) {
                // 开关、编辑与更多图标并排；key 里带上 enabled，避免 ArkUI 复用节点导致开关不刷新。
                UiSwitchControl({
                  checked: rule.enabled,
                  onChange: (enabled: boolean) => this.onEnabledChange(rule.id, enabled)
                })
                AppGlyph({ name: 'edit', glyphSize: 18, tint: this.themeColorAccent }).margin({ left: 8 })
                Stack({ alignContent: Alignment.Center }) {
                  AppGlyph({ name: 'more', glyphSize: 18, tint: this.themeColorTextTertiary })
                }.width(32).height(32).margin({ left: 4 })
                  .onClick(() => { this.rowMenuVisible = !this.rowMenuVisible; })
.bindPopup(this.rowMenuVisible, {
  builder: () => { this.RowMenu(rule) },
  placement: Placement.BottomRight,
  popupColor: '#00000000',
  enableArrow: false,
  autoCancel: true,
  width: PROFILE_MENU_WIDTH,
  onStateChange: (event: PopupStateChangeParam) => { this.rowMenuVisible = event.isVisible; }
})
              }
            }.width('100%').padding(16).backgroundColor(this.themeColorSurfaceSecondary).borderRadius(14)
              .margin({ left: 16, right: 16, bottom: 8 })
              .onClick(() => this.selectionMode ? this.onToggle(rule.id) : this.onOpen(rule.id))
              .priorityGesture(LongPressGesture({ duration: 500 }).onAction(() => this.onLongSelect(rule.id)))
          }, (rule: RuleListEntry) => `${rule.id}_${rule.enabled ? 1 : 0}`)
        }.padding({ top: 8, bottom: 120 })
      }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).width('100%').height('100%').scrollBar(BarState.Off)
    }
  }
}

@Component
export struct TxtTocRulesPage {
  @State editMoreMenuVisible: boolean = false;
  @State importMenuVisible: boolean = false;
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  /** 当前规则列表，由 Index 持有并随仓储刷新。 */
  @Prop rules: RuleListEntry[] = [];
  /** 当前规则原始数据，供编辑时回填正则；与 rules 一一对应。 */
  @Prop sourceRules: TxtTocRule[] = [];
  onSaveRule: (rule: TxtTocRule) => Promise<void> = async (_rule: TxtTocRule) => {};
  onRemoveRule: (id: number) => Promise<void> = async (_id: number) => {};
  onRemoveBatch: (ids: number[]) => Promise<void> = async (_ids: number[]) => {};
  onToggleRule: (id: number, enabled: boolean) => Promise<void> = async (_id: number, _enabled: boolean) => {};
  onMoveRule: (id: number, direction: number) => Promise<void> = async (_id: number, _direction: number) => {};
  /** 条目菜单的置顶/置底：toTop 为 true 时移到最前。 */
  onMoveRuleToEdge: (id: number, toTop: boolean) => Promise<void> = async (_id: number, _toTop: boolean) => {};
  /** 选择模式下的批量启用/停用。 */
  onSetEnabledBatch: (ids: number[], enabled: boolean) => Promise<void> = async (_ids: number[], _enabled: boolean) => {};
  onImportBuiltin: () => Promise<void> = async () => {};
  /** 从用户选择的规则文件导入。 */
  onImportRules: () => Promise<void> = async () => {};
  /** 导出给定的规则；空数组表示没有可导出内容。 */
  onExportRules: (rules: TxtTocRule[]) => Promise<void> = async (_rules: TxtTocRule[]) => {};
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State selectionMode: boolean = false;
  @State selectedRuleIds: string[] = [];
  @State sortMode: boolean = false;
  @State showAddRule: boolean = false;
  /** 是否显示粘贴按钮；剪贴板读取需要 PasteButton 授权，不能直接调用。 */
  @State showPasteAuthorization: boolean = false;
  @State ruleName: string = '';
  @State chapterRegex: string = '';
  @State exampleText: string = '';
  @State volumeRegex: string = '';
  @State testError: string = '';
  @State testResults: TxtRuleTestLine[] = [];
  @State testHasRun: boolean = false;
  /** 正在编辑的规则 id；为空表示新建。 */
  @State editingRuleId: number = -1;
  /**
   * 是否处于编辑态。
   * 不能用 editingRuleId >= 0 判断：内置规则的 id 是负数（-1、-2…），
   * 用数值范围判断会把内置规则误认成新建。
   */
  @State editingExisting: boolean = false;
  /** 待确认删除的规则 id；与替换净化页一致，确认前不动数据。 */
  @State pendingDeleteIds: number[] = [];
  /** 当前打开的确认/编辑面板标识，空串表示未打开。 */
  @State confirmSheet: string = '';

  /** 切换单条规则的选中状态。 */
  private toggleSelectedRule(id: string): void {
    this.selectedRuleIds = this.selectedRuleIds.includes(id) ?
      this.selectedRuleIds.filter((selectedId: string) => selectedId !== id) : [...this.selectedRuleIds, id];
  }

  /** 全选当前筛选结果：筛选态下「全选」应与用户眼前的列表范围一致。 */
  private selectAllVisible(): void {
    this.selectedRuleIds = this.rules.map((rule: RuleListEntry) => rule.id);
  }

  /**
   * 反选：在当前筛选结果内取差集，与上游 invertSelection() 一致。
   * 用筛选结果而不是全部规则，保证「反选」与用户眼前的列表范围一致。
   */
  private invertSelection(): void {
    const visible = this.rules.map((rule: RuleListEntry) => rule.id);
    this.selectedRuleIds = visible.filter((id: string) => !this.selectedRuleIds.includes(id));
  }

  /** 退出选择模式并清空选中，避免下次进入时残留上一次的选择。 */
  private exitSelection(): void {
    this.selectionMode = false;
    this.selectedRuleIds = [];
  }

  /** 选中的 id 转成数字数组；非法 id 直接丢弃。 */
  private selectedNumericIds(): number[] {
    return this.selectedRuleIds.map((id: string) => Number(id))
      .filter((id: number) => Number.isInteger(id));
  }

  /** 请求删除：只记录待删对象并打开确认面板，不直接删。 */
  private requestDelete(ids: number[]): void {
    if (ids.length === 0) {
      return;
    }
    this.pendingDeleteIds = ids;
    this.confirmSheet = 'confirmDelete';
  }

  /** 确认删除：单条走单条回调，多条走批量回调，然后退出选择模式。 */
  private async confirmDelete(): Promise<void> {
    const ids = this.pendingDeleteIds;
    this.pendingDeleteIds = [];
    this.confirmSheet = '';
    if (ids.length === 1) {
      await this.onRemoveRule(ids[0]);
      this.selectedRuleIds = this.selectedRuleIds.filter((id: string) => Number(id) !== ids[0]);
      return;
    }
    await this.onRemoveBatch(ids);
    this.exitSelection();
  }

  /** 取消删除：只关面板，不动选择模式，用户可以继续操作已选规则。 */
  private cancelDelete(): void {
    this.pendingDeleteIds = [];
    this.confirmSheet = '';
  }

  /** 批量启用/停用：未选中时提示而不是静默无反应。 */
  private async submitBatchEnabled(enabled: boolean): Promise<void> {
    const ids = this.selectedNumericIds();
    if (ids.length === 0) {
      this.onUnavailableAction('请先选择规则');
      return;
    }
    await this.onSetEnabledBatch(ids, enabled);
  }

  /** 批量导出选中规则；空选中直接提示。 */
  private submitBatchExport(): void {
    const ids = this.selectedNumericIds();
    if (ids.length === 0) {
      this.onUnavailableAction('请先选择规则');
      return;
    }
    const selected = this.sourceRules.filter((rule: TxtTocRule) => ids.includes(rule.id));
    if (selected.length === 0) {
      this.onUnavailableAction('所选规则已不存在');
      return;
    }
    this.onExportRules(selected);
  }

  private buildClipboardRule(): string {
    return JSON.stringify({
      id: Date.now(),
      name: this.ruleName,
      chapterRule: this.chapterRegex,
      volumeRule: this.volumeRegex,
      example: this.exampleText,
      serialNumber: -1,
      enable: true
    });
  }

  private async copyRuleToClipboard(): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.buildClipboardRule());
      await pasteboard.getSystemPasteboard().setData(data);
      this.onUnavailableAction('规则已复制到剪贴板');
    } catch (_error) {
      this.onUnavailableAction('复制规则失败');
    }
  }

  private async pasteRuleFromClipboard(result: PasteButtonOnClickResult): Promise<void> {
    this.showPasteAuthorization = false;
    if (result !== PasteButtonOnClickResult.SUCCESS) {
      this.onUnavailableAction('未获得读取剪贴板授权');
      return;
    }
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      if (data.getRecordCount() === 0) {
        this.onUnavailableAction('剪贴板为空');
        return;
      }
      const text = data.getRecord(0).toPlainText();
      const parsed: TxtRuleClipboardData = JSON.parse(text);
      const chapterRule = parsed.chapterRule ?? parsed.rule;
      if (typeof parsed.name !== 'string' || typeof chapterRule !== 'string' ||
        (typeof parsed.example !== 'string' && parsed.example !== null && parsed.example !== undefined) ||
        (typeof parsed.volumeRule !== 'string' && parsed.volumeRule !== undefined)) {
        this.onUnavailableAction('剪贴板规则格式无效');
        return;
      }
      this.ruleName = parsed.name;
      this.chapterRegex = chapterRule;
      this.exampleText = typeof parsed.example === 'string' ? parsed.example : '';
      this.volumeRegex = parsed.volumeRule ?? '';
      this.clearRuleTest();
      this.onUnavailableAction('规则已从剪贴板填入');
    } catch (_error) {
      this.onUnavailableAction('剪贴板规则格式无效');
    }
  }

  private clearRuleTest(): void {
    this.testError = '';
    this.testResults = [];
    this.testHasRun = false;
  }

  private runRuleTest(): void {
    const pattern = this.chapterRegex.trim();
    const normalized = this.exampleText.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
    if (pattern.length === 0) {
      this.testError = '章节正则不能为空';
      this.testResults = [];
      this.testHasRun = true;
      return;
    }
    if (normalized.trim().length === 0) {
      this.testError = '示例不能为空';
      this.testResults = [];
      this.testHasRun = true;
      return;
    }
    try {
      const regex = TxtTocRuleRepository.compileRegex(pattern, 'gm');
      const text = `\n${normalized}`;
      const ranges: TxtRuleMatchRange[] = [];
      let match = regex.exec(text);
      while (match !== null) {
        ranges.push({ start: match.index, end: match.index + match[0].length });
        if (match[0].length === 0) {
          regex.lastIndex += 1;
        }
        match = regex.exec(text);
      }
      const lines = normalized.split('\n');
      let offset = 1;
      this.testResults = lines.map((line: string): TxtRuleTestLine => {
        const lineStart = offset;
        const lineEnd = offset + line.length;
        const matched = ranges.some((range: TxtRuleMatchRange): boolean => {
          return range.start === range.end
            ? range.start >= lineStart && range.start <= lineEnd
            : range.start < lineEnd && range.end > lineStart;
        });
        offset = lineEnd + 1;
        return { line, matched };
      });
      this.testError = '';
      this.testHasRun = true;
    } catch (_error) {
      this.testError = '正则格式无效';
      this.testResults = [];
      this.testHasRun = true;
    }
  }

  @Builder
  private ImportMenu() {
    UiMenuPanel({
      items: this.tocImportItems(),
      panelWidth: PROFILE_MENU_WIDTH,
      onSelect: (key: string) => { this.importMenuVisible = false; this.onTocImportSelect(key); }
    })
  }

  private tocImportItems(): UiMenuItem[] {
    return [
      { key: 'sort', title: '排序' },
      { key: 'selection', title: '选择模式' },
      { key: 'import', title: '导入' },
      { key: 'export', title: '导出' },
      { key: 'import_builtin', title: '导入内置规则' }
    ];
  }

  private onTocImportSelect(key: string): void {
    if (key === 'sort') {
      this.sortMode = !this.sortMode;
    } else if (key === 'selection') {
      this.selectionMode = !this.selectionMode;
      this.selectedRuleIds = [];
    } else if (key === 'import') {
      this.onImportRules();
    } else if (key === 'export') {
      this.onExportRules(this.sourceRules);
    } else if (key === 'import_builtin') {
      this.onImportBuiltin();
    }
  }

  @Builder
  private EditMoreMenu() {
    UiMenuPanel({
      items: this.tocEditMoreItems(),
      panelWidth: PROFILE_MENU_WIDTH,
      onSelect: (key: string) => { this.editMoreMenuVisible = false; this.onTocEditMoreSelect(key); }
    })
  }

  private tocEditMoreItems(): UiMenuItem[] {
    return [
      { key: 'copy', title: '复制规则' },
      { key: 'paste', title: '粘贴规则' }
    ];
  }

  private onTocEditMoreSelect(key: string): void {
    if (key === 'copy') {
      this.copyRuleToClipboard();
    } else if (key === 'paste') {
      this.showPasteAuthorization = true;
    }
  }

  @Builder
  private ruleEditorSheet() {
    Column() {
      Row() {
        AppGlyph({ name: 'profileClose', glyphSize: 20, tint: this.themeColorTextSecondary }).padding({ right: 12 })
          .onClick(() => this.showAddRule = false)
          .accessibilityText('关闭')
        Text(this.editingExisting ? '编辑目录规则' : 'TXT 目录规则').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        AppGlyph({ name: 'more', glyphSize: 20, tint: this.themeColorTextSecondary })
          .onClick(() => { this.editMoreMenuVisible = !this.editMoreMenuVisible; })
          .accessibilityText('更多菜单')
.bindPopup(this.editMoreMenuVisible, {
  builder: this.EditMoreMenu,
  placement: Placement.BottomRight,
  popupColor: '#00000000',
  enableArrow: false,
  autoCancel: true,
  width: PROFILE_MENU_WIDTH,
  onStateChange: (event: PopupStateChangeParam) => { this.editMoreMenuVisible = event.isVisible; }
})
      }.width('100%').padding({ left: 18, right: 16, top: 8, bottom: 12 })
      Scroll() {
        Column() {
          Text('名称').fontSize(LABEL_LARGE_EMPHASIZED).fontColor('#AEB0BA').width('100%').textAlign(TextAlign.Start)
          TextInput({ placeholder: '名称', text: this.ruleName })
            .fontSize(LABEL_LARGE).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
            .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary)).borderRadius(12).padding(12).width('100%')
            .onChange((value: string) => { this.ruleName = value; this.clearRuleTest(); })
          Text('章节正则').fontSize(LABEL_LARGE_EMPHASIZED).fontColor('#AEB0BA').width('100%').textAlign(TextAlign.Start).margin({ top: 12 })
          TextInput({ placeholder: '章节正则', text: this.chapterRegex })
            .fontSize(LABEL_LARGE).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
            .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary)).borderRadius(12).padding(12).width('100%')
            .onChange((value: string) => { this.chapterRegex = value; this.clearRuleTest(); })
          Text('示例').fontSize(LABEL_LARGE_EMPHASIZED).fontColor('#AEB0BA').width('100%').textAlign(TextAlign.Start).margin({ top: 12 })
          TextArea({ placeholder: '示例', text: this.exampleText })
            .fontSize(LABEL_LARGE).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
            .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary)).borderRadius(12).height(96).padding(12).width('100%')
            .onChange((value: string) => { this.exampleText = value; this.clearRuleTest(); })
          Text('分卷正则').fontSize(LABEL_LARGE_EMPHASIZED).fontColor('#AEB0BA').width('100%').textAlign(TextAlign.Start).margin({ top: 12 })
          TextInput({ placeholder: '分卷正则', text: this.volumeRegex })
            .fontSize(LABEL_LARGE).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
            .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary)).borderRadius(12).padding(12).width('100%')
            .onChange((value: string) => { this.volumeRegex = value; this.clearRuleTest(); })
          if (this.testHasRun) {
            if (this.testError.length > 0) {
              Text(this.testError).fontSize(TITLE_SMALL).fontColor('#FF8A80').width('100%').textAlign(TextAlign.Start).margin({ top: 14 })
            } else {
              Text(`${this.testResults.filter((item: TxtRuleTestLine) => item.matched).length} / ${this.testResults.length}`)
                .fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).width('100%').textAlign(TextAlign.Start).margin({ top: 14, bottom: 6 })
              ForEach(this.testResults, (item: TxtRuleTestLine, index: number) => {
                Row() {
                  AppGlyph({ name: item.matched ? 'profileCheck' : 'profileClose', glyphSize: 18,
                    tint: item.matched ? this.themeColorAccent : '#FF8A80' }).margin({ right: 8 })
                  Text(item.line.length > 0 ? item.line : '（空行）').fontSize(LABEL_MEDIUM)
                    .fontColor(item.matched ? this.themeColorTextSecondary : this.themeColorTextTertiary).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }.width('100%')
              }, (item: TxtRuleTestLine, index: number) => `txt_rule_test_${index}`)
            }
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, bottom: 18 })
      }.edgeEffect(EdgeEffect.None).layoutWeight(1).scrollBar(BarState.Off)
      Row() {
        Row() {
          AppGlyph({ name: 'profileRunningWithErrors', glyphSize: 20, tint: this.themeColorTextPrimary })
          Text('测试').fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary).margin({ left: 7 })
        }.padding({ left: 14, right: 14, top: 10, bottom: 10 }).backgroundColor('#34353D').borderRadius(22)
          .onClick(() => this.runRuleTest())
        if (this.showPasteAuthorization) {
          PasteButton({ text: PasteDescription.PASTE, buttonType: ButtonType.Capsule })
            .onClick(async (_event: ClickEvent, result: PasteButtonOnClickResult) => {
              await this.pasteRuleFromClipboard(result);
            })
        }
        Blank()
        Row() {
          AppGlyph({ name: 'profileSave', glyphSize: 18, tint: this.themeColorTextPrimary })
        }.width(44).height(44).justifyContent(FlexAlign.Center).backgroundColor(this.themeColorAccent).borderRadius(22)
          .onClick(async () => {
            const emptyDefaultRule = this.ruleName.trim() === '默认分章规则' && this.chapterRegex.trim().length === 0;
            if (this.ruleName.trim().length === 0 || (this.chapterRegex.trim().length === 0 && !emptyDefaultRule)) {
              this.onUnavailableAction('名称和章节正则不能为空');
            } else if (!this.isValidRegex(this.chapterRegex)) {
              this.onUnavailableAction('正则格式无效，规则未保存');
            } else if (this.volumeRegex.trim().length > 0 && !this.isValidRegex(this.volumeRegex)) {
              this.onUnavailableAction('分卷正则格式无效，规则未保存');
            } else {
              const existing: TxtTocRule | undefined = this.editingExisting
                ? this.sourceRules.find((rule: TxtTocRule) => rule.id === this.editingRuleId) : undefined;
              await this.onSaveRule({
                id: this.editingExisting ? this.editingRuleId : Date.now(),
                name: this.ruleName.trim(),
                chapterRule: this.chapterRegex.trim(),
                volumeRule: this.volumeRegex.trim(),
                example: this.exampleText.length > 0 ? this.exampleText : undefined,
                // 编辑已有规则时沿用原序号，新建的排在末尾由仓储重排。
                serialNumber: existing?.serialNumber ?? -1,
                enable: existing?.enable ?? true
              });
              this.showAddRule = false;
            }
          })
      }.width('100%').justifyContent(FlexAlign.End).padding({ left: 16, right: 16, top: 10, bottom: 18 })
    }.width('100%').height('100%')
  }

  /** 打开编辑面板并回填已有规则；id 无效时按新建处理。 */
  private openEditor(id: string): void {
    const numericId = Number(id);
    const rule: TxtTocRule | undefined = Number.isInteger(numericId)
      ? this.sourceRules.find((item: TxtTocRule) => item.id === numericId) : undefined;
    if (rule === undefined) {
      this.onUnavailableAction('该规则已不存在');
      return;
    }
    this.editingRuleId = rule.id;
    this.editingExisting = true;
    this.ruleName = rule.name;
    this.chapterRegex = rule.chapterRule;
    this.exampleText = rule.example ?? '';
    this.volumeRegex = rule.volumeRule;
    this.clearRuleTest();
    this.showAddRule = true;
  }

  /** 打开新建面板，清空编辑态。 */
  private openCreator(): void {
    this.editingRuleId = -1;
    this.editingExisting = false;
    this.ruleName = '';
    this.chapterRegex = '';
    this.exampleText = '';
    this.volumeRegex = '';
    this.clearRuleTest();
    this.showAddRule = true;
  }

  build() {
    Column() {
      Blank().height(32)
      Row() {
        Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.themeColorTextSecondary)
          .width(36).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        AppGlyph({ name: 'search', glyphSize: 19, tint: this.themeColorTextSecondary }).padding({ left: 8, right: 8 })
          .onClick(() => {
            this.showSearch = !this.showSearch;
            if (!this.showSearch) { this.searchQuery = ''; }
          })
          .accessibilityText('搜索')
        AppGlyph({ name: 'more', glyphSize: 18, tint: this.themeColorTextSecondary }).padding({ left: 6, right: 8 })
          .onClick(() => { this.importMenuVisible = !this.importMenuVisible; })
          .accessibilityText('更多菜单')
.bindPopup(this.importMenuVisible, {
  builder: this.ImportMenu,
  placement: Placement.BottomRight,
  popupColor: '#00000000',
  enableArrow: false,
  autoCancel: true,
  width: PROFILE_MENU_WIDTH,
  onStateChange: (event: PopupStateChangeParam) => { this.importMenuVisible = event.isVisible; }
})
      }.width('100%').height(40).padding({ left: 18, right: 18 })
      Row() {
        Text(this.selectionMode ? `已选择 ${this.selectedRuleIds.length} 项` : 'TXT 目录规则')
          .fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
      }.width('100%').padding({ left: 18, right: 18, top: 12 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '搜索 TXT 目录规则', text: this.searchQuery })
            .fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).placeholderColor(this.themeColorTextTertiary)
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .id('my_txt_toc_search')
            .onAppear(() => focusControl.requestFocus('my_txt_toc_search'))
            .onChange((value: string) => this.searchQuery = value)
        }.width('calc(100% - 32vp)').height(48).padding({ left: 14, right: 14 })
          .margin({ left: 16, right: 16, top: 8, bottom: 4 }).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(24)
      }

      if (this.selectionMode) {
        Row() {
          Text(this.selectedRuleIds.length === 0 ? '取消' : `已选择 ${this.selectedRuleIds.length} 项`)
            .fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).layoutWeight(1)
            .onClick(() => this.exitSelection())
          Text('全选').fontSize(TITLE_SMALL).fontColor(this.themeColorAccent).padding({ left: 10, right: 10 })
            .onClick(() => this.selectAllVisible())
          Text('反选').fontSize(TITLE_SMALL).fontColor(this.themeColorAccent).padding({ left: 0, right: 10 })
            .onClick(() => this.invertSelection())
        }.width('100%').padding({ left: 18, right: 18, top: 8, bottom: 4 })
        Row() {
          Text('启用').fontSize(TITLE_SMALL)
            .fontColor(this.selectedRuleIds.length > 0 ? this.themeColorAccent : '#5C5E68')
            .onClick(() => this.submitBatchEnabled(true))
          Text('停用').fontSize(TITLE_SMALL).margin({ left: 18 })
            .fontColor(this.selectedRuleIds.length > 0 ? this.themeColorAccent : '#5C5E68')
            .onClick(() => this.submitBatchEnabled(false))
          Text('导出').fontSize(TITLE_SMALL).margin({ left: 18 })
            .fontColor(this.selectedRuleIds.length > 0 ? this.themeColorAccent : '#5C5E68')
            .onClick(() => this.submitBatchExport())
          Blank().layoutWeight(1)
          Text('删除').fontSize(TITLE_SMALL)
            .fontColor(this.selectedRuleIds.length > 0 ? '#D99AA5' : '#5C5E68')
            .onClick(() => this.requestDelete(this.selectedNumericIds()))
        }.width('100%').padding({ left: 18, right: 18, top: 2, bottom: 10 })
      }
      RuleListBody({
        rules: this.rules, query: this.searchQuery, selectedIds: this.selectedRuleIds,
        selectionMode: this.selectionMode, sortMode: this.sortMode, emptyMessage: '暂无 TXT 目录规则',
        onOpen: (id: string) => this.openEditor(id),
        onToggle: (id: string) => this.toggleSelectedRule(id),
        onLongSelect: (id: string) => { this.selectionMode = true; this.selectedRuleIds = [id]; },
        onMove: (id: string, direction: number) => {
          const numericId = Number(id);
          if (Number.isInteger(numericId)) {
            this.onMoveRule(numericId, direction);
          }
        },
        onEnabledChange: (id: string, enabled: boolean) => {
          const numericId = Number(id);
          if (Number.isInteger(numericId)) {
            this.onToggleRule(numericId, enabled);
          }
        },
        onMoveToEdge: (id: string, toTop: boolean) => {
          const numericId = Number(id);
          if (Number.isInteger(numericId)) {
            this.onMoveRuleToEdge(numericId, toTop);
          }
        },
        onDelete: (id: string) => {
          const numericId = Number(id);
          if (Number.isInteger(numericId)) {
            this.requestDelete([numericId]);
          }
        }
      }).layoutWeight(1)
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'add', glyphSize: 24, tint: this.themeColorTextPrimary })
        }.width(56).height(56).backgroundColor(this.themeColorAccent).borderRadius(28)
          .onClick(() => this.openCreator())
      }.width('100%').justifyContent(FlexAlign.End).padding({ right: 16, top: 8, bottom: 16 })
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      .bindSheet(this.showAddRule, this.ruleEditorSheet(), {
        height: 620,
        dragBar: true,
        showClose: false,
        backgroundColor: this.themeColorSurfaceElevated,
        onDisappear: () => this.showAddRule = false
      })
      .bindSheet(this.confirmSheet === 'confirmDelete', this.DeleteConfirmSheet(), {
        // 删除确认只有几行文字，用内容自适应高度，避免半屏空白。
        height: SheetSize.FIT_CONTENT,
        dragBar: true,
        showClose: false,
        backgroundColor: '#17181E',
        onDisappear: () => this.confirmSheet = ''
      })
  }

  /**
   * 删除确认面板：批量删除与条目菜单的单条删除共用，确认前不动数据。
   * 与上游 RuleListScaffold.kt:75-86 的 AppAlertDialog 语义一致。
   */
  @Builder
  private DeleteConfirmSheet() {
    Column() {
      Text('删除规则').fontSize(HEADLINE_SMALL).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        .width('100%').padding({ left: 18, right: 18, top: 16, bottom: 10 })
      Text(this.pendingDeleteIds.length > 1
        ? `确定删除选中的 ${this.pendingDeleteIds.length} 条目录规则？删除后可通过导入恢复。`
        : '确定删除这条目录规则？删除后可通过导入恢复。')
        .fontSize(TITLE_SMALL).fontColor(this.themeColorTextTertiary)
        .width('100%').padding({ left: 18, right: 18, bottom: 20 })
      Row() {
        Text('取消').fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary).layoutWeight(1).textAlign(TextAlign.Center)
          .padding({ top: 14, bottom: 14 })
          .onClick(() => this.cancelDelete())
        Text('删除').fontSize(LABEL_LARGE).fontColor('#D99AA5').layoutWeight(1).textAlign(TextAlign.Center)
          .padding({ top: 14, bottom: 14 })
          .onClick(() => this.confirmDelete())
      }.width('100%').padding({ left: 8, right: 8, bottom: 12 })
    }.width('100%').alignItems(HorizontalAlign.Start).backgroundColor('#17181E')
  }

  private isValidRegex(pattern: string): boolean {
    return TxtTocRuleRepository.isValidRegex(pattern, 'm');
  }
}

interface TxtRuleMatchRange {
  start: number;
  end: number;
}

interface TxtRuleTestLine {
  line: string;
  matched: boolean;
}

interface TxtRuleClipboardData {
  name?: string;
  chapterRule?: string;
  rule?: string;
  volumeRule?: string;
  example?: string | null;
}

@Component
export struct DictionaryRulesPage {
  @State ruleEditorMenuVisible: boolean = false;
  @State importMenuVisible: boolean = false;
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('appTopInset') appTopInset: number = 0;
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onOpenEditor: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @Prop rules: RuleListEntry[] = [];
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State selectionMode: boolean = false;
  @State selectedRuleIds: string[] = [];
  @State sortMode: boolean = false;
  @State showRuleEditor: boolean = false;
  @State ruleName: string = '';
  @State urlRule: string = '';
  @State showRule: string = '';
  @State showPasteAuthorization: boolean = false;

  @Builder
  private RuleEditorMenu() {
    UiMenuPanel({
      items: this.dictEditorMenuItems(),
      panelWidth: PROFILE_MENU_WIDTH,
      onSelect: (key: string) => { this.ruleEditorMenuVisible = false; this.onDictEditorMenuSelect(key); }
    })
  }

  private dictEditorMenuItems(): UiMenuItem[] {
    return [
      { key: 'copy', title: '复制规则' },
      { key: 'paste', title: '粘贴规则' }
    ];
  }

  private onDictEditorMenuSelect(key: string): void {
    if (key === 'copy') {
      this.copyDictionaryRule();
    } else if (key === 'paste') {
      this.showPasteAuthorization = true;
    }
  }

  private async copyDictionaryRule(): Promise<void> {
    try {
      const value = JSON.stringify({ name: this.ruleName, urlRule: this.urlRule,
        showRule: this.showRule, enabled: true, sortNumber: 0 });
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, value);
      await pasteboard.getSystemPasteboard().setData(data);
      this.onUnavailableAction('规则已复制到剪贴板');
    } catch (_error) {
      this.onUnavailableAction('复制规则失败');
    }
  }

  private async pasteDictionaryRule(result: PasteButtonOnClickResult): Promise<void> {
    this.showPasteAuthorization = false;
    if (result !== PasteButtonOnClickResult.SUCCESS) {
      this.onUnavailableAction('未获得读取剪贴板授权');
      return;
    }
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      if (data.getRecordCount() === 0) {
        this.onUnavailableAction('剪贴板为空');
        return;
      }
      const parsed: DictionaryRuleClipboardData = JSON.parse(data.getRecord(0).toPlainText());
      if (typeof parsed.name !== 'string' || typeof parsed.urlRule !== 'string' ||
        typeof parsed.showRule !== 'string') {
        this.onUnavailableAction('剪贴板规则格式无效');
        return;
      }
      this.ruleName = parsed.name;
      this.urlRule = parsed.urlRule;
      this.showRule = parsed.showRule;
      this.onUnavailableAction('规则已从剪贴板填入');
    } catch (_error) {
      this.onUnavailableAction('剪贴板规则格式无效');
    }
  }

  @Builder
  private DictionaryEditorField(label: string, value: string, field: string, multiline: boolean = false) {
    Column() {
      Text(label).fontSize(LABEL_LARGE_EMPHASIZED).fontColor('#C3C5CD').margin({ left: 14, bottom: 3 })
      if (multiline) {
        TextArea({ placeholder: '', text: value }).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary)
          .height(120).backgroundColor('#24252C').borderRadius(8)
          .padding({ left: 14, right: 14, top: 14 }).width('100%')
          .onChange((text: string) => this.updateDictionaryField(field, text))
      } else {
        TextInput({ placeholder: '', text: value }).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary)
          .height(54).backgroundColor('#24252C').borderRadius(8)
          .padding({ left: 14, right: 14 }).width('100%')
          .onChange((text: string) => this.updateDictionaryField(field, text))
      }
    }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 10 })
  }

  private updateDictionaryField(field: string, value: string): void {
    if (field === 'name') { this.ruleName = value; }
    else if (field === 'urlRule') { this.urlRule = value; }
    else { this.showRule = value; }
  }

  private openRuleEditor(): void {
    this.ruleName = '';
    this.urlRule = '';
    this.showRule = '';
    this.showPasteAuthorization = false;
    this.showRuleEditor = true;
  }

  @Builder
  private DictionaryRuleSheet() {
    Column() {
      Row() {
        Text('字典规则').fontSize(HEADLINE_SMALL).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileClose', glyphSize: 20, tint: this.themeColorTextSecondary })
        }.width(40).height(40).onClick(() => this.showRuleEditor = false)
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'more', glyphSize: 19, tint: this.themeColorTextSecondary })
                }.width(40).height(40)
          .onClick(() => { this.ruleEditorMenuVisible = !this.ruleEditorMenuVisible; })
.bindPopup(this.ruleEditorMenuVisible, {
  builder: this.RuleEditorMenu,
  placement: Placement.BottomRight,
  popupColor: '#00000000',
  enableArrow: false,
  autoCancel: true,
  width: PROFILE_MENU_WIDTH,
  onStateChange: (event: PopupStateChangeParam) => { this.ruleEditorMenuVisible = event.isVisible; }
})
      }.width('100%').padding({ left: 18, right: 12, top: 12, bottom: 10 })
      Scroll() {
        Column() {
          this.DictionaryEditorField('名称', this.ruleName, 'name')
          this.DictionaryEditorField('Url规则 (urlRule)', this.urlRule, 'urlRule')
          this.DictionaryEditorField('显示规则 (showRule)', this.showRule, 'showRule', true)
        }.width('100%').alignItems(HorizontalAlign.Start)
          .padding({ left: 16, right: 16, top: 4, bottom: 120 })
      }.edgeEffect(EdgeEffect.None).layoutWeight(1).scrollBar(BarState.Off)
      Row() {
        if (this.showPasteAuthorization) {
          PasteButton({ text: PasteDescription.PASTE, buttonType: ButtonType.Capsule })
            .onClick(async (_event: ClickEvent, result: PasteButtonOnClickResult) =>
              await this.pasteDictionaryRule(result))
        }
        Blank()
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileSave', glyphSize: 20, tint: this.themeColorAccent })
        }.width(50).height(50).backgroundColor('#454F70').borderRadius(14)
          .onClick(() => this.onUnavailableAction('字典规则存储尚未接入，规则未保存'))
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 14 })
    }.width('100%').height('100%').backgroundColor('#17181E')
  }

  @Builder
  private ImportMenu() {
    UiMenuPanel({
      items: this.dictImportItems(),
      panelWidth: PROFILE_MENU_WIDTH,
      onSelect: (key: string) => { this.importMenuVisible = false; this.onDictImportSelect(key); }
    })
  }

  private dictImportItems(): UiMenuItem[] {
    return [
      { key: 'sort', title: '排序' },
      { key: 'selection', title: '选择模式' },
      { key: 'import', title: '导入' }
    ];
  }

  private onDictImportSelect(key: string): void {
    if (key === 'sort') {
      this.sortMode = !this.sortMode;
    } else if (key === 'selection') {
      this.selectionMode = !this.selectionMode;
      this.selectedRuleIds = [];
    } else if (key === 'import') {
      this.onUnavailableAction('字典规则导入尚未接入，未导入任何数据');
    }
  }

  private toggleSelectedRule(id: string): void {
    this.selectedRuleIds = this.selectedRuleIds.includes(id) ?
      this.selectedRuleIds.filter((selectedId: string) => selectedId !== id) : [...this.selectedRuleIds, id];
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
          Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.themeColorTextSecondary)
        }.width(40).height(40).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
          AppGlyph({ name: 'search', glyphSize: 20, tint: this.themeColorTextSecondary })
        }.width(40).height(40)
          .onClick(() => {
            this.showSearch = !this.showSearch;
            if (!this.showSearch) { this.searchQuery = ''; }
          })
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
          AppGlyph({ name: 'more', glyphSize: 20, tint: this.themeColorTextSecondary })
        }.width(40).height(40)
          .onClick(() => { this.importMenuVisible = !this.importMenuVisible; })
.bindPopup(this.importMenuVisible, {
  builder: this.ImportMenu,
  placement: Placement.BottomRight,
  popupColor: '#00000000',
  enableArrow: false,
  autoCancel: true,
  width: PROFILE_MENU_WIDTH,
  onStateChange: (event: PopupStateChangeParam) => { this.importMenuVisible = event.isVisible; }
})
      }.width('100%').height(40).padding({ left: 11, right: 12 })
        .margin({ top: this.appTopInset - 8 })

      Text(this.selectionMode ? `已选择 ${this.selectedRuleIds.length} 项` : '字典规则')
        .fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor(this.themeColorTextPrimary)
        .width('100%').padding({ left: 12, right: 18, top: 12 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '搜索字典规则', text: this.searchQuery })
            .fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).placeholderColor(this.themeColorTextTertiary)
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .id('my_dictionary_rule_search')
            .onAppear(() => focusControl.requestFocus('my_dictionary_rule_search'))
            .onChange((value: string) => this.searchQuery = value)
        }.width('calc(100% - 32vp)').height(48).padding({ left: 14, right: 14 })
          .margin({ left: 16, right: 16, top: 8, bottom: 4 }).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(24)
      }

      if (this.selectionMode && this.selectedRuleIds.length > 0) {
        Row() {
          Text('全选').fontSize(TITLE_SMALL).fontColor(this.themeColorAccent).onClick(() =>
            this.selectedRuleIds = this.rules.map((rule: RuleListEntry) => rule.id))
          Text('删除').fontSize(TITLE_SMALL).fontColor('#F0A6A6').margin({ left: 18 })
            .onClick(() => this.onUnavailableAction('字典规则删除尚未迁移，未更改数据'))
        }.width('100%').padding({ left: 18, right: 18, top: 8, bottom: 8 })
      }
      RuleListBody({
        rules: this.rules, query: this.searchQuery, selectedIds: this.selectedRuleIds,
        selectionMode: this.selectionMode, sortMode: this.sortMode, emptyMessage: '暂无字典规则',
        onOpen: (_id: string) => this.onUnavailableAction('现有字典规则编辑尚未接入'),
        onToggle: (id: string) => this.toggleSelectedRule(id),
        onLongSelect: (id: string) => { this.selectionMode = true; this.selectedRuleIds = [id]; },
        onMove: (_id: string, _direction: number) => this.onUnavailableAction('字典规则排序尚未迁移')
      }).layoutWeight(1)
      Stack({ alignContent: Alignment.Center }) {
        AppGlyph({ name: 'add', glyphSize: 22, tint: this.themeColorAccent })
      }.width(50).height(50).backgroundColor('#454F70').borderRadius(14)
        .onClick(() => this.openRuleEditor())
        .margin({ right: 16, bottom: 16 }).alignSelf(ItemAlign.End)
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      .bindSheet(this.showRuleEditor, this.DictionaryRuleSheet(), {
        height: SheetSize.LARGE,
        dragBar: true,
        showClose: false,
        backgroundColor: '#17181E',
        onDisappear: () => { this.showRuleEditor = false; this.showPasteAuthorization = false; }
      })
  }
}

interface DictionaryRuleClipboardData {
  name?: string;
  urlRule?: string;
  showRule?: string;
  enabled?: boolean;
  sortNumber?: number;
}

@Component
export struct DictionaryRuleEditPage {
  @State ruleActionsMenuVisible: boolean = false;
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('appTopInset') appTopInset: number = 0;
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State name: string = '';
  @State urlRule: string = '';
  @State showRule: string = '';
  @State showPasteAuthorization: boolean = false;

  @Builder
  private RuleActionsMenu() {
    UiMenuPanel({
      items: this.dictEditActionItems(),
      panelWidth: PROFILE_MENU_WIDTH,
      onSelect: (key: string) => { this.ruleActionsMenuVisible = false; this.onDictEditActionSelect(key); }
    })
  }

  private dictEditActionItems(): UiMenuItem[] {
    return [
      { key: 'copy', title: '复制规则' },
      { key: 'paste', title: '粘贴规则' }
    ];
  }

  private onDictEditActionSelect(key: string): void {
    if (key === 'copy') {
      this.copyRule();
    } else if (key === 'paste') {
      this.showPasteAuthorization = true;
    }
  }

  private clipboardJson(): string {
    return JSON.stringify({
      name: this.name,
      urlRule: this.urlRule,
      showRule: this.showRule,
      enabled: true,
      sortNumber: 0
    });
  }

  private async copyRule(): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.clipboardJson());
      await pasteboard.getSystemPasteboard().setData(data);
      this.onUnavailableAction('规则已复制到剪贴板');
    } catch (_error) {
      this.onUnavailableAction('复制规则失败');
    }
  }

  private async pasteRule(result: PasteButtonOnClickResult): Promise<void> {
    this.showPasteAuthorization = false;
    if (result !== PasteButtonOnClickResult.SUCCESS) {
      this.onUnavailableAction('未获得读取剪贴板授权');
      return;
    }
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      if (data.getRecordCount() === 0) {
        this.onUnavailableAction('剪贴板为空');
        return;
      }
      const parsed: DictionaryRuleClipboardData = JSON.parse(data.getRecord(0).toPlainText());
      if (typeof parsed.name !== 'string' || typeof parsed.urlRule !== 'string' ||
        typeof parsed.showRule !== 'string') {
        this.onUnavailableAction('剪贴板规则格式无效');
        return;
      }
      this.name = parsed.name;
      this.urlRule = parsed.urlRule;
      this.showRule = parsed.showRule;
      this.onUnavailableAction('规则已从剪贴板填入');
    } catch (_error) {
      this.onUnavailableAction('剪贴板规则格式无效');
    }
  }

  @Builder
  private RuleField(label: string, value: string, field: string, multiline: boolean = false) {
    Column() {
      Text(label).fontSize(LABEL_LARGE_EMPHASIZED).fontColor('#C3C5CD').margin({ left: 14, bottom: 3 })
      if (multiline) {
        TextArea({ placeholder: '', text: value })
          .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
          .height(120).backgroundColor('#24252C').borderRadius(8).padding({ left: 14, right: 14, top: 14 })
          .width('100%').onChange((text: string) => this.updateField(field, text))
      } else {
        TextInput({ placeholder: '', text: value })
          .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
          .height(58).backgroundColor('#24252C').borderRadius(8).padding({ left: 14, right: 14 })
          .width('100%').onChange((text: string) => this.updateField(field, text))
      }
      Row().width('100%').height(1).backgroundColor('#898B94')
    }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 12 })
  }

  private updateField(field: string, value: string): void {
    if (field === 'name') { this.name = value; }
    else if (field === 'urlRule') { this.urlRule = value; }
    else { this.showRule = value; }
  }

  private saveRule(): void {
    if (this.name.trim().length === 0) {
      this.onUnavailableAction('名称不能为空');
      return;
    }
    this.onUnavailableAction('字典规则存储尚未接入，规则未保存');
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
          AppGlyph({ name: 'profileClose', glyphSize: 20, tint: this.themeColorTextSecondary })
        }.width(40).height(40).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
          AppGlyph({ name: 'more', glyphSize: 20, tint: this.themeColorTextSecondary })
                }.width(40).height(40)
          .onClick(() => { this.ruleActionsMenuVisible = !this.ruleActionsMenuVisible; })
.bindPopup(this.ruleActionsMenuVisible, {
  builder: this.RuleActionsMenu,
  placement: Placement.BottomRight,
  popupColor: '#00000000',
  enableArrow: false,
  autoCancel: true,
  width: PROFILE_MENU_WIDTH,
  onStateChange: (event: PopupStateChangeParam) => { this.ruleActionsMenuVisible = event.isVisible; }
})
      }.width('100%').height(40).padding({ left: 11, right: 12 }).margin({ top: this.appTopInset - 8 })
      Text('字典规则').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor(this.themeColorTextPrimary)
        .width('100%').padding({ left: 14, right: 0, top: 12 })
      Scroll() {
        Column() {
          this.RuleField('名称', this.name, 'name')
          this.RuleField('Url规则 (urlRule)', this.urlRule, 'urlRule')
          this.RuleField('显示规则 (showRule)', this.showRule, 'showRule', true)
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, top: 0, bottom: 140 })
          .layoutWeight(1)
      }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).layoutWeight(1).scrollBar(BarState.Off)
      Row() {
        if (this.showPasteAuthorization) {
          PasteButton({ text: PasteDescription.PASTE, buttonType: ButtonType.Capsule })
            .onClick(async (_event: ClickEvent, result: PasteButtonOnClickResult) => await this.pasteRule(result))
        }
        Blank()
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileSave', glyphSize: 20, tint: this.themeColorAccent })
        }.width(50).height(50).backgroundColor('#454F70').borderRadius(14).onClick(() => this.saveRule())
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 16 })
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
  }
}

@Component
export struct HighlightTagRulesPage {
  @State tagEditorMenuVisible: boolean = false;
  @State importMenuVisible: boolean = false;
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('appTopInset') appTopInset: number = 0;
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onOpenEditor: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @Prop rules: RuleListEntry[] = [];
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State selectionMode: boolean = false;
  @State selectedRuleIds: string[] = [];
  @State sortMode: boolean = false;
  @State showRuleEditor: boolean = false;
  @State draftTitle: string = '';
  @State draftPattern: string = '';
  @State draftEnabled: boolean = true;
  @State showPasteAuthorization: boolean = false;

  @Builder
  private ImportMenu() {
    UiMenuPanel({
      items: this.tagImportItems(),
      panelWidth: PROFILE_MENU_WIDTH,
      onSelect: (key: string) => { this.importMenuVisible = false; this.onTagImportSelect(key); }
    })
  }

  private tagImportItems(): UiMenuItem[] {
    return [
      { key: 'sort', title: '排序' },
      { key: 'selection', title: '选择模式' },
      { key: 'import', title: '导入' }
    ];
  }

  private onTagImportSelect(key: string): void {
    if (key === 'sort') {
      this.sortMode = !this.sortMode;
    } else if (key === 'selection') {
      this.selectionMode = !this.selectionMode;
      this.selectedRuleIds = [];
    } else if (key === 'import') {
      this.onUnavailableAction('标签规则导入尚未接入，未导入任何数据');
    }
  }

  private toggleSelectedRule(id: string): void {
    this.selectedRuleIds = this.selectedRuleIds.includes(id) ?
      this.selectedRuleIds.filter((selectedId: string) => selectedId !== id) : [...this.selectedRuleIds, id];
  }

  @Builder
  private TagEditorMenu() {
    UiMenuPanel({
      items: this.tagEditorMenuItems(),
      panelWidth: PROFILE_MENU_WIDTH,
      onSelect: (key: string) => { this.tagEditorMenuVisible = false; this.onTagEditorMenuSelect(key); }
    })
  }

  private tagEditorMenuItems(): UiMenuItem[] {
    return [
      { key: 'copy', title: '复制规则' },
      { key: 'paste', title: '粘贴规则' }
    ];
  }

  private onTagEditorMenuSelect(key: string): void {
    if (key === 'copy') {
      this.copyTagRule();
    } else if (key === 'paste') {
      this.showPasteAuthorization = true;
    }
  }

  private async copyTagRule(): Promise<void> {
    try {
      const value = JSON.stringify({ id: Date.now(), title: this.draftTitle,
        pattern: this.draftPattern, enabled: this.draftEnabled, order: 0 });
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, value);
      await pasteboard.getSystemPasteboard().setData(data);
      this.onUnavailableAction('规则已复制到剪贴板');
    } catch (_error) {
      this.onUnavailableAction('复制规则失败');
    }
  }

  private async pasteTagRule(result: PasteButtonOnClickResult): Promise<void> {
    this.showPasteAuthorization = false;
    if (result !== PasteButtonOnClickResult.SUCCESS) {
      this.onUnavailableAction('未获得读取剪贴板授权');
      return;
    }
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      if (data.getRecordCount() === 0) {
        this.onUnavailableAction('剪贴板没有内容');
        return;
      }
      const parsed: HighlightTagRuleClipboardData = JSON.parse(data.getRecord(0).toPlainText());
      if (typeof parsed.title !== 'string' || typeof parsed.pattern !== 'string' ||
        (parsed.enabled !== undefined && typeof parsed.enabled !== 'boolean')) {
        this.onUnavailableAction('剪贴板规则格式无效');
        return;
      }
      this.draftTitle = parsed.title;
      this.draftPattern = parsed.pattern;
      this.draftEnabled = parsed.enabled !== false;
      this.onUnavailableAction('规则已从剪贴板填入');
    } catch (_error) {
      this.onUnavailableAction('剪贴板规则格式无效');
    }
  }

  private openTagRuleEditor(): void {
    this.draftTitle = '';
    this.draftPattern = '';
    this.draftEnabled = true;
    this.showPasteAuthorization = false;
    this.showRuleEditor = true;
  }

  @Builder
  private TagRuleEditorSheet() {
    Column() {
      Row() {
        Text('添加规则').fontSize(HEADLINE_SMALL).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileClose', glyphSize: 20, tint: this.themeColorTextSecondary })
        }.width(40).height(40).onClick(() => this.showRuleEditor = false)
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'more', glyphSize: 19, tint: this.themeColorTextSecondary })
                }.width(40).height(40)
          .onClick(() => { this.tagEditorMenuVisible = !this.tagEditorMenuVisible; })
.bindPopup(this.tagEditorMenuVisible, {
  builder: this.TagEditorMenu,
  placement: Placement.BottomRight,
  popupColor: '#00000000',
  enableArrow: false,
  autoCancel: true,
  width: PROFILE_MENU_WIDTH,
  onStateChange: (event: PopupStateChangeParam) => { this.tagEditorMenuVisible = event.isVisible; }
})
      }.width('100%').padding({ left: 18, right: 12, top: 12, bottom: 10 })
      Scroll() {
        Column() {
          Text('标题（可选）').fontSize(LABEL_LARGE_EMPHASIZED).fontColor('#C3C5CD').margin({ left: 14, bottom: 3 })
          TextInput({ placeholder: '', text: this.draftTitle }).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary)
            .height(54).backgroundColor('#24252C').borderRadius(8)
            .padding({ left: 14, right: 14 }).width('100%')
            .onChange((value: string) => this.draftTitle = value)
          Text('匹配规则').fontSize(LABEL_LARGE_EMPHASIZED).fontColor('#C3C5CD').margin({ left: 14, bottom: 3, top: 8 })
          TextArea({ placeholder: '', text: this.draftPattern }).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary)
            .height(120).backgroundColor('#24252C').borderRadius(8)
            .padding({ left: 14, right: 14, top: 14 }).width('100%')
            .onChange((value: string) => this.draftPattern = value)
          Row() {
            Text('已启用').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).layoutWeight(1)
            UiSwitchControl({
              checked: this.draftEnabled,
              interactive: false,
              onChange: (value: boolean) => this.draftEnabled = value
            })
          }.width('100%').padding({ top: 12, bottom: 12 })
            .onClick(() => this.draftEnabled = !this.draftEnabled)
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, bottom: 120 })
      }.edgeEffect(EdgeEffect.None).layoutWeight(1).scrollBar(BarState.Off)
      Row() {
        if (this.showPasteAuthorization) {
          PasteButton({ text: PasteDescription.PASTE, buttonType: ButtonType.Capsule })
            .onClick(async (_event: ClickEvent, result: PasteButtonOnClickResult) =>
              await this.pasteTagRule(result))
        }
        Blank()
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileSave', glyphSize: 20, tint: this.themeColorAccent })
        }.width(50).height(50).backgroundColor('#454F70').borderRadius(14)
          .onClick(() => this.onUnavailableAction('标签规则存储尚未接入，规则未保存'))
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 14 })
    }.width('100%').height('100%').backgroundColor('#17181E')
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
          Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.themeColorTextSecondary)
        }.width(40).height(40).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
          AppGlyph({ name: 'search', glyphSize: 20, tint: this.themeColorTextSecondary })
        }.width(40).height(40)
          .onClick(() => {
            this.showSearch = !this.showSearch;
            if (!this.showSearch) { this.searchQuery = ''; }
          })
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
          AppGlyph({ name: 'more', glyphSize: 20, tint: this.themeColorTextSecondary })
                }.width(40).height(40)
          .onClick(() => { this.importMenuVisible = !this.importMenuVisible; })
.bindPopup(this.importMenuVisible, {
  builder: this.ImportMenu,
  placement: Placement.BottomRight,
  popupColor: '#00000000',
  enableArrow: false,
  autoCancel: true,
  width: PROFILE_MENU_WIDTH,
  onStateChange: (event: PopupStateChangeParam) => { this.importMenuVisible = event.isVisible; }
})
      }.width('100%').height(40).padding({ left: 11, right: 12 }).margin({ top: this.appTopInset - 8 })

      Text(this.selectionMode ? `已选择 ${this.selectedRuleIds.length} 项` : '标签规则')
        .fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor(this.themeColorTextPrimary)
        .width('100%').padding({ left: 12, right: 18, top: 12 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '搜索标签规则', text: this.searchQuery })
            .fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).placeholderColor(this.themeColorTextTertiary)
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .id('my_highlight_tag_search')
            .onAppear(() => focusControl.requestFocus('my_highlight_tag_search'))
            .onChange((value: string) => this.searchQuery = value)
        }.width('calc(100% - 32vp)').height(48).padding({ left: 14, right: 14 })
          .margin({ left: 16, right: 16, top: 8, bottom: 4 }).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(24)
      }

      if (this.selectionMode && this.selectedRuleIds.length > 0) {
        Row() {
          Text('全选').fontSize(TITLE_SMALL).fontColor(this.themeColorAccent).onClick(() =>
            this.selectedRuleIds = this.rules.map((rule: RuleListEntry) => rule.id))
          Text('删除').fontSize(TITLE_SMALL).fontColor('#F0A6A6').margin({ left: 18 })
            .onClick(() => this.onUnavailableAction('标签规则删除尚未迁移，未更改数据'))
        }.width('100%').padding({ left: 18, right: 18, top: 8, bottom: 8 })
      }
      RuleListBody({
        rules: this.rules, query: this.searchQuery, selectedIds: this.selectedRuleIds,
        selectionMode: this.selectionMode, sortMode: this.sortMode, emptyMessage: '暂无标签规则',
        onOpen: (_id: string) => this.onUnavailableAction('现有标签规则编辑尚未接入'),
        onToggle: (id: string) => this.toggleSelectedRule(id),
        onLongSelect: (id: string) => { this.selectionMode = true; this.selectedRuleIds = [id]; },
        onMove: (_id: string, _direction: number) => this.onUnavailableAction('标签规则排序尚未迁移')
      }).layoutWeight(1)
      Stack({ alignContent: Alignment.Center }) {
        AppGlyph({ name: 'add', glyphSize: 22, tint: this.themeColorAccent })
      }.width(50).height(50).backgroundColor('#454F70').borderRadius(14)
        .onClick(() => this.openTagRuleEditor())
        .margin({ right: 16, bottom: 16 }).alignSelf(ItemAlign.End)
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      .bindSheet(this.showRuleEditor, this.TagRuleEditorSheet(), {
        height: SheetSize.LARGE,
        dragBar: true,
        showClose: false,
        backgroundColor: '#17181E',
        onDisappear: () => { this.showRuleEditor = false; this.showPasteAuthorization = false; }
      })
  }
}

interface HighlightTagRuleClipboardData {
  id?: number;
  title?: string;
  pattern?: string;
  enabled?: boolean;
  order?: number;
}

@Component
export struct HighlightTagRuleEditPage {
  @State ruleActionsMenuVisible: boolean = false;
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('appTopInset') appTopInset: number = 0;
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State title: string = '';
  @State pattern: string = '';
  @State ruleEnabled: boolean = true;
  @State showPasteAuthorization: boolean = false;

  @Builder
  private RuleActionsMenu() {
    UiMenuPanel({
      items: this.tagEditActionItems(),
      panelWidth: PROFILE_MENU_WIDTH,
      onSelect: (key: string) => { this.ruleActionsMenuVisible = false; this.onTagEditActionSelect(key); }
    })
  }

  private tagEditActionItems(): UiMenuItem[] {
    return [
      { key: 'copy', title: '复制规则' },
      { key: 'paste', title: '粘贴规则' }
    ];
  }

  private onTagEditActionSelect(key: string): void {
    if (key === 'copy') {
      this.copyRule();
    } else if (key === 'paste') {
      this.showPasteAuthorization = true;
    }
  }

  private clipboardJson(): string {
    return JSON.stringify({ id: Date.now(), title: this.title, pattern: this.pattern, enabled: this.ruleEnabled, order: 0 });
  }

  private async copyRule(): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.clipboardJson());
      await pasteboard.getSystemPasteboard().setData(data);
      this.onUnavailableAction('规则已复制到剪贴板');
    } catch (_error) {
      this.onUnavailableAction('复制规则失败');
    }
  }

  private async pasteRule(result: PasteButtonOnClickResult): Promise<void> {
    this.showPasteAuthorization = false;
    if (result !== PasteButtonOnClickResult.SUCCESS) {
      this.onUnavailableAction('未获得读取剪贴板授权');
      return;
    }
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      if (data.getRecordCount() === 0) {
        this.onUnavailableAction('剪贴板没有内容');
        return;
      }
      const parsed: HighlightTagRuleClipboardData = JSON.parse(data.getRecord(0).toPlainText());
      if (typeof parsed.title !== 'string' || typeof parsed.pattern !== 'string' ||
        (parsed.enabled !== undefined && typeof parsed.enabled !== 'boolean')) {
        this.onUnavailableAction('剪贴板规则格式无效');
        return;
      }
      this.title = parsed.title;
      this.pattern = parsed.pattern;
      this.ruleEnabled = parsed.enabled !== false;
      this.onUnavailableAction('规则已从剪贴板填入');
    } catch (_error) {
      this.onUnavailableAction('剪贴板规则格式无效');
    }
  }

  private saveRule(): void {
    this.onUnavailableAction('标签规则存储尚未接入，规则未保存');
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
          AppGlyph({ name: 'profileClose', glyphSize: 20, tint: this.themeColorTextSecondary })
        }.width(40).height(40).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
          AppGlyph({ name: 'more', glyphSize: 20, tint: this.themeColorTextSecondary })
                }.width(40).height(40)
          .onClick(() => { this.ruleActionsMenuVisible = !this.ruleActionsMenuVisible; })
.bindPopup(this.ruleActionsMenuVisible, {
  builder: this.RuleActionsMenu,
  placement: Placement.BottomRight,
  popupColor: '#00000000',
  enableArrow: false,
  autoCancel: true,
  width: PROFILE_MENU_WIDTH,
  onStateChange: (event: PopupStateChangeParam) => { this.ruleActionsMenuVisible = event.isVisible; }
})
      }.width('100%').height(40).padding({ left: 11, right: 12 }).margin({ top: this.appTopInset - 8 })
      Text('添加规则').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor(this.themeColorTextPrimary)
        .width('100%').padding({ left: 14, right: 0, top: 12 })
      Scroll() {
        Column() {
          Text('标题（可选）').fontSize(LABEL_LARGE_EMPHASIZED).fontColor('#C3C5CD').margin({ left: 14, bottom: 3 })
          TextInput({ placeholder: '', text: this.title })
            .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
            .height(58).backgroundColor('#24252C').borderRadius(8).padding({ left: 14, right: 14 }).width('100%')
            .onChange((value: string) => this.title = value)
          Row().width('100%').height(1).backgroundColor('#898B94').margin({ bottom: 12 })
          Text('匹配规则').fontSize(LABEL_LARGE_EMPHASIZED).fontColor('#C3C5CD').margin({ left: 14, bottom: 3 })
          TextArea({ placeholder: '', text: this.pattern })
            .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
            .height(120).backgroundColor('#24252C').borderRadius(8).padding({ left: 14, right: 14, top: 14 }).width('100%')
            .onChange((value: string) => this.pattern = value)
          Row().width('100%').height(1).backgroundColor('#898B94').margin({ bottom: 12 })
          Row() {
            Text('已启用').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).layoutWeight(1)
            UiSwitchControl({
              checked: this.ruleEnabled,
              interactive: false,
              onChange: (value: boolean) => this.ruleEnabled = value
            })
          }.width('100%').padding({ top: 8, bottom: 8 })
            .onClick(() => this.ruleEnabled = !this.ruleEnabled)
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, bottom: 140 })
          .layoutWeight(1)
      }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).layoutWeight(1).scrollBar(BarState.Off)
      Row() {
        if (this.showPasteAuthorization) {
          PasteButton({ text: PasteDescription.PASTE, buttonType: ButtonType.Capsule })
            .onClick(async (_event: ClickEvent, result: PasteButtonOnClickResult) => await this.pasteRule(result))
        }
        Blank()
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileSave', glyphSize: 20, tint: this.themeColorAccent })
        }.width(50).height(50).backgroundColor('#454F70').borderRadius(14).onClick(() => this.saveRule())
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 16 })
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
  }
}

export interface BookmarkBookSummary {
  key: string;
  title: string;
  author: string;
  bookmarkCount: number;
  noteCount: number;
  /** 本地书籍的书源地址；与条目自带的 sourceUrl 不一致即视为其他书源。 */
  sourceUrl: string;
  /** 书籍封面的显示地址（自定义封面优先）；为空时按 coverColor + coverMark 渲染占位封面。 */
  coverUri: string;
  coverColor: string;
  coverMark: string;
}

export interface BookmarkEntrySummary {
  id: string;
  bookKey: string;
  chapterName: string;
  excerpt: string;
  note: string;
  kind: 'bookmark' | 'note';
  /** 章节序号与章内偏移，用于按正文位置排序（对齐上游 detailItems 的章节序排列）。 */
  chapterIndex: number;
  chapterPosition: number;
  /** 记录里带的书源地址；与当前书籍不一致时显示「其他书源」，对齐上游 marks_other_source。 */
  sourceUrl: string;
}

const BOOKMARK_EMPTY_FACES: string[] = [
  '(；′⌒`)', '(つ﹏⊂)', '(•̀ᴗ•́)و', '(๑•́ ₃ •̀๑)', '(눈‸눈)', '(ಥ﹏ಥ)', '(｡•́︿•̀｡)'
];

@Component
export struct AllBookmarksPage {
  @State exportMenuVisible: boolean = false;
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('appTopInset') appTopInset: number = 0;
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onOpenBookmark: (bookmarkId: string) => void = (_bookmarkId: string) => {};
  /** 打开书签编辑面板；上游 AllBookmarkScreen 点击书签条目即进入编辑。 */
  onEditBookmark: (bookmarkId: string) => void = (_bookmarkId: string) => {};
  /** 打开一条笔记（kind === 'note' 的条目），跳到划线所在位置。 */
  onOpenMarking: (markingId: string) => void = (_markingId: string) => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @Prop books: BookmarkBookSummary[] = [];
  @Prop entries: BookmarkEntrySummary[] = [];
  /** 当前书籍的书源地址，用于判断条目是否来自其他书源。 */
  @Prop currentSourceUrl: string = '';
  /** 导出当前选中书的书签；isMarkdown 为 true 时导出 Markdown。 */
  onExportBookmarks: (bookKey: string, isMarkdown: boolean) => void =
    (_bookKey: string, _isMarkdown: boolean) => {};
  /**
   * 批5（:153）排列方向。
   * 上游书签列表恒升序，没有方向开关；这里按盘面 :153 的形态参考（目录 reverse_toc）补一个
   * 会落盘的开关，值由 Index 持有（偏好读写都在那边），本页只负责按方向排序与切换。
   */
  @Prop sortDescending: boolean = false;
  onToggleSortDescending: () => void = () => {};
  /**
   * 批5（:152）批量删除。书签和笔记在两个仓储里，分开传，各自落盘。
   */
  onDeleteEntries: (bookmarkIds: string[], markingIds: string[]) => void =
    (_bookmarkIds: string[], _markingIds: string[]) => {};
  /** 批5（:152）批量导出：只导出选中的条目，isMarkdown 决定格式。 */
  onExportSelectedEntries: (ids: string[], isMarkdown: boolean) => void =
    (_ids: string[], _isMarkdown: boolean) => {};
  @State selectionMode: boolean = false;
  @State selectedEntryIds: string[] = [];
  @State batchExportMenuVisible: boolean = false;
  @State selectedBookKey: string = '';
  @State selectedBookTitle: string = '';
  @State selectedTab: number = 0;
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State emptyFaceIndex: number = Math.floor(Math.random() * BOOKMARK_EMPTY_FACES.length);
  /** 进入某本书后要滚到的笔记 id，对齐上游 targetMarkingId（定位完成即清空）。 */
  @State targetMarkingId: string = '';
  private bookmarkScroller: Scroller = new Scroller();
  private noteScroller: Scroller = new Scroller();

  /**
   * 搜索命中的那条笔记 id，对齐上游 BookmarkBookUi.matchedMarkingId。
   * 上游只在「未选中书 && 有搜索词」时计算，命中则卡片显示「包含匹配笔记，点击查看」；
   * 匹配口径与上游 BookMarking.matchesNoteQuery 一致：备注 / 划线文本 / 章名。
   */
  private getMatchedMarkingId(bookKey: string): string {
    const query = this.searchQuery.trim().toLocaleLowerCase();
    if (query.length === 0) { return ''; }
    const hit = this.entries.find((entry: BookmarkEntrySummary) => entry.bookKey === bookKey &&
      entry.kind === 'note' && (entry.note.toLocaleLowerCase().includes(query) ||
        entry.excerpt.toLocaleLowerCase().includes(query) || entry.chapterName.toLocaleLowerCase().includes(query)));
    return hit === undefined ? '' : hit.id;
  }

  private getVisibleBooks(): BookmarkBookSummary[] {
    const query = this.searchQuery.trim().toLocaleLowerCase();
    // 上游 AllBookmarkViewModel：`filter { selectedBook != null || query.isBlank() || matchedMarkingId != null }`
    // 搜索态下只保留「有匹配笔记」的书（书名/作者命中不算），点进去直接跳到那条笔记。
    if (query.length === 0) { return this.books; }
    return this.books.filter((book: BookmarkBookSummary) => this.getMatchedMarkingId(book.key).length > 0);
  }

  private getVisibleEntries(bookKey: string, tabIndex: number): BookmarkEntrySummary[] {
    const query = this.searchQuery.trim().toLocaleLowerCase();
    const matched = this.entries.filter((entry: BookmarkEntrySummary) => {
      if (entry.bookKey !== bookKey || (tabIndex === 0 && entry.kind !== 'bookmark') ||
        (tabIndex === 1 && entry.kind !== 'note')) { return false; }
      return query.length === 0 || entry.chapterName.toLocaleLowerCase().includes(query) ||
        entry.excerpt.toLocaleLowerCase().includes(query) || entry.note.toLocaleLowerCase().includes(query);
    });
    // 上游 AllBookmarkViewModel 把书签与笔记混成 detailItems 后按 (章节序号, 章内偏移) 排序，
    // 本地原来沿用存储顺序（新书签前插），列表和正文顺序对不上。
    // 批5（:153）：升序/降序只翻这两个比较键的方向，不动过滤与搜索口径。
    const direction = this.sortDescending ? -1 : 1;
    return matched.sort((left: BookmarkEntrySummary, right: BookmarkEntrySummary) => {
      if (left.chapterIndex !== right.chapterIndex) {
        return (left.chapterIndex - right.chapterIndex) * direction;
      }
      return (left.chapterPosition - right.chapterPosition) * direction;
    });
  }

  /**
   * 当前书在某一 tab 下的条目数。
   * 不能沿用进入书籍时的 `book.bookmarkCount` 快照：删除/编辑书签后 entries 已更新，
   * 快照不会重算，tab 标签会停在旧数字（上游 AllBookmarkViewModel 是从实时列表算的）。
   */
  private countEntriesForBook(bookKey: string, kind: 'bookmark' | 'note'): number {
    let total = 0;
    for (let index = 0; index < this.entries.length; index++) {
      const entry = this.entries[index];
      if (entry === undefined) { continue; }
      if (entry.bookKey === bookKey && entry.kind === kind) { total++; }
    }
    return total;
  }

  /**
   * 把 targetMarkingId 指向的笔记滚到可见处，对齐上游
   * `LaunchedEffect(targetMarkingId, detailItems) { noteListState.scrollToItem(index) }`。
   */
  private scrollToTargetMarking(): void {
    if (this.targetMarkingId.length === 0) { return; }
    const notes = this.getVisibleEntries(this.selectedBookKey, 1);
    const index = notes.findIndex((entry: BookmarkEntrySummary) => entry.id === this.targetMarkingId);
    if (index >= 0) {
      this.noteScroller.scrollToIndex(index, true);
    }
    this.targetMarkingId = '';
  }

  private handleBack(): void {
    // 批5（:152）选择模式下先退选择，再退书，别一步退回上一页把选择态丢了
    if (this.selectionMode) {
      this.exitSelectionMode();
      return;
    }
    if (this.selectedBookKey.length > 0) {
      this.selectedBookKey = '';
      this.selectedBookTitle = '';
      this.currentSourceUrl = '';
      this.searchQuery = '';
      this.selectedTab = 0;
      this.targetMarkingId = '';
    } else {
      this.onBack();
    }
  }

  private randomizeEmptyFace(): void {
    this.emptyFaceIndex = Math.floor(Math.random() * BOOKMARK_EMPTY_FACES.length);
  }

  /** 书签导出菜单，对应上游 AllBookmarkScreen 的两项导出。 */
  @Builder
  private BookmarkExportMenu() {
    UiMenuPanel({
      items: this.bookmarkExportItems(),
      panelWidth: PROFILE_MENU_WIDTH,
      onSelect: (key: string) => { this.exportMenuVisible = false; this.onBookmarkExportSelect(key); }
    })
  }

  private bookmarkExportItems(): UiMenuItem[] {
    return [
      { key: 'json', title: '导出为 JSON' },
      { key: 'markdown', title: '导出为 Markdown' }
    ];
  }

  private onBookmarkExportSelect(key: string): void {
    if (key === 'json') {
      this.onExportBookmarks(this.selectedBookKey, false);
    } else if (key === 'markdown') {
      this.onExportBookmarks(this.selectedBookKey, true);
    }
  }

  /** 批5（:152）选择模式：条目是否已选。 */
  private isEntrySelected(id: string): boolean {
    return this.selectedEntryIds.includes(id);
  }

  private toggleEntrySelection(id: string): void {
    const next = this.selectedEntryIds.filter((value: string) => value !== id);
    // 长度没变说明原来不在选中集里，补进去
    if (next.length === this.selectedEntryIds.length) {
      next.push(id);
    }
    this.selectedEntryIds = next;
  }

  private exitSelectionMode(): void {
    this.selectionMode = false;
    this.selectedEntryIds = [];
    this.batchExportMenuVisible = false;
  }

  /**
   * 批5（:152）批量删除二次确认。
   * 上游 selectionSecondaryActions 的批量操作都会先确认，这里照同一口径，文案把条数写进去，
   * 删除后无法恢复要说清楚。
   */
  private confirmBatchDeleteEntries(): void {
    const count = this.selectedEntryIds.length;
    if (count === 0) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '删除书签',
      message: `删除选中的 ${count} 条书签？删除后无法恢复。`,
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        action: () => {
          const bookmarkIds: string[] = [];
          const markingIds: string[] = [];
          for (let index = 0; index < this.selectedEntryIds.length; index++) {
            const id = this.selectedEntryIds[index];
            const entry = this.entries.find((item: BookmarkEntrySummary) => item.id === id);
            if (entry === undefined) {
              continue;
            }
            if (entry.kind === 'bookmark') {
              bookmarkIds.push(id);
            } else {
              markingIds.push(id);
            }
          }
          this.onDeleteEntries(bookmarkIds, markingIds);
          this.exitSelectionMode();
        }
      }
    });
  }

  private requestBatchExport(isMarkdown: boolean): void {
    if (this.selectedEntryIds.length === 0) {
      return;
    }
    this.batchExportMenuVisible = false;
    this.onExportSelectedEntries(this.selectedEntryIds, isMarkdown);
  }

  @Builder
  private BookmarkBatchExportMenu() {
    UiMenuPanel({
      items: [
        { key: 'json', title: '导出选中为 JSON' },
        { key: 'markdown', title: '导出选中为 Markdown' }
      ],
      panelWidth: PROFILE_MENU_WIDTH,
      onSelect: (key: string) => this.requestBatchExport(key === 'markdown')
    })
  }

  /**
   * 批5（:152）批量操作栏。
   * 只放任务书要求的两项：删除与导出；未选中时按钮置灰，避免点了没反应。
   */
  @Builder
  private BookmarkSelectionBar() {
    Row() {
      Text(`已选 ${this.selectedEntryIds.length} 项`)
        .fontSize(LABEL_LARGE).fontColor(this.themeColorTextSecondary).layoutWeight(1)
      Row() {
        AppGlyph({ name: 'download', glyphSize: 18,
          tint: this.selectedEntryIds.length > 0 ? this.themeColorTextSecondary : this.themeColorTextTertiary })
        Text('导出').fontSize(LABEL_LARGE).margin({ left: 4 })
          .fontColor(this.selectedEntryIds.length > 0 ? this.themeColorTextPrimary : this.themeColorTextTertiary)
      }.padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .onClick(() => {
          if (this.selectedEntryIds.length === 0) { return; }
          this.batchExportMenuVisible = !this.batchExportMenuVisible;
        })
        .bindPopup(this.batchExportMenuVisible, {
          builder: this.BookmarkBatchExportMenu,
          placement: Placement.TopRight,
          popupColor: '#00000000',
          enableArrow: false,
          autoCancel: true,
          width: PROFILE_MENU_WIDTH,
          onStateChange: (event: PopupStateChangeParam) => { this.batchExportMenuVisible = event.isVisible; }
        })
      Row() {
        AppGlyph({ name: 'delete', glyphSize: 18,
          tint: this.selectedEntryIds.length > 0 ? '#E57373' : this.themeColorTextTertiary })
        Text('删除').fontSize(LABEL_LARGE).margin({ left: 4 })
          .fontColor(this.selectedEntryIds.length > 0 ? '#E57373' : this.themeColorTextTertiary)
      }.padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .onClick(() => this.confirmBatchDeleteEntries())
    }.width('100%').height(56).padding({ left: 16, right: 12 })
      .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent :
        (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary))
  }

  @Builder
  private BookmarkEmptyMessage(message: string) {
    Column() {
      Text(BOOKMARK_EMPTY_FACES[this.emptyFaceIndex]).fontSize(HEADLINE_LARGE).fontColor(this.themeColorTextPrimary)
        .textAlign(TextAlign.Center).onClick(() => this.randomizeEmptyFace())
      Text(message).fontSize(LABEL_LARGE).fontColor(this.themeColorTextSecondary).textAlign(TextAlign.Center).maxLines(2)
        .margin({ top: 2 })
    }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .padding({ left: 16, right: 16 })
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
          Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.themeColorTextSecondary)
        }.width(40).height(40).onClick(() => this.handleBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
          AppGlyph({ name: 'search', glyphSize: 20, tint: this.themeColorTextSecondary })
        }.width(40).height(40).onClick(() => {
          this.showSearch = !this.showSearch;
          if (!this.showSearch) { this.searchQuery = ''; }
        })
        if (this.selectedBookKey.length > 0) {
          // 批5（:153）方向切换：图标用 swap，读屏念当前方向，点一下翻面后由 Index 落盘
          Stack({ alignContent: Alignment.Center }) {
            Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
            AppGlyph({ name: 'swap', glyphSize: 20, tint: this.themeColorTextSecondary })
          }.width(40).height(40)
            .accessibilityText(this.sortDescending ? '降序' : '升序')
            .accessibilityDescription('切换书签与笔记的排列方向')
            .onClick(() => this.onToggleSortDescending())
          // 批5（:152）选择模式开关：进入后点击/长按都只切选中态，不再跳正文
          Stack({ alignContent: Alignment.Center }) {
            Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
            AppGlyph({ name: this.selectionMode ? 'profileClose' : 'list', glyphSize: 20, tint: this.themeColorTextSecondary })
          }.width(40).height(40)
            .accessibilityText(this.selectionMode ? '退出选择' : '选择')
            .onClick(() => {
              if (this.selectionMode) {
                this.exitSelectionMode();
              } else {
                this.selectionMode = true;
                this.selectedEntryIds = [];
              }
            })
          Stack({ alignContent: Alignment.Center }) {
            Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
            AppGlyph({ name: 'more', glyphSize: 20, tint: this.themeColorTextSecondary })
          }.width(40).height(40)
            .onClick(() => { this.exportMenuVisible = !this.exportMenuVisible; })
.bindPopup(this.exportMenuVisible, {
  builder: this.BookmarkExportMenu,
  placement: Placement.BottomRight,
  popupColor: '#00000000',
  enableArrow: false,
  autoCancel: true,
  width: PROFILE_MENU_WIDTH,
  onStateChange: (event: PopupStateChangeParam) => { this.exportMenuVisible = event.isVisible; }
})
        }
      }.width('100%').height(40).padding({ left: 11, right: 12 }).margin({ top: this.appTopInset - 8 })

      Text(this.selectedBookKey.length === 0 ? '所有书签' : this.selectedBookTitle)
        .fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor(this.themeColorTextPrimary)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%').padding({ left: 12, right: 18, top: 12 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: this.selectedBookKey.length === 0
            ? '搜索笔记内容'
            : `搜索当前${this.selectedTab === 0 ? '书签' : '笔记'}`, text: this.searchQuery })
            .fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).placeholderColor(this.themeColorTextTertiary)
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .id('my_bookmark_search')
            .onAppear(() => focusControl.requestFocus('my_bookmark_search'))
            .onChange((value: string) => this.searchQuery = value)
        }.width('calc(100% - 32vp)').height(48).padding({ left: 14, right: 14 })
          .margin({ left: 16, right: 16, top: 8, bottom: 4 }).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(24)
      }

      if (this.selectedBookKey.length > 0) {
        Row() {
          ModuleTab({ label: `书签 ${this.countEntriesForBook(this.selectedBookKey, 'bookmark')}`, selected: this.selectedTab === 0, onSelect: () => { this.selectedTab = 0; this.searchQuery = ''; } })
          ModuleTab({ label: `笔记 ${this.countEntriesForBook(this.selectedBookKey, 'note')}`, selected: this.selectedTab === 1, onSelect: () => { this.selectedTab = 1; this.searchQuery = ''; } })
        }.margin({ left: 16, right: 16, top: 8, bottom: 12 })
        Swiper() {
          ForEach([0, 1], (tabIndex: number) => {
            Column() {
              if (this.getVisibleEntries(this.selectedBookKey, tabIndex).length === 0) {
                this.BookmarkEmptyMessage(this.searchQuery.length > 0 ? '没有找到相关笔记' :
                  (tabIndex === 0 ? '暂无书签' : '暂无笔记'))
              } else {
                List({ scroller: tabIndex === 1 ? this.noteScroller : this.bookmarkScroller }) {
                  ForEach(this.getVisibleEntries(this.selectedBookKey, tabIndex), (entry: BookmarkEntrySummary) => {
                    ListItem() {
                      BookmarkEntryCard({
                        entry: entry,
                        currentSourceUrl: this.currentSourceUrl,
                        // 批5（:152）选择模式：点击与长按都只切选中态，避免长按跳走丢选中
                        selectionMode: this.selectionMode,
                        selected: this.isEntrySelected(entry.id),
                        // 上游 DetailList：书签条目点击与长按都打开编辑面板；
                        // 笔记（Marking）条目点击无任何行为。
                        onSelect: () => {
                          if (this.selectionMode) { this.toggleEntrySelection(entry.id); return; }
                          if (entry.kind === 'bookmark') { this.onEditBookmark(entry.id); }
                        },
                        onJump: () => {
                          if (this.selectionMode) { this.toggleEntrySelection(entry.id); return; }
                          if (entry.kind === 'bookmark') { this.onEditBookmark(entry.id); }
                        }
                      })
                    }
                  }, (entry: BookmarkEntrySummary) => entry.id)
                }.padding({ left: 16, right: 16, top: 4, bottom: 20 })
                  .listDirection(Axis.Vertical).scrollBar(BarState.Off).layoutWeight(1)
              }
            }.width('100%').height('100%')
          }, (tabIndex: number) => tabIndex.toString())
        }.layoutWeight(1).width('100%').index(this.selectedTab).loop(false).indicator(false)
          .onChange((index: number) => { this.selectedTab = index; this.searchQuery = ''; })
        // 批5（:152）批量操作栏只在选择模式下出现，退出选择时一起收走
        if (this.selectionMode) {
          this.BookmarkSelectionBar()
        }
      } else if (this.getVisibleBooks().length === 0) {
        this.BookmarkEmptyMessage(this.searchQuery.length > 0 ? '没有找到相关笔记' : '暂无书签')
      } else {
        Scroll() {
          Column() {
            ForEach(this.getVisibleBooks(), (book: BookmarkBookSummary) => {
              BookmarkOverviewCard({
                book: book,
                matchedMarkingId: this.getMatchedMarkingId(book.key),
                onSelect: () => {
                  this.selectedBookKey = book.key;
                  this.selectedBookTitle = book.title;
                  this.currentSourceUrl = book.sourceUrl;
                  // 上游：带定位目标时直接落在笔记 tab，并把该条笔记滚到可见处
                  const target = this.getMatchedMarkingId(book.key);
                  this.targetMarkingId = target;
                  this.selectedTab = target.length > 0 ? 1 : 0;
                  this.searchQuery = '';
                  if (target.length > 0) {
                    setTimeout((): void => this.scrollToTargetMarking(), 120);
                  }
                }
              })
            }, (book: BookmarkBookSummary) => book.key)
          }.padding({ left: 16, right: 16, top: 8, bottom: 20 })
        }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).layoutWeight(1).scrollBar(BarState.Off)
      }
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
  }
}

@Component
struct BookmarkOverviewCard {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @Prop book: BookmarkBookSummary = {
    key: '', title: '', author: '', bookmarkCount: 0, noteCount: 0, sourceUrl: '',
    coverUri: '', coverColor: '', coverMark: ''
  };
  /** 搜索命中的笔记 id；非空时卡片显示「包含匹配笔记，点击查看」。 */
  @Prop matchedMarkingId: string = '';
  onSelect: () => void = () => {};
  @StorageProp('themeCardRadius') themeCardRadius: number = 16;
  @StorageProp('themeCardBorderWidth') themeCardBorderWidth: number = 0;
  @StorageProp('themeCardBorderColor') themeCardBorderColor: string = '#6A6D77';
  @StorageProp('themeCardBackground') themeCardBackground: string = '';
  @StorageProp('themeContainerBackground') themeContainerBackground: string = '';
  build() {
    Row() {
      Column() {
        Text(this.book.title).fontSize(BODY_LARGE).fontColor(this.themeColorTextSecondary).maxLines(2)
        if (this.book.author.length > 0) { Text(this.book.author).fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary).margin({ top: 3 }) }
        // 上游 feature_bookmarks_counts：「%1$d 个书签 · %2$d 个笔记」
        Text(`${this.book.bookmarkCount} 个书签 · ${this.book.noteCount} 个笔记`).fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 4 })
        // 上游 feature_bookmarks_match_hint：搜索命中笔记时用主色提示「包含匹配笔记，点击查看」
        if (this.matchedMarkingId.length > 0) {
          Text('包含匹配笔记，点击查看').fontSize(BODY_SMALL).fontColor(this.themeColorAccent).margin({ top: 2 })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      // 上游 CoilBookCover width(52.dp)：封面占位与宽度与书架一致
      BookCover({
        book: {
          id: this.book.key, title: this.book.title, author: this.book.author, category: '',
          lastChapter: '', progress: 0,
          coverUri: this.book.coverUri.length > 0 ? this.book.coverUri : undefined, isLocal: true
        },
        displayWidth: 52, displayHeight: 73, cornerRadius: 8
      }).margin({ left: 12 })
    }.width('100%').padding(12).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat).margin({ bottom: 8 })
      .onClick(() => this.onSelect())
  }
}

@Component
struct BookmarkEntryCard {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @Prop entry: BookmarkEntrySummary = {
    id: '', bookKey: '', chapterName: '', excerpt: '', note: '', kind: 'bookmark',
    chapterIndex: 0, chapterPosition: 0, sourceUrl: ''
  };
  /** 当前书籍的书源地址；与条目记录里的 sourceUrl 不一致时显示「其他书源」。 */
  @Prop currentSourceUrl: string = '';
  /** 批5（:152）选择模式：为 true 时卡片左侧显示勾选框，点击/长按只切选中态。 */
  @Prop selectionMode: boolean = false;
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};
  /** 长按跳转到正文位置，保留原有的跳转能力。 */
  onJump: () => void = () => {};
  /**
   * 批5（:100）：章名回退只写一份。
   * 上游 feature_bookmarks_chapter_fallback 用 chapterIndex + 1，正文显示与读屏播报共用同一段文字，
   * 否则两处各拼一次，改一处就漂一处。
   */
  private chapterTitle(): string {
    return this.entry.chapterName.length > 0 ? this.entry.chapterName : `第 ${this.entry.chapterIndex + 1} 章`;
  }
  /**
   * 批5（:100）：读屏播报用的整句。
   * 上游 ReaderAccessibilityPolicy.kt:19 的 isBookmarked 负责阅读页「已加书签」播报，这里补的是
   * 书签/笔记列表卡片的播报 —— 卡片本身只有零散 Text，读屏会逐段念，拼成一句才听得懂。
   */
  private accessibilitySummary(): string {
    const chapter = this.chapterTitle();
    const body = this.entry.kind === 'bookmark' ? this.entry.excerpt : this.entry.note;
    const prefix = this.entry.kind === 'bookmark' ? '书签' : '笔记';
    return body.length > 0 ? `${prefix}：${chapter}。${body}` : `${prefix}：${chapter}。`;
  }
  build() {
    Column() {
      Row() {
        // 批5（:152）勾选框：选择模式下才出现，未选中是空心描边，选中填强调色 + 勾
        if (this.selectionMode) {
          Stack({ alignContent: Alignment.Center }) {
            Row().width(18).height(18).borderRadius(4).borderWidth(1)
              .borderColor(this.selected ? this.themeColorAccent : this.themeColorTextTertiary)
              .backgroundColor(this.selected ? this.themeColorAccent : Color.Transparent)
            if (this.selected) {
              AppGlyph({ name: 'profileCheck', glyphSize: 12, tint: '#FFFFFF' })
            }
          }.width(18).height(18).margin({ right: 8 })
        }
        // 上游：章名为空时回退「第 N 章」（feature_bookmarks_chapter_fallback，用 chapterIndex + 1）
        Text(this.chapterTitle())
          .fontSize(LABEL_LARGE).fontColor(this.themeColorAccent).maxLines(1).layoutWeight(1)
        // 上游 marks_other_source：`bookUrl.isNotBlank() && bookUrl != book?.bookUrl`
        // 记录属于别的书源时标红提示，避免误以为当前书里找不到。
        if (this.entry.sourceUrl.length > 0 && this.entry.sourceUrl !== this.currentSourceUrl) {
          Text('其他书源').fontSize(BODY_SMALL).fontColor('#E57373').margin({ left: 6 })
        }
      }.width('100%')
      if (this.entry.excerpt.length > 0) { Text(this.entry.excerpt).fontSize(LABEL_LARGE).fontColor(this.themeColorTextSecondary).maxLines(3).margin({ top: 6 }) }
      if (this.entry.note.length > 0) { Text(this.entry.note).fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary).maxLines(3).margin({ top: 4 }) }
    }.width('100%').padding(16)
      .backgroundColor(this.selected ? this.themeColorSurfaceTertiary : this.themeColorSurfaceSecondary)
      .borderRadius(14).margin({ bottom: 8 })
      .accessibilityText(this.accessibilitySummary())
      .accessibilityDescription('点击编辑，长按跳转到正文')
      .onClick(() => this.onSelect())
      .gesture(LongPressGesture().onAction(() => this.onJump()))
  }
}

@Component
export struct ReadRecordsPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  /** 扫描/修复/清空改变了数据后通知 Index 重读会话，避免页面仍显示旧列表。 */
  onRecordsChanged: () => void = () => {};
  /** 顶栏更多菜单里的「阅读总览」入口，由 Index 切到总览页。 */
  onOpenOverview: () => void = () => {};
  /** 点条目打开书：由 Index 按书名+作者反查书架并 openBook。 */
  onOpenBook: (bookName: string, bookAuthor: string) => void = (_bookName: string, _bookAuthor: string) => {};
  @Prop records: ReadTimeRecord[] = [];
  @Prop details: ReadRecordDetail[] = [];
  @Prop summaries: ReadRecordSummary[] = [];
  /**
   * 书架全量书籍：封面（coverUri）与私密判定（isPrivate / groupNames）都要靠它反查。
   * 阅读记录表里只存书名+作者，没有 bookUrl 也没有封面路径。
   */
  @Prop books: Book[] = [];
  /**
   * 私密体系状态。@StorageProp 直接订阅 AppStorage：PrivateAccessRepository 每次 publish
   * 后这些值都会重建，不需要自己传回调。
   */
  @StorageProp('privateEnabled') privateEnabled: boolean = false;
  @StorageProp('privateUnlocked') privateUnlocked: boolean = false;
  /** 关掉「打开书籍时验证」= 不按条目脱敏（上游 rememberPrivateLockedRecords 第一分支）。 */
  @StorageProp('privateVerifyOnOpenBook') privateVerifyOnOpenBook: boolean = true;
  /**
   * 「每次都验证」档的分组授权集合，订阅后 grant() 才能触发重绘。
   *
   * 没有订阅 `privateGrantedBookKeys`：阅读记录表里没有 bookUrl，单本授权项无从匹配。
   * 上游 `isTargetGranted(null, groupMask)` 传的也是 null，同一处限制。
   */
  @StorageProp('privateGrantedGroupIds') privateGrantedGroupIds: number[] = [];
  /** 列表首个可见项与滚动偏移：悬浮日期条只在滚过一定距离后出现（对齐上游 floatingDate）。 */
  @State listFirstVisibleIndex: number = 0;
  @State listFirstVisibleScrollOffset: number = 0;
  // 列表真实滚动控制器：用 currentOffset().yOffset 取代逐帧累加，Spring 回弹后能精确归零。
  private recordListScroller: Scroller = new Scroller();
  @State recordEnabled: boolean = true;
  @State displayMode: number = 0;
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State emptyFaceIndex: number = Math.floor(Math.random() * BOOKMARK_EMPTY_FACES.length);
  @State showActionsSheet: boolean = false;
  @State showCalendarSheet: boolean = false;
  /** 热力图档位：0=次数（上游默认 COUNT）/ 1=时长；面板内状态，不持久化（上游 remember）。 */
  @State heatmapMode: number = 0;
  @State showClearConfirm: boolean = false;
  @State selectedCalendarDay: number = 0;
  /** 热力图选中的日期，非空时三视图只看这一天；对应上游 SelectDate。 */
  @State selectedDateKey: string = '';
  /** 选择模式：三种条目的稳定 key 集合，非空即处于选择模式。 */
  @State selectedKeys: Set<string> = new Set<string>();
  /** 删除确认面板，单条与批量共用，文案按待删条数切换。 */
  @State showDeleteConfirm: boolean = false;
  /** 删除确认「本页不再提醒」临时档，对应上游 skipDeleteConfirmTemp。 */
  @State skipDeleteConfirmForPage: boolean = false;
  /** 删除确认「不再提醒」长期档，键名与上游 READ_RECORD_SKIP_DELETE_CONFIRM 一致。 */
  @State skipDeleteConfirm: boolean = false;
  /** 确认框里的两档勾选项，点「删除」时才生效。 */
  @State skipDeleteConfirmPageDraft: boolean = false;
  @State skipDeleteConfirmLongTermDraft: boolean = false;
  /** 删除确认档位：1 单条 / 0 删时段 / -1 清空 / >1 多条。按动作来源赋值、决定四档文案。 */
  @State deleteConfirmKind: number = 1;
  /** 合并对话框：目标汇总行、候选、多选集合与搜索词。 */
  @State showMergeSheet: boolean = false;
  @State mergeTarget: ReadRecordSummary | undefined = undefined;
  @State mergeCandidates: ReadRecordSummary[] = [];
  @State mergeSelectedKeys: Set<string> = new Set<string>();
  @State mergeSearchQuery: string = '';

  aboutToAppear(): void {
    this.recordEnabled = ReadRecordRepository.isEnabled();
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      ReadRecordRepository.loadSkipDeleteConfirm(context).then((value: boolean) => {
        this.skipDeleteConfirm = value;
      });
      ReadRecordRepository.loadDisplayMode(context).then((mode: string) => {
        this.displayMode = mode === 'TIMELINE' ? 1 : (mode === 'LATEST' ? 2 : 0);
      });
    }
  }

  private getModeLabel(): string {
    if (this.displayMode === 1) { return '时间线视图'; }
    if (this.displayMode === 2) { return '最后阅读视图'; }
    return '汇总视图';
  }

  /**
   * 把书名+作者拼成一个最小 Book 供 BookCover 用。
   *
   * 照 ReadRecordOverviewPage.ets:189-192 的 coverUriOf 口径：反查不到时返回空壳 Book，
   * BookCover 会画占位色块——这正是上游 CoilBookCover 在 path == null 时的行为，不额外隐藏。
   */
  private bookForRecord(bookName: string, bookAuthor: string): Book {
    const hit = this.books.find((item: Book) => item.title === bookName && item.author === bookAuthor);
    if (hit !== undefined) { return hit; }
    return {
      id: `${bookName}-${bookAuthor}`, title: bookName, author: bookAuthor,
      category: '', lastChapter: '', progress: 0, isLocal: true
    };
  }

  /**
   * 当前所有私密分组的 id。分组上的 isPrivate 标记早就有，这里只是取出来用。
   *
   * 用 getAll() 而不是 getVisibleUserGroups()：后者会滤掉 show=false 的分组，
   * 但 `maskFromNames` 与书架的 `getUserGroups()` 都不滤，混用会让隐藏的私密分组漏判。
   */
  private privateGroupIds(): number[] {
    return BookGroupRepository.getAll()
      .filter((group: BookGroup) => group.groupId > 0 && group.isPrivate === true)
      .map((group: BookGroup) => group.groupId);
  }

  /**
   * 这条记录现在要不要脱敏。判定照上游 `rememberPrivateLockedRecords`
   * （ui/widget/components/privacy/PrivateListMasking.kt:74-95）。
   *
   * 这里必须真的读 privateEnabled / privateUnlocked / privateGrantedGroupIds：
   * 它们只是 AppStorage 静态快照时，ArkUI 不会把它们当重绘依赖，输对密码或解锁分组后
   * 锁定行不会变回正常行（同 BookshelfPage.ets:900 那条注释）。
   */
  private isRecordLocked(bookName: string, bookAuthor: string): boolean {
    if (this.privateEnabled !== true) { return false; }
    // 关掉「打开书籍时验证」= 不按条目脱敏（上游 rememberPrivateLockedRecords 第一分支）
    if (!this.privateVerifyOnOpenBook) { return false; }
    const book = this.books.find((item: Book) => item.title === bookName && item.author === bookAuthor);
    // 反查不到按「与私密无关」处理（上游 factsOfByName 返回 null 同）
    if (book === undefined) { return false; }
    const groupIds = this.privateGroupIds();
    if (!isPrivateBook(book, groupIds)) { return false; }
    // 阅读记录表里没有 bookUrl，单本授权项无从匹配，只能按分组粒度判
    // （上游 isTargetGranted(null, groupMask) 传的也是 null）
    if (this.privateUnlocked === true) { return false; }
    const mask = BookGroupRepository.maskFromNames(book.groupNames ?? []);
    // mask 为 0 表示这本书只靠单本标记进私密（没挂私密分组）。此时没有任何分组授权能覆盖它，
    // 上游 isTargetGranted(null, 0L) 的 `group != 0L` 分支为 false 同样放行不了，所以照旧锁定。
    const granted = mask > 0 && this.privateGrantedGroupIds.some((groupId: number) =>
      groupIds.includes(groupId) && groupId > 0 && Math.floor(mask / groupId) % 2 === 1);
    return !granted;
  }

  /** 日期分组头：汇总视图右侧带当天总时长，时间线只有日期。
   * 用 @Builder 生成的 CustomBuilder 传给 ListItemGroup.header。 */
  @Builder
  private dateHeaderBuilder(dateKey: string, duration: string) {
    Row() {
      Text(ReadRecordRepository.formatFriendlyDate(dateKey)).fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextSecondary)
      Blank()
      if (duration.length > 0) {
        Text(duration).fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent)
      }
    }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }

  /** 悬浮日期条文案：汇总视图带当天总时长，时间线只有日期，最后阅读不显示。 */
  private floatingDateLabel(): string {
    if (this.displayMode === 2) { return ''; }
    // 严格对齐上游 ReadRecordScreen.kt:240-241：两个独立条件 OR。
    // firstVisibleItemIndex > 1 || firstVisibleItemScrollOffset > 24。
    // 去掉原先的 first===1 前置：first=0（成就卡仍可见但已滚过阈值）时也可能达到第二个条件。
    // 这里不再单看累加偏移：Spring 回弹后绝对位移无法可靠归零，会导致滚到顶悬浮条残留。
    const first = this.listFirstVisibleIndex;
    const shouldStick = first > 1 || this.listFirstVisibleScrollOffset > 24;
    if (!shouldStick) { return ''; }
    const date = this.currentVisibleDate();
    if (date.length === 0) { return ''; }
    if (this.displayMode === 0) {
      return `${ReadRecordRepository.formatFriendlyDate(date)} · ${this.formatRecordDuration(this.getSummaryDurationForDate(date))}`;
    }
    return ReadRecordRepository.formatFriendlyDate(date);
  }

  /** 首个可见项所属的日期：index 0 是「阅读总成就」卡，其后每个日期组占 1 个 header + N 个条目。 */
  private currentVisibleDate(): string {
    const keys = this.displayMode === 0 ? this.getSummaryDateKeys() : this.getDateKeys();
    const first = this.listFirstVisibleIndex;
    // first=0 是「阅读总成就」卡、first=1 是第一个日期头：两者都应取第一个日期。
    // 不加这个前置的话，循环条件 first>=1 对 first=0 全不成立，会落到末尾错取最后一个日期。
    if (first <= 1) { return keys.length > 0 ? keys[0] : ''; }
    let idx = 1;
    for (const key of keys) {
      const count = this.displayMode === 0
        ? this.getDistinctSummaryBooksForDate(key).length
        : this.getRecordsForDate(key).length;
      if (first >= idx && first <= idx + count) { return key; }
      idx += 1 + count;
    }
    return keys.length > 0 ? keys[keys.length - 1] : '';
  }

  private cycleDisplayMode(): void {
    this.displayMode = (this.displayMode + 1) % 3;
    // 切视图清选择（上游切 DisplayMode 时 selectedItemKeys=emptySet）
    this.clearSelection();
    // 列表数据整体替换，旧滚动偏移会残留；回顶并清掉，避免悬浮条误显。
    this.recordListScroller.scrollToIndex(0, false);
    this.listFirstVisibleIndex = 0;
    this.listFirstVisibleScrollOffset = 0;
    const context = this.hostContext();
    if (context !== undefined) {
      const mode = this.displayMode === 1 ? 'TIMELINE' : (this.displayMode === 2 ? 'LATEST' : 'AGGREGATE');
      ReadRecordRepository.setDisplayMode(context, mode);
    }
  }

  private getVisibleRecords(): ReadTimeRecord[] {
    const query = this.searchQuery.trim().toLocaleLowerCase();
    if (query.length === 0) { return this.records; }
    return this.records.filter((record: ReadTimeRecord) =>
      record.bookName.toLocaleLowerCase().includes(query) || record.bookAuthor.toLocaleLowerCase().includes(query));
  }

  private getDateKey(timestamp: number): string {
    return this.formatRecordDate(timestamp).substring(0, 10);
  }

  /** 汇总视图按跨午夜拆分后的自然日明细分组；搜索同时作用于明细表（对齐上游 searchDetails）。 */
  private getSummaryDateKeys(): string[] {
    const query = this.searchQuery.trim().toLocaleLowerCase();
    const keys: string[] = [];
    for (const detail of this.details) {
      if (query.length > 0 && !detail.bookName.toLocaleLowerCase().includes(query) &&
        !detail.bookAuthor.toLocaleLowerCase().includes(query)) { continue; }
      if (!keys.includes(detail.date)) { keys.push(detail.date); }
    }
    const ordered = keys.sort((left: string, right: string) => right.localeCompare(left));
    if (this.selectedDateKey.length > 0) {
      return ordered.filter((key: string) => key === this.selectedDateKey);
    }
    return ordered;
  }

  private getSummaryDetailsForDate(dateKey: string): ReadRecordDetail[] {
    const query = this.searchQuery.trim().toLocaleLowerCase();
    return this.details.filter((detail: ReadRecordDetail) => {
      if (detail.date !== dateKey) { return false; }
      if (query.length === 0) { return true; }
      return detail.bookName.toLocaleLowerCase().includes(query) ||
        detail.bookAuthor.toLocaleLowerCase().includes(query);
    });
  }

  private getDistinctSummaryBooksForDate(dateKey: string): ReadRecordDetail[] {
    const result: ReadRecordDetail[] = [];
    for (const detail of this.getSummaryDetailsForDate(dateKey)) {
      if (!result.some((item: ReadRecordDetail) =>
        item.bookName === detail.bookName && item.bookAuthor === detail.bookAuthor)) {
        result.push(detail);
      }
    }
    return result;
  }

  private getSummaryDurationForDate(dateKey: string): number {
    return this.getSummaryDetailsForDate(dateKey)
      .reduce((total: number, detail: ReadRecordDetail) => total + detail.readTime, 0);
  }

  private getSummaryBookDurationForDate(dateKey: string, bookName: string, bookAuthor: string): number {
    return this.getSummaryDetailsForDate(dateKey)
      .filter((detail: ReadRecordDetail) => detail.bookName === bookName && detail.bookAuthor === bookAuthor)
      .reduce((total: number, detail: ReadRecordDetail) => total + detail.readTime, 0);
  }

  /** 时间线仍按会话开始时间分日，单条跨午夜会话保持完整时长。 */
  private getDateKeys(): string[] {
    const keys: string[] = [];
    for (const record of this.getVisibleRecords()) {
      const key = this.getDateKey(record.startTime);
      if (!keys.includes(key)) { keys.push(key); }
    }
    const ordered = keys.sort((left: string, right: string) => right.localeCompare(left));
    if (this.selectedDateKey.length > 0) {
      return ordered.filter((key: string) => key === this.selectedDateKey);
    }
    return ordered;
  }

  /**
   * 时间线当天条目：先把 20 分钟内的连续会话合并（F9），再按开始时间倒序。
   * 合并条目的身份沿用该连续段首条原始记录，保证选择/删除能定位回原会话；
   * 显示时长用合并后的整段时长。日期分组仍按 startTime，先过滤当天再合并，天然不跨天。
   */
  private getRecordsForDate(dateKey: string): ReadTimeRecord[] {
    const originals = this.getVisibleRecords().filter((record: ReadTimeRecord) =>
      this.getDateKey(record.startTime) === dateKey);
    const sessions: ReadRecordSession[] = [];
    for (const record of originals) {
      const session: ReadRecordSession = {
        deviceId: '', bookName: record.bookName, bookAuthor: record.bookAuthor,
        bookUrl: record.bookId, startTime: record.startTime, endTime: record.endTime,
        chapterIndex: record.chapterIndex ?? 0
      };
      sessions.push(session);
    }
    // mergeContinuousSessions 要求输入按 startTime 升序；this.records 原是 endTime 倒序。
    sessions.sort((left: ReadRecordSession, right: ReadRecordSession) => left.startTime - right.startTime);
    const merged = ReadRecordRepository.mergeContinuousSessions(sessions);
    const result: ReadTimeRecord[] = [];
    for (const session of merged) {
      const first = originals.find((item: ReadTimeRecord) =>
        item.startTime === session.startTime && item.bookId === session.bookUrl);
      if (first === undefined) { continue; }
      const row: ReadTimeRecord = {
        id: first.id, bookId: first.bookId, bookName: first.bookName, bookAuthor: first.bookAuthor,
        startTime: first.startTime, endTime: first.endTime,
        durationMs: session.endTime - session.startTime,
        chapterIndex: first.chapterIndex
      };
      result.push(row);
    }
    return result.sort((left: ReadTimeRecord, right: ReadTimeRecord) => right.startTime - left.startTime);
  }

  /**
   * 章号文案。与上游 ReadRecordScreen 的 chapter_index_format 同口径，但本地固定用「第 N 章」，
   * 不去 chapters 表查真实标题：换过目录的书 chapterIndex 对不上当时的标题，查出来的标题反而是错的，
   * 而且每条记录查一次表，记录一多就是 N 次查询。
   *
   * chapterIndex 为 0 时按「未知」返回空串而不是「第 1 章」：0 是「第一章」与「未知」共用的值，
   * 本地没有别的信息能区分，宁可不说。
   */
  private chapterLabelOf(record: ReadTimeRecord): string {
    const index = record.chapterIndex ?? 0;
    return index > 0 ? `第 ${index + 1} 章` : '';
  }

  /** 「最后阅读 <日期> <时间>」一行；有章名时拼在后面，没有章名不留多余的分隔符。 */
  private latestReadLineOf(record: ReadTimeRecord): string {
    const timeText = `${ReadRecordRepository.formatFriendlyDate(this.getDateKey(record.endTime))} `
      + this.formatRecordDate(record.endTime).substring(11);
    const label = this.chapterLabelOf(record);
    return label.length > 0 ? `最后阅读 ${timeText} · ${label}` : `最后阅读 ${timeText}`;
  }

  private getDistinctBooks(records: ReadTimeRecord[]): ReadTimeRecord[] {
    const result: ReadTimeRecord[] = [];
    for (const record of records) {
      if (!result.some((item: ReadTimeRecord) => item.bookId === record.bookId)) { result.push(record); }
    }
    return result;
  }

  private getLatestRecords(): ReadTimeRecord[] {
    const ordered = [...this.getVisibleRecords()].sort((left: ReadTimeRecord, right: ReadTimeRecord) =>
      right.endTime - left.endTime);
    const filtered = this.selectedDateKey.length > 0
      ? ordered.filter((record: ReadTimeRecord) => this.getDateKey(record.startTime) === this.selectedDateKey)
      : ordered;
    return this.getDistinctBooks(filtered);
  }

  private getTotalDuration(records: ReadTimeRecord[]): number {
    return records.reduce((total: number, record: ReadTimeRecord) => total + record.durationMs, 0);
  }

  private getBookDuration(bookId: string, records: ReadTimeRecord[]): number {
    return this.getTotalDuration(records.filter((record: ReadTimeRecord) => record.bookId === bookId));
  }

  private getCalendarCells(): number[] {
    const today = new Date();
    const firstWeekday = new Date(today.getFullYear(), today.getMonth(), 1).getDay();
    const dayCount = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
    const days: number[] = [];
    for (let index = 0; index < 42; index++) {
      const day = index - firstWeekday + 1;
      days.push(day > 0 && day <= dayCount ? day : 0);
    }
    return days;
  }

  private getCalendarDayDuration(day: number): number {
    if (day <= 0) { return 0; }
    const today = new Date();
    const year = today.getFullYear();
    const month = (today.getMonth() + 1).toString().padStart(2, '0');
    const date = day.toString().padStart(2, '0');
    const dateKey = `${year}-${month}-${date}`;
    return this.details
      .filter((detail: ReadRecordDetail) => detail.date === dateKey)
      .reduce((total: number, detail: ReadRecordDetail) => total + detail.readTime, 0);
  }

  private getSummaryBookCount(): number {
    return this.summaries.length;
  }

  private getSummaryDuration(): number {
    return this.summaries.reduce((total: number, summary: ReadRecordSummary) => total + summary.readTime, 0);
  }

  /** 热力图按日次数：details 按 date 分组的个数，对应上游 dailyReadCounts。 */
  private buildDailyReadCounts(): Map<string, number> {
    const result = new Map<string, number>();
    for (const detail of this.details) {
      result.set(detail.date, (result.get(detail.date) ?? 0) + 1);
    }
    return result;
  }

  /** 热力图按日时长：details 按 date 累加 readTime，对应上游 dailyReadTimes。 */
  private buildDailyReadTimes(): Map<string, number> {
    const result = new Map<string, number>();
    for (const detail of this.details) {
      result.set(detail.date, (result.get(detail.date) ?? 0) + detail.readTime);
    }
    return result;
  }

  /** 汇总条目 key：类型 + 书名 + 作者 + 日期（分隔符用上游 selectionKey 的空字符）。 */
  private aggregateKey(detail: ReadRecordDetail, dateKey: string): string {
    return `D\u0000${detail.bookName}\u0000${detail.bookAuthor}\u0000${dateKey}`;
  }

  /** 时间线条目 key：类型 + 书名 + 作者 + 起止时间。 */
  private timelineKey(record: ReadTimeRecord): string {
    return `T\u0000${record.bookName}\u0000${record.bookAuthor}\u0000${record.startTime}\u0000${record.endTime}`;
  }

  /** 最后阅读条目 key：类型 + 书名 + 作者。 */
  private latestKey(record: ReadTimeRecord): string {
    return `L\u0000${record.bookName}\u0000${record.bookAuthor}`;
  }

  private isInSelectionMode(): boolean {
    return this.selectedKeys.size > 0;
  }

  private clearSelection(): void {
    this.selectedKeys = new Set<string>();
  }

  /** 长按单条：进入选择模式并选中该条，对应上游 onEnterSelection。 */
  private enterSelectionWith(key: string): void {
    const next = new Set<string>(this.selectedKeys);
    next.add(key);
    this.selectedKeys = next;
  }

  /** 选择模式下单击条目切换选中。 */
  private toggleSelectionKey(key: string): void {
    const next = new Set<string>(this.selectedKeys);
    if (next.has(key)) { next.delete(key); } else { next.add(key); }
    this.selectedKeys = next;
  }

  /** 顶栏返回：优先退选择模式，对应上游 BackHandler(enabled = inSelectionMode)。 */
  private handleReadRecordBack(): void {
    if (this.isInSelectionMode()) { this.clearSelection(); return; }
    this.onBack();
  }

  /**
   * 侧滑露出的删除块。上游 SwipeRevealVerticalInset = 3vp（上下内缩）、
   * SwipeRevealEdgeInset = 8vp、SwipeRevealCornerRadius = 16vp。
   * 注意 actionAreaDistance 保持 SDK 默认 56vp，对应上游 60% 触发阈值。
   */
  @Builder
  private swipeDeleteAction(onTrigger: () => void) {
    Row() {
      AppGlyph({ name: 'delete', glyphSize: 24, tint: '#FFFFFF' })
    }
    .width(72).height('100%')
    .justifyContent(FlexAlign.Center)
    .margin({ top: 3, bottom: 3, left: 8, right: 8 })
    .backgroundColor('#D95656')
    .borderRadius(16)
    .onClick(() => onTrigger())
    .accessibilityText('删除阅读记录')
  }

  /** 最后阅读视图右滑（end 侧）露出的合并块：上游 primary 底 + Merge 图标。 */
  @Builder
  private swipeMergeAction(onTrigger: () => void) {
    Row() {
      AppGlyph({ name: 'profileCheck', glyphSize: 24, tint: '#FFFFFF' })
    }
    .width(72).height('100%')
    .justifyContent(FlexAlign.Center)
    .margin({ top: 3, bottom: 3, left: 8, right: 8 })
    .backgroundColor(this.themeColorAccent)
    .borderRadius(16)
    .onClick(() => onTrigger())
    .accessibilityText('将阅读记录合并到此书')
  }

  /**
   * 侧滑单条删除：把这一条塞进选择集，再走同一套确认与执行链路。
   * 不新写删除逻辑——performDeleteSelected 已经按 key 前缀分派到三条删除 SQL。
   */
  private requestDeleteOne(key: string): void {
    this.selectedKeys = new Set<string>([key]);
    this.requestDeleteSelected();
  }

  /** 侧滑时间线会话：文案是「删时段」而不是「删一条记录」。 */
  private requestDeletePeriod(key: string): void {
    this.selectedKeys = new Set<string>([key]);
    this.deleteConfirmKind = 0;
    if (this.skipDeleteConfirmForPage || this.skipDeleteConfirm) {
      this.performDeleteSelected();
      return;
    }
    this.skipDeleteConfirmPageDraft = false;
    this.skipDeleteConfirmLongTermDraft = false;
    this.showDeleteConfirm = true;
  }

  /** 点顶栏删除按钮：按选中条数分档，已勾不再提醒就直接删，否则弹两档确认。 */
  private requestDeleteSelected(): void {
    if (!this.isInSelectionMode()) { return; }
    // 多选批量按条数分档；单条侧滑时 selectedKeys 也只有 1 条，走 else 分支文案。
    this.deleteConfirmKind = this.selectedKeys.size;
    if (this.skipDeleteConfirmForPage || this.skipDeleteConfirm) {
      this.performDeleteSelected();
      return;
    }
    this.skipDeleteConfirmPageDraft = false;
    this.skipDeleteConfirmLongTermDraft = false;
    this.showDeleteConfirm = true;
  }

  /** 确认框点删除：应用两档，长期档写 preferences，然后逐条删。 */
  private async confirmDeleteSelected(): Promise<void> {
    this.showDeleteConfirm = false;
    this.skipDeleteConfirmForPage = this.skipDeleteConfirmPageDraft || this.skipDeleteConfirmLongTermDraft;
    if (this.skipDeleteConfirmLongTermDraft) {
      const context = this.hostContext();
      if (context !== undefined) { await ReadRecordRepository.setSkipDeleteConfirm(context, true); }
      this.skipDeleteConfirm = true;
    }
    await this.performDeleteSelected();
  }

  /** 逐条走批 0 的删除方法，删完清空选择并通知 Index 重读三表。 */
  private async performDeleteSelected(): Promise<void> {
    const context = this.hostContext();
    if (context === undefined) { return; }
    const keys: string[] = [];
    this.selectedKeys.forEach((key: string) => keys.push(key));
    for (const key of keys) {
      const parts = key.split('\u0000');
      if (parts[0] === 'D') {
        const hit = this.details.find((item: ReadRecordDetail) =>
          item.bookName === parts[1] && item.bookAuthor === parts[2] && item.date === parts[3]);
        await ReadRecordRepository.deleteDetailByIdKey(context,
          hit !== undefined ? hit.deviceId : '', parts[1], parts[2], parts[3]);
      } else if (parts[0] === 'T') {
        const startTime = Number(parts[3]);
        const endTime = Number(parts[4]);
        const hit = this.records.find((item: ReadTimeRecord) =>
          item.bookName === parts[1] && item.bookAuthor === parts[2] &&
          item.startTime === startTime && item.endTime === endTime);
        if (hit !== undefined) {
          const session: ReadRecordSession = {
            deviceId: '', bookName: parts[1], bookAuthor: parts[2], bookUrl: hit.bookId,
            startTime: startTime, endTime: endTime, chapterIndex: 0
          };
          await ReadRecordRepository.deleteSessionById(context, session);
        }
      } else if (parts[0] === 'L') {
        await ReadRecordRepository.deleteSummaryByKey(context, parts[1], parts[2]);
      }
    }
    this.clearSelection();
    this.onRecordsChanged();
  }

  /** 动作单「恢复删除确认」：把长期档与临时档都清掉。 */
  private restoreDeleteConfirm(): void {
    const context = this.hostContext();
    if (context !== undefined) { ReadRecordRepository.setSkipDeleteConfirm(context, false); }
    this.skipDeleteConfirm = false;
    this.skipDeleteConfirmForPage = false;
    this.showActionsSheet = false;
    this.onUnavailableAction('已恢复删除确认');
  }

  /** 打开合并对话框：以最后阅读视图点中的那条为目标取候选。 */
  private async openMergeSheetForRecord(record: ReadTimeRecord): Promise<void> {
    const context = this.hostContext();
    if (context === undefined) { return; }
    let target: ReadRecordSummary | undefined = this.summaries.find((item: ReadRecordSummary) =>
      item.bookName === record.bookName && item.bookAuthor === record.bookAuthor);
    if (target === undefined) {
      target = {
        deviceId: '', bookName: record.bookName, bookAuthor: record.bookAuthor,
        readTime: 0, lastRead: 0
      };
    }
    const candidates = await ReadRecordRepository.loadMergeCandidates(context, target);
    this.mergeTarget = target;
    this.mergeCandidates = candidates;
    // 默认预选所有同名候选（上游 mergeDialogData 初始 selectedMergeKeys）：
    // 这些正是最该合并的同名不同作者条目。
    this.mergeSelectedKeys = new Set<string>(
      candidates
        .filter((item: ReadRecordSummary) => item.bookName === record.bookName)
        .map((item: ReadRecordSummary) => this.mergeCandidateKey(item))
    );
    this.mergeSearchQuery = '';
    this.showActionsSheet = false;
    this.showMergeSheet = true;
  }

  private mergeCandidateKey(item: ReadRecordSummary): string {
    return `${item.bookName}\u0000${item.bookAuthor}`;
  }

  private getFilteredMergeCandidates(): ReadRecordSummary[] {
    const query = this.mergeSearchQuery.trim();
    if (query.length === 0) { return this.mergeCandidates; }
    return this.mergeCandidates.filter((item: ReadRecordSummary) =>
      item.bookName.includes(query) || item.bookAuthor.includes(query));
  }

  private toggleMergeCandidate(key: string): void {
    const next = new Set<string>(this.mergeSelectedKeys);
    if (next.has(key)) { next.delete(key); } else { next.add(key); }
    this.mergeSelectedKeys = next;
  }

  /** 确认合并：把勾选的候选会话改判到目标，再通知 Index 重读三表。 */
  private async confirmMerge(): Promise<void> {
    const context = this.hostContext();
    const target = this.mergeTarget;
    if (context === undefined || target === undefined) { return; }
    const sources = this.mergeCandidates.filter((item: ReadRecordSummary) =>
      this.mergeSelectedKeys.has(this.mergeCandidateKey(item)));
    if (sources.length === 0) { return; }
    await ReadRecordRepository.mergeReadRecords(context, target, sources);
    this.showMergeSheet = false;
    this.mergeTarget = undefined;
    this.onRecordsChanged();
  }

  /** 清除归属决定：清掉 openBook 时「合并还是保留」记住的选择。 */
  private clearAliasDecisions(): void {
    const context = this.hostContext();
    if (context !== undefined) { ReadRecordRepository.clearAliasDecisions(context); }
    this.showActionsSheet = false;
    this.onUnavailableAction('已清除归属决定');
  }

  private formatRecordDuration(durationMs: number): string {
    return ReadRecordRepository.formatDuration(durationMs);
  }

  private formatRecordDate(timestamp: number): string {
    const date = new Date(timestamp);
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    const hour = date.getHours().toString().padStart(2, '0');
    const minute = date.getMinutes().toString().padStart(2, '0');
    return `${date.getFullYear()}-${month}-${day} ${hour}:${minute}`;
  }

  /** 取宿主 Ability 上下文，拿不到就提示并返回 undefined。 */
  private hostContext(): Context | undefined {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.onUnavailableAction('无法获取应用上下文，操作未执行');
    }
    return context;
  }

  /** 启用/停用阅读记录总开关，对应上游 localPreferences 的 readRecordEnabled。 */
  private async toggleRecordEnabled(): Promise<void> {
    const context = this.hostContext();
    if (context === undefined) { return; }
    const enabled = !ReadRecordRepository.isEnabled();
    await ReadRecordRepository.setEnabled(context, enabled);
    this.recordEnabled = enabled;
    this.onUnavailableAction(enabled ? '已启用阅读记录，之后会继续记账' : '已停用阅读记录，期间不再记账');
  }

  /** 扫描重复/异常记录，只读不改数据。 */
  private async runScanIssues(): Promise<void> {
    const context = this.hostContext();
    if (context === undefined) { return; }
    const report = await ReadRecordRepository.scanIssues(context);
    // 扫描与修复共用上游三段格式；扫描阶段 mergedCount 表示可合并条数。
    this.onUnavailableAction(
      `合并：${report.mergedCount}，异常：${report.exceptionCount}，字段完全相同的阅读时段记录：${report.duplicateSessionCount}`
    );
  }

  /** 修复重复记录与身份写法，并按会话重算明细与汇总。 */
  private async runRepair(): Promise<void> {
    const context = this.hostContext();
    if (context === undefined) { return; }
    const report = await ReadRecordRepository.repair(context);
    this.onUnavailableAction(
      `合并：${report.mergedCount}，异常：${report.exceptionCount}，字段完全相同的阅读时段记录：${report.duplicateSessionCount}`
    );
    const total = report.duplicateSessionCount + report.normalizedRecordCount + report.mergedCount;
    if (total > 0) { this.onRecordsChanged(); }
  }

  /** 清空全部本地阅读记录（含当前未落库的会话），有确认面板。 */
  private requestClearAll(): void {
    if (this.records.length === 0 && !ReadRecordRepository.isEnabled()) {
      this.onUnavailableAction('当前没有可清空的阅读记录');
      return;
    }
    if (this.records.length === 0) {
      this.onUnavailableAction('当前没有可清空的阅读记录');
      return;
    }
    this.showClearConfirm = true;
  }

  private async confirmClearAll(): Promise<void> {
    this.showClearConfirm = false;
    const context = this.hostContext();
    if (context === undefined) { return; }
    await ReadRecordRepository.clearAll(context);
    this.onRecordsChanged();
    this.onUnavailableAction('阅读记录已清空');
  }

  @Builder
  private ReadRecordEmptyMessage(message: string) {
    Column() {
      Text(BOOKMARK_EMPTY_FACES[this.emptyFaceIndex]).fontSize(HEADLINE_LARGE).fontColor(this.themeColorTextPrimary)
        .textAlign(TextAlign.Center).onClick(() => {
          this.emptyFaceIndex = Math.floor(Math.random() * BOOKMARK_EMPTY_FACES.length);
        })
      Text(message).fontSize(LABEL_LARGE).fontColor(this.themeColorTextSecondary).textAlign(TextAlign.Center).maxLines(2).margin({ top: 2 })
    }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .padding({ left: 16, right: 16 })
  }

  /** 顶栏左侧：多选态清空选择、否则返回，逻辑已在 handleReadRecordBack 里，直接复用。 */
  @Builder
  private topNavSlot() {
    // @BuilderParam 必须箭头包一层：直接传方法引用会把 builder 的 this 重绑到 AppTopBar，
    // 导致 this.handleReadRecordBack 为 undefined，点返回即崩。
    TopBarBackButton({ onSelect: () => this.handleReadRecordBack() })
  }

  /** 顶栏动作区：多选态只有删除，否则显示模式切换 + 搜索 + 更多。 */
  @Builder
  private topActions() {
    if (this.isInSelectionMode()) {
      TopBarButton({
        icon: 'delete',
        showDivider: false,
        onSelect: () => this.requestDeleteSelected()
      })
    } else {
      // 图标按当前视图取：汇总→时间线、时间线→时钟、最后阅读→列表。
      TopBarButton({
        icon: this.displayMode === 0 ? 'profileTimeline' : (this.displayMode === 1 ? 'clock' : 'list'),
        showDivider: false,
        onSelect: () => this.cycleDisplayMode()
      })
      TopBarButton({
        icon: 'search',
        onSelect: () => {
          this.showSearch = !this.showSearch;
          if (!this.showSearch) { this.searchQuery = ''; }
        }
      })
      TopBarButton({
        icon: 'more',
        onSelect: () => this.showActionsSheet = true
      })
    }
  }

  build() {
    Column() {
      // 顶栏：统一用 AppTopBar，与书架页/设置页同款。
      // 不要再在外面包 margin 让出 appTopInset——AppTopBar 自己读 @StorageProp('appTopInset')
      // 并把它加进高度（components/TopBar.ets:189-190），外面再让一次会双倍留白。
      AppTopBar({
        title: this.isInSelectionMode() ? `已选 ${this.selectedKeys.size} 项` : '阅读记录',
        subtitle: this.isInSelectionMode() ? '点按项目选择，返回退出' : this.getModeLabel(),
        collapsed: false,
        hasNavigation: true,
        navigationIcon: () => { this.topNavSlot() },
        actions: () => { this.topActions() }
      })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '搜索', text: this.searchQuery })
            .fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).placeholderColor(this.themeColorTextTertiary)
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .id('my_read_record_search')
            .onAppear(() => focusControl.requestFocus('my_read_record_search'))
            .onChange((value: string) => this.searchQuery = value)
        }.width('calc(100% - 32vp)').height(48).padding({ left: 14, right: 14 })
          .margin({ left: 16, right: 16, top: 8, bottom: 4 }).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(24)
          .transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE, curve: Curve.EaseInOut }))
      }

      if (this.selectedDateKey.length > 0) {
        Row() {
          Text(`只看 ${ReadRecordRepository.formatFriendlyDate(this.selectedDateKey)} 的记录`)
            .fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextSecondary).layoutWeight(1)
          Text('查看全部').fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent)
            .onClick(() => { this.selectedDateKey = ''; })
        }.width('calc(100% - 32vp)').padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .margin({ left: 16, right: 16, top: 8 })
          .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary))
          .borderRadius(12)
      }

      if (this.getVisibleRecords().length === 0) {
        this.ReadRecordEmptyMessage(this.records.length === 0 ? '没有阅读记录' : '没有匹配的阅读记录')
      } else {
        // 用 List + ListItemGroup 实现日期头吸顶（StickyStyle.Header），替换原来的
        // Scroll + Column + 三层 ForEach：后者一次渲染全部条目，既没有 sticky，条目多了也掉帧。
        // Stack 让悬浮日期条盖在列表左上角；它自己占满剩余高度，List 再填满 Stack。
        Stack({ alignContent: Alignment.TopStart }) {
          List({ scroller: this.recordListScroller }) {
            // 「阅读总成就」不是日期分组，用普通 ListItem 平铺在最前面。
            ListItem() {
              Column() {
                Text('阅读总成就').fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
                Row() {
                  Text(`${this.getSummaryBookCount()} 本书`).fontSize(HEADLINE_SMALL).fontColor(this.themeColorAccent)
                  Blank()
                  Text(this.formatRecordDuration(this.getSummaryDuration()))
                    .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextSecondary)
                }.width('100%').margin({ top: 12 })
              }.width('calc(100% - 32vp)').padding(16).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
                .margin({ left: 16, right: 16, bottom: 10 }).onClick(() => this.showCalendarSheet = true)
            }
            if (this.displayMode === 0) {
              // 汇总视图：每个自然日一个 ListItemGroup，日期行作为 header 参与吸顶。
              ForEach(this.getSummaryDateKeys(), (dateKey: string) => {
                ListItemGroup({ header: this.dateHeaderBuilder(dateKey, this.formatRecordDuration(this.getSummaryDurationForDate(dateKey))) }) {
                  ForEach(this.getDistinctSummaryBooksForDate(dateKey), (detail: ReadRecordDetail) => {
                    if (this.isInSelectionMode()) {
                      ListItem() {
                        Row() {
                          // 行首封面：上游 ReadRecordItem（ReadRecordScreen.kt:1408）是 44dp 宽、5:7 的 CoilBookCover。
                          BookCover({
                            book: this.bookForRecord(detail.bookName, detail.bookAuthor),
                            displayWidth: 44,
                            displayHeight: 62,
                            cornerRadius: 4,
                            locked: this.isRecordLocked(detail.bookName, detail.bookAuthor)
                          }).margin({ right: this.isInSelectionMode() ? 8 : 16 })
                          Column() {
                            // 锁定行书名/作者/时长一律空串（上游只留模糊封面，不留占位条与「已隐藏」字样）。
                            Text(this.isRecordLocked(detail.bookName, detail.bookAuthor) ? '' : detail.bookName)
                              .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary)
                            Text(this.isRecordLocked(detail.bookName, detail.bookAuthor) ? '' : detail.bookAuthor)
                              .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
                          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                          Text(this.isRecordLocked(detail.bookName, detail.bookAuthor) ? ''
                            : this.formatRecordDuration(this.getSummaryBookDurationForDate(dateKey, detail.bookName, detail.bookAuthor)))
                            .fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent)
                        }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
                          .border({ width: { top: 1 }, color: this.themeColorSurfacePrimary })
                          .backgroundColor(this.selectedKeys.has(this.aggregateKey(detail, dateKey)) ? '#48577D' : Color.Transparent)
                          .onClick(() => {
                            if (this.isRecordLocked(detail.bookName, detail.bookAuthor)) {
                              this.onOpenBook(detail.bookName, detail.bookAuthor);
                              return;
                            }
                            if (this.isInSelectionMode()) {
                              this.toggleSelectionKey(this.aggregateKey(detail, dateKey));
                            } else {
                              this.onOpenBook(detail.bookName, detail.bookAuthor);
                            }
                          })
                          .gesture(LongPressGesture({ duration: 500 }).onAction(() => {
                            // 锁定行不进多选（上游 ReadRecordItem：锁定态 onLongClick = onClick）
                            if (this.isRecordLocked(detail.bookName, detail.bookAuthor)) { return; }
                            this.enterSelectionWith(this.aggregateKey(detail, dateKey));
                          }))
                      }
                    } else {
                      ListItem() {
                        Row() {
                          // 行首封面：上游 ReadRecordItem（ReadRecordScreen.kt:1408）是 44dp 宽、5:7 的 CoilBookCover。
                          BookCover({
                            book: this.bookForRecord(detail.bookName, detail.bookAuthor),
                            displayWidth: 44,
                            displayHeight: 62,
                            cornerRadius: 4,
                            locked: this.isRecordLocked(detail.bookName, detail.bookAuthor)
                          }).margin({ right: this.isInSelectionMode() ? 8 : 16 })
                          Column() {
                            // 锁定行书名/作者/时长一律空串（上游只留模糊封面，不留占位条与「已隐藏」字样）。
                            Text(this.isRecordLocked(detail.bookName, detail.bookAuthor) ? '' : detail.bookName)
                              .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary)
                            Text(this.isRecordLocked(detail.bookName, detail.bookAuthor) ? '' : detail.bookAuthor)
                              .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
                          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                          Text(this.isRecordLocked(detail.bookName, detail.bookAuthor) ? ''
                            : this.formatRecordDuration(this.getSummaryBookDurationForDate(dateKey, detail.bookName, detail.bookAuthor)))
                            .fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent)
                        }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
                          .border({ width: { top: 1 }, color: this.themeColorSurfacePrimary })
                          .backgroundColor(this.selectedKeys.has(this.aggregateKey(detail, dateKey)) ? '#48577D' : Color.Transparent)
                          .onClick(() => {
                            if (this.isRecordLocked(detail.bookName, detail.bookAuthor)) {
                              this.onOpenBook(detail.bookName, detail.bookAuthor);
                              return;
                            }
                            if (this.isInSelectionMode()) {
                              this.toggleSelectionKey(this.aggregateKey(detail, dateKey));
                            } else {
                              this.onOpenBook(detail.bookName, detail.bookAuthor);
                            }
                          })
                          .gesture(LongPressGesture({ duration: 500 }).onAction(() => {
                            // 锁定行不进多选（上游 ReadRecordItem：锁定态 onLongClick = onClick）
                            if (this.isRecordLocked(detail.bookName, detail.bookAuthor)) { return; }
                            this.enterSelectionWith(this.aggregateKey(detail, dateKey));
                          }))
                      }
                      .swipeAction({
                        start: { builder: () => { this.swipeDeleteAction(() => this.requestDeleteOne(this.aggregateKey(detail, dateKey))) } }
                      })
                    }
                  }, (detail: ReadRecordDetail) =>
                    `${dateKey}-${detail.bookName}-${detail.bookAuthor}-${this.selectedKeys.has(this.aggregateKey(detail, dateKey))}-${this.isRecordLocked(detail.bookName, detail.bookAuthor)}`)
                }.width('calc(100% - 32vp)').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(12)
                  .margin({ left: 16, right: 16, bottom: 8 })
              }, (dateKey: string) => dateKey)
            } else if (this.displayMode === 1) {
              // 时间线视图：同样按日期分组吸顶，header 只有日期、不带时长（对齐上游 timeline_header）。
              ForEach(this.getDateKeys(), (dateKey: string) => {
                ListItemGroup({ header: this.dateHeaderBuilder(dateKey, '') }) {
                  ForEach(this.getRecordsForDate(dateKey), (record: ReadTimeRecord) => {
                    if (this.isInSelectionMode()) {
                      ListItem() {
                        Row() {
                          Text(this.formatRecordDate(record.startTime).substring(11)).fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent)
                            .width(56)
                          // 行首封面：上游 TimelineSessionItem（ReadRecordScreen.kt:1254）同为 44dp 宽 5:7。
                          BookCover({
                            book: this.bookForRecord(record.bookName, record.bookAuthor),
                            displayWidth: 44,
                            displayHeight: 62,
                            cornerRadius: 4,
                            locked: this.isRecordLocked(record.bookName, record.bookAuthor)
                          }).margin({ right: this.isInSelectionMode() ? 8 : 16 })
                          Column() {
                            // 锁定行书名/作者/章号一律空串，只留封面上的「已加密」蒙层。
                            Text(this.isRecordLocked(record.bookName, record.bookAuthor) ? '' : record.bookName)
                              .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary)
                            Text(this.isRecordLocked(record.bookName, record.bookAuthor) ? '' : record.bookAuthor)
                              .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
                            if (!this.isRecordLocked(record.bookName, record.bookAuthor) && this.chapterLabelOf(record).length > 0) {
                              Text(this.chapterLabelOf(record)).fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 2 })
                            }
                          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                          Text(this.isRecordLocked(record.bookName, record.bookAuthor) ? ''
                            : this.formatRecordDuration(record.durationMs)).fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextSecondary)
                        }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
                          .border({ width: { top: 1 }, color: this.themeColorSurfacePrimary })
                          .backgroundColor(this.selectedKeys.has(this.timelineKey(record)) ? '#48577D' : Color.Transparent)
                          .onClick(() => {
                            if (this.isRecordLocked(record.bookName, record.bookAuthor)) {
                              this.onOpenBook(record.bookName, record.bookAuthor);
                              return;
                            }
                            if (this.isInSelectionMode()) {
                              this.toggleSelectionKey(this.timelineKey(record));
                            } else {
                              this.onOpenBook(record.bookName, record.bookAuthor);
                            }
                          })
                          .gesture(LongPressGesture({ duration: 500 }).onAction(() => {
                            this.enterSelectionWith(this.timelineKey(record));
                          }))
                      }
                    } else {
                      ListItem() {
                        Row() {
                          Text(this.formatRecordDate(record.startTime).substring(11)).fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent)
                            .width(56)
                          // 行首封面：上游 TimelineSessionItem（ReadRecordScreen.kt:1254）同为 44dp 宽 5:7。
                          BookCover({
                            book: this.bookForRecord(record.bookName, record.bookAuthor),
                            displayWidth: 44,
                            displayHeight: 62,
                            cornerRadius: 4,
                            locked: this.isRecordLocked(record.bookName, record.bookAuthor)
                          }).margin({ right: this.isInSelectionMode() ? 8 : 16 })
                          Column() {
                            // 锁定行书名/作者/章号一律空串，只留封面上的「已加密」蒙层。
                            Text(this.isRecordLocked(record.bookName, record.bookAuthor) ? '' : record.bookName)
                              .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary)
                            Text(this.isRecordLocked(record.bookName, record.bookAuthor) ? '' : record.bookAuthor)
                              .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
                            if (!this.isRecordLocked(record.bookName, record.bookAuthor) && this.chapterLabelOf(record).length > 0) {
                              Text(this.chapterLabelOf(record)).fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 2 })
                            }
                          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                          Text(this.isRecordLocked(record.bookName, record.bookAuthor) ? ''
                            : this.formatRecordDuration(record.durationMs)).fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextSecondary)
                        }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
                          .border({ width: { top: 1 }, color: this.themeColorSurfacePrimary })
                          .backgroundColor(this.selectedKeys.has(this.timelineKey(record)) ? '#48577D' : Color.Transparent)
                          .onClick(() => {
                            if (this.isRecordLocked(record.bookName, record.bookAuthor)) {
                              this.onOpenBook(record.bookName, record.bookAuthor);
                              return;
                            }
                            if (this.isInSelectionMode()) {
                              this.toggleSelectionKey(this.timelineKey(record));
                            } else {
                              this.onOpenBook(record.bookName, record.bookAuthor);
                            }
                          })
                          .gesture(LongPressGesture({ duration: 500 }).onAction(() => {
                            this.enterSelectionWith(this.timelineKey(record));
                          }))
                      }
                      .swipeAction({
                        start: { builder: () => { this.swipeDeleteAction(() => this.requestDeletePeriod(this.timelineKey(record))) } }
                      })
                    }
                  }, (record: ReadTimeRecord) => `${record.id}-${this.selectedKeys.has(this.timelineKey(record))}`)
                }.width('calc(100% - 32vp)').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(12)
                  .margin({ left: 16, right: 16, bottom: 8 })
              }, (dateKey: string) => dateKey)
            } else {
              // 最后阅读视图：上游是普通 items(...) 平铺，没有日期分组，
              // 所以这里不用 ListItemGroup、不参与吸顶（StickyStyle.Header 只对 group 的 header 生效）。
              ForEach(this.getLatestRecords(), (record: ReadTimeRecord) => {
                if (this.isInSelectionMode()) {
                  ListItem() {
                    Column() {
                      Row() {
                        // 行首封面：上游 LatestReadItem（ReadRecordScreen.kt:1143）同为 44dp 宽 5:7。
                        BookCover({
                          book: this.bookForRecord(record.bookName, record.bookAuthor),
                          displayWidth: 44,
                          displayHeight: 62,
                          cornerRadius: 4,
                          locked: this.isRecordLocked(record.bookName, record.bookAuthor)
                        }).margin({ right: this.isInSelectionMode() ? 8 : 16 })
                        Column() {
                          // 锁定行只留封面上的「已加密」蒙层，行内文字区一律空白。
                          Text(this.isRecordLocked(record.bookName, record.bookAuthor) ? '' : record.bookName)
                            .fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
                          Text(this.isRecordLocked(record.bookName, record.bookAuthor) ? '' : record.bookAuthor)
                            .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 4 })
                        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                        Text(this.isRecordLocked(record.bookName, record.bookAuthor) ? ''
                          : this.formatRecordDuration(this.getBookDuration(record.bookId, this.records)))
                          .fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent)
                        // 「合并」是行内文字，锁定态一并隐去。
                        if (!this.isRecordLocked(record.bookName, record.bookAuthor)) {
                          Text('合并').fontSize(BODY_SMALL).fontColor(this.themeColorAccent)
                            .padding({ left: 10, right: 2 })
                            .onClick(() => { this.openMergeSheetForRecord(record); })
                        }
                      }.width('100%')
                      Text(this.isRecordLocked(record.bookName, record.bookAuthor) ? '' : this.latestReadLineOf(record))
                        .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).width('100%').margin({ top: 10 })
                    }.width('calc(100% - 32vp)').padding(16).backgroundColor(this.selectedKeys.has(this.latestKey(record)) ? '#48577D' : (this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary))).borderRadius(14)
                      .margin({ left: 16, right: 16, bottom: 8 })
                      .onClick(() => {
                        if (this.isRecordLocked(record.bookName, record.bookAuthor)) {
                          this.onOpenBook(record.bookName, record.bookAuthor);
                          return;
                        }
                        if (this.isInSelectionMode()) {
                          this.toggleSelectionKey(this.latestKey(record));
                        } else {
                          this.onOpenBook(record.bookName, record.bookAuthor);
                        }
                      })
                      .gesture(LongPressGesture({ duration: 500 }).onAction(() => {
                        // 锁定行不进多选（上游 ReadRecordItem：锁定态 onLongClick = onClick）
                        if (this.isRecordLocked(record.bookName, record.bookAuthor)) { return; }
                        this.enterSelectionWith(this.latestKey(record));
                      }))
                  }
                } else {
                  ListItem() {
                    Column() {
                      Row() {
                        // 行首封面：上游 LatestReadItem（ReadRecordScreen.kt:1143）同为 44dp 宽 5:7。
                        BookCover({
                          book: this.bookForRecord(record.bookName, record.bookAuthor),
                          displayWidth: 44,
                          displayHeight: 62,
                          cornerRadius: 4,
                          locked: this.isRecordLocked(record.bookName, record.bookAuthor)
                        }).margin({ right: this.isInSelectionMode() ? 8 : 16 })
                        Column() {
                          // 锁定行只留封面上的「已加密」蒙层，行内文字区一律空白。
                          Text(this.isRecordLocked(record.bookName, record.bookAuthor) ? '' : record.bookName)
                            .fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
                          Text(this.isRecordLocked(record.bookName, record.bookAuthor) ? '' : record.bookAuthor)
                            .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 4 })
                        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                        Text(this.isRecordLocked(record.bookName, record.bookAuthor) ? ''
                          : this.formatRecordDuration(this.getBookDuration(record.bookId, this.records)))
                          .fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent)
                        // 「合并」是行内文字，锁定态一并隐去。
                        if (!this.isRecordLocked(record.bookName, record.bookAuthor)) {
                          Text('合并').fontSize(BODY_SMALL).fontColor(this.themeColorAccent)
                            .padding({ left: 10, right: 2 })
                            .onClick(() => { this.openMergeSheetForRecord(record); })
                        }
                      }.width('100%')
                      Text(this.isRecordLocked(record.bookName, record.bookAuthor) ? '' : this.latestReadLineOf(record))
                        .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).width('100%').margin({ top: 10 })
                    }.width('calc(100% - 32vp)').padding(16).backgroundColor(this.selectedKeys.has(this.latestKey(record)) ? '#48577D' : (this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary))).borderRadius(14)
                      .margin({ left: 16, right: 16, bottom: 8 })
                      .onClick(() => {
                        if (this.isRecordLocked(record.bookName, record.bookAuthor)) {
                          this.onOpenBook(record.bookName, record.bookAuthor);
                          return;
                        }
                        if (this.isInSelectionMode()) {
                          this.toggleSelectionKey(this.latestKey(record));
                        } else {
                          this.onOpenBook(record.bookName, record.bookAuthor);
                        }
                      })
                      .gesture(LongPressGesture({ duration: 500 }).onAction(() => {
                        // 锁定行不进多选（上游 ReadRecordItem：锁定态 onLongClick = onClick）
                        if (this.isRecordLocked(record.bookName, record.bookAuthor)) { return; }
                        this.enterSelectionWith(this.latestKey(record));
                      }))
                  }
                  .swipeAction({
                    start: { builder: () => { this.swipeDeleteAction(() => this.requestDeleteOne(this.latestKey(record))) } },
                    end: { builder: () => { this.swipeMergeAction(() => this.openMergeSheetForRecord(record)) } }
                  })
                }
              }, (record: ReadTimeRecord) =>
                `${record.bookId}-${this.selectedKeys.has(this.latestKey(record))}-${this.isRecordLocked(record.bookName, record.bookAuthor)}`)
            }
          }
          .width('100%').height('100%').padding({ top: 8, bottom: 16 })
          .scrollBar(BarState.Off)
          // 汇总/时间线两个视图的每个 ListItemGroup 都带 header，最后阅读视图不用 group，
          // 所以 Header 吸顶不会出现「有 group 没 header」的空档。
          .sticky(StickyStyle.Header)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false })
          .transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE, curve: Curve.EaseInOut }))
          .onScrollIndex((first: number, _last: number, _center: number) => {
            // 只更新首项索引；偏移改由 onDidScroll 读 scroller 绝对量，避免逐帧累加不归零。
            this.listFirstVisibleIndex = first;
          })
          .onDidScroll((_offset: number, _state: ScrollState) => {
            // offset 是逐帧增量，累加在 Spring 回弹后无法可靠归零（实测回顶后悬浮条残留）。
            // 改读 scroller 的真实绝对偏移：回顶精确为 0，悬浮条随之消失（验收第 5 条）。
            // 用 yOffset 对应上游 firstVisibleItemScrollOffset（列表滚过成就卡的距离）。
            this.listFirstVisibleScrollOffset = Math.max(0, this.recordListScroller.currentOffset().yOffset);
          })

          // 悬浮日期条：对齐上游 TopFloatingStickyItem（TextCard，圆角 8、padding 8）。
          // hitTestBehavior(None) 必须加，否则会挡住下面日期头/条目的点击。
          if (this.floatingDateLabel().length > 0) {
            Text(this.floatingDateLabel())
              .fontSize(LABEL_SMALL).fontColor(this.themeColorTextPrimary)
              .padding({ left: 8, right: 8, top: 8, bottom: 8 })
              .backgroundColor(this.themeColorSurfaceSecondary)
              .borderRadius(8)
              .margin({ left: 8, top: 4 })
              .hitTestBehavior(HitTestMode.None)
          }
        }.width('100%').layoutWeight(1)
      }
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      // 三个半模态共用一个 bindSheet：同一节点链式挂多个 bindSheet 时，
      // 任一状态变化都会让刚打开的 sheet 立即 onDisappear（实测 0.6s 内被顶掉），
      // 所以用互斥条件 + 单一入口。
      .bindSheet(this.showActionsSheet || this.showCalendarSheet || this.showClearConfirm || this.showDeleteConfirm || this.showMergeSheet, this.ReadRecordSheetContent(), {
        height: (this.showClearConfirm || this.showDeleteConfirm) ? SheetSize.FIT_CONTENT : (this.showCalendarSheet ? 570 : 500),
        dragBar: !(this.showClearConfirm || this.showDeleteConfirm),
        showClose: false,
        backgroundColor: this.themeColorSurfaceElevated,
        onDisappear: () => {
          this.showActionsSheet = false; this.showCalendarSheet = false;
          this.showClearConfirm = false; this.showDeleteConfirm = false; this.showMergeSheet = false;
          // 对齐上游 remember 语义：面板关闭后档位复位为次数，下次打开默认按次数
          this.heatmapMode = 0;
        }
      })
  }

  /** 清空确认面板，与替换净化的删除确认同款交互。 */
  @Builder
  private ReadRecordClearConfirmSheet() {
    Column() {
      Text('清空阅读记录').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        .width('100%').textAlign(TextAlign.Center).padding({ top: 22 })
      Text('确定要清空全部阅读记录吗？此操作无法撤销。')
        .fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).width('100%').textAlign(TextAlign.Center)
        .padding({ left: 28, right: 28, top: 12, bottom: 20 })
      Row() {
        Text('取消').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextSecondary).textAlign(TextAlign.Center)
          .layoutWeight(1).height(48).backgroundColor('#23242C').borderRadius(24)
          .onClick(() => this.showClearConfirm = false)
        Text('清空').fontSize(TITLE_MEDIUM).fontColor('#FFFFFF').textAlign(TextAlign.Center)
          .layoutWeight(1).height(48).backgroundColor('#D95656').borderRadius(24).margin({ left: 12 })
          .onClick(() => { this.confirmClearAll(); })
      }.width('100%').padding({ left: 28, right: 28, bottom: 24 })
    }.backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated))
  }

  @Builder
  private ReadRecordSheetContent() {
    if (this.showMergeSheet) { this.ReadRecordMergeSheet() }
    else if (this.showDeleteConfirm) { this.ReadRecordDeleteConfirmSheet() }
    else if (this.showClearConfirm) { this.ReadRecordClearConfirmSheet() }
    else if (this.showCalendarSheet) { this.ReadRecordCalendarSheet() }
    else { this.ReadRecordOptionsSheet() }
  }

  /** 合并阅读记录：顶部搜索、候选多选、无候选提示。 */
  @Builder
  private ReadRecordMergeSheet() {
    Column() {
      Text('合并阅读记录').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        .width('100%').textAlign(TextAlign.Center).padding({ top: 20 })
      Text('把勾选的记录并入目标书籍，按阅读会话重算，不直接相加时长。')
        .fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextSecondary).width('100%').textAlign(TextAlign.Center)
        .padding({ left: 24, right: 24, top: 8, bottom: 14 })
      TextInput({ text: this.mergeSearchQuery, placeholder: '按书名或作者搜索候选' })
        .width('calc(100% - 48vp)').height(44).margin({ bottom: 8 })
        .onChange((value: string) => { this.mergeSearchQuery = value; })
      if (this.getFilteredMergeCandidates().length === 0) {
        Text('没有可合并的候选').fontSize(TITLE_SMALL).fontColor(this.themeColorTextTertiary)
          .width('100%').textAlign(TextAlign.Center).padding({ top: 28, bottom: 28 })
      } else {
        Scroll() {
          Column() {
            ForEach(this.getFilteredMergeCandidates(), (item: ReadRecordSummary) => {
              Row() {
                Column() {
                  Text(item.bookName).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary)
                  Text(item.bookAuthor.length > 0 ? item.bookAuthor : '（作者为空）')
                    .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text(this.mergeSelectedKeys.has(this.mergeCandidateKey(item)) ? '已选' : '选择')
                  .fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent)
              }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
                .backgroundColor(this.mergeSelectedKeys.has(this.mergeCandidateKey(item)) ? '#48577D' : Color.Transparent)
                .onClick(() => this.toggleMergeCandidate(this.mergeCandidateKey(item)))
            }, (item: ReadRecordSummary) => `${this.mergeCandidateKey(item)}-${this.mergeSelectedKeys.has(this.mergeCandidateKey(item))}`)
          }.width('100%')
        }.edgeEffect(EdgeEffect.None).height(240).scrollBar(BarState.Off)
      }
      Row() {
        Text('取消').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextSecondary).textAlign(TextAlign.Center)
          .layoutWeight(1).height(48).backgroundColor('#23242C').borderRadius(24)
          .onClick(() => this.showMergeSheet = false)
        Text('合并').fontSize(TITLE_MEDIUM).fontColor('#FFFFFF').textAlign(TextAlign.Center)
          .layoutWeight(1).height(48).backgroundColor(this.themeColorAccent).borderRadius(24).margin({ left: 12 })
          .onClick(() => { this.confirmMerge(); })
      }.width('100%').padding({ left: 28, right: 28, top: 12, bottom: 24 })
    }.backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated))
  }

  /** 删除确认面板：1 条是单条删除，多条是批量删除；两档「不再提醒」与上游一致。 */
  @Builder
  private ReadRecordDeleteConfirmSheet() {
    Column() {
      Text(this.deleteConfirmKind === 0 ? '删除阅读时段' : (this.deleteConfirmKind > 1 ? `删除 ${this.deleteConfirmKind} 条记录` : '删除阅读记录'))
        .fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        .width('100%').textAlign(TextAlign.Center).padding({ top: 22 })
      Text(this.deleteConfirmKind === 0
        ? '确定要删除这个阅读时段吗？该行连续的所有会话（包括其他设备的会话）都会被删除。'
        : (this.deleteConfirmKind > 1
          ? `确定要删除选中的 ${this.deleteConfirmKind} 条阅读记录吗？`
          : '确定要删除这条记录吗？'))
        .fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).width('100%').textAlign(TextAlign.Center)
        .padding({ left: 28, right: 28, top: 12, bottom: 16 })
      Row() {
        Text('本次打开不再提示').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextSecondary).layoutWeight(1)
        UiSwitchControl({
          checked: this.skipDeleteConfirmPageDraft,
          interactive: false,
          onChange: (value: boolean) => { this.skipDeleteConfirmPageDraft = value; }
        })
      }.width('100%').padding({ left: 28, right: 28, bottom: 8 })
        .onClick(() => {
          this.skipDeleteConfirmPageDraft = !this.skipDeleteConfirmPageDraft;
          // 上游两档互斥：勾「本次打开」就清掉「今后都不再提醒」
          if (this.skipDeleteConfirmPageDraft) { this.skipDeleteConfirmLongTermDraft = false; }
        })
      Row() {
        Text('今后不再提醒').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextSecondary).layoutWeight(1)
        UiSwitchControl({
          checked: this.skipDeleteConfirmLongTermDraft,
          interactive: false,
          onChange: (value: boolean) => { this.skipDeleteConfirmLongTermDraft = value; }
        })
      }.width('100%').padding({ left: 28, right: 28, bottom: 16 })
        .onClick(() => {
          this.skipDeleteConfirmLongTermDraft = !this.skipDeleteConfirmLongTermDraft;
          // 反向互斥：勾「今后都不再提醒」就清掉「本次打开不再提示」
          if (this.skipDeleteConfirmLongTermDraft) { this.skipDeleteConfirmPageDraft = false; }
        })
      Row() {
        Text('取消').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextSecondary).textAlign(TextAlign.Center)
          .layoutWeight(1).height(48).backgroundColor('#23242C').borderRadius(24)
          .onClick(() => { this.showDeleteConfirm = false; this.clearSelection(); })
        Text('删除').fontSize(TITLE_MEDIUM).fontColor('#FFFFFF').textAlign(TextAlign.Center)
          .layoutWeight(1).height(48).backgroundColor('#D95656').borderRadius(24).margin({ left: 12 })
          .onClick(() => { this.confirmDeleteSelected(); })
      }.width('100%').padding({ left: 28, right: 28, bottom: 24 })
    }.backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated))
  }

  /** 主页阅读热力图：年度按周网格，取代原 42 格月历；月历移到批 4 总览页。 */
  @Builder
  private ReadRecordCalendarSheet() {
    Column() {
      Row() {
        Text('阅读热力图').fontSize(HEADLINE_SMALL).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        // 两档切换：次数 / 时长。上游 MediumToggleButton 换图标，本地换图标+文案语义等价。
        Row() {
          AppGlyph({
            name: this.heatmapMode === 1 ? 'accessTime' : 'list',
            glyphSize: 18,
            tint: this.themeColorAccent
          })
          Text(this.heatmapMode === 1 ? '按时长' : '按次数').fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent).margin({ left: 4 })
        }
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor(this.themeColorSurfaceTertiary)
        .borderRadius(16)
        .onClick(() => { this.heatmapMode = this.heatmapMode === 1 ? 0 : 1; })
        Text('关闭').fontSize(TITLE_SMALL).fontColor(this.themeColorAccent).margin({ left: 12 })
          .onClick(() => this.showCalendarSheet = false)
      }.width('100%').padding({ left: 18, right: 18, top: 12, bottom: 14 })
      if (this.selectedDateKey.length > 0) {
        Row() {
          Text(`只看 ${ReadRecordRepository.formatFriendlyDate(this.selectedDateKey)}`)
            .fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextSecondary).layoutWeight(1)
          Text('查看全部').fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent)
            .onClick(() => { this.selectedDateKey = ''; })
        }.width('100%').padding({ left: 18, right: 18, bottom: 8 })
      }
      ReadRecordHeatmap({
        dailyReadCounts: this.buildDailyReadCounts(),
        dailyReadTimes: this.buildDailyReadTimes(),
        selectedDate: this.selectedDateKey,
        mode: this.heatmapMode,
        onDateSelected: (date: string) => {
          this.selectedDateKey = date;
          this.showCalendarSheet = false;
        }
      })
      Text('点格子只看当天，再点「查看全部」恢复')
        .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).width('100%')
        .textAlign(TextAlign.Center).margin({ top: 12 })
    }.width('100%').padding({ bottom: 20 })
  }

  @Builder
  private ReadRecordOptionsSheet() {
    Column() {
      Text('阅读记录选项').fontSize(HEADLINE_SMALL).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        .width('100%').padding({ left: 18, right: 16, top: 12, bottom: 14 })
      ReadRecordOptionRow({ icon: 'chart', title: '显示阅读热力图', detail: '按周网格查看近一年阅读', onSelect: () => {
        this.showActionsSheet = false;
        this.showCalendarSheet = true;
      } })
      ReadRecordOptionRow({
        icon: 'clock',
        title: this.recordEnabled ? '停用阅读记录' : '启用阅读记录',
        detail: this.recordEnabled ? '当前已启用' : '当前已停用，开启后继续记账',
        onSelect: (): void => { this.toggleRecordEnabled(); }
      })
      ReadRecordOptionRow({ icon: 'search', title: '扫描阅读记录问题', detail: '检查重复或异常记录',
        onSelect: (): void => { this.runScanIssues(); } })
      ReadRecordOptionRow({ icon: 'swap', title: '修复阅读记录', detail: '修复重复记录和阅读时段',
        onSelect: (): void => { this.runRepair(); } })
      ReadRecordOptionRow({ icon: 'delete', title: '清空阅读记录', detail: '删除本地阅读历史',
        onSelect: (): void => { this.showActionsSheet = false; this.requestClearAll(); } })
      if (this.skipDeleteConfirm) {
        ReadRecordOptionRow({ icon: 'profileRefresh', title: '恢复删除确认', detail: '删除前重新弹出确认框',
          onSelect: (): void => { this.restoreDeleteConfirm(); } })
      }
      ReadRecordOptionRow({ icon: 'profileRefresh', title: '清除归属决定', detail: '重新询问作者为空的旧记录归属',
        onSelect: (): void => { this.clearAliasDecisions(); } })
      ReadRecordOptionRow({ icon: 'profileTimeline', title: '阅读总览', detail: '跨书统计、排行与读书日历',
        onSelect: (): void => { this.showActionsSheet = false; this.onOpenOverview(); } })
    }.width('100%').padding({ bottom: 16 })
  }
}

@Component
export struct CacheManagementPage {
  @State cacheGroupMenuVisible: boolean = false;
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('appTopInset') appTopInset: number = 0;
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @Prop groups: string[] = [];
  @Prop books: Book[] = [];
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State selectedCacheGroup: string = '全部';
  @State cacheStats: Map<string, BookCacheStat> = new Map<string, BookCacheStat>();
  @State expandedBookKeys: Set<string> = new Set<string>();
  /** 批2（:441）：展开过的书才加载章节，免得一进页面把所有书都读一遍。key = bookKey。 */
  @State chapterRowsByBook: Map<string, BookChapter[]> = new Map<string, BookChapter[]>();
  /** 批2（:439）：卡片级下载档位，key = bookKey。 */
  @State bookDownloadStates: Map<string, DownloadState> = new Map<string, DownloadState>();
  /** 批2（:441）：章节级下载档位，key = `${bookKey}#${chapterIndex}`。 */
  @State chapterDownloadStates: Map<string, DownloadState> = new Map<string, DownloadState>();
  /** 批2（:446）：长按进选择模式，选中项是 bookKey。 */
  @State selectionMode: boolean = false;
  @State selectedBookKeys: Set<string> = new Set<string>();
  private downloadUnsubscribe: (() => void) | undefined = undefined;

  aboutToAppear(): void {
    this.refreshCacheStats();
    // 一次订阅供卡片与章节行共用（上游 BookCacheManageScreen 也是同一份 state）。
    this.downloadUnsubscribe = ChapterDownloadQueue.subscribe(() => this.refreshDownloadStates());
    this.refreshDownloadStates();
  }

  aboutToDisappear(): void {
    if (this.downloadUnsubscribe !== undefined) {
      this.downloadUnsubscribe();
      this.downloadUnsubscribe = undefined;
    }
  }

  /** 刷新统计：整批替换 Map，@State 对 Map 原地 set 不触发刷新。 */
  private async refreshCacheStats(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    this.cacheStats = await CacheStatsRepository.load(context, this.books);
  }

  /**
   * 缓存页的书籍过滤，语义照上游 BookCacheManageScreen.kt:118-133：
   * 搜索只比书名与作者且不区分大小写。
   * 本地 Book 没有掩码，groupNames 是名字数组，所以用 includes 而不是位与——
   * 这是本地与上游的实质差异。
   */
  private filteredCacheBooks(): Book[] {
    const keyword = this.searchQuery.trim().toLowerCase();
    return this.books.filter((book: Book) => {
      const groupNames = book.groupNames ?? [];
      let matchesGroup = true;
      if (this.selectedCacheGroup === '无分组') {
        matchesGroup = groupNames.length === 0;
      } else if (this.selectedCacheGroup !== '全部') {
        matchesGroup = groupNames.includes(this.selectedCacheGroup);
      }
      const matchesSearch = keyword.length === 0 ||
        book.title.toLowerCase().includes(keyword) ||
        book.author.toLowerCase().includes(keyword);
      return matchesGroup && matchesSearch;
    });
  }

  private bookKey(book: Book): string {
    return LocalBookRestorePlanner.bookUrlOf(book);
  }

  private chapterCountOf(book: Book): number {
    const stat = this.cacheStats.get(this.bookKey(book));
    return stat !== undefined ? stat.chapterCount : Number(book.chapterCount ?? '0');
  }

  private importedOf(book: Book): boolean {
    const stat = this.cacheStats.get(this.bookKey(book));
    return stat !== undefined ? stat.imported : false;
  }

  private sizeLabelOf(book: Book): string {
    const stat = this.cacheStats.get(this.bookKey(book));
    return this.formatSize(stat !== undefined ? stat.sizeBytes : 0);
  }

  private formatSize(bytes: number): string {
    if (bytes >= 1024 * 1024) { return `${(bytes / (1024 * 1024)).toFixed(1)} MB`; }
    if (bytes >= 1024) { return `${(bytes / 1024).toFixed(1)} KB`; }
    return `${bytes} B`;
  }

  private isExpanded(book: Book): boolean {
    return this.expandedBookKeys.has(this.bookKey(book) + '_' + book.id);
  }

  private toggleExpand(book: Book): void {
    const key = this.bookKey(book) + '_' + book.id;
    const next = new Set<string>(this.expandedBookKeys);
    if (next.has(key)) {
      next.delete(key);
    } else {
      next.add(key);
      // 批2（:441）：展开时才去读章节，读者不展开就不花这份 IO。
      this.loadChapterRows(book);
    }
    this.expandedBookKeys = next;
  }

  /** 批2（:441）：章节行数据源；在线书才读，本地书正文就是一整本文件。 */
  private async loadChapterRows(book: Book): Promise<void> {
    if (!BookRepository.isOnlineBook(book)) {
      return;
    }
    const key = this.bookKey(book);
    if ((this.chapterRowsByBook.get(key) ?? []).length > 0) {
      return;
    }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    try {
      const rows = await BookRepository.getChapterList(context, key);
      const nextRows = new Map<string, BookChapter[]>(this.chapterRowsByBook);
      nextRows.set(key, rows);
      this.chapterRowsByBook = nextRows;
      this.refreshDownloadStates();
    } catch (_) {
      this.onUnavailableAction('章节列表读取失败');
    }
  }

  /**
   * 批2（:439/:441）：把队列快照摊成卡片档位与章节档位两张表。
   * 上游 BookCacheManageScreen.kt:499-626 的下载按钮与章节行状态读的是同一份下载状态，
   * 所以这里一次性推两张表，两边同时变。
   */
  private refreshDownloadStates(): void {
    const nextBookStates = new Map<string, DownloadState>();
    const nextChapterStates = new Map<string, DownloadState>();
    this.books.forEach((book: Book) => {
      if (!BookRepository.isOnlineBook(book)) {
        return;
      }
      const key = this.bookKey(book);
      const snapshot = ChapterDownloadQueue.snapshot(key);
      let bookState: DownloadState = 'idle';
      if (snapshot.paused) {
        bookState = 'paused';
      } else if (snapshot.running > 0) {
        bookState = 'running';
      } else if (snapshot.total > 0 && snapshot.done + snapshot.failed >= snapshot.total) {
        bookState = snapshot.failed > 0 ? 'failed' : 'done';
      } else if (snapshot.total > 0) {
        bookState = 'queued';
      }
      nextBookStates.set(key, bookState);
      (this.chapterRowsByBook.get(key) ?? []).forEach((chapter: BookChapter) => {
        const state = ChapterDownloadQueue.chapterState(key, chapter.index);
        if (state !== 'idle') {
          nextChapterStates.set(`${key}#${chapter.index}`, state);
        }
      });
    });
    this.bookDownloadStates = nextBookStates;
    this.chapterDownloadStates = nextChapterStates;
  }

  /** 批2（:442）：六档文案，与管理页 :459 的文案保持同一套，别各写一份。 */
  private downloadStateLabel(state: DownloadState): string {
    if (state === 'queued') { return '排队中'; }
    if (state === 'running') { return '下载中'; }
    if (state === 'paused') { return '已暂停'; }
    if (state === 'done') { return '已下载'; }
    if (state === 'failed') { return '失败'; }
    return '未下载';
  }

  private bookDownloadStateOf(book: Book): DownloadState {
    return this.bookDownloadStates.get(this.bookKey(book)) ?? 'idle';
  }

  private isBookDownloadBusy(book: Book): boolean {
    const state = this.bookDownloadStateOf(book);
    return state === 'queued' || state === 'running' || state === 'paused';
  }

  private chapterRowsOf(book: Book): BookChapter[] {
    return this.chapterRowsByBook.get(this.bookKey(book)) ?? [];
  }

  private chapterStateMap(book: Book): Map<number, DownloadState> {
    const result = new Map<number, DownloadState>();
    const key = this.bookKey(book);
    this.chapterRowsOf(book).forEach((chapter: BookChapter) => {
      result.set(chapter.index, this.chapterDownloadStates.get(`${key}#${chapter.index}`) ?? 'idle');
    });
    return result;
  }

  /** 批2（:439）：卡片上的下载/停止。忙就停，闲就把缺的章全入队。 */
  private toggleBookDownload(book: Book): void {
    const key = this.bookKey(book);
    if (this.isBookDownloadBusy(book)) {
      ChapterDownloadQueue.stop(key);
      return;
    }
    const rows = this.chapterRowsOf(book).filter((chapter: BookChapter) =>
      !BookRepository.isChapterCached(book, chapter));
    if (rows.length === 0) {
      this.onUnavailableAction(this.chapterRowsOf(book).length === 0
        ? '章节还没加载出来，展开后再试' : '这本书的章节都已经缓存好了');
      return;
    }
    ChapterDownloadQueue.enqueue(book, rows);
    this.refreshDownloadStates();
  }

  /** 批2（:443）：单章下载 / 暂停整本，两者都不改书目，只改缓存。 */
  private requestChapterDownload(book: Book, chapter: BookChapter): void {
    if (BookRepository.isChapterCached(book, chapter)) {
      this.onUnavailableAction('这一章已经缓存好了');
      return;
    }
    ChapterDownloadQueue.enqueue(book, [chapter]);
    this.refreshDownloadStates();
  }

  private pauseBookDownload(book: Book): void {
    ChapterDownloadQueue.pause(this.bookKey(book));
    this.refreshDownloadStates();
  }

  /** 批2（:445）：删章节缓存要确认，删除后重读会重新下载。 */
  private confirmDeleteChapterCache(book: Book, chapter: BookChapter): void {
    this.getUIContext().showAlertDialog({
      title: '删除这一章的缓存？',
      message: `会删掉「${chapter.title}」在应用内的正文缓存，重新阅读时要重新下载。`,
      autoCancel: true,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '删除',
        action: () => {
          const deleted = BookRepository.deleteOnlineChapterCache(book, chapter);
          this.onUnavailableAction(deleted ? '章节缓存已删除' : '这一章本来就没有缓存');
          this.refreshCacheStats();
          this.refreshDownloadStates();
        }
      }
    });
  }

  /** 批2（:446）：长按卡片进选择模式；底栏「删除选中」按书清在线缓存。 */
  private toggleBookSelection(book: Book): void {
    const key = this.bookKey(book);
    const next = new Set<string>(this.selectedBookKeys);
    if (next.has(key)) {
      next.delete(key);
    } else {
      next.add(key);
    }
    this.selectedBookKeys = next;
  }

  private exitSelectionMode(): void {
    this.selectionMode = false;
    this.selectedBookKeys = new Set<string>();
  }

  private confirmDeleteSelectedCaches(): void {
    const keys = Array.from(this.selectedBookKeys);
    if (keys.length === 0) {
      this.onUnavailableAction('还没有选中书籍');
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '删除选中缓存？',
      message: `会删除选中的 ${keys.length} 本书在应用内的正文缓存，书目与阅读进度保留。重新阅读时要重新下载。`,
      autoCancel: true,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '删除',
        action: () => {
          this.books.filter((book: Book) => keys.includes(this.bookKey(book)))
            .forEach((book: Book) => BookRepository.clearOnlineBookCache(book));
          BookRepository.clearChapterCache();
          this.exitSelectionMode();
          this.refreshCacheStats();
          this.refreshDownloadStates();
          this.onUnavailableAction(`已清除 ${keys.length} 本书的缓存`);
        }
      }
    });
  }

  /** 删缓存只清应用内导入副本，保留书目与进度；不复用 deleteBook（那会连书目一起删）。 */
  private confirmDeleteCache(book: Book): void {
    this.getUIContext().showAlertDialog({
      title: '删除缓存？',
      message: '会删除应用内的正文副本，书目与阅读进度保留。原始文件如需找回，可用『恢复本地书』。',
      autoCancel: true,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '删除',
        action: () => {
          BookRepository.discardImportedCopy(book);
          this.refreshCacheStats();
        }
      }
    });
  }

  private cacheGroupOptions(): string[] {
    const options: string[] = ['全部', '无分组'];
    this.groups.forEach((group: string) => {
      if (group.length > 0 && group !== '全部' && group !== '无分组' && !options.includes(group)) {
        options.push(group);
      }
    });
    return options;
  }

  @Builder
  private CacheGroupMenu() {
    UiMenuPanel({
      items: this.cacheGroupItems(),
      panelWidth: PROFILE_MENU_WIDTH,
      onSelect: (key: string) => { this.cacheGroupMenuVisible = false; this.selectedCacheGroup = key; }
    })
  }

  private cacheGroupItems(): UiMenuItem[] {
    return this.cacheGroupOptions().map((group: string) => {
      const item: UiMenuItem = { key: group, title: group, selected: this.selectedCacheGroup === group };
      return item;
    });
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
          Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.themeColorTextSecondary)
        }.width(40).height(40).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
          AppGlyph({ name: 'search', glyphSize: 20, tint: this.themeColorTextSecondary })
        }.width(40).height(40).onClick(() => {
          this.showSearch = !this.showSearch;
          if (!this.showSearch) { this.searchQuery = ''; }
        })
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
          AppGlyph({ name: 'profileFilterAlt', glyphSize: 20, tint: this.themeColorTextSecondary })
        }.width(40).height(40)
          .onClick(() => { this.cacheGroupMenuVisible = !this.cacheGroupMenuVisible; })
.bindPopup(this.cacheGroupMenuVisible, {
  builder: this.CacheGroupMenu,
  placement: Placement.BottomRight,
  popupColor: '#00000000',
  enableArrow: false,
  autoCancel: true,
  width: PROFILE_MENU_WIDTH,
  onStateChange: (event: PopupStateChangeParam) => { this.cacheGroupMenuVisible = event.isVisible; }
})
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(16)
          AppGlyph({ name: 'profileRefresh', glyphSize: 20, tint: this.themeColorTextSecondary })
        }.width(40).height(40).onClick(() => this.refreshCacheStats())
      }.width('100%').height(40).padding({ left: 11, right: 12 }).margin({ top: this.appTopInset - 8 })

      Text('缓存管理').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor(this.themeColorTextPrimary)
        .width('100%').padding({ left: 12, right: 18, top: 12 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '筛选书名/作者', text: this.searchQuery })
            .fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).placeholderColor(this.themeColorTextTertiary)
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .id('my_cache_manage_search')
            .onAppear(() => focusControl.requestFocus('my_cache_manage_search'))
            .onChange((value: string) => this.searchQuery = value)
        }.width('calc(100% - 32vp)').height(48).padding({ left: 14, right: 14 })
          .margin({ left: 16, right: 16, top: 8, bottom: 4 }).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(24)
      }

      if (this.filteredCacheBooks().length === 0) {
        Column() {
          CacheEmptySection({
            title: '书架书籍',
            message: this.books.length === 0 ? '书架里还没有书' : '没有符合当前筛选条件的书籍'
          })
          if (this.selectedCacheGroup === '全部') {
            CacheEmptySection({
              title: '未在书架',
              message: '本地导入的书都在书架里，没有独立的下载队列'
            })
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, top: 8, bottom: 18 })
          .layoutWeight(1)
      } else {
        Scroll() {
          Column() {
            ForEach(this.filteredCacheBooks(), (book: Book) => {
              CacheBookCard({
                bookTitle: book.title,
                bookAuthor: book.author,
                chapterCount: this.chapterCountOf(book),
                imported: this.importedOf(book),
                sizeLabel: this.sizeLabelOf(book),
                expanded: this.isExpanded(book),
                online: BookRepository.isOnlineBook(book),
                downloadState: this.bookDownloadStateOf(book),
                downloadStateLabel: this.downloadStateLabel(this.bookDownloadStateOf(book)),
                chapters: this.chapterRowsOf(book),
                chapterStates: this.chapterStateMap(book),
                selectionMode: this.selectionMode,
                selected: this.selectedBookKeys.has(this.bookKey(book)),
                onToggleExpand: () => this.toggleExpand(book),
                onDeleteCache: () => this.confirmDeleteCache(book),
                onToggleDownload: () => this.toggleBookDownload(book),
                onPauseDownload: () => this.pauseBookDownload(book),
                onDownloadChapter: (chapter: BookChapter) => this.requestChapterDownload(book, chapter),
                onDeleteChapter: (chapter: BookChapter) => this.confirmDeleteChapterCache(book, chapter),
                onLongPressSelect: () => {
                  this.selectionMode = true;
                  this.toggleBookSelection(book);
                }
              })
            }, (book: Book) => this.bookKey(book) + '_' + book.id)
          }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 18 })
        }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).layoutWeight(1).scrollBar(BarState.Off)
      }
      // 批2（:446）：选择模式底栏，只有一个批量动作——删除选中书籍的缓存。
      if (this.selectionMode) {
        Row() {
          Text(`已选 ${this.selectedBookKeys.size} 项`)
            .fontSize(LABEL_LARGE).fontColor(this.themeColorTextPrimary).layoutWeight(1)
          Text('删除选中')
            .fontSize(LABEL_LARGE).fontColor('#E5484D')
            .padding({ left: 12, right: 4, top: 8, bottom: 8 })
            .onClick(() => this.confirmDeleteSelectedCaches())
          Text('完成')
            .fontSize(LABEL_LARGE).fontColor(this.themeColorTextSecondary)
            .padding({ left: 12, right: 4, top: 8, bottom: 8 })
            .onClick(() => this.exitSelectionMode())
        }
        .width('100%').padding({ left: 16, right: 8, top: 10, bottom: 10 })
        .backgroundColor(this.themeColorSurfaceElevated)
      }
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
  }
}

@Component
struct ReadRecordOptionRow {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @Prop icon: AppGlyphName = 'info';
  @Prop title: string = '';
  @Prop detail: string = '';
  onSelect: () => void = () => {};

  build() {
    Row() {
      AppGlyph({ name: this.icon, glyphSize: 19, tint: this.themeColorAccent }).width(32)
      Column() {
        Text(this.title).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary)
        Text(this.detail).fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .onClick(() => this.onSelect())
  }
}

@Component
struct CacheEmptySection {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @Prop title: string = '';
  @Prop message: string = '';
  build() {
    Column() {
      Text(this.title).fontSize(TITLE_SMALL_EMPHASIZED).fontColor(this.themeColorAccent)
        .alignSelf(ItemAlign.Start).margin({ left: 10, bottom: 7 })
      Text(this.message).fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).width('100%').textAlign(TextAlign.Start)
        .padding({ left: 12, right: 12, top: 12, bottom: 12 }).backgroundColor(this.themeColorSurfaceSecondary).borderRadius(8)
    }.width('100%').margin({ bottom: 14 })
  }
}

/** 缓存页的书籍卡：本地书是整本导入（n/total 与进度恒 100%），在线书按章下载。 */
@Component
struct CacheBookCard {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @Prop bookTitle: string = '';
  @Prop bookAuthor: string = '';
  @Prop chapterCount: number = 0;
  @Prop imported: boolean = false;
  @Prop sizeLabel: string = '';
  @Prop expanded: boolean = false;
  /** 批2（:439）：在线书才有下载这套；本地书正文就是磁盘那一本文件。 */
  @Prop online: boolean = false;
  @Prop downloadState: DownloadState = 'idle';
  @Prop downloadStateLabel: string = '未下载';
  /** 批2（:441）：章节行数据源，只有展开且已加载过才有内容。 */
  @Prop chapters: BookChapter[] = [];
  @Prop chapterStates: Map<number, DownloadState> = new Map<number, DownloadState>();
  /** 批2（:446）：选择模式下整卡可勾选。 */
  @Prop selectionMode: boolean = false;
  @Prop selected: boolean = false;
  onToggleExpand: () => void = () => {};
  onDeleteCache: () => void = () => {};
  onToggleDownload: () => void = () => {};
  onPauseDownload: () => void = () => {};
  onDownloadChapter: (chapter: BookChapter) => void = (_chapter: BookChapter) => {};
  onDeleteChapter: (chapter: BookChapter) => void = (_chapter: BookChapter) => {};
  onLongPressSelect: () => void = () => {};

  private chapterStateLabel(index: number): string {
    const state = this.chapterStates.get(index) ?? 'idle';
    if (state === 'queued') { return '排队中'; }
    if (state === 'running') { return '下载中'; }
    if (state === 'paused') { return '已暂停'; }
    if (state === 'done') { return '已下载'; }
    if (state === 'failed') { return '失败'; }
    return '未下载';
  }

  private chapterStateOf(index: number): DownloadState {
    return this.chapterStates.get(index) ?? 'idle';
  }

  private isBusy(): boolean {
    return this.downloadState === 'queued' || this.downloadState === 'running' || this.downloadState === 'paused';
  }

  build() {
    Column() {
      Row() {
        if (this.selectionMode) {
          Stack() {
            Row()
              .width(18).height(18).borderRadius(4).borderWidth(1)
              .borderColor(this.selected ? this.themeColorAccent : this.themeColorTextTertiary)
              .backgroundColor(this.selected ? this.themeColorAccent : Color.Transparent)
            if (this.selected) {
              AppGlyph({ name: 'profileCheck', glyphSize: 12, tint: '#FFFFFF' })
            }
          }.width(18).height(18).margin({ right: 10 })
        }
        AppGlyph({ name: 'profileExpandMore', glyphSize: 18, tint: this.themeColorAccent })
          .rotate({ angle: this.expanded ? 90 : 0 }).margin({ right: 8 })
        Column() {
          Text(this.bookTitle).fontSize(LABEL_LARGE).fontColor(this.themeColorTextPrimary).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.bookAuthor.length > 0 ? this.bookAuthor : '作者未知').fontSize(LABEL_SMALL)
            .fontColor(this.themeColorTextTertiary).maxLines(1).margin({ top: 2 })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        // 批2（:442）：在线书卡片右端显示六档档位之一，本地书仍显示 n/total。
        if (this.online) {
          Text(this.downloadStateLabel).fontSize(BODY_SMALL)
            .fontColor(this.downloadState === 'failed' ? '#E5484D' : this.themeColorAccent)
        } else {
          Text(`${this.imported ? this.chapterCount : 0}/${this.chapterCount}`)
            .fontSize(BODY_SMALL).fontColor(this.themeColorAccent)
        }
      }.width('100%')
        .onClick(() => {
          if (this.selectionMode) {
            this.onLongPressSelect();
          } else {
            this.onToggleExpand();
          }
        })
        .gesture(LongPressGesture().onAction(() => this.onLongPressSelect()))
      Progress({
        value: this.chapterCount === 0 ? 0 : (this.imported ? 100 : 0),
        total: 100,
        type: ProgressType.Linear
      }).height(3).color(this.themeColorAccent).backgroundColor('#E4E0D7').margin({ top: 9 })
      Row() {
        Text(`章节 ${this.chapterCount} | ${this.imported ? '已导入' : '未导入'} | 占用 ${this.sizeLabel}`)
          .fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).layoutWeight(1)
        if (this.online) {
          // 批2（:439）：下载 / 下载中… 点一下即停止。
          Text(this.isBusy() ? '停止' : '下载')
            .fontSize(BODY_SMALL).fontColor(this.themeColorAccent)
            .padding({ left: 8, top: 4, bottom: 4 })
            .onClick(() => this.onToggleDownload())
          // 批2（:443）：暂停只对正在下或排队中有意义。
          if (this.downloadState === 'queued' || this.downloadState === 'running') {
            Text('暂停').fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary)
              .padding({ left: 8, top: 4, bottom: 4 })
              .onClick(() => this.onPauseDownload())
          }
        } else {
          Text('删除缓存').fontSize(BODY_SMALL).fontColor('#FF6B6B')
            .padding({ left: 8, top: 4, bottom: 4 }).onClick(() => this.onDeleteCache())
        }
      }.width('100%').margin({ top: 8 })
      // 批2（:441）：展开后逐章列出行与状态，动作按档位切换（下载 / 删除缓存）。
      if (this.expanded) {
        if (this.online) {
          if (this.chapters.length === 0) {
            Text('章节列表加载中…').fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary)
              .width('100%').margin({ top: 6 })
          } else {
            Column() {
              ForEach(this.chapters, (chapter: BookChapter) => {
                Row() {
                  Text(chapter.title).fontSize(LABEL_SMALL).fontColor(this.themeColorTextPrimary)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
                  Text(this.chapterStateLabel(chapter.index))
                    .fontSize(LABEL_SMALL)
                    .fontColor(this.chapterStateOf(chapter.index) === 'failed' ? '#E5484D' : this.themeColorTextTertiary)
                    .margin({ left: 8 })
                  if (this.chapterStateOf(chapter.index) === 'done') {
                    Text('删除').fontSize(LABEL_SMALL).fontColor('#FF6B6B')
                      .padding({ left: 10, top: 4, bottom: 4 })
                      .onClick(() => this.onDeleteChapter(chapter))
                  } else if (this.chapterStateOf(chapter.index) === 'idle' ||
                    this.chapterStateOf(chapter.index) === 'failed') {
                    Text('下载').fontSize(LABEL_SMALL).fontColor(this.themeColorAccent)
                      .padding({ left: 10, top: 4, bottom: 4 })
                      .onClick(() => this.onDownloadChapter(chapter))
                  }
                }.width('100%').padding({ top: 5, bottom: 5 })
              }, (chapter: BookChapter) => `${chapter.index}_${chapter.title}`)
            }.width('100%').margin({ top: 6 })
          }
        } else {
          Text(this.imported ? '正文已在应用内导入，缓存即整本文件。' : '应用内正文副本已删除，可用「恢复本地书」找回。')
            .fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).width('100%').margin({ top: 6 })
        }
      }
    }.width('100%').padding(12).backgroundColor(this.themeColorSurfaceSecondary)
      .borderRadius(8).margin({ bottom: 12 })
      .borderWidth(this.selectionMode && this.selected ? 1 : 0)
      .borderColor(this.themeColorAccent)
  }
}


@Component
export struct AboutAppPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onOpenPrivacyNotice: () => void = () => {};
  onOpenLicense: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State versionName: string = '';
  @State collapsedHeader: boolean = false;
  private aboutScroller: Scroller = new Scroller();

  private updateHeader(): void {
    const offset = this.aboutScroller.currentOffset().yOffset;
    const shouldCollapse = offset > HEADER_COLLAPSE_THRESHOLD ? true : offset < HEADER_EXPAND_THRESHOLD ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      // 顶部折叠是位移，用弹簧收尾更自然；弹簧不吃 duration，删掉（写了也不生效）。
      this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.86) }, () => {
        this.collapsedHeader = shouldCollapse;
      });
    }
  }

  aboutToAppear(): void {
    this.loadVersionName();
  }

  private async loadVersionName(): Promise<void> {
    try {
      const bundleInfo = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      );
      this.versionName = bundleInfo.versionName;
    } catch (_) {
      this.versionName = '版本信息不可用';
    }
  }

  build() {
    Column() {
      CollapsingSettingsHeader({ title: '关于', collapsed: this.collapsedHeader, onBack: () => this.onBack() })
      Scroll(this.aboutScroller) {
        Column() {
          Column() {
            Image($r('app.media.about_cat')).width(72).height(72)
            Blank().height(18)
            Blank().height(5)
            Text('阅读·D').fontSize(TITLE_LARGE).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
            if (this.versionName.length > 0) {
              Text(this.versionName).fontSize(BODY_SMALL).fontColor(this.themeColorTextSecondary).padding({ left: 9, right: 9, top: 4, bottom: 4 })
                .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(8).margin({ top: 3 })
            }
            Text('全新设计的阅读 3.0').fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 4 })
          }.width('100%').padding({ top: 4, bottom: 8 }).alignItems(HorizontalAlign.Center)

          Row() {
            AboutQuickAction({ icon: 'about_web', description: '项目主页', onSelect: () => this.onUnavailableAction('项目主页尚未接入外部链接') })
            AboutQuickAction({ icon: 'about_github', description: 'GitHub', onSelect: () => this.onUnavailableAction('GitHub 尚未接入外部链接') })
            AboutQuickAction({ icon: 'about_update', description: '检查更新', onSelect: () => this.onUnavailableAction('更新检查尚未迁移') })
          }.width('100%').padding({ left: 12, right: 12, bottom: 8 })

          Column() {
            AboutActionRow({ title: '开发人员', onSelect: () => this.onUnavailableAction('开发人员页面尚未迁移') })
            AboutActionRow({ title: '用户隐私与协议', onSelect: () => this.onOpenPrivacyNotice() })
            AboutActionRow({ title: '开源许可', onSelect: () => this.onOpenLicense() })
            AboutActionRow({ title: '免责声明', onSelect: () => this.onUnavailableAction('免责声明页面尚未迁移') })
            AboutActionRow({ title: '崩溃日志', onSelect: () => this.onUnavailableAction('崩溃日志页面尚未迁移') })
            AboutActionRow({ title: '保存日志', onSelect: () => this.onUnavailableAction('日志导出尚未迁移') })
            AboutActionRow({ title: '创建堆转储', last: true, onSelect: () => this.onUnavailableAction('堆转储尚未迁移') })
          }.width('100%').padding({ top: 2, bottom: 2 }).backgroundColor(this.themeColorSurfaceSecondary).borderRadius(14)
        }.padding({ left: 16, right: 16, top: 4, bottom: 18 })
      }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
  }
}

@Component
struct AboutQuickAction {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @Prop icon: string = 'about_web';
  @Prop description: string = '';
  onSelect: () => void = () => {};
  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Image(this.icon === 'about_github' ? $r('app.media.about_github') :
          (this.icon === 'about_update' ? $r('app.media.about_update') : $r('app.media.about_web')))
          .width(20).height(20).fillColor(this.themeColorTextSecondary).accessibilityText(this.description)
      }.width(36).height(36).backgroundColor(this.themeColorSurfaceElevated).borderRadius(18).onClick(() => this.onSelect())
    }.layoutWeight(1).alignItems(HorizontalAlign.Center)
  }
}

@Component
struct AboutActionRow {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop title: string = '';
  @Prop last: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Column() {
      Row() {
        Text(this.title).fontSize(PROFILE_ROW_TITLE_SIZE).fontColor(this.themeColorTextSecondary).layoutWeight(1)
      }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 16 }).onClick(() => this.onSelect())
      if (!this.last) { Row().height(1).width('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary)).margin({ left: 16, right: 16 }) }
    }.width('100%')
  }
}

@Component
export struct AppSettingsHomePage {
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onOpenCategory: (destination: ProfileRoute) => void = (_destination: ProfileRoute) => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State collapsedHeader: boolean = false;
  private settingsScroller: Scroller = new Scroller();

  private updateHeader(): void {
    const offset = this.settingsScroller.currentOffset().yOffset;
    const shouldCollapse = offset > HEADER_COLLAPSE_THRESHOLD ? true : offset < HEADER_EXPAND_THRESHOLD ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      // 顶部折叠是位移，用弹簧收尾更自然；弹簧不吃 duration，删掉（写了也不生效）。
      this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.86) }, () => {
        this.collapsedHeader = shouldCollapse;
      });
    }
  }
  @StorageProp('themeCardRadius') themeCardRadius: number = 16;
  @StorageProp('themeCardBorderWidth') themeCardBorderWidth: number = 0;
  @StorageProp('themeCardBorderColor') themeCardBorderColor: string = '#6A6D77';
  @StorageProp('themeCardBackground') themeCardBackground: string = '';
  @StorageProp('themeContainerBackground') themeContainerBackground: string = '';
  build() {
    Column() {
      SettingsPageHeader({ title: '设置', collapsed: this.collapsedHeader, onBack: () => this.onBack() })
      Scroll(this.settingsScroller) {
        Column() {
          Column() {
          // 上游 ConfigNavScreen.kt:57-104 是「一个 SplicedColumnGroup + 11 个
          // ClickableSettingItem」，行组件统一走 UiAction（含自带分隔线），
          // 不再手写 SettingsCategoryRow + ThemeItemDivider。
          UiAction({ title: '外观', onSelect: () => this.onOpenCategory(ProfileRoute.APP_THEME_SETTINGS) })
          UiAction({ title: '高级', onSelect: () => this.onOpenCategory(ProfileRoute.APP_OTHER_SETTINGS) })
          UiAction({ title: '阅读界面', onSelect: () => this.onOpenCategory(ProfileRoute.APP_READ_SETTINGS) })
          UiAction({ title: '朗读设置', detail: '管理角色声音池、背景音乐池与角色配音分配', onSelect: () => this.onOpenCategory(ProfileRoute.APP_ALOUD_SETTINGS) })
          UiAction({ title: '封面设置', onSelect: () => this.onOpenCategory(ProfileRoute.APP_COVER_SETTINGS) })
          UiAction({ title: '下载与缓存', onSelect: () => this.onOpenCategory(ProfileRoute.APP_DOWNLOAD_CACHE_SETTINGS) })
          UiAction({ title: '备份与恢复', onSelect: () => this.onOpenCategory(ProfileRoute.APP_BACKUP_SETTINGS) })
          UiAction({ title: 'AI 设置', onSelect: () => this.onOpenCategory(ProfileRoute.APP_AI_SETTINGS) })
          UiAction({ title: '翻译设置', onSelect: () => this.onOpenCategory(ProfileRoute.APP_TRANSLATION_SETTINGS) })
          UiAction({ title: '隐私', onSelect: () => this.onOpenCategory(ProfileRoute.APP_PRIVACY_SETTINGS) })
          UiAction({ title: '实验室', showDivider: false, onSelect: () => this.onOpenCategory(ProfileRoute.APP_LAB_SETTINGS) })
          }.width('100%').backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
        }.padding({ left: 16, right: 16, top: 8, bottom: 16 })
      }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
  }
}

@Component
struct SettingsPageHeader {
  @Prop title: string = '';
  @Prop collapsed: boolean = false;
  onBack: () => void = () => {};

  @Builder navSlot() {
    TopBarBackButton({ onSelect: () => this.onBack() })
  }

  build() {
    AppTopBar({
      title: this.title,
      collapsed: this.collapsed,
      hasNavigation: true,
      // @BuilderParam 一律箭头包装：直接传方法引用会把 builder 的 this 重绑到 AppTopBar，
      // 导致 navSlot 内 this.onBack 为 undefined，点返回即崩溃（批3 实测）。
      navigationIcon: () => { this.navSlot() }
    })
  }
}

@Component
export struct AiChatPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State historyVisible: boolean = false;
  @State draft: string = '';
  @State reasoningIndex: number = 1;
  @State showReasoningSheet: boolean = false;

  private handleBack(): void {
    if (this.historyVisible) {
      this.historyVisible = false;
    } else {
      this.onBack();
    }
  }

  private sendDraft(): void {
    if (this.draft.trim().length === 0) { return; }
    this.onUnavailableAction('AI服务商未配置，消息未发送');
  }

  private reasoningLabel(): string {
    if (this.reasoningIndex <= 0) { return '关闭'; }
    if (this.reasoningIndex === 1) { return '自动'; }
    if (this.reasoningIndex === 2) { return '轻度'; }
    if (this.reasoningIndex === 3) { return '中'; }
    if (this.reasoningIndex === 4) { return '高'; }
    if (this.reasoningIndex === 5) { return '极高'; }
    return '最高';
  }

  @Builder
  private ReasoningSheet() {
    Column() {
      Text('思考模式').fontSize(HEADLINE_SMALL).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        .width('100%').padding({ left: 20, right: 20, top: 20, bottom: 10 })
      Text(this.reasoningLabel()).fontSize(HEADLINE_MEDIUM).fontColor(this.themeColorTextPrimary)
        .width('100%').textAlign(TextAlign.Center).padding({ top: 20, bottom: 20 })
      Slider({ value: this.reasoningIndex, min: 0, max: 6, step: 1, style: SliderStyle.OutSet })
        .blockColor(this.themeColorAccent).trackColor('#41485D').selectedColor(this.themeColorAccent)
        .showSteps(true).showTips(false).margin({ left: 22, right: 22 })
        .onChange((value: number) => this.reasoningIndex = Math.round(value))
      Text('此选项仅为本页预览；AI 服务未连接时不会用于生成。')
        .fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary).textAlign(TextAlign.Center)
        .width('100%').padding({ left: 20, right: 20, top: 18, bottom: 24 })
    }.width('100%').backgroundColor('#17181E')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Row() {
          Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.themeColorTextSecondary)
            .width(36).onClick(() => this.handleBack())
          Column() {
            Text('AI 对话').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
            Text('新对话').fontSize(PROFILE_PAGE_SUBTITLE_SIZE).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          AppGlyph({ name: 'list', glyphSize: 19, tint: this.themeColorTextSecondary }).padding({ left: 8, right: 8 })
            .onClick(() => this.historyVisible = true)
          .accessibilityText('最近对话')
          AppGlyph({ name: 'add', glyphSize: 19, tint: this.themeColorTextSecondary }).padding({ left: 8, right: 8 })
            .onClick(() => { this.draft = ''; this.onUnavailableAction('新会话已准备；配置 AI 服务后即可发送消息'); })
          .accessibilityText('新建对话')
        }.width('100%').padding({ left: 12, right: 10, top: 11, bottom: 9 })

        Row() {
          AppGlyph({ name: 'sparkles', glyphSize: 16, tint: this.themeColorAccent }).margin({ right: 7 })
          Text('模型未配置').fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary)
          Blank()
          AppGlyph({ name: 'more', glyphSize: 16, tint: this.themeColorTextTertiary })
        }.padding({ left: 12, right: 12, top: 9, bottom: 9 }).margin({ left: 16, right: 16, top: 4 })
          .backgroundColor(this.themeColorSurfaceSecondary).borderRadius(18)
          .onClick(() => this.onUnavailableAction('请先在“我的→设置→AI 设置”配置服务商和模型'))

        Column() {
          AppGlyph({ name: 'sparkles', glyphSize: 40, tint: this.themeColorAccent }).margin({ bottom: 14 })
          Text('和你的书对话').fontSize(BODY_LARGE).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextSecondary)
          Text('配置 AI 服务后，提问和回复会显示在这里。')
            .fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary).textAlign(TextAlign.Center).margin({ top: 8 })
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)

        Column() {
          Row() {
            TextInput({ placeholder: '输入问题…', text: this.draft })
              .fontSize(LABEL_LARGE).fontColor(this.themeColorTextSecondary).placeholderColor(this.themeColorTextTertiary)
              .backgroundColor(Color.Transparent).layoutWeight(1).maxLines(4)
              .onChange((value: string) => this.draft = value)
            Image($r('app.media.app_send')).width(18).height(18).fillColor(this.draft.trim().length > 0 ? this.themeColorTextPrimary : this.themeColorTextTertiary)
              .width(40).height(40).backgroundColor(this.draft.trim().length > 0 ? this.themeColorAccent : '#303139')
              .borderRadius(20).onClick(() => this.sendDraft())
          }.padding({ left: 14, right: 8, top: 7, bottom: 7 }).backgroundColor(this.themeColorSurfaceSecondary).borderRadius(24)
          Row() {
            Text(`思考模式：${this.reasoningLabel()}`).fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary)
              .onClick(() => this.showReasoningSheet = true)
            Blank()
            Text('AI 服务未配置').fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary)
          }.padding({ left: 6, right: 6, top: 7, bottom: 5 })
        }.padding({ left: 16, right: 16, top: 8, bottom: 12 })
      }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))

      if (this.historyVisible) {
        Stack({ alignContent: Alignment.TopStart }) {
          Column().width('100%').height('100%').backgroundColor('#99000000')
            .onClick(() => this.historyVisible = false)
          Column() {
            Row() {
              Text('最近会话').fontSize(HEADLINE_SMALL).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary).layoutWeight(1)
              AppGlyph({ name: 'add', glyphSize: 19, tint: this.themeColorTextSecondary }).padding(8)
                .onClick(() => { this.historyVisible = false; this.draft = ''; })
            }.padding({ left: 18, right: 12, top: 18, bottom: 16 })
            Row() {
              AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
              TextInput({ placeholder: '搜索会话…' }).fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary)
                .placeholderColor(this.themeColorTextTertiary).backgroundColor(Color.Transparent).layoutWeight(1)
            }.padding({ left: 12, right: 12, top: 8, bottom: 8 }).margin({ left: 14, right: 14 })
              .backgroundColor('#22232A').borderRadius(20)
            Column() {
              AppGlyph({ name: 'sparkles', glyphSize: 28, tint: this.themeColorTextTertiary }).margin({ bottom: 10 })
              Text('暂无会话记录').fontSize(TITLE_SMALL).fontColor('#AEB0BA')
            }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
            Text('新建对话').fontSize(LABEL_LARGE).fontColor(this.themeColorTextPrimary).textAlign(TextAlign.Center)
              .width('100%').padding(13).margin({ left: 14, right: 14, bottom: 20 })
              .backgroundColor(this.themeColorAccent).borderRadius(24)
              .onClick(() => { this.historyVisible = false; this.draft = ''; this.onUnavailableAction('配置 AI 服务后即可开始对话'); })
          }.width('82%').height('100%').backgroundColor('#17181E')
        }.width('100%').height('100%')
      }
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      .bindSheet(this.showReasoningSheet, this.ReasoningSheet(), {
        height: SheetSize.FIT_CONTENT,
        dragBar: true,
        showClose: false,
        backgroundColor: '#17181E',
        onDisappear: () => this.showReasoningSheet = false
      })
  }
}

@Component
struct ModuleHeader {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @Prop title: string = '';
  @Prop subtitle: string = '';
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  build() {
    Column() {
      Row() {
        Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.themeColorTextSecondary).width(36).onClick(() => this.onBack())
        Column() {
          Text(this.title).fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
          Text(this.subtitle).fontSize(PROFILE_PAGE_SUBTITLE_SIZE).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        AppGlyph({ name: 'search', glyphSize: 18, tint: this.themeColorTextSecondary }).padding({ left: 8, right: 8 })
          .onClick(() => this.onUnavailableAction('设置搜索尚未迁移'))
        AppGlyph({ name: 'more', glyphSize: 17, tint: this.themeColorTextSecondary }).padding({ left: 6, right: 6 })
          .onClick(() => this.onUnavailableAction('设置更多操作尚未迁移'))
      }.width('100%').padding({ left: 12, right: 10, top: 11, bottom: 9 })
    }
  }
}

@Component
struct ModuleSearch {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop hint: string = '';
  @State query: string = '';
  build() {
    Row() {
      AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
      TextInput({ placeholder: this.hint, text: this.query })
        .fontSize(TITLE_MEDIUM)
        .fontColor(this.themeColorTextSecondary)
        .placeholderColor(this.themeColorTextTertiary)
        .backgroundColor(Color.Transparent)
        .onChange((value: string) => this.query = value)
        .layoutWeight(1)
    }.width('100%').padding({ left: 12, right: 14, top: 7, bottom: 7 }).margin({ left: 16, right: 16 }).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(22)
  }
}

@Component
struct ModuleTab {
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @Prop label: string = '';
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Text(this.label).fontSize(TITLE_MEDIUM).fontColor(this.selected ? '#E1E5F3' : '#A4A6B0')
      .textAlign(TextAlign.Center).layoutWeight(1).padding({ top: 9, bottom: 9 })
      .backgroundColor(this.selected ? '#41485D' : this.themeColorSurfaceSecondary).borderRadius(20).margin({ right: 7 })
      .onClick(() => this.onSelect())
  }
}

/** P4 菜单里的一行（条目菜单与批量面板共用），点一下回传 onClick。 */
@Component
struct UiMenuItemView {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @Prop title: string = '';
  onSelect: () => void = () => {};
  build() {
    Row() {
      Text(this.title).fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary).layoutWeight(1)
    }.width('100%').padding({ left: 14, right: 14, top: 12, bottom: 12 })
      .borderRadius(8).backgroundColor(this.themeColorSurfaceTertiary)
      .margin({ bottom: 6 })
      .onClick(() => this.onSelect())
  }
}

@Component
struct ModuleEmpty {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @Prop icon: AppGlyphName = 'book';
  @Prop title: string = '';
  @Prop detail: string = '';
  build() {
    Column() {
      AppGlyph({ name: this.icon, glyphSize: 34, tint: this.themeColorAccent }).margin({ bottom: 14 })
      Text(this.title).fontSize(TITLE_LARGE).fontColor(this.themeColorTextSecondary)
      Text(this.detail).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextTertiary).textAlign(TextAlign.Center).margin({ left: 34, right: 34, top: 8 })
    }.width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }
}

@Component
struct MetricCard {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop label: string = '';
  @Prop value: string = '';
  build() {
    Column() {
      Text(this.label).fontSize(TITLE_SMALL).fontColor(this.themeColorTextTertiary)
      Text(this.value).fontSize(BODY_LARGE).fontColor(this.themeColorTextSecondary).margin({ top: 5 })
    }.layoutWeight(1).alignItems(HorizontalAlign.Start).padding(15).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated))
      .borderRadius(14).margin({ right: 6 })
  }
}

@Component
struct FileCategoryRow {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @Prop icon: AppGlyphName = 'folder';
  @Prop title: string = '';
  @Prop detail: string = '';
  onSelect: () => void = () => {};
  build() {
    Row() {
      AppGlyph({ name: this.icon, glyphSize: 20, tint: this.themeColorAccent }).width(36)
      Column() {
        Text(this.title).fontSize(PROFILE_ROW_TITLE_SIZE).fontColor(this.themeColorTextSecondary)
        Text(this.detail).fontSize(PROFILE_ROW_DETAIL_SIZE).fontColor(this.themeColorTextTertiary).margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.reader_next')).width(18).height(18).fillColor(this.themeColorTextTertiary)
    }.padding({ left: 15, right: 15, top: PROFILE_ROW_VERTICAL_PADDING, bottom: PROFILE_ROW_VERTICAL_PADDING }).margin({ left: 16, right: 16, bottom: 1 })
      .backgroundColor(this.themeColorSurfaceSecondary).onClick(() => this.onSelect())
  }
}

