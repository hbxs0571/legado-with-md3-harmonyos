/**
 * 目录规则预览页，对齐上游 `ui/book/toc/rule/preview/TxtTocRulePreviewScreen.kt`。
 *
 * 上游从目录页菜单进「选择目录规则」，每张卡片右下角显示这条规则能把当前书切成多少章，
 * 点开卡片能看到前 500 章标题，选好直接应用（写回 book.tocUrl 并重切目录）。
 * 本地此前只有规则管理页（增删改查 + 单条正则测试），看不到「这条规则对这本书切出什么」，
 * 用户只能保存后回目录页试，试错成本高。
 *
 * 与上游的三处形态差异（写进 docs/parity/TXT-READER.md 的差异说明）：
 * 1. 上游卡片计数是异步逐条算、未算出时显示进度圈；本地保留同样的 `-1 = 未算出` 占位与进度圈，
 *    但整批扫描一次性交给 taskpool worker（见 `TocRulePreviewEngine`），主线程只等结果。
 * 2. 上游编辑规则走独立 `RuleEditSheet`；本地复用规则管理页的编辑面板，这里只提供跳转。
 * 3. 上游应用规则走 `BookPageResult` 回传到目录页；本地直接在当前页回写并重切。
 */
import { AppGlyph } from '../components/AppGlyph';
import { Book } from '../model/Book';
import { TxtTocRule } from '../model/TxtTocRule';
import { BookRepository } from '../data/BookRepository';
import { TxtTocRuleRepository } from '../data/TxtTocRuleRepository';
import { TocRulePreviewEngine } from '../data/TocRulePreviewEngine';

/** 一条规则的预览条目：`totalCount < 0` 表示还没算出来。 */
interface TocRulePreviewItem {
  rule: TxtTocRule;
  totalCount: number;
  chapterTitles: string[];
}

