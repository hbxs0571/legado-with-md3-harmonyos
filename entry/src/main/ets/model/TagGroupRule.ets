/**
 * 与 Android TagGroupRule 实体对齐的标签分组规则。
 *
 * 上游：app/src/main/java/io/legado/app/data/entities/TagGroupRule.kt
 * @Entity(tableName = "tag_group_rules")，@PrimaryKey id: Long。
 * order 是 SQL 关键字，建表与读写都带反引号。
 */
export interface TagGroupRule {
  /** 主键；上游 id: Long = System.currentTimeMillis()。 */
  id: number;
  pattern: string;
  groupName: string;
  /** 上游 order: Int = 0。 */
  order: number;
}
