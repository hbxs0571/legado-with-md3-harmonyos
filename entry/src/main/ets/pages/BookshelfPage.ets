import { Book, bookCoverMark } from '../model/Book';
import { BookGroup, BookGroupDraft, BOOK_SORT_OPTIONS, BookSortOption, bookSortLabel } from '../model/BookGroup';
import {
  BookshelfLayoutSettings, BookshelfLayoutOption, DEFAULT_BOOKSHELF_LAYOUT,
  BOOKSHELF_LAYOUT_MODE_OPTIONS, BOOKSHELF_SORT_ORDER_OPTIONS,
  BOOK_GROUP_STYLE_OPTIONS, BOOKSHELF_FOLDER_LAYOUT_MODE_OPTIONS,
  BOOKSHELF_GROUP_LIST_STYLE_OPTIONS,
  bookshelfLayoutOptionLabel, copyBookshelfLayout, TagColorPair, parseTagColors
} from '../model/BookshelfLayout';
import { BookshelfSort } from '../data/BookshelfSort';
import { CoverSettings, DEFAULT_COVER_SETTINGS } from '../data/CoverSettingsRepository';
import { BookRepository } from '../data/BookRepository';
import { BookCover } from '../components/BookCover';
import { BookGroupCard } from '../components/BookGroupCard';
import { AppGlyph } from '../components/AppGlyph';
import { normalizeCustomColor } from '../data/CustomThemeColors';
import { AppLog } from '../lib/AppLog';
import { BookshelfListTransfer } from '../data/BookshelfListTransfer';
import { window } from '@kit.ArkUI';
import { toTimeAgo } from '../lib/TimeAgo';
import { LocalBookRestorePlanner } from '../data/LocalBookRestorePlanner';
import { argbToColorHex, hexToArgb, deriveTagBgColor, baseHueFromHex, generateTagColors } from '../lib/TagColorUtils';
import { TagGroupRuleRepository } from '../data/TagGroupRuleRepository';
import { TagGroupRule } from '../model/TagGroupRule';
import { pasteboard } from '@kit.BasicServicesKit';
import {
  PRIVATE_UNLOCK_EVERY_TIME, PrivateAccessRepository, isPrivateBook, requiresPrivateUnlock
} from '../data/PrivateAccessRepository';

/** 网格左右内边距，对应上游 BookshelfScreen.kt contentPadding horizontal 8.dp。 */
const BOOKSHELF_GRID_PADDING: number = 8;
/** 网格行间距与列间距，对应上游 BookshelfScreen.kt:1770-1772 的 spacedBy(8.dp)。 */
const BOOKSHELF_GRID_GAP: number = 8;
/**
 * 首屏封面预加载列数：本地没有封面预加载器
 * （`grep -rn 'preload\|Preload' entry/src/main/ets` 零命中），按 0 处理，
 * 不新建预加载系统；封面由 components/BookCover.ets 各卡片自行加载。
 * 对应 KI-SL-C3 / 对照表 C 块「首屏封面预加载列数」一行的本地落点。
 */
const BOOKSHELF_FIRST_SCREEN_PRELOAD_COLUMNS: number = 0;

/** 网格样式选项，对应上游 bookshelf_grid_layout（标准 / 紧凑 / 仅封面）。 */
const BOOKSHELF_GRID_STYLE_OPTIONS: BookshelfLayoutOption[] = [
  { value: 0, label: '标准' },
  { value: 1, label: '紧凑' },
  { value: 2, label: '仅封面' }
];

/** 卡片底色十六进制转 ARGB 整数；空串或非法值返回 0（= 跟随主题）。 */
function bookshelfCardHexToInt(hex: string): number {
  const normalized = normalizeCustomColor(hex);
  if (normalized.length === 0) { return 0; }
  const digits = normalized.slice(1);
  const argb = parseInt(digits.length === 6 ? `FF${digits}` : digits, 16);
  return Number.isFinite(argb) ? (argb | 0) : 0;
}

/** ARGB 整数转 #RRGGBB；0 返回空串（丢 alpha，对齐 ReaderMarkingEditor 的展示口径）。 */
function bookshelfCardIntToHex(color: number): string {
  if (color === 0) { return ''; }
  const unsigned = color >>> 0;
  const channel = (value: number): string => value.toString(16).padStart(2, '0');
  return `#${channel((unsigned >>> 16) & 0xFF)}${channel((unsigned >>> 8) & 0xFF)}${channel(unsigned & 0xFF)}`.toUpperCase();
}

