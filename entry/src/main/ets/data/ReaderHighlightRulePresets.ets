import { ReaderHighlightRule } from '../model/ReaderHighlightRule';

/**
 * 阅读页「高亮规则 → 预设规则」的内置清单，对齐 Android `HighlightRulePresets`。
 *
 * 预设是「加进来再自己调」的起点，因此统一用同一个半透明底纹，不预设一堆颜色组合，
 * 避免和用户已有的样式审美打架。enabled 沿用上游「常用几条开、其余关」的分布：
 * 一次加十几条全开会糊满正文，关着加进来、用户按需打开更可控。
 *
 * 与上游的差异（每条都在下方注释里写明，不静默改）：
 * - `bracket_note_default`：上游正则末尾 `\[[^\]\n]{1,120}]` 的 `]` 没转义，
 *   在 ECMAScript RegExp 下报 `Lone quantifier brackets` 直接编译失败。本地补成 `\]`，
 *   语义不变（仍是「方括号内含 1–120 个非括号非换行字符」）。
 * - `date_time_default`：上游正则 314 字符，超过本地 `maximumPatternLength = 256`。
 *   本地裁掉「纯中文数字年份 + 农历月」这一分支后为 179 字符；阿拉伯数字年月日、
 *   中文日期后缀、HH:mm 与「N点N分」三种形态都保留。裁剪分支见常量注释。
 * - `title_emphasis_default`：上游 targetScope 为 TARGET_TITLE（标题）。本地引擎只执行
 *   正文规则，这条会被如实标为「标题规则，本地暂不执行」并默认不勾选，不伪装成生效。
 */
export class ReaderHighlightRulePresets {
  /** 统一的预设底色：20% 透明度的琥珀，日间/夜间压在正文上都不糊字。 */
  static readonly presetBackgroundColor: number = 0x33FFC107;

  /** 标题作用域；与 Android `HighlightRule.TARGET_TITLE` 一致。 */
  static readonly targetTitle: number = 1;

  /** 正文作用域；与 Android `HighlightRule.TARGET_CONTENT` 一致。 */
  static readonly targetContent: number = 2;

