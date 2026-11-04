import { LocalReaderPage } from '../pages/LocalReaderPaginator';

/**
 * 页身份与跨章页表定位的纯函数集合。
 *
 * 上游 `feature/reader/core/navigation/ReaderPageNavigator.kt:32-33` 的注释原文：
 *   "Page-table insertions, removals and same-id replacements must not reuse an old index."
 * 意思是：页表插入 / 删除 / 同 id 替换之后，旧数组下标不再有意义，必须按页身份
 * （`ReaderPageId(chapterIndex, pageIndex)`，`ReaderPage.kt:5`）重新查一次。
 *
 * 本地 `LocalReaderPage` 在页层批次 3 补上了可选的 `chapterIndex` / `pageIndex`
 * 两个身份字段（未填的旧页按 0/0 兜底），这里的函数都基于这两个字段工作：
 * - 批次 3：`rebasePageIndex`（页表变更后按身份重查下标）；
 * - 批次 4：`locateOrNull` / `chapterPosition` / `locateChapterPage` /
 *   `canTurnNext` / `canTurnPrevious`（页表跨章后的定位、章内页号换算、翻页边界）。
 *
 * 全部是零状态、零副作用的纯函数：`pages` 是「页表内下标 → 页」的有序数组，
 * `page.chapterIndex` / `page.pageIndex` 是页自身的身份，与数组下标是两回事——
 * 页表跨章后尤其不能混用。`ReaderCanvasWindow.of()` 按 `pages[pageIndex]` 取
 * 相邻四页，页表跨章后自然取到邻章页，故不需要改。
 */

/**
 * 页表变更后，用旧的「章号 + 章内页号」身份重新查新页表里的下标。
 *
 * 对齐上游 `ReaderPageNavigator.rebasePageIndex`（`:32-33`）与
 * `ReadBookController.kt:2949-2965` 的 `.indexOfFirst { ... }.takeIf { it >= 0 }`：
 * 返回匹配页在新 `pages` 里的数组下标；找不到（页被删、章被换出窗口）返回 `-1`，
 * 由调用方决定回退到哪一页，绝不复用旧下标。
 */
export function rebasePageIndex(
  pages: LocalReaderPage[], previousChapterIndex: number, previousPageIndex: number): number {
  for (let index = 0; index < pages.length; index++) {
    const page = pages[index];
    if (page === undefined) { continue; }
    const chapterIndex = page.chapterIndex ?? 0;
    const pageIndex = page.pageIndex ?? 0;
    if (chapterIndex === previousChapterIndex && pageIndex === previousPageIndex) {
      return index;
    }
  }
  // 对应上游 `.takeIf { it >= 0 }` 的 null 分支：身份已不在窗口里，不猜、不复用旧值。
  return -1;
}

/**
 * 当前页在「它所属的那一章」里的位置。
 *
 * 页表跨章（页层批次 4）后 `localReaderPages` 是窗口页表，数组下标不再是章内页号；
 * 页眉页脚、进度条、全书页码这些要显示「本章第几页 / 共几页」的地方都靠它现算。
 * 对齐上游 `ReaderPageNavigator.chapterPosition`（`:188-197`）返回的
 * `ReaderChapterPagePosition(chapterIndex, localIndex, chapterPages.size)`。
 */
export interface ReaderChapterPagePosition {
  chapterIndex: number;
  pageIndex: number;
  pageCount: number;
}

/**
 * 按章内字符坐标定位页下标；该章不在页表里返回 -1。
 *
 * 对齐上游 `ReaderPageNavigator.locateOrNull`（`:134-139`）：先按 chapterIndex 筛出
 * 该章的页，取最后一个 `pageStart <= chapterPosition` 的页，找不到则取该章第一页。
 * 上游注释（`:128-133`）强调「不把『未定位』折叠成 0，0 是全书首页的合法下标」，
 * 所以本函数返回 -1 表示「该章不在窗口里」，由调用方决定回退，绝不返回 0 冒充。
 *
 * 本地补一条：跳过 `titleOnly` 标题页（补查 A：标题行 startPosition 用 0 冒充正文
 * 坐标，让它参与比较会把 0% 定位拖进标题坐标空间）。与批次 4 之前
 * `ReaderPage.ets` 内联定位循环里 `if (page.titleOnly) { continue; }` 口径一致。
 */
