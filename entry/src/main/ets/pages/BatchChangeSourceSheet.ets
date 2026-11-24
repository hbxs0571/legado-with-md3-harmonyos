// 批量换源向导（批10 :564 :566 :567 :568）。
//
// 为什么做成一个组件而不是三个：上游 BookshelfManageScreen.kt 里「选择目标书源」(BookSourcePickerSheet)
// 「批量换源选项」(ChangeSourceMigrationOptionsSheet)「批量换源预览」(BatchChangePreviewSheet) 是同一流程的
// 三个步骤，拆成三个组件就要在 Index 里维护三份状态与三次跳转，中间任何一步被系统回收就丢上下文。
// 一个组件 + @State step 最省。
//
// 与单本换源的关系：单本用 ChangeSourceSheet（自动搜候选、只换一本），批量用这个（人从列表里挑源 +
// 逐本自动搜 + 先预览再执行）。两者共用 ChangeSourceCoordinator，不共用 UI。
import { Book } from '../model/Book';
import { BookSource } from '../model/BookSource';
import {
  ChangeSourceCandidate, ChangeSourceCoordinator, ChangeSourceMigrationOptions, defaultMigrationOptions
} from '../bookSource/ChangeSourceCoordinator';
import { BookSourceRepository } from '../data/BookSourceRepository';
import { AppGlyph } from '../components/AppGlyph';
import { BookCover } from '../components/BookCover';
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

