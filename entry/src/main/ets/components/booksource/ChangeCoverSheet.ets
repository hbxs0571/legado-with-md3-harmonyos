// 换封面面板（第九表 B-9 / 第八表 H2-1）：对齐上游 `ui/book/info/BookInfoSheets.kt:194-272 ChangeCoverSheet`。
//
// 上游要点（逐项对齐）：
//   1. `AppModalBottomSheet(title = change_cover_source「封面换源」, endAction = MediumTonalButton(...))`：
//      右侧按钮搜索中是 MoreVert（more_menu），空闲是 Refresh（refresh），点击在「开始搜索 / 停止搜索」间切换。
//   2. 搜索中在标题下加一条 `AppLinearProgressIndicator(fillMaxWidth())` + `Spacer(12.dp)`。
//   3. `LazyVerticalGrid(columns = Fixed(3), horizontalArrangement = spacedBy(12.dp), verticalArrangement = spacedBy(12.dp))`，
//      每项 `Column(clip(RoundedCornerShape(4.dp)).clickable { onSelect(item.coverUrl.orEmpty()) }.padding(8.dp), spacedBy(4.dp))`，
//      内部 `CoilBookCover(Modifier.width(112.dp).aspectRatio(5f/7f))` + `AppText(item.originName, labelSmallEmphasized, maxLines = 2)`。
//   4. `DisposableEffect(show) { onDispose { viewModel.stopSearch() } }`：面板关闭即停搜。
//   5. 只有 `show = true` 才收集数据流自动搜索（否则每次进编辑页都会触发全部书源搜索）。
//
// 本地落点：BookInfoPage（详情页换封面）与 BookInfoEditPage（编辑页换封面）共用本组件，
// 搜索逻辑走 `ChangeCoverCoordinator.searchCovers`（并发 8、首项固定「默认封面」）。
import { ChangeCoverCandidate, ChangeCoverCoordinator, CHANGE_COVER_DEFAULT_URL } from '../../bookSource/ChangeCoverCoordinator';
import { BUILTIN_DEFAULT_COVER, CoverAlbumRepository } from '../../data/CoverAlbumRepository';
import { CoverSettings, DEFAULT_COVER_SETTINGS } from '../../data/CoverSettingsRepository';
import { Book } from '../../model/Book';
import { BookCover } from '../BookCover';
import { realAuthorOf } from '../../data/BookExportSettings';
import { AppGlyph } from '../AppGlyph';
import { BODY_MEDIUM, LABEL_SMALL, TITLE_LARGE } from '../typography/TypographyTokens';

/** 网格列间距 / 行间距，上游 `spacedBy(12.dp)`。 */
const GRID_GAP: number = 12;
/** 封面卡片内边距，上游 `padding(8.dp)`。 */
const CARD_PADDING: number = 8;
/** 封面卡片圆角，上游 `RoundedCornerShape(4.dp)`。 */
const CARD_RADIUS: number = 4;
/** 标题行底部留白，上游 `padding(bottom = 12.dp)`。 */
const HEADER_BOTTOM: number = 12;
/** 进度条高度，上游 `AppLinearProgressIndicator` 默认 4dp。 */
const PROGRESS_HEIGHT: number = 4;
/** 右上按钮命中区 40×40，对齐上游 `MediumTonalButton`（`MediumSeriesIconButtonSize = DpSize(40.dp, 40.dp)`）。 */
const ACTION_SIZE: number = 40;
/**
 * 候选网格最大高度（vp）。
 *
 * 上游 `LazyVerticalGrid` 放在 `AppModalBottomSheet` 里是**按内容撑开**的，
 * 面板本身限制在半屏内、超出才滚动（`AppModalBottomSheet.kt` 用 `SheetDefaults` 的
 * `skipPartiallyExpanded = false` 语义，展开态约半屏）。
 * 本地两个宿主都没有确定高度（详情页 `SheetSize.FIT_CONTENT`、编辑页自绘浮层），
 * 所以这里给一个上限自己约束，而不是靠父容器分配。
 */
const COVER_GRID_MAX_HEIGHT: number = 420;
/**
 * 候选封面宽高（vp）。
 *
 * 上游 `CoilBookCover(Modifier.width(112.dp).aspectRatio(5f / 7f))` —— 宽固定 112、高按 5:7 推。
 * 本地 `BookCover` 接的是显式宽高，这里按同一比例算好传进去（112 × 7 / 5 = 156.8 → 157）。
 */