export function locateOrNull(
  pages: LocalReaderPage[], chapterIndex: number, chapterPosition: number): number {
  let chapterFirst = -1;
  let located = -1;
  for (let index = 0; index < pages.length; index++) {
    const page = pages[index];
    if (page === undefined) { continue; }
    if ((page.chapterIndex ?? 0) !== chapterIndex) { continue; }
    if (page.titleOnly) { continue; }
    if (chapterFirst < 0) { chapterFirst = index; }
    // 同章页按章内页号升序，startPosition 随之单调不减；越过目标就可以停，
    // 对应批次 4 之前 `ReaderPage.ets` 内联定位循环里的 break（任务书 §批次 4）。
    if (page.startPosition > chapterPosition) { break; }
    located = index;
  }
  return located >= 0 ? located : chapterFirst;
}

/**
 * 页表内下标 → 该页所属章 + 章内页号 + 本章页数。
 *
 * 对齐上游 `ReaderPageNavigator.chapterPosition`（`:188-197`）：按页身份的
 * `chapterIndex` 筛出同章页，再按数组位置算章内序号（`indexOfFirst` 的本地等价）。
 * 页表内不存在该下标时返回 undefined，对应上游 `getOrNull(pageIndex) ?: return null`。
 */
export function chapterPosition(
  pages: LocalReaderPage[], pageIndex: number): ReaderChapterPagePosition | undefined {
  const page = pages[pageIndex];
  if (page === undefined) { return undefined; }
  const targetChapter = page.chapterIndex ?? 0;
  let localIndex = -1;
  let pageCount = 0;
  for (let index = 0; index < pages.length; index++) {
    const candidate = pages[index];
    if (candidate === undefined) { continue; }
    if ((candidate.chapterIndex ?? 0) !== targetChapter) { continue; }
    if (index === pageIndex) { localIndex = pageCount; }
    pageCount++;
  }
  if (localIndex < 0) { return undefined; }
  return { chapterIndex: targetChapter, pageIndex: localIndex, pageCount: pageCount };
}

/**
 * 按「章号 + 章内页号」定位页表内下标；该章不在页表里返回 -1。
 *
 * 对齐上游 `ReaderPageNavigator.locateChapterPage`（`:199-207`）：
 * `chapterPages[chapterPageIndex.coerceIn(chapterPages.indices)].index`。
 * `coerceIn` 的钳位让传入超大值即可拿到该章末页——向上翻章落章末就靠这一点，
 * 不需要调用方先数出本章有几页。
 */
export function locateChapterPage(
  pages: LocalReaderPage[], chapterIndex: number, chapterPageIndex: number): number {
  const chapterIndexes: number[] = [];
  for (let index = 0; index < pages.length; index++) {
    const page = pages[index];
    if (page === undefined) { continue; }
    if ((page.chapterIndex ?? 0) === chapterIndex) { chapterIndexes.push(index); }
  }
  if (chapterIndexes.length === 0) { return -1; }
  const clamped = Math.max(0, Math.min(chapterIndexes.length - 1, chapterPageIndex));
  return chapterIndexes[clamped] ?? -1;
}

/**
 * 能否往后翻：页表里还有下一页，或者还有下一章（由宿主换章）。
 *
 * 对齐上游 `ReaderPageNavigator.canTurnNext`（`:121-126`）的
 * `window.next != null || hasNextChapter`，以及 `:115-119` 的注释：邻章排版滞后时
 * 不能把「可翻的边界」误判成书末形成死端，放行要回到业务语义、把翻页交给宿主。
 * `window.next` 就是页表相邻的下一页（`ReaderPageNavigator.window` 按
 * `pages[pageIndex + 1]` 取），跨章页表下它可能是邻章的页——上游照放不误，
 * 换章落地由宿主在跨出当前章时触发，不在这里拦。
 */
export function canTurnNext(
  pages: LocalReaderPage[], pageIndex: number, hasNextChapter: boolean): boolean {
  return pages[pageIndex + 1] !== undefined || hasNextChapter;
}

/**
 * 能否往回翻：页表里还有上一页，或者还有上一章。
 * 对齐上游 `ReaderPageNavigator.canTurnPrevious`（`:124-126`）的
 * `window.previous != null || hasPreviousChapter`，`window.previous` 等价于
 * `pages[pageIndex - 1]` 存在。
 */
export function canTurnPrevious(
  pages: LocalReaderPage[], pageIndex: number, hasPreviousChapter: boolean): boolean {
  return (pageIndex > 0 && pages[pageIndex - 1] !== undefined) || hasPreviousChapter;
}
