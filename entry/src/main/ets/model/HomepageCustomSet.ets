/**
 * 与 Android HomepageCustomSet 实体对齐的首页自定义分组。
 *
 * 上游：app/src/main/java/io/legado/app/data/entities/HomepageCustomSet.kt
 * @Entity(tableName = "homepage_custom_sets")，@PrimaryKey id。
 */
export interface HomepageCustomSet {
  /** 主键；上游 id: String = ""。 */
  id: string;
  name: string;
  /** 上游 sortOrder: Int = 0。 */
  sortOrder: number;
}
