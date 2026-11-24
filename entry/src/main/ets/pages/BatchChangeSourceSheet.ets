// 批量换源向导（批10 :564 :566 :567 :568）。
//
// 与上游的对应：上游 `BookshelfManageScreen.kt:790-870` 把「选择目标书源」(`BookSourcePickerSheet`)、
// 「批量换源选项」(`ChangeSourceMigrationOptionsSheet`)、「批量换源预览」(`BatchChangePreviewSheet`)
// 做成三个独立面板，由三个 `show*` 状态串起来。本地仍是一个组件 + `@State step` 承载三步流程
// （三个独立面板需要在 Index 里维护三份状态与三次跳转，中间任何一步被系统回收就丢上下文），
// 但**每一步的面板本体都是上游同名组件的本地实现，不是在本文件里另写一份**：
//   · step 0 = 复用公共组件 `BookSourcePickerSheet`（搜索框 / 已选源可长按拖拽排序 / 可选源）
//   · step 1 = 复用公共组件 `ChangeSourceMigrationOptionsSheet`（title「批量换源选项」+ subtitle）
//   · step 2 = `BatchChangePreviewSheet` 的等价内容（双书卡 + 5 个动作按钮 + 「查看其他源信息」）
//   · step 3 = 执行结果汇总
//
// 与单本换源的关系：单本用 ChangeSourceSheet（自动搜候选、只换一本），批量用这个（人从列表里挑源 +
// 逐本自动搜 + 先预览再执行）。两者共用 ChangeSourceCoordinator 与 ChangeSourceMigrationOptionsSheet。
import { Book } from '../model/Book';
import { BookSource } from '../model/BookSource';
import {
  ChangeSourceCandidate, ChangeSourceCoordinator, ChangeSourceMigrationOptions, defaultMigrationOptions
} from '../bookSource/ChangeSourceCoordinator';
import { BookSourceRepository } from '../data/BookSourceRepository';
import { SearchBookItem } from '../bookSource/SourceModels';
import { AppGlyph } from '../components/AppGlyph';
import { BookCover } from '../components/BookCover';
import { ChangeSourceMigrationOptionsSheet } from '../components/booksource/ChangeSourceMigrationOptionsSheet';
import { BookSourcePickerSheet } from '../components/booksource/BookSourcePickerSheet';
import { BODY_SMALL, LABEL_LARGE, LABEL_MEDIUM, LABEL_SMALL, TITLE_LARGE, TITLE_MEDIUM } from '../components/typography/TypographyTokens';

/** 预览状态：对齐上游 BatchChangeSourcePreviewStatus（ChangeBookSourceUseCase.kt:65-69）。 */
export const BATCH_PREVIEW_MATCHED: number = 0;
export const BATCH_PREVIEW_NOT_FOUND: number = 1;
export const BATCH_PREVIEW_SKIPPED: number = 2;

/** 一本书的预览结果。对齐上游 BatchChangeSourcePreviewItem（ChangeBookSourceUseCase.kt:52-63）。 */
export interface BatchChangeSourcePreviewItem {
  bookUrl: string;
  title: string;
  oldSourceName: string;
  newSourceName: string;
  chapterCount: number;
  status: number;
  /** 命中的候选；未命中为 null。执行阶段直接用它，保证「预览什么就执行什么」。 */
  candidate: ChangeSourceCandidate | null;
  /**
   * G-8/G-9/G-11：该书在选中源里的**全部**候选（上游 `item.candidates`）。
   * 多于 1 个时预览行出现「查看其他源信息」按钮，其它源信息 Sheet 也从这里取。
   */
  candidates: ChangeSourceCandidate[];
  /** G-11：当前选中的候选下标（上游 `selectedCandidateIndex`）。 */
  selectedCandidateIndex: number;
  /** 作者，供预览卡第三行 `getRealAuthor() · N章` 用。 */
  author: string;
}

/** 批量执行结果。对齐上游 BatchChangeBookSourceResult（ChangeBookSourceUseCase.kt:40-44）。 */
export interface BatchChangeSourceResult {
  succeeded: number;
  failed: number;
  skipped: number;
}

/**
 * 批量换源向导。
 *
 * G-2：选源那一步不再在本文件里另画一份列表，而是复用公共组件 `BookSourcePickerSheet`
 * ——上游 `BookshelfManageScreen.kt:790-799` 调的也是独立的 `BookSourcePickerSheet`，
 * 面板本体（筛选框 / 已选源拖拽 / 可选源）只该有一份实现。
 */
@Component
export struct BatchChangeSourceSheet {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;