@Component
export struct TxtTocRulePreviewPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop book: Book = {
    id: '', title: '', author: '', category: '', lastChapter: '', progress: 0, isLocal: true
  };
  onBack: () => void = () => {};
  /** 应用选中的规则：由 Index 负责落库并重切目录。 */
  onApplyRule: (chapterRule: string, ruleName: string) => Promise<void> = async (_rule: string, _name: string) => {};
  /** 跳到规则管理页；上游这里是顶栏第三个按钮（设置图标）。 */
  onOpenManagePage: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};

  @State items: TocRulePreviewItem[] = [];
  @State loading: boolean = true;
  /** 网格 / 列表；默认网格，与上游 `isGridLayout = true` 同。 */
  @State gridLayout: boolean = true;
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  /** 当前书已固定的章节正则，用于卡片选中描边。 */
  @State currentRule: string = '';
  /** 正在应用规则，防重入。 */
  @State applying: boolean = false;

  /** 当前打开的章节列表面板对应的规则名；空串表示未打开。 */
  @State sheetRuleName: string = '';
  @State sheetChapterTitles: string[] = [];
  @State sheetTotalCount: number = 0;

  aboutToAppear(): void {
    this.currentRule = this.book.tocRule ?? '';
    this.loadItems();
  }

  /** 读整本正文 → 交给 worker 逐条规则扫，算出「这条规则能切出几章」。 */
  private loadItems(): void {
    this.loading = true;
    const rules = TxtTocRuleRepository.getAll()
      .filter((rule: TxtTocRule) => rule.chapterRule.trim().length > 0);
    // 先把所有规则以 -1 占位放进列表，让列表立刻能画出来；
    // 上游 `loadRules` 同样先铺 totalCount = -1，再在后台逐条 replace。
    this.items = rules.map((rule: TxtTocRule): TocRulePreviewItem => {
      return { rule: rule, totalCount: -1, chapterTitles: [] };
    });
    this.loading = false;
    const contentPath = this.book.contentPath ?? '';
    if (this.book.format !== 'txt' || !this.book.isLocal || contentPath.length === 0) {
      // 非本地 TXT 时卡片全部显示 0 章，与上游 book == null 一致。
      this.items = this.items.map((item: TocRulePreviewItem): TocRulePreviewItem => {
        return { rule: item.rule, totalCount: 0, chapterTitles: [] };
      });
      return;
    }
    this.runPreviewScan(contentPath, this.book.charset ?? 'utf-8', rules);
  }

  /**
   * 几十条规则 × 整本正文的扫描放到 taskpool worker 里，主线程只等结果。
   *
   * 早先的实现是在主线程分帧扫（每条规则按行切片、`setTimeout` 让下一片），
   * 一本 3MB 的书 × 27 条规则仍然把主线程占满，被 watchdog 判成 THREAD_BLOCK_6S。
   * worker 侧自己读文件解码，正文不进任务参数。
   */
  private async runPreviewScan(path: string, encoding: string, rules: TxtTocRule[]): Promise<void> {
    const patterns: string[] = rules.map((rule: TxtTocRule) => rule.chapterRule);
    const counts = await TocRulePreviewEngine.scan(path, encoding, patterns);
    if (counts.length !== rules.length) {
      // worker 起不来时全部显示 0 章，而不是一直转圈。
      this.items = this.items.map((item: TocRulePreviewItem): TocRulePreviewItem => {
        return { rule: item.rule, totalCount: 0, chapterTitles: [] };
      });
      return;
    }
    this.items = rules.map((rule: TxtTocRule, index: number): TocRulePreviewItem => {
      const count = counts[index];
      return {
        rule: rule,
        totalCount: count !== undefined ? count.totalCount : 0,
        chapterTitles: count !== undefined ? count.chapterTitles : []
      };
    });
  }

  /** 按搜索词过滤后的规则列表，口径同上游 `filteredRules`。 */
  private visibleItems(): TocRulePreviewItem[] {
    const keyword = this.searchQuery.trim().toLowerCase();
    if (keyword.length === 0) {
      return this.items;
    }
    return this.items.filter((item: TocRulePreviewItem) => {
      if (item.rule.name.toLowerCase().includes(keyword)) {
        return true;
      }
      const example = (item.rule.example ?? '').toLowerCase();
      return example.includes(keyword);
    });
  }

  /** 卡片选中描边：这条规则就是当前书正在用的那条。 */
  private isSelected(item: TocRulePreviewItem): boolean {
    return item.rule.chapterRule === this.currentRule && this.currentRule.length > 0;
  }

  /** 打开章节列表面板，对齐上游点卡片后的 `ShowChapterList`。 */
  private openChapterSheet(item: TocRulePreviewItem): void {
    this.sheetRuleName = item.rule.name;
    this.sheetChapterTitles = item.chapterTitles;
    this.sheetTotalCount = item.totalCount < 0 ? 0 : item.totalCount;
    this.applySelectedRule(item.rule);
  }

  private async applySelectedRule(rule: TxtTocRule): Promise<void> {
    if (this.applying) {
      return;
    }
    this.currentRule = rule.chapterRule;
  }

  /** 点面板里的「应用」：把这条规则交给 Index 落库并重切目录。 */
  private async applyRule(rule: TxtTocRule): Promise<void> {
    if (this.applying) {
      return;
    }
    this.applying = true;
    try {
      await this.onApplyRule(rule.chapterRule, rule.name);
    } finally {
      this.applying = false;
      this.sheetRuleName = '';
    }
  }

  @Builder
  private TopBar() {
    Column() {
      Row() {
        Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.themeColorTextSecondary)
          .width(36).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        AppGlyph({ name: 'search', glyphSize: 19, tint: this.themeColorTextSecondary })
          .padding({ left: 8, right: 8 })
          .onClick(() => {
            this.showSearch = !this.showSearch;
            if (!this.showSearch) { this.searchQuery = ''; }
          })
        AppGlyph({ name: this.gridLayout ? 'list' : 'profileRule', glyphSize: 19,
          tint: this.themeColorTextSecondary })
          .padding({ left: 6, right: 6 })
          .onClick(() => this.gridLayout = !this.gridLayout)
        AppGlyph({ name: 'settings', glyphSize: 19, tint: this.themeColorTextSecondary })
          .padding({ left: 6, right: 8 })
          .onClick(() => this.onOpenManagePage())
      }.width('100%').height(40).padding({ left: 18, right: 18 })
      Column() {
        Text('选择目录规则').fontSize(24).fontWeight(FontWeight.Bold)
          .fontColor(this.themeColorTextPrimary).width('100%')
        Text('选择规则预览章节').fontSize(13).fontColor(this.themeColorTextTertiary)
          .width('100%').margin({ top: 4 })
      }.width('100%').padding({ left: 18, right: 18, top: 8, bottom: 10 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '搜索目录规则', text: this.searchQuery })
            .fontSize(14).fontColor(this.themeColorTextSecondary).placeholderColor(this.themeColorTextTertiary)
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .id('txt_toc_preview_search')
            .onAppear(() => focusControl.requestFocus('txt_toc_preview_search'))
            .onChange((value: string) => this.searchQuery = value)
        }.width('calc(100% - 32vp)').height(48).padding({ left: 14, right: 14 })
          .margin({ left: 16, right: 16, top: 4, bottom: 6 })
          .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent
            : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary))
          .borderRadius(24)
      }
    }.width('100%')
  }

  /**
   * 计数徽章：`totalCount < 0` 时显示进度圈，否则显示「N 章」。
   * 徽章样式对齐上游 `Surface(RoundedCornerShape(12.dp), primaryContainer α0.85)`。
   */
  @Builder
  private CountBadge(totalCount: number) {
    Row() {
      if (totalCount < 0) {
        LoadingProgress().width(12).height(12).color(this.themeColorAccent)
      } else {
        Text(`${totalCount} 章`).fontSize(11).fontColor('#1B1C22')
      }
    }
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor('#D6DEF8').borderRadius(12)
  }

  /**
   * 网格卡片，对齐上游 `RulePreviewCard`：
   * 名字两行、示例两行、右下角计数徽章；选中 1.5vp 强调色描边。
   */
  @Builder
  private RuleCard(item: TocRulePreviewItem) {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        Text(item.rule.name).fontSize(14).fontWeight(FontWeight.Medium)
          .fontColor(this.themeColorTextPrimary).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if ((item.rule.example ?? '').length > 0) {
          Text(item.rule.example ?? '').fontSize(11).fontColor(this.themeColorTextTertiary)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%').margin({ top: 4 })
        }
      }.width('100%').alignItems(HorizontalAlign.Start)
        // 底部留出徽章高度，避免示例文字被徽章压住（上游 padding(bottom = 28.dp)）。
        .padding({ left: 12, right: 12, top: 12, bottom: 40 })
      Row() {
        this.CountBadge(item.totalCount);
      }.margin({ right: 8, bottom: 8 })
    }
      .width('100%').height(120)
      .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : this.themeColorSurfaceElevated)
      .borderRadius(16)
      .border({
        width: this.isSelected(item) ? 1.5 : 0.5,
        color: this.isSelected(item) ? this.themeColorAccent : '#00000000'
      })
      .onClick(() => this.openChapterSheet(item))
  }

  /** 列表行，对齐上游 `RulePreviewListItem`：名字一行 + 示例一行 + 右侧计数徽章。 */
  @Builder
  private RuleRow(item: TocRulePreviewItem) {
    Row() {
      Column() {
        Text(item.rule.name).fontSize(15).fontColor(this.themeColorTextPrimary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        if ((item.rule.example ?? '').length > 0) {
          Text(item.rule.example ?? '').fontSize(11).fontColor(this.themeColorTextTertiary)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%').margin({ top: 2 })
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Row() {
        this.CountBadge(item.totalCount);
      }.margin({ left: 12 })
    }
      .width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : this.themeColorSurfaceElevated)
      .borderRadius(12)
      .border({
        width: this.isSelected(item) ? 1.5 : 0.5,
        color: this.isSelected(item) ? this.themeColorAccent : '#00000000'
      })
      .onClick(() => this.openChapterSheet(item))
  }

  /** 章节列表面板：标题是规则名，列表最多 500 章，底部给「应用」。 */
  @Builder
  private ChapterListSheet() {
    Column() {
      Text(this.sheetRuleName).fontSize(18).fontWeight(FontWeight.Medium)
        .fontColor(this.themeColorTextPrimary).width('100%')
        .padding({ left: 18, right: 18, top: 16, bottom: 6 })
      Text(`${this.sheetTotalCount} 章`).fontSize(13).fontColor(this.themeColorTextTertiary)
        .width('100%').padding({ left: 18, right: 18, bottom: 10 })
      List() {
        ForEach(this.sheetChapterTitles, (title: string, index: number) => {
          ListItem() {
            Text(title).fontSize(14).fontColor(this.themeColorTextSecondary)
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%').padding({ left: 18, right: 18, top: 8, bottom: 8 })
          }
        }, (title: string, index: number) => `${index}-${title}`)
        if (this.sheetChapterTitles.length >= BookRepository.previewChapterLimit) {
          ListItem() {
            Text('仅预览前 500 章').fontSize(12).fontColor(this.themeColorTextTertiary)
              .width('100%').padding({ left: 18, right: 18, top: 8, bottom: 8 })
          }
        }
      }.layoutWeight(1).width('100%')
      Row() {
        Text('取消').fontSize(15).fontColor(this.themeColorTextTertiary).layoutWeight(1)
          .textAlign(TextAlign.Center).padding({ top: 14, bottom: 14 })
          .onClick(() => this.sheetRuleName = '')
        Text(this.applying ? '应用中…' : '应用').fontSize(15)
          .fontColor(this.applying ? this.themeColorTextTertiary : this.themeColorAccent)
          .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 14, bottom: 14 })
          .onClick(() => {
            const matched = this.items.find((item: TocRulePreviewItem) =>
              item.rule.name === this.sheetRuleName);
            if (matched !== undefined) {
              this.applyRule(matched.rule);
            }
          })
      }.width('100%').padding({ left: 8, right: 8, bottom: 12 })
    }.width('100%').height('100%').alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      this.TopBar();
      if (this.loading) {
        Column() {
          LoadingProgress().width(32).height(32).color(this.themeColorAccent)
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.visibleItems().length === 0) {
        Column() {
          Text('没有匹配的目录规则').fontSize(14).fontColor(this.themeColorTextTertiary)
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.gridLayout) {
        Grid() {
          ForEach(this.visibleItems(), (item: TocRulePreviewItem) => {
            GridItem() {
              this.RuleCard(item);
            }
          }, (item: TocRulePreviewItem) => `${item.rule.id}-${item.totalCount}`)
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(8)
        .rowsGap(8)
        .padding({ left: 16, right: 16, top: 4, bottom: 16 })
        .layoutWeight(1)
        .width('100%')
      } else {
        List({ space: 4 }) {
          ForEach(this.visibleItems(), (item: TocRulePreviewItem) => {
            ListItem() {
              this.RuleRow(item);
            }
          }, (item: TocRulePreviewItem) => `${item.rule.id}-${item.totalCount}`)
        }
        .listDirection(Axis.Vertical)
        .padding({ left: 16, right: 16, top: 4, bottom: 16 })
        .layoutWeight(1)
        .width('100%')
      }
    }
      .width('100%').height('100%')
      .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent
        : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      .bindSheet(this.sheetRuleName.length > 0, this.ChapterListSheet(), {
        height: 520,
        dragBar: true,
        showClose: false,
        backgroundColor: this.themeColorSurfaceElevated,
        onDisappear: () => this.sheetRuleName = ''
      })
  }
}
