/**
 * 封面共享元素键的唯一拼装入口。
 *
 * 对齐上游 `ui/main/BookCoverSharedElement.kt:10-25`：用显式的作用域命名空间
 * （shelf / detail）实现天然隔离，杜绝字符串模糊匹配与不同层级间的锚点污染。
 *
 * ArkUI 侧用的是 `geometryTransition(id)`：一个 id 只能绑定两个组件，分别充当
 * 进场与出场的一方（`common.d.ts:21406` 的文档原文）。所以这里产出的字符串
 * 必须全 App 唯一，且源端与目标端用同一个函数算出来，不能各写一遍字面量。
 */

/** 书架卡片的来源标识。对齐上游 `CoverMemoryKey.kt:24 bookshelfSharedCoverSourceId`。 */
export function bookshelfSharedCoverSourceId(groupId: number): string {
  return `bookshelf:${groupId}`;
}

/**
 * 书架页封面键。对齐上游 `BookCoverSharedElement.kt:11-14 forShelf`。
 *
 * 不带分组时是 `cover:shelf:<bookUrl>`，带分组时插一层来源标识——
 * 同一个书在不同分组页里是不同的锚点，转场不会跨分组错接。
 */
export function shelfCoverSharedElementKey(bookUrl: string, sourceId: string = ''): string {
  return sourceId.length > 0 ? `cover:shelf:${sourceId}:${bookUrl}` : `cover:shelf:${bookUrl}`;
}

/** 书籍详情页封面键。对齐上游 `BookCoverSharedElement.kt:16 forDetail`。 */
export function detailCoverSharedElementKey(bookUrl: string): string {
  return `cover:detail:${bookUrl}`;
}

/**
 * 卡片与阅读页共用的封面键。对齐上游 `BookCoverSharedElement.kt:17-20`。
 *
 * 上游书架卡片用它、阅读页整块面板也用它——共享元素的两端因此对得上。
 */
export function bookCoverSharedElementKey(bookUrl: string, sourceId: string = ''): string {
  return sourceId.length > 0 ? `book-cover:${sourceId}:${bookUrl}` : `book-cover:${bookUrl}`;
}

/**
 * 书籍详情页封面键（带打开请求序号）。对齐上游 `BookCoverSharedElement.kt:22-25`。
 *
 * `openRequestId` 非 0 时追加一段：同一本书连着被打开两次时，第二次的锚点与
 * 第一次不同，避免上一次还没走完的转场被复用。
 */
export function bookInfoCoverSharedElementKey(bookUrl: string, openRequestId: number = 0): string {
  const key = detailCoverSharedElementKey(bookUrl);
  return openRequestId === 0 ? key : `${key}:request:${openRequestId}`;
}
