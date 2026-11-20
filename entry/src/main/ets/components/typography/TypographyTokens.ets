/**
 * 排版语义层：24 个槽位的字号 / 行高 / 字重。
 *
 * 对齐上游 app/src/main/java/io/legado/app/ui/theme/LegadoTheme.kt:85-115 的
 * data class LegadoTypography。上游那 24 个槽位靠 CompositionLocal 隐式继承，
 * 调用点只写 LegadoTheme.typography.titleMedium；ArkUI 没有这个机制
 * （SDK 全目录 grep -rn 'CompositionLocal' 零命中），所以本地调用点必须显式写出槽位名，
 * 这是能力边界，不是设计取舍。
 *
 * 行高为什么是绝对 fp 而不是比例：
 * 上游 ui/theme/Typography.kt:90 用 (reference.lineHeight.value / reference.fontSize.value).em
 * 表达相对行高，字号改了行高自动跟。ArkUI 的 lineHeight 收 number | string | Resource，
 * 数字单位 fp，字符串支持 "10" / "10fp"，不支持 em（component/units.d.ts 全文搜 em 零命中）。
 * 所以这里把「比例 × 字号」预乘成绝对 fp。全局字号缩放的响应性没有丢：
 * pages/Index.ets:3869 的 setFontSizeScale 会缩放 fp，行高跟着一起缩，效果与上游 em 一致。
 *
 * 数值来源与可信度：
 * 字号取自 Typography.kt:19-39 的 15 条 .sp 注释（去重后 10 个值）；
 * 行高比取自 Material3 Typography() 无参构造的官方规范值（如 bodyLarge 16/24 = 1.5）。
 * 后者无法从本地依赖源码核到——取证时 ~/.gradle 不存在、上游 app/build 不存在，
 * 没有 material3 源码可比。上机量过真实行高后，以上机值为准并更新本注释。
 */

// ── headline 类 ──────────────────────────────────────
/** 上游 LegadoTheme.kt:86。32fp / 40fp，对应 M3 headlineLarge（miuix title1，行高比 1.25）。 */
export const HEADLINE_LARGE: number = 32;
export const HEADLINE_LARGE_LINE_HEIGHT: number = 40;
/** 上游 LegadoTheme.kt:87。与 HEADLINE_LARGE 同号，仅字重改 Medium。 */
export const HEADLINE_LARGE_EMPHASIZED: number = 32;
export const HEADLINE_LARGE_EMPHASIZED_LINE_HEIGHT: number = 40;
/** 上游 LegadoTheme.kt:88。24fp / 30.86fp，对应 M3 headlineMedium（miuix title2，行高比 1.2857）。 */
export const HEADLINE_MEDIUM: number = 24;
export const HEADLINE_MEDIUM_LINE_HEIGHT: number = 30.86;
/** 上游 LegadoTheme.kt:89。与 HEADLINE_MEDIUM 同号，仅字重改 Medium。 */
export const HEADLINE_MEDIUM_EMPHASIZED: number = 24;
export const HEADLINE_MEDIUM_EMPHASIZED_LINE_HEIGHT: number = 30.86;
/** 上游 LegadoTheme.kt:90。20fp / 26.67fp，对应 M3 headlineSmall（miuix title3，行高比 1.3333）。 */
export const HEADLINE_SMALL: number = 20;
export const HEADLINE_SMALL_LINE_HEIGHT: number = 26.67;
/** 上游 LegadoTheme.kt:91。与 HEADLINE_SMALL 同号，仅字重改 Medium。 */
export const HEADLINE_SMALL_EMPHASIZED: number = 20;
export const HEADLINE_SMALL_EMPHASIZED_LINE_HEIGHT: number = 26.67;

// ── title 类 ─────────────────────────────────────────
/** 上游 LegadoTheme.kt:93。18fp / 22.91fp，对应 M3 titleLarge（miuix title4，行高比 1.2727）。 */
export const TITLE_LARGE: number = 18;
export const TITLE_LARGE_LINE_HEIGHT: number = 22.91;
/** 上游 LegadoTheme.kt:94。与 TITLE_LARGE 同号，仅字重改 Medium。 */
export const TITLE_LARGE_EMPHASIZED: number = 18;
export const TITLE_LARGE_EMPHASIZED_LINE_HEIGHT: number = 22.91;
/** 上游 LegadoTheme.kt:95。16fp / 24fp，对应 M3 titleMedium（miuix headline2，行高比 1.5）。 */
export const TITLE_MEDIUM: number = 16;
export const TITLE_MEDIUM_LINE_HEIGHT: number = 24;
/** 上游 LegadoTheme.kt:96。与 TITLE_MEDIUM 同号，仅字重改 Medium。 */
export const TITLE_MEDIUM_EMPHASIZED: number = 16;
export const TITLE_MEDIUM_EMPHASIZED_LINE_HEIGHT: number = 24;
/** 上游 LegadoTheme.kt:97。14fp / 20fp，对应 M3 titleSmall（miuix subtitle，行高比 1.4286）。 */
export const TITLE_SMALL: number = 14;
export const TITLE_SMALL_LINE_HEIGHT: number = 20;
/** 上游 LegadoTheme.kt:98。与 TITLE_SMALL 同号，仅字重改 Medium。 */
export const TITLE_SMALL_EMPHASIZED: number = 14;
export const TITLE_SMALL_EMPHASIZED_LINE_HEIGHT: number = 20;