  /** 要换源的书籍；由书架管理页的选择模式传进来。 */
  books: Book[] = [];
  onClose: () => void = () => {};
  /**
   * 执行：Index 负责逐本迁移。
   * 第三个参数是预览结果——执行阶段不再二次搜索，直接用预览命中的候选落库，
   * 否则「预览 3 成 1 败」和「执行 3 成 1 败」会因为两次搜索结果不同而漂移。
   */
  onConfirm: (sourceUrls: string[], options: ChangeSourceMigrationOptions, preview: BatchChangeSourcePreviewItem[]) =>
    Promise<BatchChangeSourceResult> =
    async (_sourceUrls: string[], _options: ChangeSourceMigrationOptions,
      _preview: BatchChangeSourcePreviewItem[]): Promise<BatchChangeSourceResult> =>
      ({ succeeded: 0, failed: 0, skipped: 0 });

  /**
   * G-7：预览卡片上的「搜索 / 迁移 / 新增 / 详情」四个动作与九个回调。
   *
   * 上游 `BatchChangePreviewSheet`（`BookshelfManageScreen.kt:1518-1566`）把这些动作全部交回
   * 页面层（`onManualSearch` / `onMigrate` / `onAddToShelf` / `onOpenBook` / `onShowOtherSources`
   * / `onMigrateAll` / `onAddAllToShelf`），面板自己不碰仓库——因为它只是「看一眼再决定」的
   * 中间层。本地沿用同一分工：落库与换源都在 Index，面板只负责把选中的候选递出去。
   */

  /** 打开候选书的详情页（上游 `OpenBookInfoPreview(book, inBookshelf)`）。 */
  onOpenPreviewBook: (book: SearchBookItem, inBookshelf: boolean) => void = () => {};

  /** 手动搜索：拿这本旧书去单本换源面板重搜候选（上游 `manualSearchPreviewBook = book`）。 */
  onManualSearch: (book: Book) => void = () => {};

  /** 把命中的候选作为新书加入书架（上游 `AddPreviewItemToShelf`）。返回是否成功。 */
  onAddPreviewToShelf: (item: BatchChangeSourcePreviewItem) => Promise<boolean> =
    async (_item: BatchChangeSourcePreviewItem): Promise<boolean> => false;

  /** 单本迁移（上游 `MigratePreviewItem`）。返回是否成功；成功后该行从预览列表移除。 */
  onMigratePreview: (item: BatchChangeSourcePreviewItem, options: ChangeSourceMigrationOptions) =>
    Promise<boolean> =
    async (_item: BatchChangeSourcePreviewItem,
      _options: ChangeSourceMigrationOptions): Promise<boolean> => false;

  /** 0 = 选源，1 = 选项，2 = 预览，3 = 执行中/结果。 */
  @State step: number = 0;
  /** 全部已导入书源（原样保存；「启用 + 文本 + 有搜索地址」的过滤在面板里做，与上游同口径）。 */
  @State allSources: BookSource[] = [];
  /** 已选源地址，按已选区顺序；预览与执行都按这个顺序走。 */
  @State selectedUrls: string[] = [];
  @State options: ChangeSourceMigrationOptions = defaultMigrationOptions();
  @State preview: BatchChangeSourcePreviewItem[] = [];
  @State result: BatchChangeSourceResult = { succeeded: 0, failed: 0, skipped: 0 };
  @State loading: boolean = true;
  @State previewing: boolean = false;
  @State previewDone: number = 0;
  @State running: boolean = false;
  @State message: string = '';
  /** G-11：正在看「其它源信息」的那本（上游 `otherSourcePreviewItem`）。 */
  @State otherSourceBookUrl: string = '';
  /** 预览/执行的可取消标志：置 true 后循环在每本之前退出，已处理的书不回滚（与上游一致）。 */
  @State cancelled: boolean = false;

  aboutToAppear(): void {
    this.loadSources();
  }

