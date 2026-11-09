/**
 * 与 Android DictRule 实体对齐的字典规则。
 *
 * 上游：app/src/main/java/io/legado/app/data/entities/DictRule.kt
 * @Entity(tableName = "dictRules")，@PrimaryKey name。
 * 字段名逐字对齐，Gson 写出的 dictRule.json 可直接互认，不写字段映射表。
 */
export interface DictRule {
  /** 主键；上游 name: String = ""。 */
  name: string;
  /** 上游 urlRule: String = ""。 */
  urlRule: string;
  /** 上游 showRule: String = ""。 */
  showRule: string;
  /** 上游 @ColumnInfo(defaultValue = "1") enabled: Boolean = true。 */
  enabled: boolean;
  /** 上游 @ColumnInfo(defaultValue = "0") sortNumber: Int = 0。 */
  sortNumber: number;
}
