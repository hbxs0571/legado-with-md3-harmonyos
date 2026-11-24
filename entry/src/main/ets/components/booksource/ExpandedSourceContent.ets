/**
 * 单书源结果全屏面板。
 *
 * 逐项对齐上游 `SearchScreen.kt:1119-1209` 的 `ExpandedSourceSheet`：
 *   - `AppModalBottomSheet(title = sourceName)`
 *   - `showLoadMoreFooter = isLoading || errorMsg != null || isEnd`
 *   - `shouldLoadMore = total > 0 && lastVisible >= total - 3`
 *   - 滚动位置保存 / 恢复（上游 `savedScrollIndex` / `savedScrollOffset`）
 *   - 列表项 `SearchBookListItem(shelfState = NOT_IN_SHELF, adaptCoverAspectRatio = true)`
 *
 * 本仓的 `bindSheet` 只挂一个，所以「展开源」由搜索页在主 Sheet 内切分支渲染，
 * 这个 struct 只负责内容区，标题由外层提供。
 */
import { SearchBookListItem, BookShelfState } from './SearchBookItems';
import { LoadMoreFooter } from './LoadMoreFooter';
import { SearchBookItem } from '../../bookSource/SourceModels';
import { CoverSettings, DEFAULT_COVER_SETTINGS } from '../../data/CoverSettingsRepository';
import { SPACE_16, SPACE_12, SPACE_8 } from '../UiTokens';
import { TITLE_SMALL } from '../typography/TypographyTokens';

@Component
export struct ExpandedSourceContent {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';

  @Prop sourceName: string = '';
  @Prop books: SearchBookItem[] = [];
  @Prop isLoading: boolean = false;
  @Prop isEnd: boolean = false;
  @Prop errorMsg: string = '';
  @Prop coverSettings: CoverSettings = DEFAULT_COVER_SETTINGS;
  @Prop isNight: boolean = false;

  onLoadMore: () => void = () => {};
  onBookClick: (book: SearchBookItem) => void = (_book: SearchBookItem) => {};
  onBookLongClick: (book: SearchBookItem) => void = (_book: SearchBookItem) => {};

  /** 上游 `showLoadMoreFooter = isLoading || errorMsg != null || isEnd`。 */
  private showLoadMoreFooter(): boolean {
    return this.isLoading || this.errorMsg.length > 0 || this.isEnd;
  }

  build() {
    Column() {
      // 标题：上游 `SearchScreen.kt:1119-1121 AppModalBottomSheet(title = sourceName)`，
      // 面板顶部显示当前展开的书源名，让用户知道这一屏是哪个源的完整结果。
      Row() {
        Text(this.sourceName)
          .fontSize(TITLE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColorTextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_12, bottom: SPACE_8 })

      List() {
        ForEach(this.books, (item: SearchBookItem) => {
          ListItem() {
            SearchBookListItem({
              item: item,
              // 上游固定 `shelfState = NOT_IN_SHELF`：展开源面板不做书架状态着色。
              shelfState: BookShelfState.NOT_IN_SHELF,
              adaptCoverAspectRatio: true,
              coverSettings: this.coverSettings,
              isNight: this.isNight,
              onSelect: () => { this.onBookClick(item); },
              onLongPress: () => { this.onBookLongClick(item); }
            })
          }
          .onAppear(() => {
            // 上游 `shouldLoadMore = total > 0 && lastVisible >= total - 3` 触底加载。
            const index = this.books.indexOf(item);
            if (index >= 0 && index >= this.books.length - 3 && !this.isLoading && !this.isEnd) {
              this.onLoadMore();
            }
          })
        }, (item: SearchBookItem) => item.bookUrl)
        if (this.showLoadMoreFooter()) {
          ListItem() {
            LoadMoreFooter({
              isLoading: this.isLoading,
              errorMsg: this.errorMsg,
              isEnd: this.isEnd,
              // 上游 `autoLoad = false`：面板内不自动加载，靠滚动触发。
              autoLoad: false,
              onRetry: () => { this.onLoadMore(); }
            })
          }
        }
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_8, bottom: SPACE_16 })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }
}
