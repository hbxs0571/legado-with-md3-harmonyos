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
        newSourceName: '', chapterCount: 0, status: BATCH_PREVIEW_SKIPPED, candidate: null
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
    let picked: ChangeSourceCandidate | null = null;
    for (let index = 0; index < candidates.length; index++) {
      const candidate = candidates[index];
      if (candidate === undefined) { continue; }
      if (!candidate.verified) { continue; }
      if (sourceUrls.indexOf(candidate.sourceUrl) < 0) { continue; }
      // searchCandidates 已按「校验通过 + 章节数多」排好序，第一条就是最优。
      picked = candidate;
      break;
    }
    if (picked === null) {
      return {
        bookUrl: book.contentPath ?? book.id, title: book.title, oldSourceName: oldName,
        newSourceName: '', chapterCount: 0, status: BATCH_PREVIEW_NOT_FOUND, candidate: null
      };
    }
    return {
      bookUrl: book.contentPath ?? book.id, title: book.title, oldSourceName: oldName,
      newSourceName: picked.sourceName, chapterCount: picked.chapterCount,
      status: BATCH_PREVIEW_MATCHED, candidate: picked
    };
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

  private statusText(item: BatchChangeSourcePreviewItem): string {
    if (item.status === BATCH_PREVIEW_SKIPPED) { return '本地书，跳过'; }
    if (item.status === BATCH_PREVIEW_NOT_FOUND) { return '未找到可用候选源'; }
    return `${item.oldSourceName.length > 0 ? item.oldSourceName : '原源'} → ${item.newSourceName} · ${item.chapterCount} 章`;
  }

  private rowBackground(): string {
    return this.themePureBlack ? '#1E1F26' : this.themeColorSurfaceElevated;
  }

  @Builder
  private StepHeader() {
    Row() {
      Text(this.step === 0 ? '选择目标书源' : (this.step === 1 ? '批量换源选项'
        : (this.step === 2 ? '换源预览' : '换源结果')))
        .fontSize(TITLE_LARGE).fontColor(this.themeColorTextPrimary).layoutWeight(1)
      Text('✕').fontSize(TITLE_LARGE).fontColor(this.themeColorTextTertiary)
        .onClick(() => this.onClose())
    }.width('100%').padding({ bottom: 12 })
    Text(`已选 ${this.books.length} 本书`).fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary)
      .width('100%').margin({ bottom: 8 })
  }

  @Builder
  private SourceStep() {
    if (this.loading) {
      Row() {
        Text('正在读取书源…').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
      }.width('100%').justifyContent(FlexAlign.Center).padding(24)
    } else {
      Scroll() {
        Column() {
          ForEach(this.sources, (item: BatchSourceRow) => {
            Row() {
              Column() {
                Text(item.name).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).maxLines(1)
                Text(item.group.length > 0 ? item.group : item.url)
                  .fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 3 }).maxLines(1)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Toggle({ type: ToggleType.Checkbox, isOn: item.checked })
                .onChange((value: boolean) => this.toggleSource(item.url, value))
            }.width('100%').padding(12).backgroundColor(this.rowBackground()).borderRadius(12).margin({ bottom: 8 })
          }, (item: BatchSourceRow) => item.url)
        }.width('100%')
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
    }
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
      Scroll() {
        Column() {
          ForEach(this.preview, (item: BatchChangeSourcePreviewItem) => {
            Column() {
              Text(item.title).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).maxLines(1)
              Text(this.statusText(item)).fontSize(LABEL_SMALL)
                .fontColor(item.status === BATCH_PREVIEW_MATCHED
                  ? this.themeColorAccent : this.themeColorTextTertiary)
                .margin({ top: 4 }).maxLines(2)
            }.width('100%').alignItems(HorizontalAlign.Start)
              .padding(12).backgroundColor(this.rowBackground()).borderRadius(12).margin({ bottom: 8 })
          }, (item: BatchChangeSourcePreviewItem) => item.bookUrl)
        }.width('100%')
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').layoutWeight(1)
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