const COVER_WIDTH_VP: number = 112;
const COVER_HEIGHT_VP: number = 157;

/**
 * 换封面面板内容。
 *
 * 只负责「画 + 搜索 + 选中回调」，面板容器（bottom sheet 外壳）由调用方提供：
 * 上游 `AppModalBottomSheet` 在本地对应 `ReaderSheetShell` / 页面自绘 sheet，
 * 两个调用页各自已有外壳，组件本身不再套一层。
 */
@Component
export struct ChangeCoverSheet {
  /** 书名（搜索关键词左半），上游 `name`。 */
  @Prop bookName: string = '';
  /** 作者（搜索关键词右半，会先去掉「作者：」前缀），上游 `author`。 */
  @Prop author: string = '';
  /** 夜间模式，用于内置默认封面的取色。 */
  @Prop isNight: boolean = false;
  /**
   * 封面文字/默认封面设置，透传给 `BookCover`。
   *
   * 上游换封面网格里的 `CoilBookCover` 读的是 `LocalAppUiConfiguration.current.cover`，
   * 与书架、详情页同一份配置；本地对应 `CoverSettingsRepository.get()`，由调用页传下来。
   */
  @Prop coverSettings: CoverSettings = DEFAULT_COVER_SETTINGS;
  /** 选中封面回调；默认封面项传回 `CHANGE_COVER_DEFAULT_URL`。 */
  onSelect: (coverUrl: string) => void = () => {};
  /** 搜索失败时提示，上游走 `AppLog` + toast，本地交给调用方的统一提示。 */
  onMessage: (message: string) => void = () => {};

  @StorageProp('themeColorTextPrimary') private themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') private themeColorTextSecondary: string = '#4A4C55';
  @StorageProp('themeColorAccent') private themeColorAccent: string = '#3F5BD9';

  @State private candidates: ChangeCoverCandidate[] = [];
  @State private searching: boolean = false;

  /** 搜索令牌：自增即作废在途结果，等价上游 `stopSearch()` 的协程取消。 */
  private searchToken: number = 0;

  aboutToAppear(): void {
    // 上游只有 `show = true` 才自动搜索；本组件只在面板可见时被挂载，因此直接开搜。
    this.runSearch();
  }

  aboutToDisappear(): void {
    // 上游 `DisposableEffect(show) { onDispose { viewModel.stopSearch() } }`：关闭即停搜。
    this.searchToken += 1;
    this.searching = false;
  }

  /** 开始搜索；搜索中再点即停止（上游 `startOrStopSearch`）。 */
  private runSearch(): void {
    if (this.searching) {
      this.searchToken += 1;
      this.searching = false;
      return;
    }
    this.searchToken += 1;
    const token = this.searchToken;
    this.searching = true;
    this.candidates = [];
    const name = this.bookName;
    const author = realAuthorOf(this.author);
    // 流式回填：上游 `ChangeCoverViewModel.kt:65-72` 每搜到一本就 trySend 一次，
    // 界面立刻长出一项；本地书源数百个，等全部跑完才显示要几分钟。
    ChangeCoverCoordinator.searchCovers(name, author, (list: ChangeCoverCandidate[]) => {
      if (token !== this.searchToken) { return; }
      this.candidates = list;
    })
      .then((list: ChangeCoverCandidate[]) => {
        if (token !== this.searchToken) { return; }
        this.candidates = list;
        this.searching = false;
      })
      .catch(() => {
        if (token !== this.searchToken) { return; }
        this.searching = false;
        this.onMessage('封面搜索失败');
      });
  }

  /** 选中一项：默认封面走内置封面，其余直接回传 coverUrl（上游 `onSelect(item.coverUrl.orEmpty())`）。 */
  private choose(coverUrl: string): void {
    this.searchToken += 1;
    this.searching = false;
    this.onSelect(coverUrl);
  }