  /** 第一步（:566）：列全部已导入的源，人从列表里挑；不复用单本的「按书名自动搜」。 */
  private async loadSources(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.loading = false;
      this.message = '无法读取书源列表';
      return;
    }
    const all = await BookSourceRepository.load(context);
    this.allSources = all;
    this.loading = false;
    let pickable: number = 0;
    for (let index = 0; index < all.length; index++) {
      const source: BookSource | undefined = all[index];
      if (source === undefined) { continue; }
      if (!source.enabled) { continue; }
      if (source.bookSourceType !== 0) { continue; }
      if (source.bookSourceUrl.length === 0) { continue; }
      pickable = pickable + 1;
    }
    if (pickable === 0) { this.message = '还没有导入任何启用的文本书源'; }
  }

  /** 已选源地址（顺序即预览/执行顺序，上游 `selectedSources`）。 */
  private selectedSourceUrls(): string[] {
    return this.selectedUrls.slice(0);
  }

  /**
   * 第三步（:567）：逐本搜候选并过滤到选中的源，把「原源 → 新源 → 章节数」列成表。
   * 这是整个流程最慢的一步（N 本 × M 个源），所以每处理完一本就刷新进度，且可取消。
   */
  private async runPreview(): Promise<void> {
    const urls = this.selectedSourceUrls();
    if (urls.length === 0) {
      this.message = '请至少选择一个目标书源';
      return;
    }
    this.step = 2;
    this.previewing = true;
    this.cancelled = false;
    this.preview = [];
    this.previewDone = 0;
    this.message = '';
    const items: BatchChangeSourcePreviewItem[] = [];
    for (let index = 0; index < this.books.length; index++) {
      if (this.cancelled) { break; }
      const book = this.books[index];
      if (book === undefined) { continue; }
      const item = await this.previewOne(book, urls);
      items.push(item);
      this.previewDone = index + 1;
      this.preview = items.slice();
    }
    this.previewing = false;
    if (this.cancelled) {
      // 取消后必须立刻停且不改任何书：预览本身不写库，清掉半成品结果即可。
      this.preview = [];
      this.message = '已取消，未改动任何书籍';
      this.step = 0;
      return;
    }
    if (items.length === 0) { this.message = '没有可预览的书籍'; }
  }

  /** 单本预览：本地书跳过；否则搜候选并按选中的源过滤，取章节数最多的一个。 */
  private async previewOne(book: Book, sourceUrls: string[]): Promise<BatchChangeSourcePreviewItem> {
    const oldName = book.originName !== undefined && book.originName.length > 0
      ? book.originName : (book.origin ?? '');
    if (book.isLocal) {
      return {
        bookUrl: book.contentPath ?? book.id, title: book.title, oldSourceName: oldName,
        newSourceName: '', chapterCount: 0, status: BATCH_PREVIEW_SKIPPED, candidate: null,
        candidates: [], selectedCandidateIndex: 0, author: book.author
      };
    }
    let candidates: ChangeSourceCandidate[] = [];
    try {
      candidates = await ChangeSourceCoordinator.searchCandidates(
        book.title, book.author, book.origin ?? ''
      );
    } catch (_) {
      candidates = [];
    }
    // G-8/G-9/G-11：只保留「校验通过 + 命中选中源」的候选，全部留下供
    // 「查看其他源信息」用（上游 `item.candidates` 是候选集合，不是单个）。
    const picked: ChangeSourceCandidate[] = [];
    for (let index = 0; index < candidates.length; index++) {
      const candidate = candidates[index];
      if (candidate === undefined) { continue; }
      if (!candidate.verified) { continue; }
      if (sourceUrls.indexOf(candidate.sourceUrl) < 0) { continue; }
      picked.push(candidate);
    }
    if (picked.length === 0) {
      return {
        bookUrl: book.contentPath ?? book.id, title: book.title, oldSourceName: oldName,
        newSourceName: '', chapterCount: 0, status: BATCH_PREVIEW_NOT_FOUND, candidate: null,
        candidates: [], selectedCandidateIndex: 0, author: book.author
      };
    }
    // searchCandidates 已按「校验通过 + 章节数多」排好序，第一条就是最优。
    const best = picked[0];
    if (best === undefined) {
      return {
        bookUrl: book.contentPath ?? book.id, title: book.title, oldSourceName: oldName,
        newSourceName: '', chapterCount: 0, status: BATCH_PREVIEW_NOT_FOUND, candidate: null,
        candidates: [], selectedCandidateIndex: 0, author: book.author
      };
    }
    return {
      bookUrl: book.contentPath ?? book.id, title: book.title, oldSourceName: oldName,
      newSourceName: best.sourceName, chapterCount: best.chapterCount,
      status: BATCH_PREVIEW_MATCHED, candidate: best,
      candidates: picked, selectedCandidateIndex: 0, author: book.author
    };
  }

  /**
   * G-11：切换某本的选中候选（上游 `SelectPreviewCandidate(oldBookUrl, candidateIndex)`）。
   * 换候选后同步改 `newSourceName` / `chapterCount` / `candidate`，保证预览与执行一致。
   */
  private selectCandidate(bookUrl: string, candidateIndex: number): void {
    const next: BatchChangeSourcePreviewItem[] = [];
    for (let index = 0; index < this.preview.length; index++) {
      const item = this.preview[index];
      if (item === undefined) { continue; }
      if (item.bookUrl !== bookUrl) { next.push(item); continue; }
      const chosen = item.candidates[candidateIndex];
      if (chosen === undefined) { next.push(item); continue; }
      next.push({
        bookUrl: item.bookUrl, title: item.title, oldSourceName: item.oldSourceName,
        newSourceName: chosen.sourceName, chapterCount: chosen.chapterCount,
        status: BATCH_PREVIEW_MATCHED, candidate: chosen,
        candidates: item.candidates, selectedCandidateIndex: candidateIndex, author: item.author
      });
    }
    this.preview = next;
  }

  /**
   * G-9：某本改为「不迁移」（上游 `SkipPreviewItem`）。跳过后不再参与执行，
   * 状态显示「不迁移」，且清掉候选避免被当成可迁移项。
   */
  private skipPreviewItem(bookUrl: string): void {
    const next: BatchChangeSourcePreviewItem[] = [];
    for (let index = 0; index < this.preview.length; index++) {
      const item = this.preview[index];
      if (item === undefined) { continue; }
      if (item.bookUrl !== bookUrl) { next.push(item); continue; }
      next.push({
        bookUrl: item.bookUrl, title: item.title, oldSourceName: item.oldSourceName,
        newSourceName: '', chapterCount: 0, status: BATCH_PREVIEW_SKIPPED, candidate: null,
        candidates: item.candidates, selectedCandidateIndex: item.selectedCandidateIndex, author: item.author
      });
    }
    this.preview = next;
  }

  /** 从预览列表里移除一条（上游 `removePreviewItem`）。 */
  private removePreviewItem(bookUrl: string): void {
    const next: BatchChangeSourcePreviewItem[] = [];
    for (let index = 0; index < this.preview.length; index++) {
      const item = this.preview[index];
      if (item === undefined) { continue; }
      if (item.bookUrl === bookUrl) { continue; }
      next.push(item);
    }
    this.preview = next;
  }

  /**
   * G-7：手动搜索（上游 `onManualSearch` → `manualSearchPreviewBook = book`，搜到后
   * `UpdatePreviewItem`，见 `BookshelfManageScreenViewModel.kt:959-988`）。
   *
   * 上游复用单本 `ChangeSourceSheet` 的搜索界面；本地复用同一次搜索
   * （`ChangeSourceCoordinator.searchCandidates`）并把结果放回本组件已有的候选面板，
   * 由人在这里挑。落点与上游 `UpdatePreviewItem` 一致：新候选插到该行候选列表最前面、
   * `selectedCandidateIndex = 0`、状态回到「已匹配」。
   */
  private async manualSearchPreview(item: BatchChangeSourcePreviewItem): Promise<void> {
    this.message = `正在搜索《${item.title}》的候选源…`;
    let found: ChangeSourceCandidate[] = [];
    try {
      found = await ChangeSourceCoordinator.searchCandidates(item.title, item.author, '');
    } catch (error) {
      this.message = '手动搜索失败：' + (error instanceof Error ? error.message : String(error));
      return;
    }
    const verified: ChangeSourceCandidate[] = [];
    for (let index = 0; index < found.length; index++) {
      const candidate = found[index];
      if (candidate !== undefined && candidate.verified) { verified.push(candidate); }
    }
    if (verified.length === 0) {
      this.message = '没有搜到校验通过的候选源';
      return;
    }
    // 上游 UpdatePreviewItem：candidates = listOf(新候选) + 旧候选，选中第 0 条。
    const merged: ChangeSourceCandidate[] = verified.concat(item.candidates);
    const best = merged[0];
    if (best === undefined) { return; }
    const next: BatchChangeSourcePreviewItem[] = [];
    for (let index = 0; index < this.preview.length; index++) {
      const current = this.preview[index];
      if (current === undefined) { continue; }
      if (current.bookUrl !== item.bookUrl) { next.push(current); continue; }
      next.push({
        bookUrl: current.bookUrl, title: current.title, oldSourceName: current.oldSourceName,
        newSourceName: best.sourceName, chapterCount: best.chapterCount,
        status: BATCH_PREVIEW_MATCHED, candidate: best, candidates: merged,
        selectedCandidateIndex: 0, author: current.author
      });
    }
    this.preview = next;
    // 搜到多条时直接把候选面板摊开，让人挑——这是上游「打开单本换源面板」那一步的落点。
    if (merged.length > 1) { this.otherSourceBookUrl = item.bookUrl; }
    this.message = `已更新《${item.title}》的候选（${merged.length} 个）`;
  }

  /**
   * G-7：单本迁移（上游 `onMigrate` → `MigratePreviewItem`，
   * `BookshelfManageScreenViewModel.kt:897-923`）：成功后该行从预览列表移除。
   */
  private async migratePreviewItem(item: BatchChangeSourcePreviewItem): Promise<void> {
    if (item.status !== BATCH_PREVIEW_MATCHED || item.candidate === null) { return; }
    this.message = `正在迁移《${item.title}》…`;
    const ok = await this.onMigratePreview(item, this.options);
    if (ok) {
      this.removePreviewItem(item.bookUrl);
      if (this.otherSourceBookUrl === item.bookUrl) { this.otherSourceBookUrl = ''; }
      this.message = `《${item.title}》迁移完成`;
    } else {
      this.message = `《${item.title}》迁移失败`;
    }
  }

  /**
   * G-7：把候选作为新书加入书架（上游 `onAddToShelf` → `AddPreviewItemToShelf`，
   * `BookshelfManageScreenViewModel.kt:990-1012`）：旧书保持不动，只新增。
   */
  private async addPreviewItemToShelf(item: BatchChangeSourcePreviewItem): Promise<void> {
    if (item.status !== BATCH_PREVIEW_MATCHED || item.candidate === null) { return; }
    this.message = `正在把《${item.title}》的新源加入书架…`;
    const ok = await this.onAddPreviewToShelf(item);
    if (ok) {
      this.message = `《${item.title}》已加入书架`;
    } else {
      this.message = `《${item.title}》加入书架失败`;
    }
  }

  /** 第四步（:564）：逐本执行。一本失败不能中断整批——执行在 Index 侧逐本 try/catch。 */
  private async runExecute(): Promise<void> {
    const urls = this.selectedSourceUrls();
    this.step = 3;
    this.running = true;
    this.message = '';
    try {
      this.result = await this.onConfirm(urls, this.options, this.preview);
    } catch (error) {
      this.result = { succeeded: 0, failed: 0, skipped: 0 };
      this.message = '批量换源失败：' + (error instanceof Error ? error.message : String(error));
    }
    this.running = false;
  }

  private matchedCount(): number {
    let count = 0;
    for (let index = 0; index < this.preview.length; index++) {
      const item = this.preview[index];
      if (item !== undefined && item.status === BATCH_PREVIEW_MATCHED) { count++; }
    }
    return count;
  }

  /** G-10：上游 `statusText`（`BookshelfManageScreen.kt:1756-1762`）三态文案。 */
  private statusText(item: BatchChangeSourcePreviewItem): string {
    if (item.status === BATCH_PREVIEW_SKIPPED) { return '不迁移'; }
    if (item.status === BATCH_PREVIEW_NOT_FOUND) { return '未找到'; }
    return '已匹配';
  }

  private rowBackground(): string {
    return this.themePureBlack ? '#1E1F26' : this.themeColorSurfaceElevated;
  }

  @Builder
  private StepHeader() {
    // 【单根节点】@Builder 多根时在部分宿主（bindSheet / 单参数位置）只渲染第一个，
    // 统一用外层 Column 收口。
    Column() {
      Row() {
        // step 0 的标题由 `BookSourcePickerSheet` 自己画（上游面板自带 title），
        // 这里不再重复一份，只留右上角关闭。
        if (this.step === 0) {
          Blank()
        } else {
          Text(this.step === 1 ? '批量换源选项' : (this.step === 2 ? '换源预览' : '换源结果'))
            .fontSize(TITLE_LARGE).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        }
        Text('✕').fontSize(TITLE_LARGE).fontColor(this.themeColorTextTertiary)
          .onClick(() => this.onClose())
      }.width('100%').padding({ bottom: 12 })
      Text(`已选 ${this.books.length} 本书`).fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary)
        .width('100%').margin({ bottom: 8 })
    }.width('100%')
  }

  /**
   * 第一步：选源。
   *
   * G-2：上游 `BookshelfManageScreen.kt:790-799` 调的是独立的 `BookSourcePickerSheet`
   * （title「选择目标书源」，`onConfirm` 把已选源交给 `pendingBatchSources`）。
   * 本地不再在本文件里另画一份「筛选框 + 已选区 + 可选区」，直接复用同名公共组件，
   * 保证面板本体只有一份实现（单本换源、批量换源、以后别的入口都走它）。
   */
  @Builder
  private SourceStep() {
    if (this.loading) {
      Row() {
        Text('正在读取书源…').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
      }.width('100%').justifyContent(FlexAlign.Center).padding(24)
    } else {
      BookSourcePickerSheet({
        title: '选择目标书源',
        sources: this.allSources,
        initialSelectedUrls: this.selectedUrls,
        onDismissRequest: () => this.onClose(),
        onConfirm: (selected: BookSource[]) => {
          const urls: string[] = [];
          for (let index = 0; index < selected.length; index++) {
            const source: BookSource | undefined = selected[index];
            if (source !== undefined) { urls.push(source.bookSourceUrl); }
          }
          this.selectedUrls = urls;
          this.message = '';
          this.step = 1;
        }
      })
    }
  }

  @Builder
  private OptionStep() {
    Column() {
      // G-6：上游 `BookshelfManageScreen.kt:801-817` 调的是公共组件
      // `ChangeSourceMigrationOptionsSheet(title = "批量换源选项",
      //   subtitle = "将对已选 ${selectedBookUrls.size} 本书执行换源；选项只对本次操作生效。")`。
      // 本地原来只有两个开关（`migrateProgress` / `migrateMetadata`），与上游八项口径不符，
      // 改为同一个公共组件，字段与三处调用点统一。
      ChangeSourceMigrationOptionsSheet({
        title: '批量换源选项',
        subtitle: `将对已选 ${this.books.length} 本书执行换源；选项只对本次操作生效。`,
        showDeleteDownloaded: true,
        initialOptions: this.options,
        onDismissRequest: () => { this.step = 0; },
        onConfirm: (options: ChangeSourceMigrationOptions) => {
          this.options = options;
          this.runPreview();
        }
      })
    }.width('100%').layoutWeight(1)
  }

  @Builder
  private PreviewStep() {
    Column() {
      if (this.previewing) {
        Row() {
          Text(`正在搜索并校验目录… ${this.previewDone} / ${this.books.length}`)
            .fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
        }.width('100%').justifyContent(FlexAlign.Center).padding(16)
      }
      // G-13：上游预览列表 `LazyColumn(heightIn(max=640.dp), spacedBy(10.dp))`
      // （`BookshelfManageScreen.kt:1549-1553`）。
      Scroll() {
        Column({ space: 10 }) {
          ForEach(this.preview, (item: BatchChangeSourcePreviewItem) => {
            // G-8/G-9：上游 `BatchChangePreviewRow`（:1571-1661）——GlassCard 内
            // 双书卡（原书籍 / 候选源）+ 5 个动作按钮。
            Column({ space: 12 }) {
              Row({ space: 12 }) {
                this.PreviewBookInfo('原书籍', item.title, item.author,
                  item.oldSourceName.length > 0 ? item.oldSourceName : '', '', true, 0)
                this.PreviewBookInfo(
                  item.status === BATCH_PREVIEW_SKIPPED ? '不迁移'
                    : (item.status === BATCH_PREVIEW_NOT_FOUND ? '未找到' : item.newSourceName),
                  item.candidate !== null && item.candidate.book !== null
                    ? item.candidate.book.name : '', item.author,
                  item.newSourceName, item.bookUrl, false,
                  item.status === BATCH_PREVIEW_SKIPPED ? 0 : item.chapterCount)
              }.width('100%').alignItems(VerticalAlign.Top)
              // G-9：5 个动作按钮（上游 SmallTonalButton）。
              Row() {
                // G-7：上游 `onManualSearch = { book -> manualSearchPreviewBook = book }`
                // （`BookshelfManageScreen.kt:822`）——拿这本旧书重开单本换源面板搜候选，
                // 搜到后用 `UpdatePreviewItem` 把新候选插到本行候选列表最前面。
                this.PreviewActionButton('搜索', () => this.manualSearchPreview(item))
                this.PreviewActionButton('不迁移', () => this.skipPreviewItem(item.bookUrl))
                // G-7：上游 `onMigrate = { bookUrl -> dispatch(MigratePreviewItem(bookUrl)) }`
                // （`:824`）——只迁移这一本，成功后该行从预览列表移除（`removePreviewItem`）。
                this.PreviewActionButton('迁移', () => { void this.migratePreviewItem(item); })
                // G-7：上游 `onAddToShelf = { bookUrl -> dispatch(AddPreviewItemToShelf(bookUrl)) }`
                // （`:826`）——把候选作为新书加入书架，旧书保持不动。
                this.PreviewActionButton('新增', () => { void this.addPreviewItemToShelf(item); })
                if (item.candidates.length > 1) {
                  this.PreviewActionButton('查看其他源信息',
                    () => this.otherSourceBookUrl = item.bookUrl)
                }
              }.width('100%').justifyContent(FlexAlign.SpaceBetween)
            }.width('100%').alignItems(HorizontalAlign.Start)
              .padding(12).backgroundColor(this.rowBackground()).borderRadius(12)
          }, (item: BatchChangeSourcePreviewItem) => item.bookUrl)
        }.width('100%')
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
      // G-11：其它源信息面板（上游 `OtherSourceOptionsSheet`，:1710-1754）。
      if (this.otherSourceBookUrl.length > 0) {
        this.OtherSourcePanel()
      }
    }.width('100%').layoutWeight(1)
  }

  /** G-8：上游 `PreviewBookInfo`（:1663-1708）——54dp 封面 + 书名 + 「作者 · N章」。 */
  @Builder
  private PreviewBookInfo(title: string, bookName: string, author: string, sourceName: string,
    bookUrl: string, isOld: boolean, chapterCount: number) {
    Column({ space: 6 }) {
      if (bookName.length > 0) {
        // 上游 `CoilBookCover(... Modifier.width(54.dp))`：宽度定死，高度按封面比例。
        BookCover({
          displayWidth: 54,
          displayHeight: 76,
          book: this.previewBookFor(bookName, author, bookUrl)
        })
      } else {
        // 上游 book==null 时用 54dp 占位 + error 色标题（:1700-1707）。
        Column().width(54).height(76).borderRadius(4).backgroundColor(this.rowBackground())
      }
      Text(bookName.length > 0 ? bookName : title).fontSize(LABEL_MEDIUM)
        .fontColor(bookName.length > 0 ? this.themeColorTextPrimary : '#F2B8B5').maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis }).textAlign(TextAlign.Center)
      Text(`${author} · ${chapterCount}章`).fontSize(LABEL_SMALL)
        .fontColor(this.themeColorTextTertiary).maxLines(1)
    }.layoutWeight(1).alignItems(HorizontalAlign.Center)
  }

  /**
   * G-8：预览卡用的临时 Book 对象。上游 `PreviewBookInfo` 直接吃 `Book`，
   * 本地 `BookCover` 也需要 Book；这里只填封面要用的四字段，不落库。
   */
  private previewBookFor(name: string, author: string, bookUrl: string): Book {
    const book: Book = {
      id: bookUrl.length > 0 ? bookUrl : name,
      title: name,
      author: author,
      category: '',
      lastChapter: '',
      progress: 0,
      isLocal: false
    };
    return book;
  }

  /** G-9：预览行动作按钮（上游 SmallTonalButton，文字色 onSurfaceVariant）。 */
  @Builder
  private PreviewActionButton(label: string, onTap: () => void) {
    Text(label).fontSize(LABEL_SMALL).fontColor(this.themeColorAccent)
      .padding({ left: 8, right: 8, top: 6, bottom: 6 })
      .onClick(onTap)
  }

  /** G-11：其它源信息面板（上游 `OtherSourceOptionsSheet`：候选列表 + 详情按钮）。 */
  @Builder
  private OtherSourcePanel() {
    Column() {
      Row() {
        Text('其他源信息').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Text('关闭').fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent)
          .onClick(() => this.otherSourceBookUrl = '')
      }.width('100%').padding({ bottom: 8 })
      Scroll() {
        Column({ space: 8 }) {
          ForEach(this.otherSourceCandidates(), (candidate: ChangeSourceCandidate, index: number) => {
            Row() {
              Column() {
                Text(candidate.sourceName).fontSize(TITLE_MEDIUM)
                  .fontColor(this.themeColorTextPrimary).maxLines(1)
                Text(`${candidate.book !== null ? candidate.book.name : ''} · ${candidate.chapterCount}章`)
                  .fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 3 }).maxLines(1)
                Text(candidate.book !== null ? candidate.book.author : '')
                  .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 2 }).maxLines(1)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Text('详情').fontSize(LABEL_SMALL).fontColor(this.themeColorAccent)
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .onClick(() => this.openCandidateDetail(candidate))
            }.width('100%').padding(12)
              .backgroundColor(this.otherSourceCandidateSelected(index) ? this.themeColorSurfaceElevated : this.rowBackground())
              .borderRadius(12)
              .onClick(() => this.selectCandidate(this.otherSourceBookUrl, index))
          }, (candidate: ChangeSourceCandidate, index: number) => candidate.sourceUrl + '#' + index)
        }.width('100%')
      }.width('100%').height(280).scrollBar(BarState.Off)
    }.width('100%').padding({ top: 12 })
  }

  /** G-11：当前「其它源信息」面板对应的候选列表。 */
  private otherSourceCandidates(): ChangeSourceCandidate[] {
    for (let index = 0; index < this.preview.length; index++) {
      const item = this.preview[index];
      if (item !== undefined && item.bookUrl === this.otherSourceBookUrl) { return item.candidates; }
    }
    return [];
  }

  /** G-11：某候选是否是当前选中项（上游 `index == selectedCandidateIndex`）。 */
  private otherSourceCandidateSelected(index: number): boolean {
    for (let i = 0; i < this.preview.length; i++) {
      const item = this.preview[i];
      if (item !== undefined && item.bookUrl === this.otherSourceBookUrl) {
        return item.selectedCandidateIndex === index;
      }
    }
    return false;
  }

  /**
   * G-7：候选详情（上游 `OtherSourceOptionsSheet` 的 `trailingAction` →
   * `onOpenBook(candidate.book)`，`BookshelfManageScreen.kt:1753`）。
   * 打开的是候选书的详情页，`inBookshelf = false`——它还没进书架。
   */
  private openCandidateDetail(candidate: ChangeSourceCandidate): void {
    if (candidate.book === null) {
      this.message = '该候选没有可用的详情地址';
      return;
    }
    this.onOpenPreviewBook(candidate.book, false);
  }

  @Builder
  private ResultStep() {
    Column() {
      if (this.running) {
        Row() {
          Text('正在逐本换源…').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
        }.width('100%').justifyContent(FlexAlign.Center).padding(24)
      } else {
        Text(`成功 ${this.result.succeeded} 本 · 失败 ${this.result.failed} 本 · 跳过 ${this.result.skipped} 本`)
          .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).width('100%')
          .margin({ top: 12, bottom: 8 })
        Text('失败的书保持原源与阅读进度不变').fontSize(LABEL_SMALL)
          .fontColor(this.themeColorTextTertiary).width('100%')
      }
      Blank()
    }.width('100%').layoutWeight(1)
  }

  @Builder
  private BottomBar() {
    Row() {
      if (this.step > 0 && this.step < 3) {
        Text('上一步').fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary)
          .padding({ left: 20, right: 20, top: 12, bottom: 12 })
          .onClick(() => {
            if (this.previewing) { return; }
            this.step = this.step - 1;
            this.message = '';
          })
      }
      if (this.step === 2 && this.previewing) {
        Text('取消').fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary)
          .padding({ left: 20, right: 20, top: 12, bottom: 12 })
          .onClick(() => { this.cancelled = true; })
      }
      Blank()
      if (this.step === 0) {
        // G-2：选源步骤的「确认」由 `BookSourcePickerSheet` 自己的按钮承担
        // （上游 `MediumTonalButton(icon = PlayArrow, contentDescription = ok)`），
        // 底栏不再重复放「下一步」。
        Blank()
      } else if (this.step === 1) {
        // G-6：选项步骤的「取消 / 确认」由 `ChangeSourceMigrationOptionsSheet` 自己的按钮承担
        // （上游 `ConfirmDismissButtonsRow`），底栏不再重复放「开始预览」。
        Blank()
      } else if (this.step === 2 && !this.previewing) {
        Text('执行换源').fontSize(LABEL_LARGE).fontColor('#FFFFFF')
          .backgroundColor(this.matchedCount() > 0 ? this.themeColorAccent : '#8A8D99')
          .borderRadius(10).padding({ left: 24, right: 24, top: 12, bottom: 12 })
          .onClick(() => {
            if (this.matchedCount() === 0) { this.message = '没有可执行的书籍'; return; }
            this.runExecute();
          })
      } else if (this.step === 3 && !this.running) {
        Text('完成').fontSize(LABEL_LARGE).fontColor('#FFFFFF')
          .backgroundColor(this.themeColorAccent).borderRadius(10)
          .padding({ left: 24, right: 24, top: 12, bottom: 12 })
          .onClick(() => this.onClose())
      }
    }.width('100%').margin({ top: 8 })
  }

  build() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor(this.themePureBlack ? '#99000000' : '#66000000')
        .onClick(() => this.onClose())

      Column() {
        this.StepHeader()
        if (this.step === 0) {
          this.SourceStep()
        } else if (this.step === 1) {
          this.OptionStep()
        } else if (this.step === 2) {
          this.PreviewStep()
        } else {
          this.ResultStep()
        }
        if (this.message.length > 0) {
          Text(this.message).fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary)
            .width('100%').margin({ top: 6, bottom: 6 })
        }
        this.BottomBar()
      }
      .width('100%')
      .height('78%')
      .align(Alignment.Bottom)
      .backgroundColor(this.themePureBlack ? '#121216' : '#F2F3F6')
      .borderRadius({ topLeft: 20, topRight: 20 })
      .padding({ left: 20, right: 20, top: 20, bottom: 24 })
      .onClick((_e: ClickEvent) => { /* 阻止冒泡到遮罩 */ })
    }.width('100%').height('100%')
  }
}
