/**
 * 与 Android TxtTocRule 字段对齐的本地 TXT 目录规则模型。
 *
 * 字段对应关系见 app/src/main/java/io/legado/app/data/entities/TxtTocRule.kt：
 * 上游用 @SerializedName(value = "chapterRule", alternate = ["rule"]) 兼容旧版
 * 只用 rule 字段的订阅格式，导入解析时也要接受这两种写法。
 */
export interface TxtTocRule {
  /** 稳定标识，新建时取时间戳，与上游默认值一致。 */
  id: number;
  name: string;
  /** 章节标题正则，多行模式下逐行匹配。 */
  chapterRule: string;
  /** 分卷正则；为空表示该规则不区分卷。 */
  volumeRule: string;
  /** 示例文本，用于规则测试与人工核对。 */
  example?: string;
  /**
   * 匹配优先级序号，越小越优先。
   * 上游默认 -1，表示「未显式排序」，读取时按数组顺序处理。
   */
  serialNumber: number;
  enable: boolean;
}
