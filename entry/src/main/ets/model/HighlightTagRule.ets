/**
 * 与 Android HighlightTagRule 实体对齐的高亮标签规则。
 *
 * 上游：app/src/main/java/io/legado/app/data/entities/HighlightTagRule.kt
 * @Entity(tableName = "highlight_tag_rules")，@PrimaryKey id: Long。
 * id 默认 System.currentTimeMillis()，本地用 number 承载。
 * order 是 SQL 关键字，建表与读写都带反引号。
 */
export interface HighlightTagRule {
  /** 主键；上游 id: Long = System.currentTimeMillis()。 */
  id: number;
  title: string;
  pattern: string;
  enabled: boolean;
  /** 上游 order: Int = 0。 */
  order: number;
}