/** 选源列表的一行。ArkTS 不允许未声明类型的对象字面量，先定接口。 */
interface BatchSourceRow {
  url: string;
  name: string;
  group: string;
  checked: boolean;
}

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

  /** 0 = 选源，1 = 选项，2 = 预览，3 = 执行中/结果。 */
  @State step: number = 0;
  @State sources: BatchSourceRow[] = [];
  @State options: ChangeSourceMigrationOptions = defaultMigrationOptions();
  @State preview: BatchChangeSourcePreviewItem[] = [];
  @State result: BatchChangeSourceResult = { succeeded: 0, failed: 0, skipped: 0 };
  @State loading: boolean = true;
  @State previewing: boolean = false;
  @State previewDone: number = 0;
  @State running: boolean = false;
  @State message: string = '';
  /** G-3：源搜索框（上游 `BookshelfManageScreen.kt:1423-1429` `AppTextField(label=screen)`）。 */
  @State searchKey: string = '';
  /** G-4：已选源拖拽排序时正在拖的 url（上游 ReorderableSelectionItem）。 */
  @State draggingUrl: string = '';
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
    const rows: BatchSourceRow[] = [];
    for (let index = 0; index < all.length; index++) {
      const source: BookSource = all[index];
      if (source === undefined) { continue; }
      if (!source.enabled) { continue; }
      if (source.bookSourceType !== 0) { continue; }
      if (source.bookSourceUrl.length === 0) { continue; }
      rows.push({
        url: source.bookSourceUrl,
        name: source.bookSourceName.length > 0 ? source.bookSourceName : source.bookSourceUrl,
        group: source.bookSourceGroup ?? '',
        checked: false
      });
    }
    this.sources = rows;
    this.loading = false;
    if (rows.length === 0) { this.message = '还没有导入任何启用的文本书源'; }
  }

  private selectedSourceUrls(): string[] {
    const urls: string[] = [];
    for (let index = 0; index < this.sources.length; index++) {
      const row = this.sources[index];
      if (row !== undefined && row.checked) { urls.push(row.url); }
    }
    return urls;
  }

  /** G-3：上游按 bookSourceName / bookSourceGroup / bookSourceUrl 三字段 contains 过滤（:1400-1405）。 */
  private filteredSources(): BatchSourceRow[] {
    const key = this.searchKey.trim();
    if (key.length === 0) { return this.sources; }
    const lower = key.toLowerCase();
    const rows: BatchSourceRow[] = [];
    for (let index = 0; index < this.sources.length; index++) {
      const row = this.sources[index];
      if (row === undefined) { continue; }
      if (row.name.toLowerCase().indexOf(lower) >= 0 ||
        row.group.toLowerCase().indexOf(lower) >= 0 ||
        row.url.toLowerCase().indexOf(lower) >= 0) {
        rows.push(row);
      }
    }
    return rows;
  }

  /** G-4：已选源列表（按已选顺序，可长按拖动排序）。 */
  private selectedRows(): BatchSourceRow[] {
    const rows: BatchSourceRow[] = [];
    for (let index = 0; index < this.sources.length; index++) {
      const row = this.sources[index];
      if (row !== undefined && row.checked) { rows.push(row); }
    }
    return rows;
  }

  /**
   * G-4：把已选源里的 from 位搬到 to 位（上游 `ReorderableSelectionItem` 的
   * `move(from.index, to.index)`）。整表重排后写回，保证「已选顺序 = 预览/执行顺序」。
   */
  private moveSelectedSource(fromUrl: string, toUrl: string): void {
    if (fromUrl === toUrl) { return; }
    const selected = this.selectedRows();
    const fromIndex = selected.findIndex((row: BatchSourceRow) => row.url === fromUrl);
    const toIndex = selected.findIndex((row: BatchSourceRow) => row.url === toUrl);
    if (fromIndex < 0 || toIndex < 0) { return; }
    const moved = selected[fromIndex];
    if (moved === undefined) { return; }
    const rest = selected.filter((row: BatchSourceRow) => row.url !== fromUrl);
    const ordered: BatchSourceRow[] = [];
    for (let index = 0; index < rest.length; index++) {
      const row = rest[index];
      if (row === undefined) { continue; }
      if (index === toIndex) { ordered.push(moved); }
      ordered.push(row);
    }
    if (ordered.length < rest.length + 1) { ordered.push(moved); }
    // 未选中的源保持原相对顺序接在后面。
    const tail = this.sources.filter((row: BatchSourceRow) => !row.checked);
    const next: BatchSourceRow[] = [];
    for (let index = 0; index < ordered.length; index++) {
      const row = ordered[index];
      if (row !== undefined) { next.push(row); }
    }
    for (let index = 0; index < tail.length; index++) {
      const row = tail[index];
      if (row !== undefined) { next.push(row); }
    }
    this.sources = next;
  }

  private toggleSource(url: string, checked: boolean): void {
    const next: BatchSourceRow[] = [];
    for (let index = 0; index < this.sources.length; index++) {
      const row = this.sources[index];
      if (row === undefined) { continue; }
      next.push({ url: row.url, name: row.name, group: row.group, checked: row.url === url ? checked : row.checked });
    }
    this.sources = next;
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
        Text(this.step === 0 ? '选择目标书源' : (this.step === 1 ? '批量换源选项'
          : (this.step === 2 ? '换源预览' : '换源结果')))
          .fontSize(TITLE_LARGE).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Text('✕').fontSize(TITLE_LARGE).fontColor(this.themeColorTextTertiary)
          .onClick(() => this.onClose())
      }.width('100%').padding({ bottom: 12 })
      Text(`已选 ${this.books.length} 本书`).fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary)
        .width('100%').margin({ bottom: 8 })
    }.width('100%')
  }

  @Builder
  private SourceStep() {
    if (this.loading) {
      Row() {
        Text('正在读取书源…').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
      }.width('100%').justifyContent(FlexAlign.Center).padding(24)
    } else {
      Column() {
        // G-3：上游 `AppTextField(value=searchKey, label=screen「筛选」)`（:1423-1429）。
        TextInput({ text: this.searchKey, placeholder: '筛选书源名称 / 分组 / 地址' })
          .height(44).fontSize(BODY_SMALL).width('100%')
          .onChange((value: string) => { this.searchKey = value; })
        Scroll() {
          Column() {
            // G-4：已选源区（上游 :1431-1468，可长按拖动排序，max 280dp）。
            if (this.selectedRows().length > 0) {
              Text('已选书源（长按拖动排序）').fontSize(LABEL_MEDIUM)
                .fontColor(this.themeColorAccent).width('100%').margin({ top: 12, bottom: 8 })
              // G-4：已选源可长按拖拽排序（上游 `ReorderableSelectionItem` 的
              // `rememberReorderableLazyListState` + `move(from.index, to.index)`，
              // `BookshelfManageScreen.kt:1431-1468`）。ArkUI 用 List 的
              // editMode(true) + onItemDragStart/onItemDrop 承载同一交互。
              List({ space: 8 }) {
                ForEach(this.selectedRows(), (row: BatchSourceRow) => {
                  ListItem() {
                    this.SourceRow(row, true)
                  }
                }, (row: BatchSourceRow) => 'sel-' + row.url)
              }.width('100%').height(Math.min(280, this.selectedRows().length * 60))
                .scrollBar(BarState.Off)
                .editMode(true)
                .onItemDragStart((_event: ItemDragInfo, itemIndex: number) => {
                  const rows = this.selectedRows();
                  if (itemIndex >= 0 && itemIndex < rows.length) {
                    const row = rows[itemIndex];
                    this.draggingUrl = row !== undefined ? row.url : '';
                  }
                })
                .onItemDrop((_event: ItemDragInfo, itemIndex: number, insertIndex: number,
                  isSuccess: boolean) => {
                  if (!isSuccess) { this.draggingUrl = ''; return; }
                  const rows = this.selectedRows();
                  if (itemIndex < 0 || itemIndex >= rows.length ||
                    insertIndex < 0 || insertIndex >= rows.length) {
                    this.draggingUrl = '';
                    return;
                  }
                  const from = rows[itemIndex];
                  const to = rows[insertIndex];
                  if (from !== undefined && to !== undefined) {
                    this.moveSelectedSource(from.url, to.url);
                  }
                  this.draggingUrl = '';
                })
            }
            // G-5：可选源列表（上游 :1470-1491，max 560dp + spacedBy(8.dp)）。
            Text('可选书源').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
              .width('100%').margin({ top: 12, bottom: 8 })
            ForEach(this.filteredSources(), (row: BatchSourceRow) => {
              if (!row.checked) {
                this.SourceRow(row, false)
              }
            }, (row: BatchSourceRow) => 'avail-' + row.url)
          }.width('100%')
        }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
      }.width('100%').layoutWeight(1)
    }
  }

  /** 选源行：勾选框 + 名称 + 分组/地址；已选态显示拖拽把手提示（G-4）。 */
  @Builder
  private SourceRow(row: BatchSourceRow, selected: boolean) {
    Row() {
      Column() {
        Text(row.name).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).maxLines(1)
        Text(row.group.length > 0 ? row.group : row.url)
          .fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 3 }).maxLines(1)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      if (selected) {
        // 上游 ReorderableSelectionItem 的拖拽把手（长按可拖）。
        AppGlyph({ name: 'unfoldMore', glyphSize: 16, tint: this.themeColorTextTertiary })
          .margin({ right: 8 })
      }
      Toggle({ type: ToggleType.Checkbox, isOn: selected })
        .onChange((value: boolean) => this.toggleSource(row.url, value))
    }.width('100%').padding(12).backgroundColor(this.rowBackground()).borderRadius(12).margin({ bottom: 8 })
  }

  @Builder
  private OptionStep() {
    Column() {
      // :568：选项逐项对应 ChangeSourceMigrationOptions 的两个字段，不自造字段。
      Row() {
        Text('迁移阅读进度').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Toggle({ type: ToggleType.Checkbox, isOn: this.options.migrateProgress })
          .onChange((value: boolean) => {
            this.options = { migrateProgress: value, migrateMetadata: this.options.migrateMetadata };
          })
      }.width('100%').padding({ top: 10, bottom: 10 })
      Row() {
        Text('迁移封面与简介').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Toggle({ type: ToggleType.Checkbox, isOn: this.options.migrateMetadata })
          .onChange((value: boolean) => {
            this.options = { migrateProgress: this.options.migrateProgress, migrateMetadata: value };
          })
      }.width('100%').padding({ top: 10, bottom: 10 })
      Text('选项只对本次批量换源生效').fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary)
        .width('100%').margin({ top: 8 })
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
                this.PreviewActionButton('搜索', () => { this.message = '手动搜索暂未接入'; })
                this.PreviewActionButton('不迁移', () => this.skipPreviewItem(item.bookUrl))
                this.PreviewActionButton('迁移', () => {
                  if (item.status === BATCH_PREVIEW_MATCHED) { this.runExecute(); }
                })
                this.PreviewActionButton('新增', () => { this.message = '新增到书架暂未接入'; })
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
                .onClick(() => { this.message = '候选详情暂未接入'; })
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
        Text('下一步').fontSize(LABEL_LARGE).fontColor('#FFFFFF')
          .backgroundColor(this.selectedSourceUrls().length > 0 ? this.themeColorAccent : '#8A8D99')
          .borderRadius(10).padding({ left: 24, right: 24, top: 12, bottom: 12 })
          .onClick(() => {
            if (this.selectedSourceUrls().length === 0) { this.message = '请至少选择一个目标书源'; return; }
            this.step = 1;
            this.message = '';
          })
      } else if (this.step === 1) {
        Text('开始预览').fontSize(LABEL_LARGE).fontColor('#FFFFFF')
          .backgroundColor(this.themeColorAccent).borderRadius(10)
          .padding({ left: 24, right: 24, top: 12, bottom: 12 })
          .onClick(() => this.runPreview())
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
