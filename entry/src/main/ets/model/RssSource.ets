/**
 * 与 Android RssSource 实体对齐的 RSS 订阅源。
 *
 * 上游：app/src/main/java/io/legado/app/data/entities/RssSource.kt
 * @Entity(tableName = "rssSources")，@PrimaryKey sourceUrl。
 * 两个取舍：①上游 45 个字段全是标量或 String?，RSS 规则本身就是字符串不是嵌套对象，
 * 所以这里也不拆——只有需要排序与筛选的 5 个标量独立成列，其余全在 sourceJson 里；
 * ②sourceJson 是唯一真值，其余字段是它的派生列，供 SQL 排序与筛选，不允许单独改。
 */
export interface RssSource {
  /** 主键；上游 sourceUrl: String = ""。 */
  sourceUrl: string;
  /** 上游 sourceName: String = ""。 */
  sourceName: string;
  /** 上游 sourceGroup: String? = null。 */
  sourceGroup?: string;
  /** 上游 @ColumnInfo(defaultValue = "1") enabled: Boolean = true。 */
  enabled: boolean;
  /** 上游 @ColumnInfo(defaultValue = "0") customOrder: Int = 0。 */
  customOrder: number;
  /** 整条条目的 JSON 文本（往返真值）；从备份读入时原样保留，写出时原样拼回数组。 */
  sourceJson: string;
}
