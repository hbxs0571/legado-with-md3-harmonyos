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
 * 两个身份字段（未填的旧页按 0/0 兜底），这里的函数都基于这两个字段工作。
 * 页层批次 3 只落地 `rebasePageIndex` 这一个纯函数，页表仍是一章、行为不变；
 * 页层批次 4 页表跨章后会在此文件追加 locateOrNull / chapterPosition /
 * locateChapterPage / canTurnNext / canTurnPrevious。
 */

/**
 * 页表变更后，用旧的「章号 + 章内页号」身份重新查新页表里的下标。
 *
 * 对齐上游 `ReaderPageNavigator.rebasePageIndex`（`:32-33`）与
 * `ReadBookController.kt:2949-2965` 的 `.indexOfFirst { ... }.takeIf { it >= 0 }`：
 * 返回匹配页在新 `pages` 里的数组下标；找不到（页被删、章被换出窗口）返回 `-1`，
 * 由调用方决定回退到哪一页，绝不复用旧下标。
 *
 * `pages` 是「页表内下标 → 页」的有序数组；`page.chapterIndex` / `page.pageIndex`
 * 是页自身的身份，与数组下标是两回事——页表跨章后尤其不能混用。
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
