/**
 * 与 Android 朗读音色实体对齐的一行音色目录。
 *
 * 上游：app/src/main/java/io/legado/app/data/entities/ReadAloudSpeech.kt
 * @Entity(tableName = "read_aloud_voices")，@PrimaryKey id（String），
 * 唯一索引 (engineType, engineId, speakerId)，普通索引 (enabled, displayName)。
 * 字段名逐字对齐 14 个列名，Gson 写出的 httpTtsVoices.json 可直接互认。
 */
export interface ReadAloudVoice {
  /** 主键；上游 id: String。 */
  id: string;
  /** 上游 engineType: String；httpTTS 源音色取 'http'。 */
  engineType: string;
  /** 上游 engineId: String = ""（@ColumnInfo(defaultValue = "")），指向 httpTTS.id。 */
  engineId: string;
  /** 上游 speakerId: String = ""（@ColumnInfo(defaultValue = "")）。 */
  speakerId: string;
  /** 上游 displayName: String。 */
  displayName: string;
  /** 上游 traitsJson: String = "[]"（@ColumnInfo(defaultValue = "[]")）。 */
  traitsJson: string;
  /** 上游 emotionCatalogJson: String = "[]"（@ColumnInfo(defaultValue = "[]")）。 */
  emotionCatalogJson: string;
  /** 上游 managedBy: String = "user"（@ColumnInfo(defaultValue = "user")）。 */
  managedBy: string;
  /** 上游 enabled: Boolean = true（@ColumnInfo(defaultValue = "1")）。 */
  enabled: boolean;
  /** 上游 available: Boolean = true（@ColumnInfo(defaultValue = "1")）。 */
  available: boolean;
  /**
   * 上游 excluded: Boolean = false（@ColumnInfo(defaultValue = "0")）。
   * 用户主动排除：源自带的目录里不想用的那些音色。不是删除——行必须留着，
   * 否则下次导入同一个源会把它当成新音色重新插回来。
   */
  excluded: boolean;
  /** 上游 revision: Long = 0L（@ColumnInfo(defaultValue = "0")）。 */
  revision: number;
  /** 上游 createdAt: Long = System.currentTimeMillis()。 */
  createdAt: number;
  /** 上游 updatedAt: Long = System.currentTimeMillis()。 */
  updatedAt: number;
}

/** 上游 ReadAloudVoice.ENGINE_HTTP：这一类音色属于 httpTTS 源。 */
export const READ_ALOUD_VOICE_ENGINE_HTTP: string = 'http';

/** 上游只把由源目录同步来的音色标成这个值，用户手动加的保持 'user'。 */
export const READ_ALOUD_VOICE_MANAGED_BY_HTTP_SOURCE_CATALOG: string = 'http_source_catalog';
