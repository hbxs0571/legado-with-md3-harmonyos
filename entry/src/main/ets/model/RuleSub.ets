/**
 * 与 Android RuleSub 实体对齐的规则订阅。
 *
 * 上游：app/src/main/java/io/legado/app/data/entities/RuleSub.kt
 * @Entity(tableName = "ruleSubs")，@PrimaryKey id: Long。
 * 两个取舍：①上游 update 是 SQL 关键字、且本任务没有消费方，只留在 sourceJson 里；
 * ②type 的四值（0 书源 / 1 订阅源 / 2 替换规则 / 3 自动识别）本地不做 import 分流，
 * 四种一视同仁存下来，type 只供将来界面分类显示。
 */
export interface RuleSub {
  /** 主键；上游 @PrimaryKey val id: Long = System.currentTimeMillis()。 */
  id: number;
  /** 上游 var name: String = ""。 */
  name: string;
  /** 上游 var url: String = ""。 */
  url: string;
  /** 上游 var type: Int = RuleSubType.BOOK_SOURCE（0）。 */
  type: number;
  /** 上游 var customOrder: Int = 0。 */
  customOrder: number;
  /** 上游 var autoUpdate: Boolean = false。 */
  autoUpdate: boolean;
  /** 整条条目的 JSON 文本（往返真值）。 */
  sourceJson: string;
}
