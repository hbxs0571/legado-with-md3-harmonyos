/**
 * 书源搜索关键词，逐字段对齐上游 `data/entities/SearchKeyword.kt`：
 * `@Entity(tableName = "search_keywords")`，`word` 主键，`usage` 默认 1，`lastUseTime` 默认当前时间。
 *
 * 与 `ReaderSearchHistoryEntry` 不是同一物：后者是阅读页内「本书内搜索」的记录，
 * 带 bookName/bookAuthor；这里是搜索框的全局关键词。
 */
export interface SearchKeyword {
  /** 关键词本身，也是主键。 */
  word: string;
  /** 使用次数，每搜一次加一。 */
  usage: number;
  /** 最近一次使用的时间戳（毫秒）。 */
  lastUseTime: number;
}