// ── body 类 ──────────────────────────────────────────
/** 上游 LegadoTheme.kt:101。17fp / 25.5fp，对应 M3 bodyLarge（miuix paragraph，行高比 1.5）。 */
export const BODY_LARGE: number = 17;
export const BODY_LARGE_LINE_HEIGHT: number = 25.5;
/** 上游 LegadoTheme.kt:102。与 BODY_LARGE 同号，仅字重改 Medium。 */
export const BODY_LARGE_EMPHASIZED: number = 17;
export const BODY_LARGE_EMPHASIZED_LINE_HEIGHT: number = 25.5;
/** 上游 LegadoTheme.kt:103。16fp / 22.86fp，对应 M3 bodyMedium（miuix body1，行高比 1.4286）。 */
export const BODY_MEDIUM: number = 16;
export const BODY_MEDIUM_LINE_HEIGHT: number = 22.86;
/** 上游 LegadoTheme.kt:104。与 BODY_MEDIUM 同号，仅字重改 Medium。 */
export const BODY_MEDIUM_EMPHASIZED: number = 16;
export const BODY_MEDIUM_EMPHASIZED_LINE_HEIGHT: number = 22.86;
/** 上游 LegadoTheme.kt:105。12fp / 16fp，对应 M3 bodySmall（miuix body2，行高比 1.3333）。 */
export const BODY_SMALL: number = 12;
export const BODY_SMALL_LINE_HEIGHT: number = 16;
/** 上游 LegadoTheme.kt:106。与 BODY_SMALL 同号，仅字重改 Medium。 */
export const BODY_SMALL_EMPHASIZED: number = 12;
export const BODY_SMALL_EMPHASIZED_LINE_HEIGHT: number = 16;

// ── label 类 ─────────────────────────────────────────
/** 上游 LegadoTheme.kt:108。14fp / 18.67fp，对应 M3 labelLarge（miuix footnote1.copy(14sp)，行高比 1.3333）。 */
export const LABEL_LARGE: number = 14;
export const LABEL_LARGE_LINE_HEIGHT: number = 18.67;
/** 上游 LegadoTheme.kt:109。与 LABEL_LARGE 同号，仅字重改 Medium。 */
export const LABEL_LARGE_EMPHASIZED: number = 14;
export const LABEL_LARGE_EMPHASIZED_LINE_HEIGHT: number = 18.67;
/** 上游 LegadoTheme.kt:110。13fp / 17.33fp，对应 M3 labelMedium（miuix footnote1，行高比 1.3333）。 */
export const LABEL_MEDIUM: number = 13;
export const LABEL_MEDIUM_LINE_HEIGHT: number = 17.33;
/** 上游 LegadoTheme.kt:111。与 LABEL_MEDIUM 同号，仅字重改 Medium。 */
export const LABEL_MEDIUM_EMPHASIZED: number = 13;
export const LABEL_MEDIUM_EMPHASIZED_LINE_HEIGHT: number = 17.33;
/** 上游 LegadoTheme.kt:112。11fp / 16fp，对应 M3 labelSmall（miuix footnote2，行高比 1.4545）。 */
export const LABEL_SMALL: number = 11;
export const LABEL_SMALL_LINE_HEIGHT: number = 16;
/** 上游 LegadoTheme.kt:113。与 LABEL_SMALL 同号，仅字重改 Medium。 */
export const LABEL_SMALL_EMPHASIZED: number = 11;
export const LABEL_SMALL_EMPHASIZED_LINE_HEIGHT: number = 16;

/** 一个槽位的完整文字样式。行高已预乘成绝对 fp（见文件头说明）。 */
export interface TextStyleToken {
  size: number;
  lineHeight: number;
  weight: FontWeight;
}

/** 槽位名，与上游 LegadoTypography 的 24 个字段一一对应（小驼峰保持上游拼法）。 */
export type TypographySlot =
  | 'headlineLarge' | 'headlineLargeEmphasized'
  | 'headlineMedium' | 'headlineMediumEmphasized'
  | 'headlineSmall' | 'headlineSmallEmphasized'
  | 'titleLarge' | 'titleLargeEmphasized'
  | 'titleMedium' | 'titleMediumEmphasized'
  | 'titleSmall' | 'titleSmallEmphasized'
  | 'bodyLarge' | 'bodyLargeEmphasized'
  | 'bodyMedium' | 'bodyMediumEmphasized'
  | 'bodySmall' | 'bodySmallEmphasized'
  | 'labelLarge' | 'labelLargeEmphasized'
  | 'labelMedium' | 'labelMediumEmphasized'
  | 'labelSmall' | 'labelSmallEmphasized';

