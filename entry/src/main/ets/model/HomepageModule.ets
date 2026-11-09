/**
 * 与 Android HomepageModule 实体对齐的首页模块。
 *
 * 上游：app/src/main/java/io/legado/app/data/entities/HomepageModule.kt
 * @Entity(tableName = "homepage_modules")，@PrimaryKey id。
 * 16 个字段一字不差；上游 7 个 String? = null 的可空字段在这里用 ?: 承载，
 * 读回时走 RdbCodec.optionalText()，不能用 text() 把 null 变成空串——
 * 写回上游时空串与 null 语义不同。
 */
export interface HomepageModule {
  /** 主键；上游 id: String = ""。 */
  id: string;
  sourceUrl: string;
  moduleKey: string;
  type: string;
  title: string;
  /** 上游 args: String? = null。 */
  args?: string;
  /** 上游 layoutConfig: String? = null。 */
  layoutConfig?: string;
  /** 上游 url: String? = null。 */
  url?: string;
  isEnabled: boolean;
  sortOrder: number;
  /** 上游 customSetId: String? = null。 */
  customSetId?: string;
  isUserCreated: boolean;
  /** 上游 customTitle: String? = null。 */
  customTitle?: string;
  /** 上游 customSetTitle: String? = null。 */
  customSetTitle?: string;
  /** 上游 sourceJsonHash: String? = null。 */
  sourceJsonHash?: string;
  /** 上游 syncedAt: Long = 0。 */
  syncedAt: number;
}
