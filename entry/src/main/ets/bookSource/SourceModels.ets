// 在线书源的本地数据模型（P2）。
// 与引擎 SearchBook/BookChapter 解耦：UI 层只认这里的接口，引擎类型不外泄。

/** 搜索结果里的一本书。字段对齐上游 SearchBook，但用本地轻量接口。 */
export interface SearchBookItem {
  bookUrl: string;
  origin: string;       // 书源 URL，作为在线书的来源标识
  originName: string;   // 书源名
  name: string;
  author: string;
  kind: string;
  coverUrl: string;
  intro: string;
  lastChapter: string;
  wordCount: string;
  updateTime: string;
  tocUrl: string;       // 有的源搜索结果直接给目录地址
}

/** 详情页结果。tocUrl 为空时用 bookUrl 当目录地址。 */
export interface RemoteBookDetail {
  bookUrl: string;
  origin: string;
  originName: string;
  name: string;
  author: string;
  kind: string;
  coverUrl: string;
  intro: string;
  lastChapter: string;
  wordCount: string;
  updateTime: string;
  tocUrl: string;
}

/** 目录里的一章。 */
export interface RemoteChapter {
  url: string;
  title: string;
  isVip: boolean;
  isPay: boolean;
  /**
   * 是否是卷标题行，对应上游 BookChapter.isVolume。
   * 批3（r359）起由 ruleToc.isVolume 求值写入；缺省（undefined）按普通章节处理。
   */
  isVolume?: boolean;
}