@Component
export struct BookshelfPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @StorageProp('themeItemBackground') themeItemBackground: string = '';
  @Prop books: Book[] = [];
  @Prop groups: BookGroup[] = [];
  /** 书架布局设置，来自 Index 的持久化状态。异步恢复完成后由 onLayoutChanged 灌入记住的分组。 */
  @Prop @Watch('onLayoutChanged') layout: BookshelfLayoutSettings = DEFAULT_BOOKSHELF_LAYOUT;
  /** 封面文字设置，来自 Index 的持久化状态。 */
  @Prop coverSettings: CoverSettings = DEFAULT_COVER_SETTINGS;
  /** 当前是否夜间主题，决定封面文字用日间还是夜间那一套开关与颜色。 */
  @Prop readerNightMode: boolean = false;
  /** 正在刷新目录的书主键集合（来自 Index），网格卡据此显示更新中转圈（:120）。 */
  @Prop refreshingBookIds: string[] = [];
  @State showLayoutSheet: boolean = false;
  /** 布局面板编辑中的草稿；打开面板时从 layout 复制，确认后整体提交。 */
  @State layoutDraft: BookshelfLayoutSettings = copyBookshelfLayout(DEFAULT_BOOKSHELF_LAYOUT);
  @State selectedFilter: string = '全部';
  @State showGroupManager: boolean = false;
  @State showGroupEditor: boolean = false;
  @State editingGroupId: number = -1;
  @State draftName: string = '';
  @State draftSort: number = -1;
  @State draftRefresh: boolean = true;
  @State draftPrivate: boolean = false;
  @State draftCover: string = '';
  @State pendingDeleteGroupId: number = -1;
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State collapsedHeader: boolean = false;
  @State emptyFace: string = '(；′⌒`)';
  /**
   * 网格容器的实测宽度（vp）。
   *
   * 封面宽度要按格子宽度算（上游是 fillMaxWidth + aspectRatio 5:7），
   * 而格子宽度只有在布局完成后才知道，所以记下网格的 onAreaChange 结果。
   */
  @State bookshelfGridWidth: number = 0;
  /** 当前是否横屏：由窗口矩形（F1）与网格容器尺寸共同判断，横屏时布局取 Landscape 那套字段。 */
  @State isLandscape: boolean = false;
  /** 文件夹视图当前进入的分组名；空串表示停在根层（显示分组卡片）。 */
  @State folderViewGroup: string = '';
  /** 日间/夜间卡片底色的编辑中十六进制文本；0 值在界面上表现为空串。 */
  @State dayCardColorHex: string = '';
  @State nightCardColorHex: string = '';
  /** 日志面板是否展开；与分组/布局面板共用同一个 bindSheet。 */
  @State showLogSheet: boolean = false;
  /** 打开日志面板时抓取的 AppLog 快照，清空后置空数组触发刷新。 */
  @State logEntries: string[] = [];
  /** 「标签显示内容」三复选是否展开（:209 / :224-226）。 */
  @State showTagSources: boolean = false;
  /** 标签行取色缓存：总开关关掉时为空数组，卡片侧统一回落主题色（:124）。 */
  @State cachedTagColors: TagColorPair[] = [];
  /** 配色管理页是否展开；与布局/日志/分组面板共用同一个 bindSheet。 */
  @State showTagColorPage: boolean = false;
  /** 配色管理页编辑中的配色数组，整体替换才触发 @State 刷新。 */
  @State tagColorsDraft: TagColorPair[] = [];
  /** 取色器（hex 输入行）是否展开。 */
  @State showTagColorPicker: boolean = false;
  /** 取色器正在编辑的配色下标。 */
  @State tagColorEditIndex: number = -1;
  /** 取色器输入的文字色 hex。 */
  @State tagColorPickerHex: string = '';
  /** 分组编辑面板内的标签匹配规则开关与表达式（:249 / :250）。 */
  @State draftRuleEnabled: boolean = false;
  @State draftRulePattern: string = '';
  /** 「粘贴」需先弹 PasteButton 授权层，不能直接读剪贴板（ProfileSubPages.ets:1394）。 */
  @State showRulePasteAuthorization: boolean = false;
  /** 选择模式（:87 / :142-144）。进入后卡片点击改勾选，顶栏换关闭按钮。 */
  @State selectionMode: boolean = false;
  /**
   * 已选书籍的键集合（:142-144）。
   * 键一律用 bookUrl（contentPath 优先），不用 book.id —— id 是文件名去扩展名派生的，
   * 同名但不同目录的两本书会撞键，而 books 表主键是 bookUrl。
   * ArkTS 的 @State 不认识 Set 的原地增删，全部改用 new Set(...) 整体赋值。
   */
  @State selectedBookKeys: Set<string> = new Set<string>();
  /** 批量删除确认面板（:148 / :149）；与布局/日志/分组面板共用同一个 bindSheet。 */
  @State showBatchDeleteSheet: boolean = false;
  /** 批量删除时是否同时删掉应用内导入副本（:149）；每次打开面板都从未勾选起步。 */
  @State batchDeleteSource: boolean = false;
  /**
   * 私密体系状态（批6）。@StorageProp 直接订阅 AppStorage：
   * PrivateAccessRepository 每次 publish 后这三个值都会重建，不需要自己传回调。
   */
  @StorageProp('privateEnabled') privateEnabled: boolean = false;
  @StorageProp('privateHasPassword') privateHasPassword: boolean = false;
  @StorageProp('privateUnlocked') privateUnlocked: boolean = false;
  /**
   * 「每次都验证」档的单独授权集合。必须用 @StorageProp 订阅：该档解锁只调
   * PrivateAccessRepository.grant()，改的是 AppStorage 里的这两个数组，
   * 没有订阅的话输对密码后 build 没有依赖变化，锁定页不会换成内容。
   */
  @StorageProp('privateGrantedBookKeys') privateGrantedBookKeys: string[] = [];
  @StorageProp('privateGrantedGroupIds') privateGrantedGroupIds: number[] = [];
  /** 密码输入面板（:151）；pending* 记录这一次是为哪个分组/哪本书解锁。 */
  @State showPasswordPanel: boolean = false;
  @State passwordInput: string = '';
  @State passwordError: string = '';
  @State pendingUnlockGroupId: number = 0;
  @State pendingUnlockBookKey: string = '';
  /** 记住上次分组只灌一次，避免后续设置对象刷新覆盖用户主动选择的页签。 */
  private tabPositionRestored: boolean = false;
  /** 书架窗口引用与尺寸回调，aboutToDisappear 时解绑，避免订阅泄漏。 */
  private bookshelfWindow: window.Window | undefined = undefined;
  private windowSizeListener: (size: window.Size) => void = (_size: window.Size): void => {};
  private readonly bookshelfScroller: Scroller = new Scroller();
  private readonly emptyFaces: string[] = ['(；′⌒`)', '(つ﹏⊂)', '(•̀ᴗ•́)و', '(๑•́ ₃ •̀๑)', '(눈‸눈)', '(ಥ﹏ಥ)', '(｡•́︿•̀｡)'];
  onOpenBook: (book: Book) => void = () => {};
  onOpenBookInfo: (book: Book) => void = () => {};
  onSearch: () => void = () => {};
  onImportBook: () => Promise<Book | undefined> = async () => undefined;
  /** 重新识别全部本地 TXT 的目录。 */
  onRefreshToc: () => Promise<void> = async () => {};
  onAddGroup: (name: string) => void = (_name: string) => {};
  onRenameGroup: (id: number, name: string) => void = (_id: number, _name: string) => {};
  onSetGroupVisible: (id: number, visible: boolean) => void = (_id: number, _visible: boolean) => {};
  onRemoveGroup: (id: number) => void = (_id: number) => {};
  /** 按完整草稿新建分组，供分组编辑面板提交。 */
  onAddGroupDraft: (draft: BookGroupDraft) => Promise<void> = async (_draft: BookGroupDraft) => {};
  /** 保存编辑后的分组属性。 */
  onUpdateGroup: (id: number, draft: BookGroupDraft) => Promise<void> =
    async (_id: number, _draft: BookGroupDraft) => {};
  /** 选择分组封面，返回新的封面路径；用户取消时返回空串。 */
  onChooseGroupCover: (id: number) => Promise<string> = async (_id: number) => '';
  /** 清除分组封面。 */
  onClearGroupCover: (id: number) => Promise<void> = async (_id: number) => {};
  /** 把分组拖到另一个分组的位置。 */
  onMoveGroup: (fromId: number, toId: number) => Promise<void> = async (_fromId: number, _toId: number) => {};
  /** 保存书架布局设置。 */
  onSaveLayout: (settings: BookshelfLayoutSettings) => Promise<void> =
    async (_settings: BookshelfLayoutSettings) => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  /** 把导入书单解析出的新书交给 Index 落库并刷新书架。 */
  onImportBookList: (books: Book[]) => Promise<void> = async (_books: Book[]) => {};
  /** 全量应用标签匹配规则，交给 Index 落库并刷新书架（:241）。 */
  onApplyTagGroupRules: () => Promise<void> = async () => {};
  /** 把若干本书挪到指定分组（:146）；走替换语义，空串表示移回未分组。 */
  onSetBooksGroup: (bookKeys: string[], groupName: string) => Promise<void> =
    async (_bookKeys: string[], _groupName: string) => {};
  /** 批量删书（:148 / :149）；deleteSource 只决定要不要清应用内导入副本。 */
  onDeleteBooks: (books: Book[], deleteSource: boolean) => Promise<void> =
    async (_books: Book[], _deleteSource: boolean) => {};
  /** 拖拽重排后把新顺序交给 Index 落库并同步内存（:138）。 */
  onMoveBooks: (ordered: Book[]) => Promise<void> = async (_ordered: Book[]) => {};
  /** 批量设/取消单本私密标记（:294 / :147）；由 Index 落库后刷新 books。 */
  onSetBooksPrivate: (bookKeys: string[], isPrivate: boolean) => Promise<void> =
    async (_bookKeys: string[], _isPrivate: boolean) => {};
  /** 进书架管理页（:482）：带上当前生效的分组名，空串表示全部。 */
  onOpenBookshelfManage: (groupName: string) => void = (_groupName: string) => {};

  /** 目录或进度变更后让书架卡片重建，避免 ArkUI 复用旧章节角标。 */
  private bookCardKey(book: Book): string {
    // 列表模式卡片会展示最新章节名与简介，这两个字段变化时也要让卡片重建。
    // 后两位是私密标记与当前锁定态（:325）：ArkUI 的 ForEach 在 key 不变时直接复用旧节点，
    // 把这两项漏在 key 外面，改「设为私密」或重启后解锁态变化都不会重画锁遮罩。
    return `${book.id}_${book.chapterCount ?? ''}_${book.chapterIndex ?? 0}_${book.chapterProgress ?? 0}_${bookCoverMark(book)}_${BookRepository.isBodyMissing(book) ? 1 : 0}_${book.lastChapter}_${book.description ?? ''}_${book.isPrivate === true ? 1 : 0}_${this.isBookLocked(book) ? 1 : 0}`;
  }

  aboutToAppear(): void {
    // Index 的布局恢复是异步的；这里先尝试一次，若拿到的是默认值，@Watch 会在恢复完成后再灌一次。
    this.onLayoutChanged();
    this.resolveWindowOrientation();
    AppLog.put(`书架已显示 ${this.books.length} 本书`);
    this.refreshCachedTagColors();
  }

  aboutToDisappear(): void {
    if (this.bookshelfWindow !== undefined) {
      this.bookshelfWindow.off('windowSizeChange', this.windowSizeListener);
      this.bookshelfWindow = undefined;
    }
  }

  /**
   * 读取当前窗口方向（F1）：window.getLastWindow 取窗口矩形，width > height 即横屏；
   * 同时订阅 windowSizeChange，旋转后立刻刷新 isLandscape。
   * 网格容器的 onAreaChange 也会再兜底一次（组件级尺寸回调，旋转必触发）。
   */
  private resolveWindowOrientation(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    window.getLastWindow(context).then((targetWindow: window.Window) => {
      this.bookshelfWindow = targetWindow;
      const rect = targetWindow.getWindowProperties().windowRect;
      this.isLandscape = rect.width > rect.height;
      this.windowSizeListener = (size: window.Size): void => {
        const landscape: boolean = size.width > size.height;
        if (landscape !== this.isLandscape) { this.isLandscape = landscape; }
      };
      targetWindow.on('windowSizeChange', this.windowSizeListener);
    }).catch(() => {});
  }

  /** layout 异步恢复完成后，把记住的分组灌进当前筛选（只在拿到具体分组名时锁定）。 */
  private onLayoutChanged(): void {
    // 布局异步恢复完成后重新解析标签配色缓存（:124 的渲染总开关在这里生效）。
    this.refreshCachedTagColors();
    // 离开「文件夹」分组样式后清掉组内导航，避免下次切回时残留子视图。
    if (this.layout.bookGroupStyle !== 2 && this.folderViewGroup.length > 0) {
      this.folderViewGroup = '';
    }
    if (this.tabPositionRestored) { return; }
    const remembered = this.layout.saveTabPosition;
    if (remembered.length === 0 || remembered === '全部') { return; }
    if (this.getGroupNames().includes(remembered)) {
      this.tabPositionRestored = true;
      this.selectedFilter = remembered;
    }
  }

  /** 切换分组并写回「记住上次所在分组」。 */
  private async selectGroup(name: string): Promise<void> {
    this.tabPositionRestored = true;
    this.selectedFilter = name;
    const next = copyBookshelfLayout(this.layout);
    next.saveTabPosition = name;
    await this.onSaveLayout(next);
  }

  private getGroupNames(): string[] {
    const names: string[] = ['全部'];
    const userGroups = this.groups.filter((group: BookGroup) => group.groupId > 0);
    if (this.books.some((book: Book) => (book.groupNames ?? []).length === 0)) { names.push('本地未分组'); }
    userGroups.filter((group: BookGroup) => group.show)
      .sort((left: BookGroup, right: BookGroup) => left.order - right.order)
      .forEach((group: BookGroup) => {
        if (!names.includes(group.groupName)) { names.push(group.groupName); }
      });
    // 旧数据中的名称若没有分组定义则仍可见；已明确隐藏的分组保持隐藏。
    this.books.forEach((book: Book) => {
      (book.groupNames ?? []).forEach((name: string) => {
        const definition = userGroups.find((group: BookGroup) => group.groupName === name);
        if (name.length > 0 && definition === undefined && !names.includes(name)) { names.push(name); }
      });
    });
    // 「隐藏没有书籍的分组」只过滤自定义分组，「全部」永远保留。
    if (!this.layout.hideEmptyGroups) { return names; }
    return names.filter((name: string) => name === '全部' || this.countBooksInGroup(name) > 0);
  }

  /** 某个分组下的书籍数量，供隐藏空分组使用。 */
  private countBooksInGroup(name: string): number {
    return this.books.filter((book: Book) => {
      const names = book.groupNames ?? [];
      return name === '本地未分组' ? names.length === 0 : names.includes(name);
    }).length;
  }

  /**
   * 实际生效的分组筛选。
   *
   * 打开「隐藏没有书籍的分组」后当前选中的分组可能被过滤掉，
   * 此时回落到「全部」，避免出现页签消失但仍按旧分组过滤的空书架。
   */
  private activeFilter(): string {
    const names = this.getGroupNames();
    return names.includes(this.selectedFilter) ? this.selectedFilter : '全部';
  }

  /**
   * 顶栏标题，照上游 BookshelfViewModel.kt:921-947 的 buildTitle 四分支：
   * 搜索态且页签模式 → 「书架」；搜索态或隐藏页签 → 当前分组名（取不到回落「书架」）；
   * 文件夹模式 → 根层「书架」、进入分组后显示分组名；其余 → 「书架」。
   * 上游末尾还有「编辑态一律『书架』」与「有更新书时拼 (N)」两支，
   * 本地暂无选择模式（批 5）与待更新队列（批 2），本批先不拼尾巴，待后续接入。
   */
  private bookshelfTitle(): string {
    const shelf = '书架';
    const inSearch = this.showSearch;
    const style = this.layout.bookGroupStyle;
    const groupName = this.activeFilter();
    const hasGroup = groupName.length > 0 && groupName !== '全部';
    if (inSearch && style === 0) {
      return shelf;
    }
    if (inSearch || style === 1) {
      return hasGroup ? groupName : shelf;
    }
    if (style === 2) {
      return this.folderViewGroup.length > 0 ? this.folderViewGroup : shelf;
    }
    return shelf;
  }

  /**
   * 顶栏副标题，照上游 BookshelfViewModel.kt:676-698：搜索态显示「共 N 本」，
   * 编辑态显示「已选 N 本 · 本组共 M 本」，其余为空（不渲染）。
   * 本地暂无选择模式（批 5），本批只做搜索态一支；返回空串表示不显示。
   */
  private bookshelfSubtitle(): string {
    if (this.selectionMode) {
      return `已选 ${this.selectedBookKeys.size} 本 · 本组共 ${this.getVisibleBooks().length} 本`;
    }
    if (this.showSearch) {
      return `共 ${this.getVisibleBooks().length} 本`;
    }
    return '';
  }

  /** 「标签显示内容」右侧描述：开着的三项用 · 连起来，一项没开显示「无」。 */
  private tagSourcesLabel(): string {
    const selected: string[] = [];
    if (this.layoutDraft.bookshelfShowCustomTags) { selected.push('自定义'); }
    if (this.layoutDraft.bookshelfShowSourceTags) { selected.push('来源分类'); }
    if (this.layoutDraft.bookshelfShowWordCount) { selected.push('字数'); }
    return selected.length > 0 ? selected.join(' · ') : '无';
  }
  /** 标签行取色缓存：总开关关掉时传空数组，卡片侧统一回落主题色（:124）。 */
  private refreshCachedTagColors(): void {
    this.cachedTagColors = this.layout.enableCustomTagColors
      ? parseTagColors(this.layout.customTagColorsJson) : [];
  }

  /** 标签行第 index 个标签的文字色；配色为空或该项为 0 时回落主题强调色。 */
  private tagTextColor(index: number): string {
    if (this.cachedTagColors.length === 0) { return this.themeColorAccent; }
    const pair = this.cachedTagColors[index % this.cachedTagColors.length];
    return pair !== undefined && pair.textColor !== 0 ? argbToColorHex(pair.textColor) : this.themeColorAccent;
  }

  /** 标签行第 index 个标签的背景色；两个 0 都回落主题次级底色，避免画纯黑块。 */
  private tagBgColor(index: number): string {
    if (this.cachedTagColors.length === 0) { return this.themeColorSurfaceTertiary; }
    const pair = this.cachedTagColors[index % this.cachedTagColors.length];
    return pair !== undefined && pair.bgColor !== 0 ? argbToColorHex(pair.bgColor) : this.themeColorSurfaceTertiary;
  }

  /** 「管理标签配色」入口的描述：当前布局草稿里有几组配色。 */
  private tagColorsCount(): number {
    return parseTagColors(this.layoutDraft.customTagColorsJson).length;
  }

  /** 打开配色管理页：草稿从当前布局草稿解析，容错非法 JSON。 */
  private openTagColorPage(): void {
    this.tagColorsDraft = parseTagColors(this.layoutDraft.customTagColorsJson);
    this.showTagColorPicker = false;
    this.showTagColorPage = true;
  }

  /**
   * 配色页每次改动都即时落库：草稿序列化回 layoutDraft，经 onSaveLayout 写盘，
   * 同时刷新标签行取色缓存，不依赖布局面板「完成」才生效。
   */
  private async persistTagColors(): Promise<void> {
    const next = copyBookshelfLayout(this.layoutDraft);
    next.customTagColorsJson = JSON.stringify(this.tagColorsDraft);
    this.layoutDraft = copyBookshelfLayout(next);
    await this.onSaveLayout(copyBookshelfLayout(next));
    this.cachedTagColors = next.enableCustomTagColors ? parseTagColors(next.customTagColorsJson) : [];
  }

  /** 「生成」：按主题色相整组替换成 8 组（上游 TagColorGenerator 口径）。 */
  private async generateTagColors(): Promise<void> {
    this.tagColorsDraft = generateTagColors(baseHueFromHex(this.themeColorAccent));
    await this.persistTagColors();
  }

  /** 「添加」：追加一组 (0,0) 并立刻打开取色器编辑它。 */
  private async addTagColor(): Promise<void> {
    const empty: TagColorPair = { textColor: 0, bgColor: 0 };
    const next: TagColorPair[] = [...this.tagColorsDraft, empty];
    this.tagColorsDraft = next;
    await this.persistTagColors();
    this.openTagColorPicker(next.length - 1);
  }

  /** 删除第 index 组配色。 */
  private async removeTagColor(index: number): Promise<void> {
    const next: TagColorPair[] = this.tagColorsDraft.slice();
    next.splice(index, 1);
    this.tagColorsDraft = next;
    await this.persistTagColors();
  }

  /** 打开取色器：带出该项文字色，输入 hex 后由背景色按 HSL 推导。 */
  private openTagColorPicker(index: number): void {
    this.tagColorEditIndex = index;
    const pair = this.tagColorsDraft[index];
    this.tagColorPickerHex = pair !== undefined && pair.textColor !== 0 ? argbToColorHex(pair.textColor) : '';
    this.showTagColorPicker = true;
  }

  /** 取色器确定：只取文字色，背景色由 deriveTagBgColor 推导（同色相低饱和高亮）。 */
  private async confirmTagColor(): Promise<void> {
    const color = hexToArgb(this.tagColorPickerHex);
    if (color === 0) { this.onUnavailableAction('颜色格式不对，请输入 #RRGGBB'); return; }
    const next: TagColorPair[] = this.tagColorsDraft.slice();
    const index = this.tagColorEditIndex;
    if (index >= 0 && index < next.length) {
      const updated: TagColorPair = { textColor: color, bgColor: deriveTagBgColor(color) };
      next[index] = updated;
    }
    this.tagColorsDraft = next;
    this.showTagColorPicker = false;
    await this.persistTagColors();
  }


  /** 未读章节数角标文字：showUnread 且未读>0 才有值（上游 BookItem.kt:752）。 */
  private unreadTextOf(book: Book): string {
    if (!this.layout.showUnread) { return ''; }
    const unread = BookRepository.unreadOf(book);
    return unread > 0 ? `${unread}` : '';
  }

  /** 更新红点：showUnread 与 showUnreadNew 同时开且 lastCheckCount>0（上游耦合，别拆）。 */
  private showBadgeDotOf(book: Book): boolean {
    return this.layout.showUnread && this.layout.showUnreadNew && (book.lastCheckCount ?? 0) > 0;
  }

  /** 书籍类型，本地只做 EPUB / 本地；音频、漫画、网络文件、小说档本地无对应形态，待接。 */
  private bookTypeLabel(book: Book): string {
    if (!this.layout.showTip) { return ''; }
    if (book.format === 'epub') { return 'EPUB'; }
    return '本地';
  }

  /** 标签拼接顺序：自定义标签 → 来源分类(去重) → 字数，三段各由对应开关控制。 */
  private displayTagsOf(book: Book): string[] {
    if (!this.layout.bookshelfShowTag) { return []; }
    const tags: string[] = [];
    const sources: string[] = [];
    if (this.layout.bookshelfShowCustomTags) { sources.push(book.customTag ?? ''); }
    if (this.layout.bookshelfShowSourceTags) { sources.push(book.category); }
    for (const raw of sources) {
      const pieces = raw.split(/[,\n]/);
      for (const piece of pieces) {
        const tag = piece.trim();
        if (tag.length > 0 && tags.indexOf(tag) < 0) { tags.push(tag); }
      }
    }
    if (this.layout.bookshelfShowWordCount) {
      const wc = book.wordCount ?? '';
      if (wc.length > 0 && tags.indexOf(wc) < 0) { tags.push(wc); }
    }
    return tags;
  }

  /** 紧凑(精简详情)模式作者行合成「作者 · N 未读」，未读为 0 只显示作者。 */
  private authorLineOf(book: Book): string {
    const author = book.author.length > 0 ? book.author : '作者未知';
    if (this.layout.bookshelfLayoutCompact) {
      const unread = BookRepository.unreadOf(book);
      return unread > 0 ? `${author} · ${unread} 未读` : author;
    }
    return author;
  }

  /** 该书是否正在刷新目录（refreshingBookIds 用 contentPath 作主键）。 */
  private refreshingOf(book: Book): boolean {
    const key = book.contentPath ?? book.androidOriginalPath ?? '';
    return this.refreshingBookIds.indexOf(key) >= 0;
  }

  /**
   * 横向可滚动标签行。标签按索引取 customTagColors 里的配色（index % size），
   * 两个 0 都回落主题色；总开关由 refreshCachedTagColors 控制（:124）。
   */
  @Builder
  private BookTagRow(book: Book) {
    if (this.displayTagsOf(book).length > 0) {
      Scroll() {
        Row({ space: 4 }) {
          ForEach(this.displayTagsOf(book), (tag: string, index: number) => {
            Text(tag).fontSize(9).fontColor(this.tagTextColor(index))
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(this.tagBgColor(index)).borderRadius(4)
          }, (tag: string) => tag)
        }
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
        .margin({ top: 2, bottom: 2 })
    }
  }

  private getVisibleBooks(): Book[] {
    const selectedGroup = this.activeFilter();
    const query = this.searchQuery.trim().toLocaleLowerCase();
    const filtered = this.books.filter((book: Book) => {
      const names = book.groupNames ?? [];
      const matchesGroup = selectedGroup === '全部' ||
        (selectedGroup === '本地未分组' ? names.length === 0 : names.includes(selectedGroup));
      const matchesQuery = query.length === 0 || book.title.toLocaleLowerCase().includes(query) ||
        book.author.toLocaleLowerCase().includes(query);
      return matchesGroup && matchesQuery;
    });
    // 分组设了自己的排序方式就覆盖书架全局，与上游 sortBooks() 的取值优先级一致。
    const activeGroup = this.groups.find((group: BookGroup) =>
      group.groupId > 0 && group.groupName === selectedGroup);
    return BookshelfSort.sortBooks(filtered, activeGroup,
      this.layout.bookshelfSort, this.layout.bookshelfSortOrder);
  }

  /** 书籍的稳定键：与 books 表主键同口径（contentPath 优先），不用 book.id。 */
  private bookKey(book: Book): string {
    return LocalBookRestorePlanner.bookUrlOf(book);
  }

  private isBookSelected(book: Book): boolean {
    return this.selectedBookKeys.has(this.bookKey(book));
  }

  /** 进/出选择模式（:87 / :142）；退出时清空选中集合。 */
  private toggleSelectionMode(): void {
    if (this.selectionMode) {
      this.clearSelection();
      return;
    }
    this.selectionMode = true;
    this.selectedBookKeys = new Set<string>();
  }

  /** 退出选择模式并清空选中（:87 顶栏关闭按钮与工具条「完成」都走这里）。 */
  private clearSelection(): void {
    this.selectionMode = false;
    this.selectedBookKeys = new Set<string>();
  }

  /** 单本切换选中（:142）；选中集合清空时自动退出选择模式，与 CatalogPage 同口径。 */
  private toggleBookSelection(book: Book): void {
    const key = this.bookKey(book);
    const next = new Set<string>(this.selectedBookKeys);
    if (next.has(key)) {
      next.delete(key);
    } else {
      next.add(key);
    }
    this.selectedBookKeys = next;
    if (next.size === 0) {
      this.selectionMode = false;
    }
  }

  /** 全选当前可见书（:143）；只看 getVisibleBooks()，不是全库，上游方法名就叫 SelectAllVisible。 */
  private selectAllVisible(): void {
    const next = new Set<string>(this.selectedBookKeys);
    this.getVisibleBooks().forEach((book: Book) => { next.add(this.bookKey(book)); });
    this.selectedBookKeys = next;
  }

  /** 反选当前可见书（:144）；只翻转可见那批，不可见的选中保持不变。 */
  private invertVisibleSelection(): void {
    const next = new Set<string>(this.selectedBookKeys);
    this.getVisibleBooks().forEach((book: Book) => {
      const key = this.bookKey(book);
      if (next.has(key)) {
        next.delete(key);
      } else {
        next.add(key);
      }
    });
    this.selectedBookKeys = next;
    if (next.size === 0) {
      this.selectionMode = false;
    }
  }

  /** 已选中的书籍对象，顺序按书架当前排序。 */
  private selectedBooks(): Book[] {
    return this.books.filter((book: Book) => this.selectedBookKeys.has(this.bookKey(book)));
  }

  /** 把选中的书挪到目标分组（:146）；'本地未分组' 传空串让掩码变成 0。 */
  private async moveSelectedToGroup(groupName: string): Promise<void> {
    const keys: string[] = [];
    this.selectedBooks().forEach((book: Book) => { keys.push(this.bookKey(book)); });
    if (keys.length === 0) { return; }
    const target = groupName === '本地未分组' ? '' : groupName;
    await this.onSetBooksGroup(keys, target);
    this.onUnavailableAction(`已移动 ${keys.length} 本到${target.length > 0 ? target : '未分组'}`);
    this.clearSelection();
  }

  /** 删除选中的书（:148 / :149）；面板里才有「同时删除应用内副本」的勾选。 */
  private async executeBatchDelete(): Promise<void> {
    const books = this.selectedBooks();
    if (books.length === 0) { return; }
    this.showBatchDeleteSheet = false;
    try {
      await this.onDeleteBooks(books, this.batchDeleteSource);
    } finally {
      this.batchDeleteSource = false;
      this.clearSelection();
    }
  }

  /**
   * 拖拽重排是否可用（:138）：只有当前生效的排序方式是「手动」（bookSort === 3）才有意义。
   * BookshelfSort.compareBySort 六档里只有手动那档读 order，其它排序下拖完屏幕不会有变化，
   * 这是上游行为，不是没生效。
   */
  private canReorderBooks(): boolean {
    const group = this.groups.find((item: BookGroup) =>
      item.groupId > 0 && item.groupName === this.activeFilter());
    const sort = group !== undefined && group.bookSort >= 0 ? group.bookSort : this.layout.bookshelfSort;
    return sort === 3;
  }

  /** 把第 from 本拖到第 to 本的位置（:138）；内存顺序与落库都交给 Index。 */
  private async moveBook(from: number, to: number): Promise<void> {
    const visible = this.getVisibleBooks();
    if (from < 0 || to < 0 || from >= visible.length || to >= visible.length || from === to) { return; }
    const reordered: Book[] = visible.slice();
    const moved = reordered.splice(from, 1)[0];
    if (moved === undefined) { return; }
    reordered.splice(to, 0, moved);
    await this.onMoveBooks(reordered);
  }

  /** 选择模式工具条里的「移动」菜单：列自定义分组再加「未分组」。 */
  @Builder
  private SelectionGroupMenu() {
    Menu() {
      ForEach(this.getGroupNames().filter((name: string) => name !== '全部'), (groupName: string) => {
        MenuItem({ content: groupName === '本地未分组' ? '未分组' : groupName }).height(44)
          .onClick(async () => { await this.moveSelectedToGroup(groupName); })
      }, (groupName: string) => `sel_group_${groupName}`)
    }.backgroundColor(this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)
      .fontColor(this.themeColorTextPrimary).radius(20)
  }

  /** 批量删除确认面板（:148 / :149）。 */
  @Builder
  private BatchDeleteSheet() {
    Column() {
      Row() {
        Text('删除所选书籍').fontSize(19).fontWeight(FontWeight.Medium)
          .fontColor(this.themeColorTextPrimary).layoutWeight(1)
      }.width('100%').padding({ left: 18, right: 18, top: 14, bottom: 10 })
      Column() {
        Text(`将删除 ${this.selectedBookKeys.size} 本书，删除后无法恢复。`)
          .fontSize(13).fontColor(this.themeColorTextSecondary).width('100%')
        if (this.selectedBooks().some((book: Book) => book.isLocal)) {
          Row() {
            Checkbox()
              .select(this.batchDeleteSource)
              .onChange((checked: boolean) => { this.batchDeleteSource = checked; })
            // 本地能删的只有应用内导入副本（book.contentPath），用户原始文件不由应用删除。
            Text('同时删除应用内副本').fontSize(13).fontColor(this.themeColorTextSecondary)
          }.width('100%').margin({ top: 12 })
        }
      }.width('100%').padding({ left: 18, right: 18, bottom: 14 }).alignItems(HorizontalAlign.Start)
      Row() {
        Text('取消').fontSize(14).fontColor(this.themeColorTextTertiary).padding(10)
          .onClick(() => { this.showBatchDeleteSheet = false; this.batchDeleteSource = false; })
        Blank()
        Text('删除').fontSize(14).fontColor('#FF6B6B').padding(10)
          .onClick(async () => { await this.executeBatchDelete(); })
      }.width('100%').padding({ left: 10, right: 10, bottom: 16 })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  /** 当前所有私密分组的 id（:150 / :257）。分组上的 isPrivate 标记早就有，这里只是取出来用。 */
  private privateGroupIds(): number[] {
    return this.getUserGroups()
      .filter((group: BookGroup) => group.isPrivate === true)
      .map((group: BookGroup) => group.groupId);
  }

  /** 这本书命中的第一个私密分组 id，没有则 0；单独授权时用它。 */
  private privateGroupIdOf(book: Book): number {
    const names = book.groupNames ?? [];
    const hit = this.getUserGroups().find((group: BookGroup) =>
      group.isPrivate === true && names.includes(group.groupName));
    return hit === undefined ? 0 : hit.groupId;
  }

  /**
   * 这本书现在要不要锁（:325）：单本标记并上所属私密分组，再看解锁有效期。
   *
   * 这里必须真的读一下 privateEnabled / privateUnlocked：`requiresPrivateUnlock` 读的是
   * AppStorage 静态快照，那次读取不会被 ArkUI 当成重绘依赖；只有 build 期间读过的
   * @StorageProp 才算。少了这两句，输对密码后书架不会重画，锁定页会一直停在原样。
   */
  private isBookLocked(book: Book): boolean {
    if (this.privateEnabled !== true) { return false; }
    if (!isPrivateBook(book, this.privateGroupIds())) { return false; }
    if (PrivateAccessRepository.get().unlockScope === PRIVATE_UNLOCK_EVERY_TIME) {
      // 读一下订阅到的授权集合，让 grant() 之后能触发重绘。
      const key = this.bookKey(book);
      const groupId = this.privateGroupIdOf(book);
      const granted = this.privateGrantedBookKeys.indexOf(key) >= 0
        || (groupId > 0 && this.privateGrantedGroupIds.indexOf(groupId) >= 0);
      return !granted;
    }
    if (this.privateUnlocked) { return false; }
    return requiresPrivateUnlock(this.bookKey(book), this.privateGroupIdOf(book));
  }

  /** 某个分组卡是否该画成锁定态（:257）。读 privateEnabled / privateUnlocked 的理由同 isBookLocked。 */
  private isGroupLocked(groupName: string): boolean {
    if (this.privateEnabled !== true) { return false; }
    if (groupName === '全部' || groupName === '本地未分组') { return false; }
    const group = this.getUserGroups().find((item: BookGroup) => item.groupName === groupName);
    if (group === undefined || group.isPrivate !== true) { return false; }
    if (PrivateAccessRepository.get().unlockScope === PRIVATE_UNLOCK_EVERY_TIME) {
      const granted = this.privateGrantedGroupIds.indexOf(group.groupId) >= 0;
      return !granted;
    }
    if (this.privateUnlocked) { return false; }
    return requiresPrivateUnlock('', group.groupId);
  }

  /** 当前分组是不是「锁着的私密分组」：是就把整块内容换成锁定页（:150）。 */
  private activeGroupLocked(): boolean {
    return this.isGroupLocked(this.activeFilter());
  }

  /** 弹密码面板；bookKey 为空串表示只解这个分组。 */
  private requestPrivateUnlock(groupId: number, bookKey: string): void {
    if (!this.privateHasPassword) {
      // 没设过密码时不能假装能验证，直接引导去设置页（上游 private_content_no_password 口径）。
      this.onUnavailableAction('还没有设置本地密码，请到「我的 → 设置 → 隐私设置」设置后再查看');
      return;
    }
    this.pendingUnlockGroupId = groupId;
    this.pendingUnlockBookKey = bookKey;
    this.passwordInput = '';
    this.passwordError = '';
    this.showPasswordPanel = true;
  }

  /** 校验密码；通过后按当前解锁有效期授权这一次并关面板（:151）。 */
  private async submitPassword(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const ok = await PrivateAccessRepository.verifyPassword(context, this.passwordInput);
    if (!ok) {
      // 失败只报「密码错误」，不区分「没设过」与「不对」，避免泄露状态。
      this.passwordError = '密码错误';
      return;
    }
    if (PrivateAccessRepository.get().unlockScope === PRIVATE_UNLOCK_EVERY_TIME) {
      PrivateAccessRepository.grant(this.pendingUnlockBookKey, this.pendingUnlockGroupId);
    } else {
      PrivateAccessRepository.unlock();
    }
    this.showPasswordPanel = false;
    this.passwordInput = '';
    this.passwordError = '';
    this.pendingUnlockGroupId = 0;
    this.pendingUnlockBookKey = '';
  }

  /** 选择模式里的私密按钮文案：全都没标才是「设为私密」（:147）。 */
  private selectionTargetPrivate(): boolean {
    return this.selectedBooks().every((book: Book) => book.isPrivate !== true);
  }

  /** 批量设/取消私密标记（:147）。 */
  private async toggleSelectedPrivate(): Promise<void> {
    const keys: string[] = [];
    this.selectedBookKeys.forEach((key: string) => { keys.push(key); });
    if (keys.length === 0) { return; }
    await this.onSetBooksPrivate(keys, this.selectionTargetPrivate());
  }

  /**
   * 私密分组锁定页（:150）。
   * 只替换「这个分组自己的内容」，顶栏与分组页签保持不动——否则用户会被卡在锁定页里，
   * 连相邻分组都切不过去（上游 PrivateGroupLockedPage 的注释）。
   * 两种文案分开：设过密码给「验证后查看」，没设过给「设置本地密码」。
   */
  @Builder
  private PrivateGroupLockedPanel() {
    Column() {
      AppGlyph({ name: 'lock', glyphSize: 34, tint: this.themeColorTextTertiary })
      Text(this.privateHasPassword ? '这个分组已锁定' : '这个分组是私密分组')
        .fontSize(15).fontColor(this.themeColorTextPrimary).margin({ top: 12 })
      Text(this.privateHasPassword ? '验证后可以查看组内书籍' : '先在隐私设置里设置本地密码，才能查看组内书籍')
        .fontSize(12).fontColor(this.themeColorTextTertiary).margin({ top: 6 })
      Text(this.privateHasPassword ? '验证后查看' : '设置本地密码')
        .fontSize(13).fontColor(this.themeColorAccent).padding({ left: 18, right: 18, top: 8, bottom: 8 })
        .backgroundColor(this.themeColorSurfaceElevated).borderRadius(16).margin({ top: 16 })
        .onClick(() => {
          if (!this.privateHasPassword) {
            this.onUnavailableAction('请到「我的 → 设置 → 隐私设置」设置本地密码');
            return;
          }
          const group = this.getUserGroups().find((item: BookGroup) => item.groupName === this.activeFilter());
          this.requestPrivateUnlock(group === undefined ? 0 : group.groupId, '');
        })
    }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }

  /** 密码输入面板（:151）。校验失败只提示「密码错误」。 */
  @Builder
  private PasswordSheet() {
    Column() {
      Text('验证本地密码').fontSize(16).fontColor(this.themeColorTextPrimary)
        .alignSelf(ItemAlign.Start).padding({ left: 18, top: 16, bottom: 8 })
      TextInput({ text: this.passwordInput, placeholder: '本地密码' })
        .type(InputType.Password).fontSize(14).height(44).margin({ left: 18, right: 18 })
        .onChange((value: string) => { this.passwordInput = value; })
      if (this.passwordError.length > 0) {
        Text(this.passwordError).fontSize(12).fontColor('#FF6B6B').padding({ left: 18, top: 8 })
      }
      Row() {
        Text('取消').fontSize(14).fontColor(this.themeColorTextTertiary).padding(10)
          .onClick(() => {
            this.showPasswordPanel = false;
            this.passwordInput = '';
            this.passwordError = '';
          })
        Blank()
        Text('解锁').fontSize(14).fontColor(this.themeColorAccent).padding(10)
          .onClick(async () => { await this.submitPassword(); })
      }.width('100%').padding({ left: 10, right: 10, top: 6, bottom: 16 })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  /** 只列自定义分组，按 order 升序，与上游 GroupManageSheet 一致。 */
  private getUserGroups(): BookGroup[] {
    return this.groups.filter((group: BookGroup) => group.groupId > 0)
      .sort((left: BookGroup, right: BookGroup) => left.order - right.order);
  }

  /** 文件夹根层显示的分组名清单：与页签共用 getGroupNames，保证「全部」与各分组一致。 */
  private getFolderGroups(): string[] {
    return this.getGroupNames();
  }

  /** 某分组卡片上的预览书籍；不套搜索框关键字，与上游 previewBooks 的组内取书一致。 */
  private getFolderPreviewBooks(groupName: string): Book[] {
    return this.books.filter((book: Book) => {
      const names = book.groupNames ?? [];
      return groupName === '全部' ? true
        : (groupName === '本地未分组' ? names.length === 0 : names.includes(groupName));
    });
  }

  /** 点分组卡片进入组内：同时把筛选切到该分组，让书籍网格显示该组的书。 */
  private openFolderGroup(name: string): void {
    this.folderViewGroup = name;
    this.selectedFilter = name;
  }

  /** 返回文件夹根层：清掉组内导航与筛选。 */
  private backToFolderRoot(): void {
    this.folderViewGroup = '';
    this.selectedFilter = '全部';
  }

  /** 分组卡片在网格里的稳定 key；属性变化后必须换 key，否则 ArkUI 会复用旧节点。 */
  private groupCardKey(group: BookGroup): string {
    return `${group.groupId}_${group.groupName}_${group.show ? 1 : 0}_${group.order}_${group.bookSort}_${group.isPrivate ? 1 : 0}_${group.cover ?? ''}`;
  }

  /** 打开分组编辑面板，把当前属性与标签匹配规则一并灌进草稿。 */
  private async openGroupEditor(group: BookGroup | undefined): Promise<void> {
    this.draftRuleEnabled = false;
    this.draftRulePattern = '';
    this.showRulePasteAuthorization = false;
    if (group === undefined) {
      this.editingGroupId = -1;
      this.draftName = '';
      this.draftSort = -1;
      this.draftRefresh = true;
      this.draftPrivate = false;
      this.draftCover = '';
    } else {
      this.editingGroupId = group.groupId;
      this.draftName = group.groupName;
      this.draftSort = group.bookSort;
      this.draftRefresh = group.enableRefresh;
      this.draftPrivate = group.isPrivate;
      this.draftCover = group.cover ?? '';
      // 规则按分组名关联。规则表启动时不 load（全仓只有备份链路 load），这里显式
      // load 一次拿权威数组，避免 getAll() 读到空缓存导致已有规则显示不出来。
      const context = this.getUIContext().getHostContext();
      if (context !== undefined) {
        const rules = await TagGroupRuleRepository.load(context);
        const matched = rules.find((rule: TagGroupRule) => rule.groupName === group.groupName);
        if (matched !== undefined) {
          this.draftRuleEnabled = true;
          this.draftRulePattern = matched.pattern;
        }
      }
    }
    // 长按文件夹视图的分组卡也会走到这里，此时分组管理面板还没打开；
    // bindSheet 的开关条件是 showGroupManager，所以要一并置真，否则面板不弹出。
    this.showGroupManager = true;
    this.showGroupEditor = true;
  }

  /** 提交分组编辑面板；名称冲突等错误由调用方回传提示。规则一并写回并触发全量同步。 */
  private async submitGroupDraft(): Promise<void> {
    const name = this.draftName.trim();
    if (name.length === 0) { this.onUnavailableAction('分组名称不能为空'); return; }
    const pattern = this.draftRulePattern.trim();
    // 保存前校验正则，非法整笔不写：上游 BookGroupMutationRepository.saveGroup
    // 首行就是 Regex(ruleToSave.pattern)（不合法直接抛、事务不提交），本地同款前置拦截。
    if (this.draftRuleEnabled && pattern.length > 0) {
      try { new RegExp(pattern); } catch (error) {
        this.onUnavailableAction('正则表达式不合法');
        return;
      }
    }
    const draft: BookGroupDraft = {
      groupName: name,
      enableRefresh: this.draftRefresh,
      bookSort: this.draftSort,
      isPrivate: this.draftPrivate,
      cover: this.draftCover.length > 0 ? this.draftCover : undefined
    };
    if (this.editingGroupId > 0) {
      await this.onUpdateGroup(this.editingGroupId, draft);
      if (this.selectedFilter !== name) {
        const previous = this.groups.find((group: BookGroup) => group.groupId === this.editingGroupId);
        if (previous !== undefined && this.selectedFilter === previous.groupName) { this.selectedFilter = name; }
      }
    } else {
      await this.onAddGroupDraft(draft);
    }
    await this.saveDraftRule(name, pattern);
    this.showGroupEditor = false;
    // 规则写完后立刻全量同步一次（规则个位数、书几百本，几十毫秒级，不用做增量）。
    await this.onApplyTagGroupRules();
  }

  /** 把面板里的规则草稿写回规则表。规则按保存后的分组名关联：编辑改名时
   *  Index.updateBookshelfGroup 已先把旧名规则同步成新名，这里只按 name 找。 */
  private async saveDraftRule(name: string, pattern: string): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const rules = await TagGroupRuleRepository.load(context);
    const index = rules.findIndex((rule: TagGroupRule) => rule.groupName === name);
    if (this.draftRuleEnabled && pattern.length > 0) {
      if (index >= 0) {
        const existing = rules[index];
        rules[index] = { id: existing.id, pattern: pattern, groupName: name, order: existing.order };
      } else {
        rules.push({ id: Date.now(), pattern: pattern, groupName: name, order: rules.length });
      }
    } else if (index >= 0) {
      rules.splice(index, 1);
    } else {
      return;
    }
    await TagGroupRuleRepository.save(context, rules);
  }

  /** 复制规则，形状与上游 GSON.toJson(rule) 一致：{id,pattern,groupName,order}。 */
  private async copyGroupRule(): Promise<void> {
    const rule: TagGroupRule = {
      id: 0, pattern: this.draftRulePattern,
      groupName: this.draftName.trim(), order: 0
    };
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, JSON.stringify(rule));
      await pasteboard.getSystemPasteboard().setData(data);
      this.onUnavailableAction('规则已复制');
    } catch (error) {
      this.onUnavailableAction('规则复制失败');
    }
  }

  /** 粘贴规则：由 PasteButton 授权后读剪贴板，只回填表达式。 */
  private async pasteGroupRule(result: PasteButtonOnClickResult): Promise<void> {
    if (result !== PasteButtonOnClickResult.SUCCESS) {
      this.onUnavailableAction('未获得剪贴板授权');
      return;
    }
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      if (data.getRecordCount() === 0) { this.onUnavailableAction('剪贴板为空'); return; }
      const parsed = JSON.parse(data.getRecord(0).toPlainText()) as TagGroupRule;
      if (typeof parsed.pattern === 'string') { this.draftRulePattern = parsed.pattern; }
    } catch (error) {
      this.onUnavailableAction('粘贴的规则格式不正确');
    }
  }

  /** 分组排序方式菜单，选项来自 BOOK_SORT_OPTIONS。 */
  @Builder
  private SortMenu() {
    Menu() {
      ForEach(BOOK_SORT_OPTIONS, (option: BookSortOption) => {
        MenuItem({ content: option.label }).height(44)
          .onClick(() => this.draftSort = option.value)
      }, (option: BookSortOption) => `${option.value}`)
    }.backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).fontColor(this.themeColorTextPrimary).radius(20)
  }

  @Builder
  private GroupCoverThumb(group: BookGroup, thumbSize: number) {
    Stack({ alignContent: Alignment.Center }) {
      if ((group.cover ?? '').length > 0) {
        Image(group.cover).width(thumbSize).height(thumbSize).borderRadius(10).objectFit(ImageFit.Cover)
      } else {
        Text(group.groupName.substring(0, 1)).fontSize(thumbSize / 2.4).fontColor('#C4D1FF')
      }
    }
    .width(thumbSize).height(thumbSize).backgroundColor('#22232A').borderRadius(10)
  }

  /** 隐藏页签布局仍可从管理面板选择全部当前可用的分组筛选。 */
  @Builder
  private GroupFilterMenu() {
    Menu() {
      ForEach(this.getGroupNames(), (groupName: string) => {
        MenuItem({ content: groupName === this.activeFilter() ? `✓ ${groupName}` : groupName }).height(44)
          .onClick(async () => {
            await this.selectGroup(groupName);
            this.showGroupManager = false;
          })
      }, (groupName: string) => groupName)
    }.backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).fontColor(this.themeColorTextPrimary).radius(20)
  }

  /** 分组管理顶栏「＋」菜单（上游 GroupManageSheet.kt:150 的四项里，AI 自动分组
   *  对应本表 :239 已判不适用，不做）。
   *
   *  「添加标签匹配规则」在本地不另建独立面板（上游 TagGroupRuleEditSheet.kt）：
   *  规则段就放在分组编辑面板里（:249 / :250），两条路径写的是同一张 tag_group_rules 表，
   *  做一套就够，两套反而要维护两条写入路径。这里直接打开一个已有分组的编辑面板，
   *  让用户在里面录表达式。 */
  @Builder
  private GroupManageMoreMenu() {
    Menu() {
      MenuItem({ content: '新建分组' }).height(44)
        .onClick(() => { this.openGroupEditor(undefined); })
      MenuItem({ content: '添加标签匹配规则' }).height(44)
        .onClick(() => {
          const candidates = this.getUserGroups();
          let target: BookGroup | undefined = this.groups.find((group: BookGroup) =>
            group.groupId > 0 && group.groupName === this.activeFilter());
          if (target === undefined && candidates.length > 0) { target = candidates[0]; }
          if (target === undefined) {
            this.onUnavailableAction('请先新建一个分组，再为它添加标签匹配规则');
            return;
          }
          this.openGroupEditor(target);
        })
      MenuItem({ content: '同步标签分组' }).height(44)
        .onClick(async () => { await this.onApplyTagGroupRules(); })
    }.backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).fontColor(this.themeColorTextPrimary).radius(20)
  }

  /** 分组管理：自适应网格卡片，对应上游 LazyVerticalGrid(GridCells.Adaptive(160.dp))。 */
  @Builder
  private GroupManagerGrid() {
    Column() {
      Row() {
        Text('分组管理').fontSize(19).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Text('新建').fontSize(14).fontColor('#B9C8FF').padding(8)
          .bindMenu(this.GroupManageMoreMenu())
        Text('完成').fontSize(14).fontColor('#B9C8FF').padding(8).onClick(() => this.showGroupManager = false)
      }.width('100%').padding({ left: 18, right: 12, top: 14, bottom: 10 })
      Row() {
        Text(`切换分组：${this.activeFilter()}`).fontSize(13).fontColor(this.themeColorAccent).layoutWeight(1)
          .bindMenu(this.GroupFilterMenu())
      }.width('100%').padding({ left: 18, right: 18, bottom: 10 })

      if (this.getUserGroups().length === 0) {
        Column() {
          Text('还没有自定义分组').fontSize(14).fontColor(this.themeColorTextTertiary)
          Text('点右上「新建」创建第一个分组').fontSize(12).fontColor('#6E7078').margin({ top: 6 })
        }.width('100%').padding({ top: 40, bottom: 40 }).justifyContent(FlexAlign.Center)
      } else {
        // 长按卡片进入拖拽排序，对应上游 rememberReorderableLazyGridState；
        // editMode(true) 是 Grid 内 ForEach.onMove 生效的前提。
        Grid() {
          ForEach(this.getUserGroups(), (group: BookGroup) => {
            GridItem() {
              Column() {
                Row() {
                  this.GroupCoverThumb(group, 40)
                  Blank()
                  Toggle({ type: ToggleType.Switch, isOn: group.show })
                    .onChange((visible: boolean) => {
                      this.onSetGroupVisible(group.groupId, visible);
                      if (!visible && this.selectedFilter === group.groupName) { this.selectedFilter = '全部'; }
                    })
                }.width('100%')
                Text(group.groupName).fontSize(14).fontColor(this.themeColorTextPrimary).maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 10 }).width('100%')
                Text(`${this.countBooksInGroup(group.groupName)} 本 · ${bookSortLabel(group.bookSort)}${group.isPrivate ? ' · 私有' : ''}`)
                  .fontSize(11).fontColor(this.themeColorTextTertiary).maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 4 }).width('100%')
              }.width('100%').padding(12).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(14)
                .alignItems(HorizontalAlign.Start)
                .onClick(() => { this.openGroupEditor(group); })
            }
          }, (group: BookGroup) => this.groupCardKey(group))
            .onMove((from: number, to: number) => {
              const userGroups = this.getUserGroups();
              if (from < 0 || to < 0 || from >= userGroups.length || to >= userGroups.length) { return; }
              this.onMoveGroup(userGroups[from].groupId, userGroups[to].groupId);
            })
        }
        .columnsTemplate('1fr 1fr').columnsGap(10).rowsGap(10)
        .width('100%').layoutWeight(1).padding({ left: 16, right: 16, bottom: 18 })
        .scrollBar(BarState.Off).editMode(true)
      }
    }.width('100%').height('100%').backgroundColor('#17181E')
  }

  /** 分组编辑面板内容，对应上游 GroupEditSheet。 */
  @Builder
  private GroupEditorContent() {
    Column() {
      Row() {
        Text(this.editingGroupId > 0 ? '编辑分组' : '新建分组')
          .fontSize(19).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Text('保存').fontSize(14).fontColor('#B9C8FF').padding(8)
          .onClick(async () => { await this.submitGroupDraft(); })
        Text('取消').fontSize(14).fontColor(this.themeColorTextTertiary).padding(8)
          .onClick(() => this.showGroupEditor = false)
      }.width('100%').padding({ left: 18, right: 12, top: 14, bottom: 10 })
      Scroll() {
        Column() {
          // 封面：点击选图，长按清除，与上游 GroupEditContent 的封面项一致。
          Row() {
            Text('封面').fontSize(14).fontColor(this.themeColorTextSecondary).layoutWeight(1)
            Stack({ alignContent: Alignment.Center }) {
              if (this.draftCover.length > 0) {
                Image(this.draftCover).width(48).height(48).borderRadius(10).objectFit(ImageFit.Cover)
              } else {
                AppGlyph({ name: 'add', glyphSize: 18, tint: this.themeColorTextTertiary })
              }
            }
            .width(48).height(48).backgroundColor('#22232A').borderRadius(10)
            .onClick(async () => {
              if (this.editingGroupId <= 0) {
                this.onUnavailableAction('请先保存分组，再设置封面');
                return;
              }
              const cover = await this.onChooseGroupCover(this.editingGroupId);
              if (cover.length > 0) { this.draftCover = cover; }
            })
            if (this.draftCover.length > 0) {
              Text('清除').fontSize(12).fontColor('#D99AA5').padding({ left: 12 })
                .onClick(async () => {
                  if (this.editingGroupId > 0) { await this.onClearGroupCover(this.editingGroupId); }
                  this.draftCover = '';
                })
            }
          }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })

          Row() {
            Text('分组名称').fontSize(14).fontColor(this.themeColorTextSecondary).width(88)
            TextInput({ text: this.draftName, placeholder: '分组名称' }).layoutWeight(1).height(40)
              .fontSize(14).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
              .backgroundColor('#22232A').borderRadius(9)
              .onChange((value: string) => this.draftName = value)
          }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })

          Row() {
            Text('排序方式').fontSize(14).fontColor(this.themeColorTextSecondary).layoutWeight(1)
            Text(bookSortLabel(this.draftSort)).fontSize(14).fontColor(this.themeColorAccent)
              .bindMenu(this.SortMenu())
          }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })

          Row() {
            Column() {
              Text('下拉刷新').fontSize(14).fontColor(this.themeColorTextSecondary)
              Text('仅保存 Android 兼容字段；当前不控制实际更新').fontSize(11).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.draftRefresh })
              .onChange((enabled: boolean) => this.draftRefresh = enabled)
          }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })

          Row() {
            Column() {
              Text('私有分组').fontSize(14).fontColor(this.themeColorTextSecondary)
              Text('仅保存兼容标记；当前不限制跨分组显示').fontSize(11).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.draftPrivate })
              .onChange((enabled: boolean) => this.draftPrivate = enabled)
          }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })

          // 标签匹配规则（:249 / :250）：本地不另建独立规则面板，开关与多行输入框
          // 直接放在分组编辑面板里，对应上游 GroupEditSheet.kt:221-238。
          Row() {
            Column() {
              Text('标签匹配规则').fontSize(14).fontColor(this.themeColorTextSecondary)
              Text(this.draftRuleEnabled ? '启用后分组将根据书籍标签自动匹配' : '关闭后分组为手动管理')
                .fontSize(11).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.draftRuleEnabled })
              .onChange((enabled: boolean) => this.draftRuleEnabled = enabled)
          }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })

          if (this.draftRuleEnabled) {
            Column() {
              TextArea({ placeholder: '匹配标签的正则表达式', text: this.draftRulePattern })
                .fontSize(14).fontColor(this.themeColorTextPrimary)
                .placeholderColor(this.themeColorTextTertiary)
                .height(96).backgroundColor('#22232A').borderRadius(9).padding(10)
                .width('100%')
                .onChange((value: string) => this.draftRulePattern = value)
              Row() {
                Text('复制').fontSize(13).fontColor(this.themeColorAccent).padding({ right: 16 })
                  .onClick(() => { this.copyGroupRule(); })
                Text('粘贴').fontSize(13).fontColor(this.themeColorAccent)
                  .onClick(() => this.showRulePasteAuthorization = true)
                Blank()
              }.width('100%').padding({ top: 8 })
              // 读剪贴板需要 PasteButton 授权，不能裸调 getData()（ProfileSubPages.ets:1394）。
              if (this.showRulePasteAuthorization) {
                PasteButton({ text: PasteDescription.PASTE, buttonType: ButtonType.Capsule })
                  .onClick(async (_event: ClickEvent, result: PasteButtonOnClickResult) => {
                    await this.pasteGroupRule(result);
                    this.showRulePasteAuthorization = false;
                  })
              }
            }.width('100%').padding({ left: 16, right: 16, top: 4, bottom: 10 })
              .alignItems(HorizontalAlign.Start)
          }

          if (this.editingGroupId > 0) {
            Row() {
              Text(this.pendingDeleteGroupId === this.editingGroupId ? '确认删除' : '删除分组')
                .fontSize(14).fontColor('#D99AA5').layoutWeight(1)
                .onClick(() => {
                  if (this.pendingDeleteGroupId === this.editingGroupId) {
                    const removed = this.groups.find((group: BookGroup) => group.groupId === this.editingGroupId);
                    // 删除前真算该分组的书数，提示用户这些书会移出到未分组。
                    const count = removed !== undefined
                      ? this.books.filter((book: Book) => (book.groupNames ?? []).includes(removed.groupName)).length
                      : 0;
                    this.getUIContext().showAlertDialog({
                      title: '删除分组',
                      message: `该分组下的 ${count} 本书会移出到未分组`,
                      autoCancel: true,
                      primaryButton: { value: '取消', action: () => {} },
                      secondaryButton: {
                        value: '删除',
                        action: () => {
                          this.onRemoveGroup(this.editingGroupId);
                          if (removed !== undefined && this.selectedFilter === removed.groupName) {
                            this.selectedFilter = '全部';
                          }
                          this.pendingDeleteGroupId = -1;
                          this.showGroupEditor = false;
                        }
                      }
                    });
                  } else {
                    this.pendingDeleteGroupId = this.editingGroupId;
                  }
                })
              if (this.pendingDeleteGroupId === this.editingGroupId) {
                Text('取消').fontSize(13).fontColor(this.themeColorTextTertiary).padding({ left: 12 })
                  .onClick(() => this.pendingDeleteGroupId = -1)
              }
            }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 16 })
          }
        }.width('100%')
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#17181E')
  }

  /** 分组面板：管理网格与编辑表单共用一个 sheet，避免同一组件挂两个 bindSheet 只有后者生效。 */
  @Builder
  private GroupManagerSheet() {
    if (this.showGroupEditor) {
      this.GroupEditorContent()
    } else {
      this.GroupManagerGrid()
    }
  }

  /** 当前方向下生效的布局模式（1 网格 / 0 列表）：竖屏取 Portrait，横屏取 Landscape。 */
  private activeLayoutMode(): number {
    return this.isLandscape
      ? this.layout.bookshelfLayoutModeLandscape : this.layout.bookshelfLayoutModePortrait;
  }

  /** 当前方向下生效的网格列数。 */
  private activeGridColumns(): number {
    return this.isLandscape
      ? this.layout.bookshelfLayoutGridLandscape : this.layout.bookshelfLayoutGridPortrait;
  }

  /** 当前方向下生效的列表列数。 */
  private activeListColumns(): number {
    return this.isLandscape
      ? this.layout.bookshelfLayoutListLandscape : this.layout.bookshelfLayoutListPortrait;
  }

  /** 列表详情区是否渲染：对齐上游 BookItem.kt:738 的 showListDetails（列表模式 + 非精简 + 总开关）。 */
  private showsListDetails(): boolean {
    return this.activeLayoutMode() === 0 && !this.layout.bookshelfLayoutCompact && this.layout.showBookIntro;
  }

  /** 简介最大行数：上游 0 表示不限（BookItem.kt:1058 用 Int.MAX_VALUE 兜底）。 */
  private introMaxLines(): number {
    return this.layout.bookshelfIntroMaxLines > 0 ? this.layout.bookshelfIntroMaxLines : 999;
  }

  /** 简介行数的描述文案：0 时显示全部，否则显示「最多 N 行」。 */
  private introMaxLinesDescription(): string {
    const lines = this.layoutDraft.bookshelfIntroMaxLines;
    return lines === 0 ? '显示全部' : `最多 ${lines} 行`;
  }

  /** 面板草稿里当前方向生效的布局模式：面板未提交前只读草稿，不读已保存值。 */
  private activeDraftLayoutMode(): number {
    return this.isLandscape
      ? this.layoutDraft.bookshelfLayoutModeLandscape : this.layoutDraft.bookshelfLayoutModePortrait;
  }

  /** 面板草稿里当前方向生效的网格列数。 */
  private activeDraftGridColumns(): number {
    return this.isLandscape
      ? this.layoutDraft.bookshelfLayoutGridLandscape : this.layoutDraft.bookshelfLayoutGridPortrait;
  }

  /** 面板草稿里当前方向生效的列表列数。 */
  private activeDraftListColumns(): number {
    return this.isLandscape
      ? this.layoutDraft.bookshelfLayoutListLandscape : this.layoutDraft.bookshelfLayoutListPortrait;
  }

  /** 文件夹视图：当前方向下生效的布局模式（1 网格 / 0 列表）。 */
  private activeFolderLayoutMode(): number {
    return this.isLandscape
      ? this.layout.bookshelfFolderLayoutModeLandscape : this.layout.bookshelfFolderLayoutModePortrait;
  }

  /** 文件夹视图：当前方向下生效的网格列数。 */
  private activeFolderGridColumns(): number {
    return this.isLandscape
      ? this.layout.bookshelfFolderLayoutGridLandscape : this.layout.bookshelfFolderLayoutGridPortrait;
  }

  /** 文件夹视图：当前方向下生效的列表列数。 */
  private activeFolderListColumns(): number {
    return this.isLandscape
      ? this.layout.bookshelfFolderLayoutListLandscape : this.layout.bookshelfFolderLayoutListPortrait;
  }

  /**
   * 文件夹根视图的列数模板：对齐上游 BookshelfScreen.kt:985
   * folderColumns = if (bookshelfFolderLayoutMode == 0) bookshelfFolderLayoutList else bookshelfFolderLayoutGrid，
   * 再按 :988 的 coerceAtLeast(1) 兜底。横竖屏各取一套值。
   */
  private folderColumnsTemplate(): string {
    const mode = this.activeFolderLayoutMode();
    const configured = mode === 1 ? this.activeFolderGridColumns() : this.activeFolderListColumns();
    // 上限只留 1，对齐上游 BookshelfScreen.kt:988 的 folderColumns.coerceAtLeast(1)。
    const columns = Math.max(1, Math.round(configured));
    const template: string[] = [];
    for (let index = 0; index < columns; index += 1) { template.push('1fr'); }
    return template.join(' ');
  }

  /** 按当前方向与 Android 书架设置选择列表或网格的列数。 */
  private bookshelfColumnsTemplate(): string {
    const mode = this.activeLayoutMode();
    const configuredColumns = mode === 1 ? this.activeGridColumns() : this.activeListColumns();
    // 上限只留 1，对齐上游 BookshelfScreen.kt:1753 的 columns.coerceAtLeast(1)。
    const columns = Math.max(1, Math.round(configuredColumns));
    const template: string[] = [];
    for (let index = 0; index < columns; index += 1) { template.push('1fr'); }
    return template.join(' ');
  }

  /** 当前生效的列数，供封面宽度换算用。 */
  private bookshelfColumnCount(): number {
    const mode = this.activeLayoutMode();
    const configuredColumns = mode === 1 ? this.activeGridColumns() : this.activeListColumns();
    return Math.max(1, Math.round(configuredColumns));
  }

  /**
   * 网格里单个格子能给出的封面宽度（vp）。
   *
   * 对齐上游 BookItem.kt:269-273：封面宽度由格子宽度决定，高度按 5:7 推导。
   * 格子宽度 = (网格可用宽 - 左右内边距 8*2 - 列间距 8*(列数-1)) / 列数，
   * 再减 8 给上游 BookshelfItemCover 的 padding(4.dp) 留位置。
   * 宽度未知时返回 0，调用方回落到 100% 让布局自己算。
   */
  private bookshelfCoverSlotWidth(): number {
    if (this.bookshelfGridWidth <= 0) { return 0; }
    const columns = this.bookshelfColumnCount();
    const available = this.bookshelfGridWidth - BOOKSHELF_GRID_PADDING * 2
      - BOOKSHELF_GRID_GAP * (columns - 1);
    if (available <= 0) { return 0; }
    return Math.max(0, Math.floor(available / columns) - 8);
  }

  /**
   * 书封宽度上限：格子宽与用户设置取小值。
   *
   * 上游 bookshelfGridCoverWidth 默认 120，作用是限制封面不要随格子无限放大；
   * 格子比它窄时以格子为准，保证「填满格子」与「用户设定」两个约束同时成立。
   */
  private bookshelfCoverWidthLimit(): number {
    const slot = this.bookshelfCoverSlotWidth();
    const configured = Math.max(0, Math.round(this.layout.bookshelfGridCoverWidth));
    if (slot <= 0) { return configured; }
    return configured > 0 ? Math.min(slot, configured) : slot;
  }

  /** 书封标题字号：上游 labelMedium 13sp、labelSmall 11sp。 */
  private bookshelfTitleFontSize(): number {
    return this.layout.bookshelfTitleSmallFont ? 11 : 13;
  }

  /** 卡片底色：日夜各一套，0 时透明（沿用主题背景）。 */
  private cardBackgroundColor(): ResourceColor {
    const color = this.readerNightMode
      ? this.layout.bookshelfCardColorDark : this.layout.bookshelfCardColor;
    return color === 0 ? Color.Transparent : bookshelfCardIntToHex(color);
  }

  /** 紧凑样式下封面内标题的渐变黑底，对齐上游 BookItem.kt:123-131 的垂直渐变。 */
  private coverTitleGradient(): LinearGradientOptions {
    return { angle: 180, colors: [['#00000000', 0.0], ['#B3000000', 1.0]] };
  }

  /** 打开布局面板：从已生效设置复制一份草稿，面板内改动只落到草稿。 */
  private openLayoutSheet(): void {
    this.layoutDraft = copyBookshelfLayout(this.layout);
    this.dayCardColorHex = bookshelfCardIntToHex(this.layoutDraft.bookshelfCardColor);
    this.nightCardColorHex = bookshelfCardIntToHex(this.layoutDraft.bookshelfCardColorDark);
    this.showLayoutSheet = true;
  }

  /** 提交布局草稿并关闭面板。 */
  private updateLayoutDraft(update: (draft: BookshelfLayoutSettings) => void): void {
    const draft = copyBookshelfLayout(this.layoutDraft);
    update(draft);
    this.layoutDraft = draft;
  }

  private async submitLayout(): Promise<void> {
    this.showLayoutSheet = false;
    await this.onSaveLayout(copyBookshelfLayout(this.layoutDraft));
    // 布局提交后刷新标签配色缓存，卡片不用等 @Watch 回来再变色。
    this.refreshCachedTagColors();
    // 隐藏空分组或隐藏当前分组后，选中页签可能已不存在，回落到「全部」。
    if (!this.getGroupNames().includes(this.selectedFilter)) { this.selectedFilter = '全部'; }
  }

  /** 通用下拉：一个按钮 + 菜单，用于布局面板里的枚举项。 */
  @Builder
  private LayoutMenuRow(
    title: string, description: string, options: BookshelfLayoutOption[],
    current: number, onPick: (value: number) => void
  ) {
    Row() {
      Column() {
        Text(title).fontSize(14).fontColor(this.themeColorTextSecondary)
        if (description.length > 0) {
          Text(description).fontSize(11).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text(bookshelfLayoutOptionLabel(options, current)).fontSize(14).fontColor(this.themeColorAccent)
        .bindMenu(this.LayoutOptionsMenu(options, onPick))
    }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  /** 枚举项菜单；ArkTS 不允许 bindMenu 传对象字面量数组，统一用 Builder 生成。 */
  @Builder
  private LayoutOptionsMenu(options: BookshelfLayoutOption[], onPick: (value: number) => void) {
    Menu() {
      ForEach(options, (option: BookshelfLayoutOption) => {
        MenuItem({ content: option.label }).height(44)
          .onClick(() => onPick(option.value))
      }, (option: BookshelfLayoutOption) => `${option.value}_${option.label}`)
    }.backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).fontColor(this.themeColorTextPrimary).radius(20)
  }

  /** 开关行。 */
  @Builder
  private LayoutSwitchRow(title: string, description: string, isOn: boolean, onToggle: (value: boolean) => void) {
    Row() {
      Column() {
        Text(title).fontSize(14).fontColor(this.themeColorTextSecondary)
        if (description.length > 0) {
          Text(description).fontSize(11).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .onChange((value: boolean) => onToggle(value))
    }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
  }

  /** 数值行：用 -/+ 加减，避免滑块在小屏上难以精确点中。 */
  @Builder
  private LayoutStepperRow(
    title: string, description: string, value: number,
    minimum: number, maximum: number, onStep: (delta: number) => void
  ) {
    Row() {
      Column() {
        Text(title).fontSize(14).fontColor(this.themeColorTextSecondary)
        if (description.length > 0) {
          Text(description).fontSize(11).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('−').fontSize(18).fontColor(value > minimum ? this.themeColorAccent : '#4A4C55')
        .width(36).height(32).textAlign(TextAlign.Center)
        .onClick(() => { if (value > minimum) { onStep(-1); } })
      Text(`${value}`).fontSize(14).fontColor(this.themeColorTextPrimary).width(34).textAlign(TextAlign.Center)
      Text('+').fontSize(18).fontColor(value < maximum ? this.themeColorAccent : '#4A4C55')
        .width(36).height(32).textAlign(TextAlign.Center)
        .onClick(() => { if (value < maximum) { onStep(1); } })
    }.width('100%').padding({ left: 16, right: 12, top: 10, bottom: 10 })
  }

  /** 卡片底色编辑行：预览方块 + hex 输入，复用 CustomThemePage.ColorEditor 的交互口径。 */
  @Builder
  private ColorPickerRow(title: string, hex: string, onHex: (value: string) => void) {
    Row() {
      Row().width(24).height(24).borderRadius(6)
        .backgroundColor(normalizeCustomColor(hex).length > 0 ? hex : this.themeColorSurfacePrimary)
        .border({ width: 1, color: this.themeColorTextTertiary })
      Text(title).fontSize(14).fontColor(this.themeColorTextSecondary).layoutWeight(1).margin({ left: 12 })
      TextInput({ text: hex, placeholder: '#RRGGBB' }).width(110).fontSize(12)
        .fontColor(this.themeColorTextPrimary)
        .onChange((value: string) => onHex(value))
    }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
  }

  /** 分区标题，对应上游 PillHeaderDivider。 */
  @Builder
  private LayoutSectionHeader(title: string) {
    Row() {
      Text(title).fontSize(12).fontColor(this.themeColorTextTertiary)
    }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 6 })
  }

  /**
   * 书架布局设置面板，对应上游 BookshelfConfigSheet。
   *
   * 只迁移当前项目已有数据模型能支撑的项；上游的封面尺寸、卡片颜色、
   * 标签徽标等依赖书籍字段或网络状态，留待后续轮次。
   */
  @Builder
  private LayoutSheetContent() {
    Column() {
      Row() {
        Text('书架布局').fontSize(19).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Text('完成').fontSize(14).fontColor('#B9C8FF').padding(8)
          .onClick(async () => { await this.submitLayout(); })
      }.width('100%').padding({ left: 18, right: 12, top: 14, bottom: 6 })

      Scroll() {
        Column() {
          this.LayoutSectionHeader('分组')
          this.LayoutMenuRow('分组样式', '页签 / 隐藏页签 / 文件夹', BOOK_GROUP_STYLE_OPTIONS,
            this.layoutDraft.bookGroupStyle,
            (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookGroupStyle = value; }); })
          this.LayoutSwitchRow('隐藏没有书籍的分组', '页签只显示有书的分类',
            this.layoutDraft.hideEmptyGroups,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.hideEmptyGroups = value; }); })

          if (this.layoutDraft.bookGroupStyle === 2) {
            this.LayoutSectionHeader('文件夹（竖屏）')
            this.LayoutMenuRow('文件夹布局模式·竖屏', '列表 / 网格', BOOKSHELF_FOLDER_LAYOUT_MODE_OPTIONS,
              this.layoutDraft.bookshelfFolderLayoutModePortrait,
              (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfFolderLayoutModePortrait = value; }); })
            this.LayoutStepperRow('文件夹网格列数·竖屏', '网格模式下分组卡片每行个数',
              this.layoutDraft.bookshelfFolderLayoutGridPortrait, 1, 15,
              (delta: number) => {
                this.updateLayoutDraft((draft: BookshelfLayoutSettings) => {
                  draft.bookshelfFolderLayoutGridPortrait = Math.max(1, Math.min(15, draft.bookshelfFolderLayoutGridPortrait + delta));
                });
              })
            this.LayoutStepperRow('文件夹列表列数·竖屏', '列表模式下分组卡片每行个数',
              this.layoutDraft.bookshelfFolderLayoutListPortrait, 1, 5,
              (delta: number) => {
                this.updateLayoutDraft((draft: BookshelfLayoutSettings) => {
                  draft.bookshelfFolderLayoutListPortrait = Math.max(1, Math.min(5, draft.bookshelfFolderLayoutListPortrait + delta));
                });
              })

            this.LayoutSectionHeader('文件夹（横屏）')
            this.LayoutMenuRow('文件夹布局模式·横屏', '列表 / 网格', BOOKSHELF_FOLDER_LAYOUT_MODE_OPTIONS,
              this.layoutDraft.bookshelfFolderLayoutModeLandscape,
              (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfFolderLayoutModeLandscape = value; }); })
            this.LayoutStepperRow('文件夹网格列数·横屏', '网格模式下分组卡片每行个数',
              this.layoutDraft.bookshelfFolderLayoutGridLandscape, 1, 15,
              (delta: number) => {
                this.updateLayoutDraft((draft: BookshelfLayoutSettings) => {
                  draft.bookshelfFolderLayoutGridLandscape = Math.max(1, Math.min(15, draft.bookshelfFolderLayoutGridLandscape + delta));
                });
              })
            this.LayoutStepperRow('文件夹列表列数·横屏', '列表模式下分组卡片每行个数',
              this.layoutDraft.bookshelfFolderLayoutListLandscape, 1, 5,
              (delta: number) => {
                this.updateLayoutDraft((draft: BookshelfLayoutSettings) => {
                  draft.bookshelfFolderLayoutListLandscape = Math.max(1, Math.min(5, draft.bookshelfFolderLayoutListLandscape + delta));
                });
              })

            this.LayoutSectionHeader('文件夹列表样式')
            this.LayoutMenuRow('文件夹列表样式', '分组 / 紧凑列表 / 横排封面数量', BOOKSHELF_GROUP_LIST_STYLE_OPTIONS,
              this.layoutDraft.bookshelfGroupListStyle,
              (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfGroupListStyle = value; }); })
            if (this.layoutDraft.bookshelfGroupListStyle === 2) {
              this.LayoutStepperRow('横排封面数量', '分组卡片一行显示的封面数，不足右侧留空',
                this.layoutDraft.bookshelfGroupCoverCount, 1, 10,
                (delta: number) => {
                  this.updateLayoutDraft((draft: BookshelfLayoutSettings) => {
                    draft.bookshelfGroupCoverCount = Math.max(1, Math.min(10, draft.bookshelfGroupCoverCount + delta));
                  });
                })
            }
          }

          this.LayoutSectionHeader('排序')
          this.LayoutMenuRow('排序方式', '', BOOK_SORT_OPTIONS, this.layoutDraft.bookshelfSort,
            (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfSort = value; }); })
          this.LayoutMenuRow('排序方向', '', BOOKSHELF_SORT_ORDER_OPTIONS, this.layoutDraft.bookshelfSortOrder,
            (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfSortOrder = value; }); })

          this.LayoutSectionHeader('布局')
          // 布局模式按当前方向读写：横屏写 bookshelfLayoutModeLandscape，对齐上游
          // BookshelfConfigSheet.kt:247-265（同一个下拉按 isLandscape 分支写两个字段）。
          this.LayoutMenuRow('布局模式', this.isLandscape ? '横屏下的书架呈现方式' : '竖屏下的书架呈现方式',
            BOOKSHELF_LAYOUT_MODE_OPTIONS, this.activeDraftLayoutMode(),
            (value: number) => {
              this.updateLayoutDraft((draft: BookshelfLayoutSettings) => {
                if (this.isLandscape) { draft.bookshelfLayoutModeLandscape = value; }
                else { draft.bookshelfLayoutModePortrait = value; }
              });
            })
          if (this.activeDraftLayoutMode() === 1) {
            this.LayoutMenuRow('网格样式', '标准 / 紧凑（书名进封面）/ 仅封面',
              BOOKSHELF_GRID_STYLE_OPTIONS, this.layoutDraft.bookshelfGridLayout,
              (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfGridLayout = value; }); })
          }
          // 列数上限对齐上游 BookshelfConfigSheet.kt:288（valueRange = 1f..15f）与 :412（1f..5f）；
          // 夹取写在回调里，因为 LayoutStepperRow 的 value<maximum 守卫在连点时会读到旧值。
          if (this.activeDraftLayoutMode() === 1) {
            this.LayoutStepperRow('网格列数', '每行显示的书封数量',
              this.activeDraftGridColumns(), 1, 15,
              (delta: number) => {
                this.updateLayoutDraft((draft: BookshelfLayoutSettings) => {
                  if (this.isLandscape) {
                    draft.bookshelfLayoutGridLandscape = Math.max(1, Math.min(15, draft.bookshelfLayoutGridLandscape + delta));
                  } else {
                    draft.bookshelfLayoutGridPortrait = Math.max(1, Math.min(15, draft.bookshelfLayoutGridPortrait + delta));
                  }
                });
              })
          } else {
            this.LayoutStepperRow('列表列数', '每行显示的书封数量',
              this.activeDraftListColumns(), 1, 5,
              (delta: number) => {
                this.updateLayoutDraft((draft: BookshelfLayoutSettings) => {
                  if (this.isLandscape) {
                    draft.bookshelfLayoutListLandscape = Math.max(1, Math.min(5, draft.bookshelfLayoutListLandscape + delta));
                  } else {
                    draft.bookshelfLayoutListPortrait = Math.max(1, Math.min(5, draft.bookshelfLayoutListPortrait + delta));
                  }
                });
              })
          }
          // 列表详情区：对齐上游 BookshelfConfigSheet.kt:332 的 AnimatedVisibility(layoutMode != 1)，
          // 整串只在列表模式下出现；内部结构照 :338 / :425 / :434-488 的顺序与嵌套。
          if (this.activeDraftLayoutMode() !== 1) {
            this.LayoutSwitchRow('显示分隔线', '列表卡片之间显示一条细横线',
              this.layoutDraft.bookshelfShowDivider,
              (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfShowDivider = value; }); })
            // 显示详情区总开关（上游 R.string.show_more_info，默认 false）：本地下面的四项都它的子项。
            this.LayoutSwitchRow('显示更多信息', '列表卡片展开简介、最新章节等详情',
              this.layoutDraft.showBookIntro,
              (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.showBookIntro = value; }); })
            if (this.layoutDraft.showBookIntro) {
              this.LayoutSwitchRow('封面垂直居中', '关闭后列表封面与文字顶部对齐',
                this.layoutDraft.bookshelfListCoverCenter,
                (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfListCoverCenter = value; }); })
              this.LayoutSwitchRow('显示最新章节', '列表卡片显示最后阅读的章节名',
                this.layoutDraft.bookshelfShowLatestChapter,
                (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfShowLatestChapter = value; }); })
              this.LayoutSwitchRow('显示简介', '列表卡片显示书籍简介',
                this.layoutDraft.bookshelfShowIntro,
                (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfShowIntro = value; }); })
              // 上游 :465 的额外条件是 settings.bookshelfShowIntro && layoutMode == 0。
              if (this.layoutDraft.bookshelfShowIntro && this.activeDraftLayoutMode() === 0) {
                this.LayoutSwitchRow('简介在封面和信息下方', '开启后简介单独铺在卡片底部',
                  this.layoutDraft.bookshelfListIntroBelowContent,
                  (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfListIntroBelowContent = value; }); })
              }
              // 上游 :477 的额外条件是 settings.bookshelfShowIntro；valueRange 0f..10f，0 表示显示全部。
              if (this.layoutDraft.bookshelfShowIntro) {
                this.LayoutStepperRow('简介行数', `简介最多显示几行，0 表示显示全部（当前${this.introMaxLinesDescription()}）`,
                  this.layoutDraft.bookshelfIntroMaxLines, 0, 10,
                  (delta: number) => {
                    this.updateLayoutDraft((draft: BookshelfLayoutSettings) => {
                      draft.bookshelfIntroMaxLines = Math.max(0, Math.min(10, draft.bookshelfIntroMaxLines + delta));
                    });
                  })
              }
            }
          }
          this.LayoutSectionHeader('标签')
          this.LayoutSwitchRow('显示标签', '在书卡上显示自定义标签、来源分类与字数',
            this.layoutDraft.bookshelfShowTag,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfShowTag = value; }); })
          if (this.layoutDraft.bookshelfShowTag) {
            Row() {
              Column() {
                Text('标签显示内容').fontSize(14).fontColor(this.themeColorTextSecondary)
                Text(this.tagSourcesLabel()).fontSize(11).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              AppGlyph({ name: this.showTagSources ? 'profileExpandMore' : 'list', glyphSize: 16 })
            }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .onClick(() => { this.showTagSources = !this.showTagSources; })
            if (this.showTagSources) {
              this.LayoutSwitchRow('字数', '把全书字数作为一个标签',
                this.layoutDraft.bookshelfShowWordCount,
                (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfShowWordCount = value; }); })
              this.LayoutSwitchRow('来源分类', '把书籍分类作为一个标签',
                this.layoutDraft.bookshelfShowSourceTags,
                (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfShowSourceTags = value; }); })
              this.LayoutSwitchRow('自定义标签', '把自定义标签逐个显示',
                this.layoutDraft.bookshelfShowCustomTags,
                (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfShowCustomTags = value; }); })
            }
            this.LayoutSwitchRow('自定义标签配色', '开启后按下面的配色给标签行取色',
              this.layoutDraft.enableCustomTagColors,
              (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.enableCustomTagColors = value; }); })
            if (this.layoutDraft.enableCustomTagColors) {
              Row() {
                Column() {
                  Text('管理标签配色').fontSize(14).fontColor(this.themeColorTextSecondary)
                  Text(`${this.tagColorsCount()} 组配色`).fontSize(11).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                AppGlyph({ name: 'profileExpandMore', glyphSize: 16 })
              }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
                .onClick(() => { this.openTagColorPage(); })
            }
          }
          this.LayoutSectionHeader('徽标')
          this.LayoutSwitchRow('显示未读数', '在封面角标与标题右侧显示未读章节数',
            this.layoutDraft.showUnread,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.showUnread = value; }); })
          this.LayoutSwitchRow('显示更新红点', '有新增章节时显示红点（需同时开显示未读数）',
            this.layoutDraft.showUnreadNew,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.showUnreadNew = value; }); })
          this.LayoutSwitchRow('显示等待更新数', '控制标题末尾待更新书数 (N)',
            this.layoutDraft.showWaitUpCount,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.showWaitUpCount = value; }); })
          this.LayoutSwitchRow('显示书籍计数', '在分组卡上显示书籍数',
            this.layoutDraft.showBookCount,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.showBookCount = value; }); })
          this.LayoutSwitchRow('显示最后更新时间', '非本地书显示最近更新时间的相对文案',
            this.layoutDraft.showLastUpdateTime,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.showLastUpdateTime = value; }); })
          this.LayoutSwitchRow('显示书籍类型', '在卡片上显示 本地 / EPUB 等类型',
            this.layoutDraft.showTip,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.showTip = value; }); })
          this.LayoutStepperRow('书名行数', '书封下方标题最多显示几行',
            this.layoutDraft.bookshelfTitleMaxLines, 1, 5,
            (delta: number) => {
              this.updateLayoutDraft((draft: BookshelfLayoutSettings) => {
                draft.bookshelfTitleMaxLines = Math.max(1, Math.min(5, draft.bookshelfTitleMaxLines + delta));
              });
            })
          this.LayoutSwitchRow('标题居中', '关闭后书名左对齐', this.layoutDraft.bookshelfTitleCenter,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfTitleCenter = value; }); })
          this.LayoutSwitchRow('标题小字号', '书名用 11 号字，默认 13 号', this.layoutDraft.bookshelfTitleSmallFont,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfTitleSmallFont = value; }); })

          this.LayoutSectionHeader('外观')
          this.LayoutSwitchRow('精简详情', '开启后卡片只留封面与书名', this.layoutDraft.bookshelfLayoutCompact,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfLayoutCompact = value; }); })
          this.ColorPickerRow('日间卡片底色', this.dayCardColorHex,
            (value: string) => {
              this.dayCardColorHex = value;
              this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfCardColor = bookshelfCardHexToInt(value); });
            })
          this.ColorPickerRow('夜间卡片底色', this.nightCardColorHex,
            (value: string) => {
              this.nightCardColorHex = value;
              this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfCardColorDark = bookshelfCardHexToInt(value); });
            })
          this.LayoutStepperRow('网格封面宽度', '书封在格子里最宽能到多少，格子更窄时以格子为准',
            this.layoutDraft.bookshelfGridCoverWidth, 40, 200,
            (delta: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfGridCoverWidth = Math.max(40, Math.min(200, draft.bookshelfGridCoverWidth + delta * 10)); }); })
          this.LayoutStepperRow('列表封面宽度', '列表模式下书封宽度',
            this.layoutDraft.bookshelfListCoverWidth, 40, 200,
            (delta: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfListCoverWidth = Math.max(40, Math.min(200, draft.bookshelfListCoverWidth + delta * 10)); }); })
          // 列表模式的「显示简介 / 显示最新章节」已移进「布局」组的详情区（受 showBookIntro 总开关约束），
          // 这里不再重复。
          this.LayoutSwitchRow('书封阴影', '', this.layoutDraft.bookshelfCoverShadow,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfCoverShadow = value; }); })

          this.LayoutSectionHeader('其它')
          this.LayoutSwitchRow('搜索按钮优先打开搜索页', '关闭后单击先进筛选、长按进搜索页',
            this.layoutDraft.bookshelfSearchActionDirectToSearch,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfSearchActionDirectToSearch = value; }); })
          this.LayoutSwitchRow('显示快速滚动条', '书架右侧出现可拖动滚动条',
            this.layoutDraft.showBookshelfFastScroller,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.showBookshelfFastScroller = value; }); })
          this.LayoutSwitchRow('页签栏菜单按钮', '页签栏右端出现分组下拉按钮',
            this.layoutDraft.showBookshelfTabMenu,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.showBookshelfTabMenu = value; }); })
          this.LayoutStepperRow('书架更新线程数', '0 表示不限（上游键名 bookshelfUpdateLimit）',
            this.layoutDraft.bookshelfRefreshingLimit, 0, 100,
            (delta: number) => {
              this.updateLayoutDraft((draft: BookshelfLayoutSettings) => {
                draft.bookshelfRefreshingLimit = Math.max(0, Math.min(100, draft.bookshelfRefreshingLimit + delta));
              });
            })
        }.width('100%').padding({ bottom: 24 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#17181E')
  }

  /**
   * 书架上的半模态面板统一入口。
   *
   * 同一组件挂多个 bindSheet 只有最后一个生效（本项目已踩过的坑），
   * 所以布局面板与分组面板共用同一个 sheet，按状态分发内容。
   */
  @Builder
  private ShelfSheetContent() {
    if (this.showPasswordPanel) {
      this.PasswordSheet()
    } else if (this.showBatchDeleteSheet) {
      this.BatchDeleteSheet()
    } else if (this.showTagColorPage) {
      this.TagColorSheet()
    } else if (this.showLayoutSheet) {
      this.LayoutSheetContent()
    } else if (this.showLogSheet) {
      this.LogSheetContent()
    } else {
      this.GroupManagerSheet()
    }
  }

  /** 日志面板：显示 AppLog 的内存缓冲，底部一键清空。对应上游 AppLogSheet。 */
  @Builder
  private LogSheetContent() {
    Column() {
      Row() {
        Text('日志').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
        Blank()
        Text('清空').fontSize(13).fontColor(this.themeColorAccent).padding(6)
          .onClick(() => { AppLog.clear(); this.logEntries = []; })
      }.width('100%').padding({ left: 16, right: 16, top: 18, bottom: 12 })
      if (this.logEntries.length === 0) {
        Column() {
          Text('暂无日志').fontSize(13).fontColor(this.themeColorTextTertiary)
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.logEntries, (line: string) => {
            ListItem() {
              Text(line).fontSize(11).fontColor(this.themeColorTextSecondary)
                .fontFamily('monospace').width('100%')
            }.padding({ left: 16, right: 16, top: 4, bottom: 4 })
          }, (line: string) => line)
        }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
      }
    }.width('100%').height('100%').backgroundColor('#17181E')
  }

  /**
   * 配色管理页（:211）。上游是独立底部弹层 LabelColorManageSheet.kt，本地复用书架
   * 的同一个 bindSheet，避免同组件挂多个 sheet 只有最后一个生效。
   */
  @Builder
  private TagColorSheet() {
    Column() {
      Row() {
        Text('‹ 返回').fontSize(14).fontColor(this.themeColorAccent).padding(6)
          .onClick(() => { this.showTagColorPage = false; })
        Text('管理标签配色').fontSize(18).fontWeight(FontWeight.Bold)
          .fontColor(this.themeColorTextPrimary).layoutWeight(1).textAlign(TextAlign.Center)
        Text('生成').fontSize(13).fontColor(this.themeColorAccent).padding(6)
          .onClick(async () => { await this.generateTagColors(); })
        Text('添加').fontSize(13).fontColor(this.themeColorAccent).padding(6)
          .onClick(async () => { await this.addTagColor(); })
      }.width('100%').padding({ left: 12, right: 12, top: 16, bottom: 12 })

      if (this.tagColorsDraft.length === 0) {
        Column() {
          Text('暂无配色，点「生成」创建 8 组').fontSize(13).fontColor(this.themeColorTextTertiary)
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            ForEach(this.tagColorsDraft, (pair: TagColorPair, index: number) => {
              Row() {
                Text(`颜色 ${index + 1}`).fontSize(12)
                  .fontColor(pair.textColor !== 0 ? argbToColorHex(pair.textColor) : this.themeColorTextPrimary)
                  .padding({ left: 10, right: 10, top: 8, bottom: 8 })
                  .backgroundColor(pair.bgColor !== 0 ? argbToColorHex(pair.bgColor) : this.themeColorSurfaceTertiary)
                  .borderRadius(6)
                Blank()
                Text('编辑').fontSize(13).fontColor(this.themeColorAccent).padding(6)
                  .onClick(() => { this.openTagColorPicker(index); })
                Text('删除').fontSize(13).fontColor('#D99AA5').padding(6)
                  .onClick(async () => { await this.removeTagColor(index); })
              }.width('100%').padding({ left: 16, right: 12, top: 6, bottom: 6 })
            }, (pair: TagColorPair, index: number) => `${index}_${pair.textColor}_${pair.bgColor}`)
          }
        }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
      }

      if (this.showTagColorPicker) {
        Row() {
          TextInput({ text: this.tagColorPickerHex, placeholder: '#RRGGBB 文字色' })
            .layoutWeight(1).fontSize(12).fontColor(this.themeColorTextPrimary)
            .onChange((value: string) => { this.tagColorPickerHex = value; })
          Text('取消').fontSize(13).fontColor(this.themeColorTextTertiary).padding(6)
            .onClick(() => { this.showTagColorPicker = false; })
          Text('确定').fontSize(13).fontColor(this.themeColorAccent).padding(6)
            .onClick(async () => { await this.confirmTagColor(); })
        }.width('100%').padding({ left: 16, right: 12, top: 8, bottom: 16 })
      }
    }.width('100%').height('100%').backgroundColor('#17181E')
  }

  /** 导出书单：写 bookshelf.json，字段与上游 ExportBookshelfUseCase 一致。 */
  private async exportBookList(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      const saved = await BookshelfListTransfer.exportList(context, this.books);
      if (saved) {
        AppLog.put(`书单导出成功，共 ${this.books.length} 本`);
        this.onUnavailableAction(`已导出 ${this.books.length} 本书到 bookshelf.json`);
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.onUnavailableAction(`书单导出失败：${message}`);
      AppLog.put(`书单导出失败: ${message}`);
    }
  }

  /** 导入书单：选 .json/.txt 解析，新增条目经回调交 Index 落库刷新书架。 */
  private async importBookList(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      const entries = await BookshelfListTransfer.selectAndParse(context);
      if (entries === undefined) { return; }
      const books = BookshelfListTransfer.toBooks(entries, this.books);
      if (books.length === 0) {
        this.onUnavailableAction('书单里没有可导入的新书（可能都已存在）');
        return;
      }
      await this.onImportBookList(books);
      AppLog.put(`书单导入成功，新增 ${books.length} 本`);
      this.onUnavailableAction(`已导入 ${books.length} 本书`);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.onUnavailableAction(`书单导入失败：${message}`);
      AppLog.put(`书单导入失败: ${message}`);
    }
  }

  @Builder
  private MoreMenu() {
    Menu() {
      MenuItem({ startIcon: $r('app.media.menu_wifi'), content: '远程书籍' }).height(48)
        .onClick(() => this.onUnavailableAction('远程书籍导入尚未迁移'))
      MenuItem({ startIcon: $r('app.media.menu_save'), content: '添加本地' }).height(48)
        .onClick(async () => {
          // 多选后先进确认页（批 10 的 :555）——真正导入在 Index 的确认页回调里，
          // 这里拿到的一定是 undefined，不再按返回值切分组。
          await this.onImportBook();
        })
      MenuItem({ startIcon: $r('app.media.app_refresh'), content: '更新目录' }).height(48)
        .onClick(async () => { await this.onRefreshToc(); })
      MenuItem({ startIcon: $r('app.media.menu_grid'), content: '布局设置' }).height(48)
        .onClick(() => this.openLayoutSheet())
      MenuItem({ startIcon: $r('app.media.menu_carousel'), content: '分组管理' }).height(48)
        .onClick(() => this.showGroupManager = true)
      MenuItem({ startIcon: $r('app.media.menu_link'), content: '添加网址' }).height(48)
        .onClick(() => this.onUnavailableAction('网址导入尚未迁移'))
      MenuItem({ startIcon: $r('app.media.app_pencil'), content: '选择模式' }).height(48)
        .onClick(() => this.toggleSelectionMode())
      MenuItem({ startIcon: $r('app.media.menu_bookmarks'), content: '书架管理' }).height(48)
        .onClick(() => this.onOpenBookshelfManage(this.activeFilter()))
      MenuItem({ startIcon: $r('app.media.menu_upload_file'), content: '导出书单' }).height(48)
        .onClick(async () => { await this.exportBookList(); })
      MenuItem({ startIcon: $r('app.media.app_cloud_download'), content: '导入书单' }).height(48)
        .onClick(async () => { await this.importBookList(); })
      MenuItem({ startIcon: $r('app.media.profile_history'), content: '日志' }).height(48)
        .onClick(() => { this.logEntries = AppLog.getAll(); this.showLogSheet = true; })
    }.backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).fontColor(this.themeColorTextPrimary).radius(20)
  }

  build() {
    Column() {
      Row() {
        if (this.collapsedHeader) {
          Text(this.bookshelfTitle()).fontSize(20).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        }
        Blank()
        if (this.selectionMode) {
          // 选择模式顶栏：只留关闭按钮，搜索与更多暂时收起（:87）。
          Stack({ alignContent: Alignment.Center }) { AppGlyph({ name: 'profileClose', glyphSize: 18 }) }
            .width(36).height(36).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(18)
            .onClick(() => this.clearSelection())
        }
        if (!this.selectionMode) {
        Stack({ alignContent: Alignment.Center }) { AppGlyph({ name: 'search', glyphSize: 20 }) }.width(36).height(36).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(20)
          .onClick(() => {
            if (this.layout.bookshelfSearchActionDirectToSearch) {
              this.onSearch();
            } else {
              this.showSearch = !this.showSearch;
              if (!this.showSearch) { this.searchQuery = ''; }
            }
          })
          .priorityGesture(LongPressGesture({ duration: 500 }).onAction((_event: GestureEvent): void => {
            if (this.layout.bookshelfSearchActionDirectToSearch) {
              this.showSearch = !this.showSearch;
              if (!this.showSearch) { this.searchQuery = ''; }
            } else {
              this.onSearch();
            }
          }))
        Stack({ alignContent: Alignment.Center }) { AppGlyph({ name: 'more', glyphSize: 20 }) }
          .width(36).height(36).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(20).margin({ left: 8 })
          .bindMenu(this.MoreMenu, { placement: Placement.BottomRight })
        }
      }.width('100%').height(56).padding({ left: 16, right: 16, top: 10, bottom: 0 })
      Column() {
        Text(this.bookshelfTitle()).fontSize(28).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
        if (this.bookshelfSubtitle().length > 0) {
          Text(this.bookshelfSubtitle()).fontSize(12).fontColor(this.themeColorTextTertiary)
        }
      }.alignItems(HorizontalAlign.Start)
        .width('100%').height(this.collapsedHeader ? 0 : 58)
        .padding({ left: 16, right: 16, bottom: this.collapsedHeader ? 0 : 18 })
        .opacity(this.collapsedHeader ? 0 : 1)
        .animation({ duration: 220, curve: Curve.EaseInOut })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 17 }).margin({ right: 9 })
          TextInput({ placeholder: '搜索书名或作者…', text: this.searchQuery })
            .fontSize(16).fontColor(this.themeColorTextSecondary).placeholderColor(this.themeColorTextTertiary)
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .onChange((value: string) => this.searchQuery = value)
          if (this.searchQuery.length > 0) {
            AppGlyph({ name: 'profileClose', glyphSize: 14 }).margin({ left: 6 })
              .onClick(() => { this.searchQuery = ''; })
          }
        }.width('100%').padding({ left: 14, right: 14, top: 9, bottom: 9 })
          .margin({ left: 16, right: 16, bottom: 10 }).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(22).backgroundImage(this.themeItemBackground.length > 0 ? `file://${this.themeItemBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 1, y: 0.6 })).animation({ duration: 220, curve: Curve.EaseInOut }))
      }

      // 分组样式为「文件夹」时：根层显示分组卡片，点进分组后顶部给一条返回入口。
      if (this.layout.bookGroupStyle === 2) {
        Row() {
          if (this.folderViewGroup.length > 0) {
            Text('‹ 返回文件夹').fontSize(12).fontColor(this.themeColorAccent).padding(6)
              .onClick(() => { this.backToFolderRoot(); })
          }
          Text(this.folderViewGroup.length > 0 ? `当前分组：${this.folderViewGroup}` : '文件夹（点卡片进入分组）')
            .fontSize(12).fontColor(this.themeColorTextTertiary).layoutWeight(1)
        }.width('100%').padding({ left: 16, right: 16, bottom: 10 })
      } else if (this.layout.bookGroupStyle === 0) {
        // 分组样式为「隐藏页签」时不渲染顶部筛选栏，切换分组改由分组管理面板完成。
        Row() {
          Scroll() {
            Row() {
              ForEach(this.getGroupNames(), (groupName: string) => {
                ShelfFilter({ label: groupName, selected: this.activeFilter() === groupName })
                  .onClick(async () => { await this.selectGroup(groupName); })
              }, (groupName: string) => groupName)
            }
          }.layoutWeight(1).scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
          if (this.layout.showBookshelfTabMenu) {
            Stack({ alignContent: Alignment.Center }) { AppGlyph({ name: 'list', glyphSize: 18 }) }
              .width(34).height(34).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(17)
              .bindMenu(this.GroupFilterMenu())
          }
        }.width('100%').padding({ left: 12, right: 12, bottom: 14 })
      } else {
        Row() {
          Text(`当前分组：${this.activeFilter()}`).fontSize(12).fontColor(this.themeColorTextTertiary).layoutWeight(1)
          Text('切换分组').fontSize(12).fontColor(this.themeColorAccent).padding(6)
            .bindMenu(this.GroupFilterMenu())
        }.width('100%').padding({ left: 16, right: 16, bottom: 10 })
      }
      if (this.selectionMode) {
        // 选择模式工具条（:142-144 / :146 / :148）。
        Row() {
          Text(`已选 ${this.selectedBookKeys.size} 本`).fontSize(12)
            .fontColor(this.themeColorTextPrimary).layoutWeight(1)
          Text('全选').fontSize(12).fontColor(this.themeColorAccent).padding(6)
            .onClick(() => this.selectAllVisible())
          Text('反选').fontSize(12).fontColor(this.themeColorAccent).padding(6)
            .onClick(() => this.invertVisibleSelection())
          Text('移动').fontSize(12).fontColor(this.themeColorAccent).padding(6)
            .bindMenu(this.SelectionGroupMenu)
          // 批量私密标记（:147）：上游的可见条件是「编辑态且已设过本地密码」，
          // 没密码时不显示，免得留一个点了只能弹「请先设置密码」的按钮。
          if (this.privateHasPassword) {
            Text(this.selectionTargetPrivate() ? '设为私密' : '取消私密')
              .fontSize(12).fontColor(this.themeColorAccent).padding(6)
              .onClick(async () => { await this.toggleSelectedPrivate(); })
          }
          Text('删除').fontSize(12).fontColor('#FF6B6B').padding(6)
            .onClick(() => { this.batchDeleteSource = false; this.showBatchDeleteSheet = true; })
          Text('完成').fontSize(12).fontColor(this.themeColorTextTertiary).padding(6)
            .onClick(() => this.clearSelection())
        }.width('100%').padding({ left: 16, right: 12, bottom: 8 })
      }
      if (this.layout.bookGroupStyle === 2 && this.folderViewGroup.length === 0) {
        // 文件夹根层：分组卡片网格，列数按横竖屏各取一套（KI-SL-C2）。
        Grid() {
          ForEach(this.getFolderGroups(), (groupName: string) => {
            GridItem() {
              BookGroupCard({
                groupName: groupName,
                books: this.getFolderPreviewBooks(groupName),
                coverCount: this.layout.bookshelfGroupCoverCount,
                listStyle: this.layout.bookshelfGroupListStyle,
                coverSettings: this.coverSettings,
                isNight: this.readerNightMode,
                listCoverWidth: this.layout.bookshelfListCoverWidth,
                showCount: this.layout.showBookCount,
                // 私密分组锁定态（:257）：锁定时不画预览、不显示计数、组名旁加锁图标。
                locked: this.isGroupLocked(groupName),
                onOpen: () => { this.openFolderGroup(groupName); },
                // 长按分组卡直接进该分组的编辑面板（:107，上游 GroupEditSheet 入口）。
                onLongPress: (name: string) => {
                  const target = this.groups.find((item: BookGroup) => item.groupName === name);
                  if (target !== undefined) { this.openGroupEditor(target); }
                }
              })
            }
          }, (groupName: string) => `folder_${groupName}_${this.getFolderPreviewBooks(groupName).length}_${this.layout.bookshelfGroupCoverCount}_${this.layout.bookshelfGroupListStyle}_${this.activeLayoutMode()}`)
        }
        .columnsTemplate(this.folderColumnsTemplate())
        .rowsGap(BOOKSHELF_GRID_GAP).columnsGap(BOOKSHELF_GRID_GAP).width('100%')
        .padding({ left: BOOKSHELF_GRID_PADDING, right: BOOKSHELF_GRID_PADDING })
        .layoutWeight(1).scrollBar(BarState.Off)
      } else if (this.activeGroupLocked()) {
        this.PrivateGroupLockedPanel()
      } else if (this.getVisibleBooks().length > 0) {
        Grid(this.bookshelfScroller) {
          ForEach(this.getVisibleBooks(), (book: Book) => {
            GridItem() {
              Stack({ alignContent: Alignment.TopEnd }) {
              Column() {
                if (this.activeLayoutMode() === 0) {
                  // 列表模式卡片：左封面右信息（上游 BookItem.kt:846 BookshelfListItem）。
                  // 封面宽度只认 bookshelfListCoverWidth；网格封面宽度不参与本分支。
                  Column() {
                    Row() {
                      BookCover({
                        book: book,
                        compact: true,
                        showChapterBadge: true,
                        shadowEnabled: this.layout.bookshelfCoverShadow,
                        fillWidth: false,
                        displayWidth: this.layout.bookshelfListCoverWidth,
                        displayHeight: Math.round(this.layout.bookshelfListCoverWidth * 7 / 5),
                        coverSettings: this.coverSettings,
                        isNight: this.readerNightMode,
                        // 私密书封面盖一层锁遮罩（:325）。
                        locked: this.isBookLocked(book),
                        a11yText: [book.title, book.author, book.lastChapter]
                          .filter((value: string) => value.length > 0).join('，')
                      })
                      Column() {
                        Row() {
                          Text(book.title)
                            .fontSize(this.bookshelfTitleFontSize())
                            .fontColor(this.themeColorTextSecondary)
                            .maxLines(this.layout.bookshelfTitleMaxLines)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                            .layoutWeight(1)
                            .textAlign(this.layout.bookshelfTitleCenter ? TextAlign.Center : TextAlign.Start)
                          if (this.unreadTextOf(book).length > 0) {
                            Row() {
                              Text(this.unreadTextOf(book)).fontSize(9).fontColor('#FFFFFFFF')
                              if (this.showBadgeDotOf(book)) {
                                AppGlyph({ name: 'profileRefresh', glyphSize: 12, tint: '#FFFFFFFF' })
                              }
                            }.padding({ left: 4, right: 4 })
                              .backgroundColor(this.themeColorAccent).borderRadius(4)
                          }
                        }.width('100%')
                        // 简介在右列：需详情总门 + 显示简介开关 + 未开启「简介在下方」三个条件（上游 BookItem.kt:918）。
                        if (this.showsListDetails() && this.layout.bookshelfShowIntro
                          && !this.layout.bookshelfListIntroBelowContent) {
                          Text(book.description ?? '')
                            .fontSize(11).fontColor(this.themeColorTextTertiary)
                            .maxLines(this.introMaxLines()).textOverflow({ overflow: TextOverflow.Ellipsis })
                            .width('100%')
                            .textAlign(TextAlign.Start)
                            .padding({ top: 4, bottom: 4 })
                        }
                        // 章节行显示最新章节名（latestChapterTitle），不是当前阅读章 lastChapter。
                        if (this.showsListDetails() && this.layout.bookshelfShowLatestChapter
                          && (book.latestChapterTitle ?? '').length > 0) {
                          Text(book.latestChapterTitle ?? '')
                            .fontSize(11).fontColor(this.themeColorTextTertiary)
                            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                            .width('100%')
                            .textAlign(TextAlign.Start)
                        }
                        // 最后更新时间：上游仅非本地书显示，本地书恒不显示（本项目书全是本地书）。
                        if (this.layout.showLastUpdateTime && !book.isLocal
                          && book.latestChapterTime !== undefined) {
                          Text(toTimeAgo(book.latestChapterTime)).fontSize(10)
                            .fontColor(this.themeColorTextTertiary).opacity(0.5)
                        }
                        if (this.bookTypeLabel(book).length > 0) {
                          Text(this.bookTypeLabel(book)).fontSize(9).fontColor(this.themeColorAccent)
                        }
                        this.BookTagRow(book)
                      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                        .padding({ left: 8, right: 4 })
                    }.width('100%')
                      // 封面垂直居中（上游 BookItem.kt:194 的 bookshelfListCoverCenter）。
                      .alignItems(this.layout.bookshelfListCoverCenter ? VerticalAlign.Center : VerticalAlign.Top)
                    // 简介铺在卡片底部（上游 BookItem.kt:925 的 bottomContent）。
                    if (this.showsListDetails() && this.layout.bookshelfShowIntro
                      && this.layout.bookshelfListIntroBelowContent) {
                      Text(book.description ?? '')
                        .fontSize(11).fontColor(this.themeColorTextTertiary)
                        .maxLines(this.introMaxLines()).textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%')
                        .textAlign(TextAlign.Start)
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    }
                    // 列表卡片之间的细横线（上游 BookItem.kt:253-260 的 HorizontalDivider，0.5dp、水平留白 16dp）。
                    if (this.layout.bookshelfShowDivider) {
                      Column() {
                        Divider().strokeWidth(0.5).color(this.themeColorTextTertiary).opacity(0.5).width('100%')
                      }.width('100%').padding({ left: 16, right: 16 })
                    }
                  }.width('100%')
                } else {
                Stack({ alignContent: Alignment.Bottom }) {
                  BookCover({
                    book: book,
                    compact: true,
                    showChapterBadge: false,
                    badgeText: this.unreadTextOf(book),
                    showBadgeDot: this.showBadgeDotOf(book),
                    shadowEnabled: this.layout.bookshelfCoverShadow,
                    fillWidth: true,
                    maxWidth: this.bookshelfCoverWidthLimit(),
                    coverSettings: this.coverSettings,
                    isNight: this.readerNightMode,
                    // 私密书封面盖一层锁遮罩（:325）。
                    locked: this.isBookLocked(book),
                    a11yText: [book.title, book.author, book.lastChapter]
                      .filter((value: string) => value.length > 0).join('，')
                  })
                  if (this.layout.bookshelfGridLayout === 1) {
                    // 紧凑样式：书名移进封面内底部，白字配渐变黑底（上游 BookItem.kt:110-133）
                    Text(book.title).fontSize(this.bookshelfTitleFontSize()).fontColor('#FFFFFFFF')
                      .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                      .textAlign(this.layout.bookshelfTitleCenter ? TextAlign.Center : TextAlign.Start)
                      .padding({ left: 4, right: 4, top: 14, bottom: 4 })
                      .linearGradient(this.coverTitleGradient())
                  }
                }.width('100%')
                if (this.refreshingOf(book)) {
                  Row() {
                    LoadingProgress().width(16).height(16).color(this.themeColorAccent)
                    Text(' 更新中').fontSize(9).fontColor(this.themeColorTextTertiary)
                  }.width('100%').justifyContent(FlexAlign.Center).padding({ top: 2, bottom: 2 })
                }
                if (this.layout.bookshelfGridLayout === 0) {
                  Text(book.title).fontSize(this.bookshelfTitleFontSize()).fontColor(this.themeColorTextSecondary)
                    .maxLines(this.layout.bookshelfTitleMaxLines)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                    .textAlign(this.layout.bookshelfTitleCenter ? TextAlign.Center : TextAlign.Start)
                    .padding({ left: 4, right: 4, bottom: 4 })
                  // 作者行：非精简→作者；精简→合成「作者 · N 未读」（上游 subTitle 紧凑分支）。
                  Text(this.authorLineOf(book)).fontSize(11).fontColor(this.themeColorTextTertiary)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                    .textAlign(this.layout.bookshelfTitleCenter ? TextAlign.Center : TextAlign.Start)
                    .padding({ left: 4, right: 4, bottom: 4 })
                  if (this.bookTypeLabel(book).length > 0) {
                    Text(this.bookTypeLabel(book)).fontSize(9).fontColor(this.themeColorAccent)
                  }
                  if (this.layout.showLastUpdateTime && !book.isLocal
                    && book.latestChapterTime !== undefined) {
                    Text(toTimeAgo(book.latestChapterTime)).fontSize(10)
                      .fontColor(this.themeColorTextTertiary).opacity(0.5)
                  }
                  this.BookTagRow(book)
                }
                }
              }.width('100%').alignItems(HorizontalAlign.Center)
                .backgroundColor(this.cardBackgroundColor())
                .borderRadius(8)
                .onClick(() => {
                  // 选择模式下点击=切换选中，不打开书（:142 验收第 12 条）。
                  if (this.selectionMode) { this.toggleBookSelection(book); return; }
                  // 锁着的私密书不进阅读器，先验密码（:325 的「打开前校验」）。
                  if (this.isBookLocked(book)) {
                    this.requestPrivateUnlock(this.privateGroupIdOf(book), this.bookKey(book));
                    return;
                  }
                  if (BookRepository.isBodyMissing(book)) {
                    this.onOpenBookInfo(book);
                  } else {
                    this.onOpenBook(book);
                  }
                })
                // 手动排序下 Grid 的 onMove 拖拽同样靠长按启动，卡片这层必须先让位：
                // onGestureJudgeBegin 在判定阶段否决卡片长按，拖拽才能交给父级 Grid。
                // 其它排序方式 Grid 不启用 editMode，长按仍是「进详情」，行为不变。
                .onGestureJudgeBegin((info: GestureInfo, _event: BaseGestureEvent): GestureJudgeResult => {
                  if (this.canReorderBooks() && info.type === GestureControl.GestureType.LONG_PRESS_GESTURE) {
                    return GestureJudgeResult.REJECT;
                  }
                  return GestureJudgeResult.CONTINUE;
                })
                .gesture(LongPressGesture({ duration: 500 }).onAction((_event: GestureEvent): void => {
                  if (this.selectionMode) { this.toggleBookSelection(book); return; }
                  if (this.isBookLocked(book)) {
                    this.requestPrivateUnlock(this.privateGroupIdOf(book), this.bookKey(book));
                    return;
                  }
                  this.onOpenBookInfo(book);
                }))
              if (this.selectionMode) {
                // 勾选圈样式照 CatalogPage.ets:648-660：18×18 圆、选中底 #C4D1FF、1.5 边框。
                Stack({ alignContent: Alignment.Center }) {
                  Column().width(18).height(18).borderRadius(9)
                    .backgroundColor(this.isBookSelected(book) ? '#C4D1FF' : '#00000000')
                    .border({ width: 1.5, color: this.isBookSelected(book) ? '#C4D1FF' : '#7A7D88' })
                  if (this.isBookSelected(book)) {
                    AppGlyph({ name: 'profileCheck', glyphSize: 12, tint: '#1A1B21' })
                  }
                }.width(26).height(26).margin({ top: 4, right: 4 })
              }
              }
            }
          }, (book: Book) => this.bookCardKey(book))
            .onMove((from: number, to: number) => {
              // 拖拽重排只在「手动」排序下看得见效果（:138）。
              this.moveBook(from, to);
            })
        }
        .columnsTemplate(this.bookshelfColumnsTemplate())
        .rowsGap(BOOKSHELF_GRID_GAP).columnsGap(BOOKSHELF_GRID_GAP).width('100%')
        .padding({ left: BOOKSHELF_GRID_PADDING, right: BOOKSHELF_GRID_PADDING })
        .layoutWeight(1).scrollBar(this.layout.showBookshelfFastScroller ? BarState.On : BarState.Off)
          // editMode(true) 是 ForEach.onMove 生效的前提，与分组网格同一套写法（:138）。
          .editMode(this.canReorderBooks())
          .onAreaChange((_oldArea: Area, newArea: Area) => {
            // 记下网格可用宽度，封面宽度按格子宽度换算（见 bookshelfCoverSlotWidth）
            const width = parseFloat(String(newArea.width));
            const height = parseFloat(String(newArea.height));
            if (Number.isFinite(width) && Math.abs(width - this.bookshelfGridWidth) > 0.5) {
              this.bookshelfGridWidth = width;
            }
            // 旋转会改变容器宽高，这里再兜底刷新一次方向（窗口尺寸回调之外的第二道保险）。
            if (Number.isFinite(width) && Number.isFinite(height)) {
              const landscape: boolean = width > height;
              if (landscape !== this.isLandscape) { this.isLandscape = landscape; }
            }
          })
          .onScroll(() => {
            const shouldCollapse = Math.abs(this.bookshelfScroller.currentOffset().yOffset) > 60;
            if (this.collapsedHeader !== shouldCollapse) {
              animateTo({ duration: 220, curve: Curve.EaseInOut }, () => {
                this.collapsedHeader = shouldCollapse;
              });
            }
          })
      } else {
        Column() {
          Text(this.emptyFace).fontSize(32).fontColor(this.themeColorTextSecondary).margin({ bottom: 14 })
            .onClick(() => {
              const currentIndex = this.emptyFaces.indexOf(this.emptyFace);
              this.emptyFace = this.emptyFaces[(currentIndex + 1) % this.emptyFaces.length];
            })
          Text(this.searchQuery.length > 0 ? '没有匹配的书籍' : this.books.length === 0
            ? '书架还空着，先去搜索书籍或从发现里添加吧！' : '这个分组还没有书籍')
            .width(220).fontSize(11).fontColor(this.themeColorTextSecondary).textAlign(TextAlign.Center).maxLines(2)
          if (this.searchQuery.length > 0) {
            Text('全局搜索').fontSize(13).fontColor(this.themeColorAccent)
              .padding({ left: 16, right: 16, top: 8, bottom: 8 }).margin({ top: 14 })
              .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated))
              .borderRadius(18)
              .onClick(() => this.onSearch())
          }
        }.layoutWeight(1).width('100%').padding({ bottom: 104 }).justifyContent(FlexAlign.Center)
      }
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      .bindSheet(this.showGroupManager || this.showLayoutSheet || this.showLogSheet || this.showTagColorPage || this.showBatchDeleteSheet || this.showPasswordPanel, this.ShelfSheetContent(), {
        height: SheetSize.LARGE, dragBar: true, showClose: false, backgroundColor: '#17181E',
        onDisappear: () => { this.showGroupManager = false; this.showLayoutSheet = false; this.showLogSheet = false; this.showTagColorPage = false; this.showTagColorPicker = false; this.showRulePasteAuthorization = false; this.showBatchDeleteSheet = false; this.showPasswordPanel = false; }
      })
  }
}

@Component
struct ShelfFilter {
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @Prop label: string = '';
  @Prop selected: boolean = false;
  build() {
    Column() {
      Text(this.label).fontSize(12).fontColor(this.selected ? '#C4D1FF' : '#B6B8C2').padding({ left: 7, right: 7, top: 7, bottom: 7 })
      Row().width(42).height(2).backgroundColor(this.themeColorAccent).borderRadius(1)
        .opacity(this.selected ? 1 : 0)
        .animation({ duration: 180, curve: Curve.EaseInOut })
    }.layoutWeight(1).alignItems(HorizontalAlign.Center)
  }
}






