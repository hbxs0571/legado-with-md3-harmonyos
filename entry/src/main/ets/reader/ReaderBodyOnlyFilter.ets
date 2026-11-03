/**
 * 「仅显示正文」折叠器，对齐上游 `feature/reader/core/source/ReaderBodyOnlyFilter.kt`。
 *
 * 用途只有一处：正文编辑弹层。书里的 `<img src="data:image/…;base64,…">`、整段
 * `<usehtml>…</usehtml>`、`[newpage]` 在编辑框里是不可读的源码，光标一划就容易误删。
 * 折叠只发生在**显示层**：原始片段按顺序记住，保存时原样插回，因此编辑正文不会丢内容。
 *
 * 判据与渲染器同源（`LocalTextSemantics.parse`）：
 * - `adaptSpecialStyle` 打开时，`[newpage]` 独占一段是分页标记、`<usehtml>` 整段是富文本块；
 * - 该开关关闭时这两者按字面文字显示，此时只折叠 `<img>`，否则会把用户看得见的字藏掉。
 */

/** 折叠片段类型，`label` 直接出现在占位标记里（形如 `〔图片1〕`）。 */
export enum BodyOnlyKind {
  Image = '图片',
  Html = '富文本',
  PageBreak = '分页'
}

/** 一段被折叠的原文。`index` 从 1 开始，标记里带序号，既避免重名又能逐个定位。 */
export interface HiddenSpan {
  index: number;
  start: number;
  end: number;
  raw: string;
  kind: BodyOnlyKind;
  marker: string;
}

const USE_HTML_START: string = '<usehtml>';
const USE_HTML_END: string = '</usehtml>';
const PAGE_BREAK: string = '[newpage]';
/** 与上游 `AppPattern.imgPattern` 同一写法：`<img[^>]*src="…"[^>]*>`。 */
const IMG_PATTERN: RegExp = new RegExp('<img[^>]*src="([^"]*(?:"[^>]+\\})?)"[^>]*>', 'g');

function buildMarker(kind: BodyOnlyKind, index: number): string {
  return `〔${kind as string}${index}〕`;
}

/**
 * 按行扫描全部非正文片段。
 *
 * 逐行判断的理由与上游一致：`[newpage]`、`<usehtml>` 只有**独占一段**时才被渲染器当结构处理，
 * 夹在句子中间的就是普通文字，折叠它会藏掉用户读得到的字。
 */
export function scanHiddenSpans(text: string, adaptSpecialStyle: boolean = true): HiddenSpan[] {
  const spans: HiddenSpan[] = [];
  let lineStart = 0;
  while (lineStart <= text.length) {
    const newlineAt = text.indexOf('\n', lineStart);
    const lineEnd = newlineAt < 0 ? text.length : newlineAt;
    const line = text.substring(lineStart, lineEnd);
    const trimmed = line.trim();
    if (adaptSpecialStyle && trimmed === PAGE_BREAK) {
      spans.push({
        index: spans.length + 1, start: lineStart, end: lineEnd, raw: line,
        kind: BodyOnlyKind.PageBreak, marker: buildMarker(BodyOnlyKind.PageBreak, spans.length + 1)
      });
    } else if (adaptSpecialStyle && trimmed.startsWith(USE_HTML_START) && trimmed.endsWith(USE_HTML_END)) {
      spans.push({
        index: spans.length + 1, start: lineStart, end: lineEnd, raw: line,
        kind: BodyOnlyKind.Html, marker: buildMarker(BodyOnlyKind.Html, spans.length + 1)
      });
    } else {
      IMG_PATTERN.lastIndex = 0;
      let match = IMG_PATTERN.exec(line);
      while (match !== null) {
        if (match[0].length === 0) {
          IMG_PATTERN.lastIndex += 1;
        }
        spans.push({
          index: spans.length + 1,
          start: lineStart + match.index,
          end: lineStart + match.index + match[0].length,
          raw: match[0],
          kind: BodyOnlyKind.Image,
          marker: buildMarker(BodyOnlyKind.Image, spans.length + 1)
        });
        match = IMG_PATTERN.exec(line);
      }
    }
    if (lineEnd >= text.length) {
      break;
    }
    lineStart = lineEnd + 1;
  }
  return spans;
}

/** 把片段换成占位标记；`spans` 必须由同一份 `text` 扫描得到。 */
export function toBodyOnly(text: string, spans: HiddenSpan[]): string {
  if (spans.length === 0) {
    return text;
  }
  let result = '';
  let cursor = 0;
  for (let index = 0; index < spans.length; index++) {
    const span = spans[index];
    if (span.start < cursor || span.end > text.length) {
      continue;
    }
    result += text.substring(cursor, span.start);
    result += span.marker;
    cursor = span.end;
  }
  if (cursor < text.length) {
    result += text.substring(cursor, text.length);
  }
  return result;
}

/**
 * 按标记出现顺序把原始片段插回。
 *
 * 标记找不到时按「顺序插回剩余全部」处理——最坏情况是位置漂移，不会丢内容；
 * 这与上游 `reassemble` 的兜底一致。
 */
export function reassemble(bodyOnlyText: string, spans: HiddenSpan[]): string {
  if (spans.length === 0) {
    return bodyOnlyText;
  }
  let result = '';
  let cursor = 0;
  for (let index = 0; index < spans.length; index++) {
    const span = spans[index];
    const found = bodyOnlyText.indexOf(span.marker, cursor);
    const at = found >= 0 ? found : bodyOnlyText.length;
    result += bodyOnlyText.substring(cursor, at);
    result += span.raw;
    cursor = found >= 0 ? at + span.marker.length : bodyOnlyText.length;
  }
  if (cursor < bodyOnlyText.length) {
    result += bodyOnlyText.substring(cursor, bodyOnlyText.length);
  }
  return result;
}

/**
 * 编辑器文本 → 完整正文。
 *
 * 若文本里还带着某个片段的原始源码（切换开关那一瞬间编辑器回吐旧值），
 * 说明它本来就不是折叠文本，按原文收下——否则插回时会把片段重复一遍。
 */
export function toRawText(text: string, spans: HiddenSpan[]): string {
  for (let index = 0; index < spans.length; index++) {
    const span = spans[index];
    if (span.raw.length > 0 && text.includes(span.raw)) {
      return text;
    }
  }
  return reassemble(text, spans);
}
