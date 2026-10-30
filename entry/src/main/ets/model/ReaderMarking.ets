/** 本地正文划线/高亮和笔记，不与普通书签或正文改写记录混用。 */
// 与上游 MarkingEffect 枚举保持一致：上游只有 7 种，没有「双下划线」，
// 所以本地删除 'double'，存量数据在仓储层按 solid 处理。
export type ReaderMarkingEffect = 'solid' | 'dashed' | 'wave' | 'strike' | 'highlight' | 'background' | 'text';

export interface ReaderMarking {
  id: string;
  bookId: string;
  bookName: string;
  bookAuthor: string;
  /** 创建时的源指纹，仅用于章节/正文变化时辅助定位。 */
  bookUrl: string;
  chapterIndex: number;
  chapterName: string;
  /** 当前本地语义正文中的 UTF-16 起止偏移。 */
  chapterPosition: number;
  endPosition: number;
  selectedText: string;
  contextBefore: string;
  contextAfter: string;
  effect: ReaderMarkingEffect;
  color: string;
  note: string;
  enabled: boolean;
  createdAt: number;
  updatedAt: number;
}
