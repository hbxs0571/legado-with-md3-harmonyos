/**
 * 与 Android HttpTTS 实体对齐的在线朗读源。
 *
 * 上游：app/src/main/java/io/legado/app/data/entities/HttpTTS.kt
 * @Entity(tableName = "httpTTS")，@PrimaryKey id（Long）。
 * 字段名逐字对齐，Gson 写出的 httpTTS.json 可直接互认，不写字段映射表。
 * 可空字段保留上游 String? / Int? / Boolean? 的语义；concurrentRate 上游虽为
 * String?，JSON 里写成 "0" 这样的字符串，保持 string 不转数字。
 */
export interface HttpTts {
  /** 主键；上游 id: Long = System.currentTimeMillis()。 */
  id: number;
  /** 上游 name: String = ""。 */
  name: string;
  /** 上游 url: String = ""。 */
  url: string;
  /** 上游 contentType: String? = null。 */
  contentType?: string;
  /** 上游 concurrentRate: String? = "0"（@ColumnInfo(defaultValue = "0")）。 */
  concurrentRate?: string;
  /** 上游 loginUrl: String? = null。 */
  loginUrl?: string;
  /** 上游 loginUi: String? = null；可能是 JSON 数组字符串。 */
  loginUi?: string;
  /** 上游 header: String? = null。 */
  header?: string;
  /** 上游 jsLib: String? = null。 */
  jsLib?: string;
  /** 上游 enabledCookieJar: Boolean? = false（@ColumnInfo(defaultValue = "0")）。 */
  enabledCookieJar?: boolean;
  /** 上游 loginCheckJs: String? = null。 */
  loginCheckJs?: string;
  /** 上游 speed: Int? = null；源级语速 0..80，null 时用默认值 5（1 倍速）。 */
  speed?: number;
  /** 上游 synthesisThreadCount: Int = 1（@ColumnInfo(defaultValue = "1")），范围 1..8。 */
  synthesisThreadCount: number;
  /** 上游 lastUpdateTime: Long = System.currentTimeMillis()（@ColumnInfo(defaultValue = "0")）。 */
  lastUpdateTime: number;
}
