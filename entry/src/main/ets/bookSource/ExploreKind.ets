// 发现分类（ExploreKind）：对齐上游 `data/entities/rule/ExploreKind.kt`（49 行）
// 与 `ui/widget/components/explore/ExploreKindLayout.kt`（91 行）。
//
// 上游 `exploreKinds()`（help/source/BookSourceExtensions.kt:52-103）把 exploreUrl 解析成
// `List<ExploreKind>`：JSON 数组时逐项反序列化（title/url/type/action/chars/default/style 全要），
// 文本规则时只填 title 与 url（其余取默认值）。本地 `ExploreMenuParser` 只投影了 title/url
// 两个字段，够「发现」页的分类 chip 用，但不够探索页的分类面板用 —— 后者要按 type 画出
// 输入框、开关、下拉，还要按 style 做 flex 分行。
//
// 本文件把「完整字段的 ExploreKind + 分行算法」补齐，`ExploreMenuParser` 保持原样不动
// （发现页的分类 chip 不需要这些字段，改动它会牵动已经在用的路径）。
import { JsRuntime } from '@legado/sourceengine';
import { BookSource as LocalBookSource } from '../model/BookSource';
import { BookSourceRepository } from '../data/BookSourceRepository';
import { AppLog } from '../lib/AppLog';

/** 上游 `ExploreKind.Type`（ExploreKind.kt 的 object Type）。 */
export const EXPLORE_KIND_TYPE_URL: string = 'url';
export const EXPLORE_KIND_TYPE_TEXT: string = 'text';
export const EXPLORE_KIND_TYPE_BUTTON: string = 'button';
export const EXPLORE_KIND_TYPE_TOGGLE: string = 'toggle';
export const EXPLORE_KIND_TYPE_SELECT: string = 'select';

/**
 * 上游 `data/entities/rule/FlexChildStyle.kt:6-14`。
 * 默认值必须与上游一致：flexGrow 0 / flexShrink 1 / alignSelf "auto" /
 * flexBasisPercent -1 / wrapBefore false / justifySelf "auto"。
 */
export class FlexChildStyle {
  layoutFlexGrow: number = 0;
  layoutFlexShrink: number = 1;
  layoutAlignSelf: string = 'auto';
  layoutFlexBasisPercent: number = -1;
  layoutWrapBefore: boolean = false;
  /** 自定义的内部水平对齐属性（上游注释原文）。 */
  layoutJustifySelf: string = 'auto';

  static defaultStyle(): FlexChildStyle {
    return new FlexChildStyle();
  }
}

/**
 * 一条发现分类。字段与上游 `ExploreKind` 一一对应；
 * ArkTS 不支持 data class 的自动 equals，比对逻辑单独写成函数（`isSameExploreKind`）。
 */
export class ExploreKind {
  title: string = '';
  url: string = '';
  type: string = EXPLORE_KIND_TYPE_URL;
  action: string = '';
  chars: string[] = [];
  /** 上游 `chars` 为 `Array<String?>?`，null 表示「未配置」；本地用 `hasChars` 区分空数组与未配置。 */
  hasChars: boolean = false;
  default: string = '';
  viewName: string = '';
  style: FlexChildStyle = FlexChildStyle.defaultStyle();

  static create(title: string, url: string): ExploreKind {
    const kind = new ExploreKind();
    kind.title = title;
    kind.url = url;
    return kind;
  }
}

/** 上游 `ExploreKind.kt` 的 `style()`：未配 style 时回落 `FlexChildStyle.defaultStyle`。 */
export function exploreKindStyle(kind: ExploreKind): FlexChildStyle {
  return kind.style;
}

/**
 * 上游 `ExploreKindMultiTypeItem.kt:204-210` 的 `errorMsg` 扩展属性：
 * 分类解析失败时上游会塞一条 `ExploreKind("ERROR:...", stackTrace)`，
 * 这里按同一规则判定「这条其实是错误信息」，UI 上点开看完整报错。
 */
export function exploreKindErrorMsg(kind: ExploreKind): string {
  const title = kind.title;
  if (title.toLowerCase().startsWith('error:')) {
    return kind.url.length > 0 ? kind.url : title;
  }
  if (kind.url.indexOf('Exception') >= 0) {
    return kind.url;
  }
  if (title.indexOf('Exception') >= 0) {
    return title;
  }
  return '';
}

/** 一行分类：这一行里的各分类 + 各自占的列数（1..6），对齐上游 `List<Pair<ExploreKind, Int>>`。 */
export class ExploreKindSpan {
  kind: ExploreKind = new ExploreKind();
  span: number = 2;

  constructor(kind: ExploreKind, span: number) {
    this.kind = kind;
    this.span = span;
  }
}

/** 上游 `FlexItemLayout`（ExploreKindLayout.kt）。 */
class FlexItemLayout {
  flexGrow: number = 0;
  basisPercent: number = -1;
  wrapBefore: boolean = false;
}