  /**
   * 把候选包成一个 `Book` 交给 `BookCover` 渲染。
   *
   * 上游 `CoilBookCover(name = item.name, author = item.author, path = item.coverUrl)` 只需要这三样；
   * 本地 `BookCover` 读的是 `Book`，所以造一个最小书对象。
   * 「默认封面」项的 `coverUrl` 是 `use_default_cover` 哨兵，`BookCover.effectiveCoverUri`
   * 已经认识它（走相册内置封面、池空回落书本图标 + 书名），不需要在这里替换成别的地址。
   */
  private candidateBook(candidate: ChangeCoverCandidate): Book {
    return {
      id: '',
      title: this.bookName,
      author: this.author,
      category: '',
      lastChapter: '',
      progress: 0,
      isLocal: false,
      coverUri: candidate.coverUrl
    };
  }

  build() {
    Column() {
      Row() {
        Text('封面换源').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium)
          .fontColor(this.themeColorTextPrimary).layoutWeight(1)
        // 上游 endAction：搜索中是 MoreVert（more_menu），空闲是 Refresh（refresh）。
        Row() {
          AppGlyph({
            name: this.searching ? 'more' : 'profileRefresh',
            glyphSize: 20, tint: this.themeColorTextPrimary
          })
        }
          .width(ACTION_SIZE).height(ACTION_SIZE).justifyContent(FlexAlign.Center)
          .accessibilityText(this.searching ? '更多菜单' : '重新搜索')
          .onClick(() => this.runSearch())
      }.width('100%').padding({ bottom: HEADER_BOTTOM })

      if (this.searching) {
        // 上游 `AppLinearProgressIndicator(Modifier.fillMaxWidth())` + `Spacer(12.dp)`。
        Progress({ value: 50, total: 100, type: ProgressType.Linear })
          .width('100%').height(PROGRESS_HEIGHT).color(this.themeColorAccent)
        Blank().height(HEADER_BOTTOM)
      }

      if (this.candidates.length === 0) {
        Text(this.searching ? '正在搜索封面…' : '没有搜到可用封面')
          .fontSize(BODY_MEDIUM).fontColor(this.themeColorTextSecondary)
          .width('100%').textAlign(TextAlign.Center).padding({ top: 32, bottom: 32 })
      } else {
        Grid() {
          ForEach(this.candidates, (candidate: ChangeCoverCandidate) => {
            GridItem() {
              Column({ space: 4 }) {
                // 上游这里是 `CoilBookCover(name = item.name, author = item.author, path = item.coverUrl)`：
                // `path` 为 `use_default_cover` 或空时，`CoilBookCover` 会走内置封面池
                // （`CoilBookCover.kt:106-108 usesDefaultBookCover` → `:170-200 showCustomDefault / showDefaultIcon`），
                // 池里没有图就回落「书本图标 + 书名」，**不是留白**。
                // 本地直接用 `BookCover` 复刻这条链路：它已实现 `BUILTIN_DEFAULT_COVER` 哨兵、
                // 相册选图与无图占位，裸 `Image` 做不到（路径空就什么都不画）。
                BookCover({
                  book: this.candidateBook(candidate),
                  displayWidth: COVER_WIDTH_VP,
                  displayHeight: COVER_HEIGHT_VP,
                  coverSettings: this.coverSettings,
                  isNight: this.isNight,
                  cornerRadius: CARD_RADIUS
                })
                Text(candidate.originName).fontSize(LABEL_SMALL).fontWeight(FontWeight.Medium)
                  .fontColor(this.themeColorTextSecondary).maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
              }.width('100%').padding(CARD_PADDING).borderRadius(CARD_RADIUS)
                .onClick(() => this.choose(candidate.coverUrl))
            }
          }, (candidate: ChangeCoverCandidate) => `${candidate.sourceUrl}-${candidate.coverUrl}`)
        }
        .columnsTemplate('1fr 1fr 1fr').columnsGap(GRID_GAP).rowsGap(GRID_GAP)
        .width('100%')
        // 上游 LazyVerticalGrid 在 AppModalBottomSheet 里按内容撑开、超出半屏才滚动。
        // 这里**不能用 `.layoutWeight(1)`**：详情页走 `SheetSize.FIT_CONTENT`、编辑页是自绘浮层，
        // 两种父容器都没有确定高度，layoutWeight 会被压成 0，表现就是「只显示一行候选卡」。
        .constraintSize({ maxHeight: COVER_GRID_MAX_HEIGHT })
        .scrollBar(BarState.Off)
      }
    }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 16 })
  }
}
