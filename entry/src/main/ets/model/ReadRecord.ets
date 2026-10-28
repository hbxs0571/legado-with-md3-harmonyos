/**
 * 阅读记录的三层模型，对应上游 legado 的三张表：
 * readRecord（汇总）、readRecordDetail（按日明细）、readRecordSession（阅读时段）。
 *
 * 上游用 Room 建表并以 (deviceId, bookName, bookAuthor) 为主键；本地没有关系型数据库，
 * 用 preferences 存三段文本协议，字段语义与上游保持一致，便于备份文件互通。
 */

/** 书籍维度的阅读汇总，对应上游 ReadRecord。 */
export interface ReadRecordSummary {
  /** 设备标识。本地目前恒为空串，保留字段是为了与上游备份文件对齐。 */
  deviceId: string;
  bookName: string;
  bookAuthor: string;
  /** 累计阅读时长（毫秒）。 */
  readTime: number;
  /** 最后一次阅读的结束时间戳（毫秒）。 */
  lastRead: number;
}

/** 按自然日聚合的阅读明细，对应上游 ReadRecordDetail。 */
export interface ReadRecordDetail {
  deviceId: string;
  bookName: string;
  bookAuthor: string;
  /** 本地时区的日期，格式 yyyy-MM-dd。 */
  date: string;
  /** 当天阅读总时长（毫秒）。跨午夜的会话已按午夜切开后累加。 */
  readTime: number;
  /**
   * 当天阅读到的章节序号累加值。
   *
   * 上游同名段落注释写的是「当天阅读总字数」，但实际写入的是 durChapterIndex
   * （见 ReadRecordRepository.kt:412），本地按上游行为照做，只在时间线上用于定位章节。
   */
  readWords: number;
  /** 当天第一次阅读的起始时间戳。 */
  firstReadTime: number;
  /** 当天最后一次阅读的结束时间戳。 */
  lastReadTime: number;
}

/** 一次连续阅读时段，对应上游 ReadRecordSession。 */
export interface ReadRecordSession {
  deviceId: string;
  bookName: string;
  bookAuthor: string;
  /** 书籍副本标识，本地就是 Book.id；空串表示未归属的历史记录。 */
  bookUrl: string;
  startTime: number;
  endTime: number;
  /** 本次阅读时所在的章节序号，用于时间线定位章节标题；不是字数。 */
  chapterIndex: number;
}

/** 阅读记录修复报告，对应上游 ReadRecordRepairReport。 */
export interface ReadRecordRepairReport {
  /** 重复的阅读时段条数。 */
  duplicateSessionCount: number;
  /** 因书名/作者写法不一致而被合并的条数。 */
  mergedCount: number;
  /** 书名或作者需要规范化的条数。 */
  normalizedRecordCount: number;
}

/**
 * 扁平阅读记录，阅读记录页三种视图直接消费的结构。
 *
 * 这是会话（ReadRecordSession）的展示态投影，由 ReadRecordRepository.toTimelineRecords
 * 生成；页面的时间线、汇总、最后阅读三种模式都按它渲染。
 */
export interface ReadTimeRecord {
  id: string;
  bookId: string;
  bookName: string;
  bookAuthor: string;
  startTime: number;
  endTime: number;
  durationMs: number;
}
