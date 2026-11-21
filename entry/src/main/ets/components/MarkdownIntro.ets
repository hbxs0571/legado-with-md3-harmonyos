import {
  BODY_SMALL, BODY_SMALL_LINE_HEIGHT, HEADLINE_SMALL, HEADLINE_SMALL_LINE_HEIGHT, TITLE_LARGE,
  TITLE_LARGE_LINE_HEIGHT, TITLE_MEDIUM, TITLE_MEDIUM_LINE_HEIGHT, TITLE_SMALL, TITLE_SMALL_LINE_HEIGHT
} from './typography/TypographyTokens';

/**
 * 简介里的 Markdown 渲染（批7 :1158）。
 *
 * SDK 没有 Markdown 组件（ets/component、ets/api、ets/kits 三处搜 `arkdown` 只在
 * `@ohos.data.uniformTypeDescriptor.d.ts` 命中一次 MIME 常量），工程也没有任何三方库
 * （`oh-package.json5` 的 dependencies 是空对象），所以只能自写，并且**收窄到五类语法**：
 *
 *   1. `# ` ~ `###### ` 行首标题（只认行首，行中 `#` 不动）
 *   2. `**粗**` / `*斜*`
 *   3. `![alt](url)` 独占一行渲染成图，行内保持原文
 *   4. `[text](url)` 蓝色可点，点击走与图片同一个回调通道
 *   5. 三反引号代码块（只做等宽 + 浅底，不解析语言）
 *
 * **表格 `| a | b |` 原样显示**：上游 `MarkdownBlock.kt` 用 FlowRow 排版表格，本地不做，
 * 这里刻意按等宽文本原样输出 —— 这是明确的取舍，不是漏做。
 */
export type MarkdownBlockKind = 'heading' | 'paragraph' | 'image' | 'code' | 'table';

/** 行内片段：粗、斜、链接三属性互不排斥（上游也是这么嵌套的）。 */
export interface MarkdownInline {
  text: string;
  bold: boolean;
  italic: boolean;
  link: string;
}

/** 一个渲染块。`level` 只在 heading 上有意义（1..6）。 */
export interface MarkdownBlock {
  kind: MarkdownBlockKind;
  level: number;
  inline: MarkdownInline[];
  /** image 块是图片地址，code/table 块是原文。 */
  text: string;
}

/** h1..h6 的递减字号；取 Material 字号阶梯里已有的几档，避免自造数值。 */
const MARKDOWN_HEADING_SIZES: number[] = [
  TITLE_LARGE + 8, TITLE_LARGE + 4, TITLE_LARGE + 2, TITLE_LARGE, TITLE_LARGE - 2, TITLE_SMALL
];
const MARKDOWN_HEADING_LINE_HEIGHTS: number[] = [
  TITLE_LARGE_LINE_HEIGHT + 10, TITLE_LARGE_LINE_HEIGHT + 6, TITLE_LARGE_LINE_HEIGHT + 4,
  TITLE_LARGE_LINE_HEIGHT, TITLE_LARGE_LINE_HEIGHT - 2, TITLE_SMALL_LINE_HEIGHT
];

/** 行首标题：1..6 级。行中出现的 `#` 不参与。 */
const HEADING_PATTERN: RegExp = new RegExp('^(#{1,6})\\s+(.*)$');
/** 独占一行的图片。 */
const IMAGE_LINE_PATTERN: RegExp = new RegExp('^!\\[([^\\]]*)\\]\\(([^)\\s]+)\\)$');
/** 行内 token：粗、斜、链接。 */
const INLINE_PATTERN: RegExp = new RegExp('\\*\\*[^*]+\\*\\*|\\*[^*]+\\*|\\[[^\\]]+\\]\\([^)\\s]+\\)', 'g');

/** 把一行 Markdown 拆成行内片段。 */
export function parseMarkdownInline(line: string): MarkdownInline[] {
  const segments: MarkdownInline[] = [];
  let cursor: number = 0;
  INLINE_PATTERN.lastIndex = 0;
  let match: RegExpExecArray | null = INLINE_PATTERN.exec(line);
  while (match !== null) {
    if (match.index > cursor) {
      segments.push({ text: line.substring(cursor, match.index), bold: false, italic: false, link: '' });
    }
    const token: string = match[0];
    if (token.startsWith('**')) {
      segments.push({ text: token.substring(2, token.length - 2), bold: true, italic: false, link: '' });
    } else if (token.startsWith('[')) {
      const closeBracket: number = token.indexOf('](');
      const label: string = token.substring(1, closeBracket);
      const url: string = token.substring(closeBracket + 2, token.length - 1);
      segments.push({ text: label, bold: false, italic: false, link: url });
    } else {
      segments.push({ text: token.substring(1, token.length - 1), bold: false, italic: true, link: '' });
    }
    cursor = match.index + token.length;
    match = INLINE_PATTERN.exec(line);
  }
  if (cursor < line.length) {
    segments.push({ text: line.substring(cursor), bold: false, italic: false, link: '' });
  }
  return segments;
}

