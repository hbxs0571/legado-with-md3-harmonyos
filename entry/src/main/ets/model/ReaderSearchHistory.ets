export interface ReaderSearchHistoryEntry {
  /** 上游 search_content_history.id 是自增整数，这里转成字符串以保持 UI 层类型不变。 */
  id: string;
  bookName: string;
  bookAuthor: string;
  query: string;
  updatedAt: number;
}
