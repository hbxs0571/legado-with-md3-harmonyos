// 在线书内容提供器接口（P3-E）。
// 对应上游 BookHelp.getContent（缓存优先 + 网络兜底）与 WebBook.getChapterListAwait。
// 定义在数据层、只依赖 model/Book，避免 data ↔ bookSource 循环依赖；
// 具体实现（OnlineBookService）在 EntryAbility 里 install 进 BookRepository。

import { Book, BookChapter } from '../model/Book';

/**
 * 在线书的目录与正文来源。
 * 本地书不走这个接口（BookRepository.readChapter 按 isLocal 分流）。
 */
export interface OnlineBookProvider {
  /**
   * 拉在线目录并适配成 BookChapter。对应上游 WebBook.getChapterListAwait
   * → BookChapterList.analyzeChapterList。
   * 在线章节靠 url + index 标识，start/end 为 undefined（那是本地 TXT 的字节偏移）。
   */
  getChapterList(book: Book): Promise<BookChapter[]>;

  /**
   * 取一章正文（缓存命中直接返回，否则网络抓取并落缓存）。
   * 对应上游 BookHelp.getContent：返回纯文本 String，替换规则与 HTML 净化在抓取层完成。
   */
  getContent(book: Book, chapter: BookChapter, allowCache?: boolean): Promise<string>;

  /**
   * 该章正文是否已在本地缓存里（「已下载」状态的真值来源，批2 :442 六档状态用）。
   */
  isChapterCached(book: Book, chapter: BookChapter): boolean;

  /** 删掉该章缓存文件（批2 :443 的「删除章节缓存」）。 */
  deleteChapterCache(book: Book, chapter: BookChapter): void;

  /** 删掉整本书的章节缓存（批2 :469 批量清缓存的在线书那一路；本地书不在其中）。 */
  clearBookCache(book: Book): void;
}
