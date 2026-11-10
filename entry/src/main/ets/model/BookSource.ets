/**
 * 与 Android BookSource 实体对齐的书源。
 *
 * 上游：app/src/main/java/io/legado/app/data/entities/BookSource.kt
 * @Entity(tableName = "book_sources")，@PrimaryKey bookSourceUrl。
 * 两个取舍：①六个 rule 字段（ruleExplore/ruleSearch/ruleBookInfo/ruleToc/ruleContent/ruleReview）
 * 在上游是六个 Room @TypeConverter 列、GSON 各自 toJson 成文本；本地不拆它们，
 * 整条条目原样存 sourceJson，六个 rule 对象作为 JSON 的嵌套对象自然往返。
 * ②sourceJson 是唯一真值，其余字段是它的派生列，供 SQL 排序与筛选，不允许单独改。
 */
export interface BookSource {
  /** 主键；上游 bookSourceUrl: String = ""。 */
  bookSourceUrl: string;
  /** 上游 bookSourceName: String = ""。 */
  bookSourceName: string;
  /** 上游 bookSourceGroup: String? = null。 */
  bookSourceGroup?: string;
  /** 上游 @BookSourceType.Type bookSourceType: Int = 0（0 文本 / 1 音频 / 2 图片 / 3 文件 / 4 视频）。 */
  bookSourceType: number;
  /** 上游 @ColumnInfo(defaultValue = "1") enabled: Boolean = true。 */
  enabled: boolean;
  /** 上游 @ColumnInfo(defaultValue = "0") customOrder: Int = 0。 */
  customOrder: number;
  /** 整条条目的 JSON 文本（往返真值）；从备份读入时原样保留，写出时原样拼回数组。 */
  sourceJson: string;
}
