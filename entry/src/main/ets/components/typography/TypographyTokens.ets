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
/** 上游 LegadoTheme.kt:97 / Typography.kt:30。14fp / 20fp，对应 M3 titleSmall（miuix subtitle，行高比 1.4286）。字重为 Bold(700)：上游 titleSmall = miuixStyles.subtitle 作者注释「14.sp, Bold」，其 Emphasized 变体反而降到 Medium(Typography.kt:109)。本地调用点需显式 .fontWeight(FontWeight.Bold) 才与上游一致。 */
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

// ── M3 原生 TypeScale（与上面 24 槽位是两套，勿混） ──────────
/**
 * 上游有两套排版值，本地此前只搬了第一套：
 *
 *   第一套 = LegadoTypography 的 24 槽位（miuix 派生），即上方全部常量，
 *            对应 ui/theme/Typography.kt:18-40 的 miuixStylesToM3Typography。
 *   第二套 = M3 原生 TypeScale，来自 ui/theme/ThemeComponents.kt:257 的
 *            「val base = Typography()」无参构造（并非 miuix 映射），
 *            :281 以 typography = materialTypography 传给 MaterialExpressiveTheme。
 *
 * 顶栏标题走的是第二套：
 *   - 收起态：ui/widget/components/topbar/GlassTopAppBar.kt:76 用
 *     MaterialTheme.typography.titleLarge（M3 原生 22sp）。
 *   - 展开态：ui/widget/components/topbar/GlassMediumFlexibleTopAppBar.kt 的展开标题由 M3
 *     MediumFlexibleTopAppBar 内部取 headlineMedium（M3 原生 28sp）。
 *
 * 所以 28 / 22 不是本地自造值，也不该就近归进 24 槽位里的 24 / 20。
 *
 * 数值依据：material3 `tokens/TypeScaleTokens.kt` 实测（androidx 源文件，2026-11-21 核过，
 * 本机仍无 material3 副本）：headlineMedium 28.sp/36.0.sp、titleLarge 22.sp/28.0.sp、
 * labelLarge 14.sp/20.0.sp、bodyLarge 16.sp/24.0.sp。旁证是上游直接引用 MaterialTheme.typography。
 */
export const TYPE_SCALE_HEADLINE_MEDIUM: number = 28;
export const TYPE_SCALE_TITLE_LARGE: number = 22;
export const TYPE_SCALE_LABEL_LARGE: number = 14;
/** M3 原生 bodyLarge，16sp / 行高比 1.5。对应 M3 TextField 的默认输入文字样式（LocalTextStyle）。 */
export const TYPE_SCALE_BODY_LARGE: number = 16;