/**
 * 逐行照搬上游 `ExploreKindLayout.kt:28-91` 的 `calculateFlexRows`。
 *
 * 规则（原文注释）：Text 行恒占满一行；有 basisPercent 的按比例取列数；
 * 只给 flexGrow 的占 3 列；都没有占 2 列。每行末尾把剩余列数均摊补齐，
 * 保证一行内各控件 layoutWeight 之和恒为 maxSpan。
 *
 * 均摊有个容易写错的地方：只有「本行各项 span 全相同且不止一项」才均摊，
 * 否则剩余列数整块加给最后一项。均摊时除不尽的余数从第一项开始各 +1。
 */
export function calculateExploreKindRows(kinds: ExploreKind[], maxSpan: number): ExploreKindSpan[][] {
  const rows: ExploreKindSpan[][] = [];
  let current: ExploreKindSpan[] = [];
  let currentSpan = 0;

  const fillCurrentRowTail = (): void => {
    if (current.length === 0) { return; }
    const remain = maxSpan - currentSpan;
    if (remain <= 0) { return; }
    const firstSpan = current[0].span;
    let allSameSpan = true;
    for (let index = 1; index < current.length; index++) {
      if (current[index].span !== firstSpan) { allSameSpan = false; break; }
    }
    if (allSameSpan && current.length > 1) {
      const addEach = Math.floor(remain / current.length);
      let extra = remain % current.length;
      for (let index = 0; index < current.length; index++) {
        let add = addEach;
        if (extra > 0) {
          extra -= 1;
          add += 1;
        }
        current[index].span = current[index].span + add;
      }
    } else {
      current[current.length - 1].span = current[current.length - 1].span + remain;
    }
    currentSpan += remain;
  };

  for (const kind of kinds) {
    const layout = new FlexItemLayout();
    layout.flexGrow = kind.style.layoutFlexGrow;
    layout.basisPercent = kind.style.layoutFlexBasisPercent;
    layout.wrapBefore = kind.style.layoutWrapBefore;

    let span: number;
    if (layout.wrapBefore || layout.basisPercent >= 1.0) {
      span = maxSpan;
    } else if (layout.basisPercent > 0) {
      span = Math.round(maxSpan * layout.basisPercent);
      span = Math.min(Math.max(span, 1), maxSpan);
    } else if (layout.flexGrow > 0) {
      span = 3;
    } else {
      span = 2;
    }

    const needsWrap = (layout.wrapBefore && current.length > 0) || (currentSpan + span > maxSpan);
    if (needsWrap) {
      fillCurrentRowTail();
      rows.push(current);
      current = [];
      currentSpan = 0;
    }
    current.push(new ExploreKindSpan(kind, span));
    currentSpan += span;
    if (currentSpan >= maxSpan) {
      rows.push(current);
      current = [];
      currentSpan = 0;
    }
  }
  if (current.length > 0) {
    fillCurrentRowTail();
    rows.push(current);
  }
  return rows;
}

/** 上游 `ExploreKind.kt` 的 equals：只比 title / type / url / action / default 五个字段。 */
export function isSameExploreKind(left: ExploreKind, right: ExploreKind): boolean {
  return left.title === right.title
    && left.type === right.type
    && left.url === right.url
    && left.action === right.action
    && left.default === right.default;
}

/** 从 JSON 对象读一个字符串字段；缺省或类型不符时返回空串。 */
function readString(record: Record<string, Object>, key: string): string {
  const value = record[key];
  return typeof value === 'string' ? value as string : '';
}

/** 从 JSON 对象读一个数字字段；缺省或类型不符时返回 fallback。 */
function readNumber(record: Record<string, Object>, key: string, fallback: number): number {
  const value = record[key];
  return typeof value === 'number' ? value as number : fallback;
}

/** 从 JSON 对象读一个布尔字段；缺省或类型不符时返回 fallback。 */
function readBoolean(record: Record<string, Object>, key: string, fallback: boolean): boolean {
  const value = record[key];
  return typeof value === 'boolean' ? value as boolean : fallback;
}

/** 解析 `style` 子对象（上游 `FlexChildStyle` 的 6 个字段）。 */
function readFlexChildStyle(raw: Object | undefined): FlexChildStyle {
  const style = FlexChildStyle.defaultStyle();
  if (raw === undefined || raw === null || typeof raw !== 'object' || Array.isArray(raw)) {
    return style;
  }
  const record = raw as Record<string, Object>;
  style.layoutFlexGrow = readNumber(record, 'layout_flexGrow', style.layoutFlexGrow);
  style.layoutFlexShrink = readNumber(record, 'layout_flexShrink', style.layoutFlexShrink);
  style.layoutAlignSelf = readString(record, 'layout_alignSelf');
  if (style.layoutAlignSelf.length === 0) { style.layoutAlignSelf = 'auto'; }
  style.layoutFlexBasisPercent = readNumber(record, 'layout_flexBasisPercent', style.layoutFlexBasisPercent);
  style.layoutWrapBefore = readBoolean(record, 'layout_wrapBefore', style.layoutWrapBefore);
  style.layoutJustifySelf = readString(record, 'layout_justifySelf');
  if (style.layoutJustifySelf.length === 0) { style.layoutJustifySelf = 'auto'; }
  return style;
}