  static rules(): ReaderHighlightRule[] {
    return [
      {
        id: 'dialog_default',
        name: '对话高亮',
        pattern: '“[^“”]{1,500}”|"[^"\\n]{1,500}"|「[^「」]{1,500}」|『[^『』]{1,500}』',
        sampleText: '她轻声说：“今晚就出发。”',
        targetScope: ReaderHighlightRulePresets.targetContent,
        enabled: true,
        position: 0,
        underlineMode: 0,
        bgColor: ReaderHighlightRulePresets.presetBackgroundColor
      },
      {
        id: 'book_title_default',
        name: '书名号高亮',
        pattern: '《[^》\\n]{1,120}》',
        sampleText: '最近在重读《百年孤独》，节奏依然很稳。',
        targetScope: ReaderHighlightRulePresets.targetContent,
        enabled: true,
        position: 1,
        underlineMode: 0,
        bgColor: ReaderHighlightRulePresets.presetBackgroundColor
      },
      {
        id: 'bracket_note_default',
        name: '括号标注高亮',
        // 上游末段为 `\[[^\]\n]{1,120}]`，收尾 `]` 未转义会编译失败；本地补 `\]`。
        pattern: '（[^（）\\n]{1,120}）|\\([^()\\n]{1,120}\\)|【[^】\\n]{1,120}】|\\[[^\\]\\n]{1,120}\\]',
        sampleText: '他停了一下（像是忽然想起了什么）。',
        targetScope: ReaderHighlightRulePresets.targetContent,
        enabled: true,
        position: 2,
        underlineMode: 0,
        bgColor: ReaderHighlightRulePresets.presetBackgroundColor
      },
      {
        id: 'title_emphasis_default',
        name: '标题强调',
        pattern: '(?m)^[ \\t　]{0,2}(?:第[0-9零〇一二两三四五六七八九十百千万IVXLCDMivxlcdm]{1,12}[章节卷回部篇集幕]|序章|楔子|引子|终章|尾声|后记|番外)[^\\n]{0,200}$',
        sampleText: '第一章 雨夜来客',
        // 上游是 TARGET_TITLE；本地引擎只跑正文规则，这条会显示为「标题规则，本地暂不执行」。
        targetScope: ReaderHighlightRulePresets.targetTitle,
        enabled: true,
        position: 3,
        underlineMode: 0,
        bgColor: ReaderHighlightRulePresets.presetBackgroundColor
      },
      {
        id: 'thought_default',
        name: '心理活动',
        pattern: '（[^）\\n]{0,40}(?:心想|暗道|心道|想到|寻思着|琢磨|嘀咕)[^）\\n]{0,40}）',
        sampleText: '她心中一紧（暗道不对，这里一定有问题）。',
        targetScope: ReaderHighlightRulePresets.targetContent,
        enabled: false,
        position: 4,
        underlineMode: 0,
        bgColor: ReaderHighlightRulePresets.presetBackgroundColor
      },
      {
        id: 'narrator_default',
        name: '旁白说明',
        pattern: '(?m)^[ \\t　]{0,2}(?:(?:未完待续|待续|下文再表)[。…！!]{0,2}|(?:按|注)[:：][^\\n]{0,40})[ \\t　]*$|（(?:注|旁白|作者有话说)[:：][^）\\n]{0,40}）',
        sampleText: '（注：此处时间线与前文同步）',
        targetScope: ReaderHighlightRulePresets.targetContent,
        enabled: false,
        position: 5,
        underlineMode: 0,
        bgColor: ReaderHighlightRulePresets.presetBackgroundColor
      },
      {
        id: 'emphasis_default',
        name: '重点强调',
        // 上游示例里那段裸 `[^\n*_]{1,40}` 会匹配任意一行正文，这里换成成对标记 + 连续感叹/问号。
        pattern: '\\*\\*[^\\n*_]{1,40}\\*\\*|__[^\\n*_]{1,40}__|(?:!{3,}|！{2,}|！？|？！|\\?!|!\\?)[^\\n]{0,20}',
        sampleText: '**这是重点内容**，需要特别注意。',
        targetScope: ReaderHighlightRulePresets.targetContent,
        enabled: false,
        position: 6,
        underlineMode: 0,
        bgColor: ReaderHighlightRulePresets.presetBackgroundColor
      },
      {
        id: 'poetry_default',
        name: '诗词引用',
        pattern: '(?m)^[ \\t　]*(?!(?:第[零〇一二两三四五六七八九十百千万0-9]{1,12}[章节卷回部篇集幕]|序章|楔子|引子|终章|尾声|后记|番外))(?:[\\p{IsHan}]{5}|[\\p{IsHan}]{7})[，。！？；]?[ \\t　]*$',
        sampleText: '床前明月光，\n疑是地上霜。',
        targetScope: ReaderHighlightRulePresets.targetContent,
        enabled: false,
        position: 7,
        underlineMode: 0,
        bgColor: ReaderHighlightRulePresets.presetBackgroundColor
      },
      {
        id: 'ellipsis_default',
        name: '省略停顿',
        pattern: '…{2,}|\\.{3,}|—{2,}|-{3,}',
        sampleText: '他沉默了很久……最后还是点了头。',
        targetScope: ReaderHighlightRulePresets.targetContent,
        enabled: false,
        position: 8,
        underlineMode: 0,
        bgColor: ReaderHighlightRulePresets.presetBackgroundColor
      },
      {
        id: 'number_default',
        name: '数字金额',
        pattern: '[¥￥][ \\t]?\\d+(?:\\.\\d+)?(?:元|块|万|千|百|亿)?|\\d+(?:\\.\\d+)?(?:元|块|万|千|百|亿|%|％)|[零〇一二两三四五六七八九十百千万亿]+(?:元|块|万|千|百|亿)',
        sampleText: '原价100元，现在只要50元。',
        targetScope: ReaderHighlightRulePresets.targetContent,
        enabled: false,
        position: 9,
        underlineMode: 0,
        bgColor: ReaderHighlightRulePresets.presetBackgroundColor
      },
      {
        id: 'english_default',
        name: '英文单词',
        pattern: '\\b[A-Za-z]{2,}[A-Za-z0-9\'-]*\\b',
        sampleText: 'Hello World，你好世界。',
        targetScope: ReaderHighlightRulePresets.targetContent,
        enabled: false,
        position: 10,
        underlineMode: 0,
        bgColor: ReaderHighlightRulePresets.presetBackgroundColor
      },
      {
        id: 'date_time_default',
        name: '时间日期',
        // 上游原式 314 字符，超本地 256 上限；裁掉「纯中文数字年份 + 农历月」分支后 179 字符。
        pattern: '(?:\\d{2,4}年(?:0?[1-9]|1[0-2])月(?:(?:0?[1-9]|[12]\\d|3[01])[日号]?)?)(?![0-9零〇一二三四五六七八九十初廿卅日号])|(?<!\\d)(?:[01]?\\d|2[0-3]):[0-5]\\d(?!\\d)|(?<!\\d)(?:[01]?\\d|2[0-3])点(?:[0-5]?\\d分?)?(?!\\d)',
        sampleText: '2024年8月12日，上午10:30出发。',
        targetScope: ReaderHighlightRulePresets.targetContent,
        enabled: false,
        position: 11,
        underlineMode: 0,
        bgColor: ReaderHighlightRulePresets.presetBackgroundColor
      }
    ];
  }
}
