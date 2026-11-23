/**
 * 单本书的阅读进度快照，对应上游 AppWebDav 的 bookProgress/<书名>_<作者>.json。
 * 只带「读到哪、什么时间读的、章节标题是什么」四件事：
 * 本地书架才是进度的真源，这个文件只用于设备间搬运。
 */
export interface BookProgress {
  name: string;
  author: string;
  /** 0 基章节序号，对应 Book.chapterIndex。 */
  durChapterIndex: number;
  /** 章内字符进度，对应 Book.chapterProgress。 */
  durChapterPos: number;
  /** 最后一次阅读时间戳，用来判断远端与本地谁更新。 */
  durChapterTime: number;
  durChapterTitle: string;
}

/** 文件名里不允许出现的字符，对应上游 AppPattern.fileNameRegex2。 */
const FILE_NAME_FORBIDDEN: RegExp = new RegExp('[\\\\/:*?"<>|]', 'g');

/**
 * 把非法文件名字符换成下划线，对应上游 StringExtensions.normalizeFileName()：
 * `replace(AppPattern.fileNameRegex2, "_")`。
 */
export function normalizeFileName(text: string): string {
  return text.replace(FILE_NAME_FORBIDDEN, '_');
}

/** 保留字符的百分号编码表，逐条对应上游 UrlUtil.replaceReservedChar 的替换顺序。 */
const RESERVED_CHAR_PAIRS: string[][] = [
  ['%', '%25'],
  [' ', '%20'],
  ['"', '%22'],
  ['#', '%23'],
  ['&', '%26'],
  ['(', '%28'],
  [')', '%29'],
  ['+', '%2B'],
  [',', '%2C'],
  ['/', '%2F'],
  [':', '%3A'],
  [';', '%3B'],
  ['<', '%3C'],
  ['=', '%3D'],
  ['>', '%3E'],
  ['?', '%3F'],
  ['@', '%40'],
  ['\\', '%5C'],
  ['|', '%7C']
];

/**
 * 保留字符百分号编码，对应上游 UrlUtil.replaceReservedChar()。
 * 注意顺序：必须先替换 % 本身，否则后面的替换会把已编码的 % 再编码一次。
 */
export function replaceReservedChar(text: string): string {
  let result: string = text;
  for (let index = 0; index < RESERVED_CHAR_PAIRS.length; index++) {
    const pair = RESERVED_CHAR_PAIRS[index];
    if (pair === undefined) {
      continue;
    }
    const from: string = pair[0] ?? '';
    const to: string = pair[1] ?? '';
    if (from.length === 0) {
      continue;
    }
    result = result.split(from).join(to);
  }
  return result;
}

/**
 * 远端文件名，对应上游 AppWebDav.getProgressFileName()：
 * `UrlUtil.replaceReservedChar("${name}_${author}".normalizeFileName()) + ".json"`。
 * 两端用同一套规则，Android 侧上传的进度文件才能被本地读到，反之亦然。
 */
export function bookProgressFileName(name: string, author: string): string {
  return replaceReservedChar(normalizeFileName(`${name}_${author}`)) + '.json';
}

/**
 * 旧版文件名（`<书名>@<作者>.json`，百分号编码）。只在读取远端进度时做回退兼容，
 * 避免本轮规则切换后读不到此前已经上传的进度文件。
 */
export function legacyBookProgressFileName(name: string, author: string): string {
  return `${encodeURIComponent(name)}@${encodeURIComponent(author)}.json`;
}

export function createBookProgress(name: string, author: string, durChapterIndex: number,
  durChapterPos: number, durChapterTime: number, durChapterTitle: string): BookProgress {
  return {
    name: name,
    author: author,
    durChapterIndex: durChapterIndex,
    durChapterPos: durChapterPos,
    durChapterTime: durChapterTime,
    durChapterTitle: durChapterTitle
  };
}

/** 解析远端文件。字段缺失或类型不对一律当没有，不抛异常。 */
export function parseBookProgress(raw: string): BookProgress | undefined {
  let parsed: Record<string, Object>;
  try {
    parsed = JSON.parse(raw) as Record<string, Object>;
  } catch (_) {
    return undefined;
  }
  if (parsed === undefined || parsed === null) {
    return undefined;
  }
  const record = parsed;
  const text = (key: string): string => {
    const value = record[key];
    return typeof value === 'string' ? value as string : '';
  };
  const number = (key: string): number => {
    const value = record[key];
    return typeof value === 'number' && Number.isFinite(value) ? value as number : 0;
  };
  const name = text('name');
  if (name.length === 0) {
    return undefined;
  }
  return createBookProgress(name, text('author'), number('durChapterIndex'), number('durChapterPos'),
    number('durChapterTime'), text('durChapterTitle'));
}

export function serializeBookProgress(progress: BookProgress): string {
  return JSON.stringify(progress);
}