/** 查表：一个槽位名同时拿到字号 + 行高 + 字重三件套。 */
export function resolveTextStyle(slot: TypographySlot): TextStyleToken {
  switch (slot) {
    case 'headlineLarge':
      return { size: HEADLINE_LARGE, lineHeight: HEADLINE_LARGE_LINE_HEIGHT, weight: FontWeight.Normal };
    case 'headlineLargeEmphasized':
      return { size: HEADLINE_LARGE_EMPHASIZED, lineHeight: HEADLINE_LARGE_EMPHASIZED_LINE_HEIGHT, weight: FontWeight.Medium };
    case 'headlineMedium':
      return { size: HEADLINE_MEDIUM, lineHeight: HEADLINE_MEDIUM_LINE_HEIGHT, weight: FontWeight.Normal };
    case 'headlineMediumEmphasized':
      return { size: HEADLINE_MEDIUM_EMPHASIZED, lineHeight: HEADLINE_MEDIUM_EMPHASIZED_LINE_HEIGHT, weight: FontWeight.Medium };
    case 'headlineSmall':
      return { size: HEADLINE_SMALL, lineHeight: HEADLINE_SMALL_LINE_HEIGHT, weight: FontWeight.Normal };
    case 'headlineSmallEmphasized':
      return { size: HEADLINE_SMALL_EMPHASIZED, lineHeight: HEADLINE_SMALL_EMPHASIZED_LINE_HEIGHT, weight: FontWeight.Medium };
    case 'titleLarge':
      return { size: TITLE_LARGE, lineHeight: TITLE_LARGE_LINE_HEIGHT, weight: FontWeight.Normal };
    case 'titleLargeEmphasized':
      return { size: TITLE_LARGE_EMPHASIZED, lineHeight: TITLE_LARGE_EMPHASIZED_LINE_HEIGHT, weight: FontWeight.Medium };
    case 'titleMedium':
      return { size: TITLE_MEDIUM, lineHeight: TITLE_MEDIUM_LINE_HEIGHT, weight: FontWeight.Normal };
    case 'titleMediumEmphasized':
      return { size: TITLE_MEDIUM_EMPHASIZED, lineHeight: TITLE_MEDIUM_EMPHASIZED_LINE_HEIGHT, weight: FontWeight.Medium };
    case 'titleSmall':
      return { size: TITLE_SMALL, lineHeight: TITLE_SMALL_LINE_HEIGHT, weight: FontWeight.Normal };
    case 'titleSmallEmphasized':
      return { size: TITLE_SMALL_EMPHASIZED, lineHeight: TITLE_SMALL_EMPHASIZED_LINE_HEIGHT, weight: FontWeight.Medium };
    case 'bodyLarge':
      return { size: BODY_LARGE, lineHeight: BODY_LARGE_LINE_HEIGHT, weight: FontWeight.Normal };
    case 'bodyLargeEmphasized':
      return { size: BODY_LARGE_EMPHASIZED, lineHeight: BODY_LARGE_EMPHASIZED_LINE_HEIGHT, weight: FontWeight.Medium };
    case 'bodyMedium':
      return { size: BODY_MEDIUM, lineHeight: BODY_MEDIUM_LINE_HEIGHT, weight: FontWeight.Normal };
    case 'bodyMediumEmphasized':
      return { size: BODY_MEDIUM_EMPHASIZED, lineHeight: BODY_MEDIUM_EMPHASIZED_LINE_HEIGHT, weight: FontWeight.Medium };
    case 'bodySmall':
      return { size: BODY_SMALL, lineHeight: BODY_SMALL_LINE_HEIGHT, weight: FontWeight.Normal };
    case 'bodySmallEmphasized':
      return { size: BODY_SMALL_EMPHASIZED, lineHeight: BODY_SMALL_EMPHASIZED_LINE_HEIGHT, weight: FontWeight.Medium };
    case 'labelLarge':
      return { size: LABEL_LARGE, lineHeight: LABEL_LARGE_LINE_HEIGHT, weight: FontWeight.Normal };
    case 'labelLargeEmphasized':
      return { size: LABEL_LARGE_EMPHASIZED, lineHeight: LABEL_LARGE_EMPHASIZED_LINE_HEIGHT, weight: FontWeight.Medium };
    case 'labelMedium':
      return { size: LABEL_MEDIUM, lineHeight: LABEL_MEDIUM_LINE_HEIGHT, weight: FontWeight.Normal };
    case 'labelMediumEmphasized':
      return { size: LABEL_MEDIUM_EMPHASIZED, lineHeight: LABEL_MEDIUM_EMPHASIZED_LINE_HEIGHT, weight: FontWeight.Medium };
    case 'labelSmall':
      return { size: LABEL_SMALL, lineHeight: LABEL_SMALL_LINE_HEIGHT, weight: FontWeight.Normal };
    case 'labelSmallEmphasized':
      return { size: LABEL_SMALL_EMPHASIZED, lineHeight: LABEL_SMALL_EMPHASIZED_LINE_HEIGHT, weight: FontWeight.Medium };
    default:
      return { size: BODY_MEDIUM, lineHeight: BODY_MEDIUM_LINE_HEIGHT, weight: FontWeight.Normal };
  }
}
