/**
 * 与 Android RssStar 实体对齐的 RSS 收藏。
 *
 * 上游：app/src/main/java/io/legado/app/data/entities/RssStar.kt
 * @Entity(tableName = "rssStars", primaryKeys = ["origin", "link"])。
 * 两个取舍：①上游 group 是 SQL 关键字，本地列名用 groupName，JSON 里仍是 group；
 * ②上游 variableMap 是 @Ignore 派生属性（由 variable 惰性解析），不落库、不进 JSON，不迁。
 */
export interface RssStar {
  /** 复合主键之一；上游 override var origin: String = ""。 */
  origin: string;
  /** 复合主键之一；上游 override var link: String = ""。 */
  link: string;
  /** 上游 var title: String = ""。 */
  title: string;
  /** 上游 @ColumnInfo(defaultValue = "默认分组") var group: String。本地列名 groupName 避开 SQL 关键字。 */
  groupName: string;
  /** 上游 var sort: String = ""。 */
  sort: string;
  /** 上游 var starTime: Long = 0。落列是为了照上游 `RssStarDao` 的 `order by starTime desc` 导出。 */
  starTime: number;
  /** 上游 @ColumnInfo(defaultValue = "0") var type: Int = 0（0 网页 / 1 图片 / 2 视频）。 */
  type: number;
  /** 上游 @ColumnInfo(defaultValue = "0") var durPos: Int = 0（阅读进度）。 */
  durPos: number;
  /** 整条条目的 JSON 文本（往返真值）。 */
  sourceJson: string;
}