/** 解析 JSON 数组里的一项为 ExploreKind（对齐上游 GSON 反序列化 ExploreKind）。 */
function parseExploreKindItem(raw: Object): ExploreKind {
  const kind = new ExploreKind();
  const record = raw as Record<string, Object>;
  kind.title = readString(record, 'title');
  kind.url = readString(record, 'url');
  kind.type = readString(record, 'type');
  if (kind.type.length === 0) { kind.type = EXPLORE_KIND_TYPE_URL; }
  kind.action = readString(record, 'action');
  kind.default = readString(record, 'default');
  kind.viewName = readString(record, 'viewName');
  const chars = record['chars'];
  if (Array.isArray(chars)) {
    kind.hasChars = true;
    for (const item of chars as Object[]) {
      if (typeof item === 'string') {
        kind.chars.push(item as string);
      }
    }
  }
  kind.style = readFlexChildStyle(record['style']);
  return kind;
}

/** 发现分类的解析入口，对齐上游 `BookSourceExtensions.kt:52-103 exploreKinds()`。 */
export class ExploreKindParser {
  /**
   * 解析书源的 exploreUrl。
   *
   * 与 `ExploreMenuParser.parse` 的差别：这里保留 type/action/chars/default/style 全部字段，
   * 且解析失败时返回一条 `ERROR:` 分类（上游同样行为，让用户能在面板里点开看报错）。
   */
  static parse(exploreUrl: string): ExploreKind[] {
    const kinds: ExploreKind[] = [];
    const raw = exploreUrl === undefined ? '' : exploreUrl.trim();
    if (raw.length === 0) { return kinds; }

    let ruleStr = raw;
    if (raw.startsWith('@js:') || raw.toLowerCase().startsWith('<js>')) {
      let jsStr = '';
      if (raw.startsWith('@')) {
        jsStr = raw.substring(4);
      } else {
        const end = raw.toLowerCase().lastIndexOf('</js>');
        jsStr = end > 4 ? raw.substring(4, end) : raw.substring(4);
      }
      try {
        const js = new JsRuntime();
        ruleStr = js.evaluate(jsStr.trim()).trim();
      } catch (e) {
        const message = e instanceof Error ? e.message : String(e);
        // 上游 `ExploreKind("ERROR:${it.localizedMessage}", it.stackTraceToString())`。
        kinds.push(ExploreKind.create('ERROR:' + message, message));
        return kinds;
      }
      if (ruleStr.length === 0) { return kinds; }
    }

    if (ruleStr.startsWith('[')) {
      try {
        const parsed = JSON.parse(ruleStr) as Object;
        if (Array.isArray(parsed)) {
          for (const item of parsed as Object[]) {
            if (item === null || typeof item !== 'object') { continue; }
            kinds.push(parseExploreKindItem(item));
          }
          return kinds;
        }
      } catch (e) {
        AppLog.put(`发现分类 JSON 解析失败 ${e instanceof Error ? e.message : String(e)}`);
      }
    }

    // 文本规则：上游 `kindStr.split("::")` 后取 first / getOrNull(1)，第二段为空时 url 为 null。
    const parts = ruleStr.split(/(?:&&|\n)+/u);
    for (const part of parts) {
      const seg = part.trim();
      if (seg.length === 0) { continue; }
      const kv = seg.split('::');
      const title = kv[0].trim();
      const url = kv.length > 1 ? kv.slice(1).join('::').trim() : '';
      kinds.push(ExploreKind.create(title, url));
    }
    return kinds;
  }

  /** 取某个书源的分类列表；书源不存在或没配 exploreUrl 时返回空数组。 */
  static parseForSource(sourceUrl: string): ExploreKind[] {
    const all: LocalBookSource[] = BookSourceRepository.getAll();
    for (const local of all) {
      if (local.bookSourceUrl !== sourceUrl) { continue; }
      const exploreUrl = ExploreKindParser.exploreUrlOf(local.sourceJson);
      return ExploreKindParser.parse(exploreUrl);
    }
    return [];
  }

  /** 从书源原始 JSON 里取 exploreUrl（本地引擎投影没有这个字段，只能读 sourceJson）。 */
  static exploreUrlOf(sourceJson: string): string {
    try {
      const root = JSON.parse(sourceJson) as Record<string, Object>;
      const value = root['exploreUrl'];
      return typeof value === 'string' ? value as string : '';
    } catch (_) {
      return '';
    }
  }
}
