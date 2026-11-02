/**
 * 全文搜索的结果集，供阅读页显示「上一个 / 下一个结果」与底部结果条。
 *
 * 上游把搜索结果留在 `ReadBookState` 里（`isShowingSearchResult` + `searchMenuVisible` +
 * `searchResultIndex`），正文两侧的箭头与底部结果条都从这里读。本地搜索是独立页面
 * （`AppRoute.READER_SEARCH`），跳进正文后搜索页已被卸载，所以跳转时把整份结果集
 * 交给阅读页带着走。
 */
export interface ReaderSearchNavItem {
  chapterIndex: number;
  /** 章内字符位置，与书签定位同口径。 */
  position: number;
  chapterTitle: string;
}