/** 把整段 Markdown 拆成渲染块。 */
export function parseMarkdownBlocks(source: string): MarkdownBlock[] {
  const lines: string[] = (source ?? '').replace(/\r\n/g, '\n').split('\n');
  const blocks: MarkdownBlock[] = [];
  let index: number = 0;
  while (index < lines.length) {
    const line: string = lines[index];
    const trimmed: string = line.trim();
    if (trimmed.length === 0) {
      index += 1;
      continue;
    }
    // 代码块：到下一个 ``` 为止，没闭合就把剩下的都当代码。
    if (trimmed.startsWith('```')) {
      const code: string[] = [];
      index += 1;
      while (index < lines.length && lines[index].trim().startsWith('```') === false) {
        code.push(lines[index]);
        index += 1;
      }
      if (index < lines.length) {
        index += 1;
      }
      blocks.push({ kind: 'code', level: 0, inline: [], text: code.join('\n') });
      continue;
    }
    const heading: RegExpExecArray | null = HEADING_PATTERN.exec(trimmed);
    if (heading !== null) {
      blocks.push({
        kind: 'heading', level: heading[1].length, inline: parseMarkdownInline(heading[2]), text: heading[2]
      });
      index += 1;
      continue;
    }
    const image: RegExpExecArray | null = IMAGE_LINE_PATTERN.exec(trimmed);
    if (image !== null) {
      blocks.push({ kind: 'image', level: 0, inline: [], text: image[2] });
      index += 1;
      continue;
    }
    // 表格：本地不排真表格，整行原样（等宽）输出。
    if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
      blocks.push({ kind: 'table', level: 0, inline: [], text: trimmed });
      index += 1;
      continue;
    }
    blocks.push({ kind: 'paragraph', level: 0, inline: parseMarkdownInline(trimmed), text: trimmed });
    index += 1;
  }
  return blocks;
}

@Component
export struct MarkdownIntro {
  @Prop source: string = '';
  @Prop textColor: string = '#D0D2DB';
  /**
   * 正文（paragraph）字号与行高。上游 MarkdownBlock.kt:119 默认 style = bodyLarge（17sp），
   * 简介页此前固定用 TITLE_SMALL 呈现；这里做成可配置，默认值保持原样不影响简介页，
   * 书源调试页详情弹层传入 bodyLarge 的 17sp 以对齐上游。
   */
  @Prop bodySize: number = TITLE_SMALL;
  @Prop bodyLineHeight: number = TITLE_SMALL_LINE_HEIGHT;
  /** 链接点击：与简介图片共用一条回调通道（上游也是 `IntroImageClick`）。 */
  onLinkClick: (url: string) => void = (url: string): void => {
  };
  onImageClick: (url: string) => void = (url: string): void => {
  };

  private blocks(): MarkdownBlock[] {
    return parseMarkdownBlocks(this.source);
  }

  @Builder
  private InlineText(inline: MarkdownInline[], size: number, lineHeight: number, weight: FontWeight) {
    Text() {
      ForEach(inline, (segment: MarkdownInline, index: number) => {
        Span(segment.text)
          .fontSize(size)
          .fontWeight(segment.bold ? FontWeight.Bold : weight)
          .fontStyle(segment.italic ? FontStyle.Italic : FontStyle.Normal)
          .fontColor(segment.link.length > 0 ? '#9AB4FF' : this.textColor)
          .decoration(segment.link.length > 0 ?
            { type: TextDecorationType.Underline, color: '#9AB4FF' } : { type: TextDecorationType.None })
          .onClick(() => {
            if (segment.link.length > 0) {
              this.onLinkClick(segment.link);
            }
          })
      }, (segment: MarkdownInline, index: number) => `${index}_${segment.text}`)
    }.width('100%').lineHeight(lineHeight).alignSelf(ItemAlign.Start)
  }

  build() {
    Column() {
      ForEach(this.blocks(), (block: MarkdownBlock, index: number) => {
        if (block.kind === 'heading') {
          this.InlineText(block.inline, MARKDOWN_HEADING_SIZES[block.level - 1],
            MARKDOWN_HEADING_LINE_HEIGHTS[block.level - 1], FontWeight.Bold)
        } else if (block.kind === 'image') {
          Image(block.text)
            .width('100%')
            .objectFit(ImageFit.Contain)
            .borderRadius(8)
            .margin({ top: 6, bottom: 6 })
            .onClick(() => this.onImageClick(block.text))
        } else if (block.kind === 'code') {
          Text(block.text)
            .fontSize(BODY_SMALL)
            .lineHeight(BODY_SMALL_LINE_HEIGHT)
            .fontColor(this.textColor)
            .fontFamily('monospace')
            .width('100%')
            .padding(8)
            .backgroundColor('#1F2026')
            .borderRadius(8)
            .margin({ top: 4, bottom: 4 })
            .alignSelf(ItemAlign.Start)
        } else if (block.kind === 'table') {
          // 表格原样输出（等宽），上游 FlowRow 表格本地不做 —— 明确取舍，写进注释与盘面备注。
          Text(block.text)
            .fontSize(BODY_SMALL)
            .lineHeight(BODY_SMALL_LINE_HEIGHT)
            .fontColor(this.textColor)
            .fontFamily('monospace')
            .width('100%')
            .margin({ top: 2, bottom: 2 })
            .alignSelf(ItemAlign.Start)
        } else {
          this.InlineText(block.inline, this.bodySize, this.bodyLineHeight, FontWeight.Normal)
        }
      }, (block: MarkdownBlock, index: number) => `${index}_${block.kind}`)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}