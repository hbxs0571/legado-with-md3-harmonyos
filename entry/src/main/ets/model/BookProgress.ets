/**
 * 单本书的阅读进度快照，对应上游 AppWebDav 的 bookProgress/<书名>@<作者>.json。
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

/** 远端文件名。书名作者都可能带路径分隔符与斜杠，一律百分号编码，避免拼出子目录。 */
export function bookProgressFileName(name: string, author: string): string {
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
