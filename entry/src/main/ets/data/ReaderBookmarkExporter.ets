import { fileIo, picker } from '@kit.CoreFileKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { ReaderBookmark } from '../model/ReaderBookmark';
import { ReaderMarking } from '../model/ReaderMarking';

/**
 * 导出给 Android 版读回的 JSON 条目。
 * 字段名与上游 `io.legado.app.data.entities.Bookmark` 逐字一致，
 * 这样导出的文件能被 Android 版 GSON 直接解析。
 */
interface AndroidBookmarkJson {
  time: number;
  bookName: string;
  bookAuthor: string;
  bookUrl: string;
  chapterIndex: number;
  chapterPos: number;
  chapterName: string;
  bookText: string;
  content: string;
}

/**
 * 导出给 Android 版读回的笔记条目。
 * 字段名与上游 `io.legado.app.data.entities.BookMarking` 逐字一致；
 * 上游没有 kind 列，样式全在 styleJson 里，本地 effect 需转成 TextProcessStyle。
 */
interface AndroidMarkingJson {
  id: string;
  bookUrl: string;
  bookName: string;
  bookAuthor: string;
  chapterIndex: number;
  anchorJson: string;
  styleJson: string;
  note: string;
  chapterName: string;
  enabled: boolean;
  createdAt: number;
  updatedAt: number;
}

/** 上游 TextProcessAnchor，用于笔记的章节内定位。 */
interface AndroidTextProcessAnchor {
  chapterIndex: number;
  chapterPosition: number;
  selectedText: string;
  contextBefore: string;
  contextAfter: string;
  normalizedTextHash: string;
}

/**
 * 上游 TextProcessStyle，笔记的线段与颜色。
 * 字段可选：上游 GSON 未开启 serializeNulls，未设置的样式字段不会出现在 JSON 里，
 * 这里同样用可选字段让 JSON.stringify 省略 undefined，保证两端文本形态一致。
 */
interface AndroidTextProcessStyle {
  textColor?: number;
  bgColor?: number;
  underlineMode?: number;
  underlineColor?: number;
}

/** 「所有书签」页的导出结构，对应上游 AllBookmarkViewModel.ExportData。 */
interface AndroidAllBookmarksExport {
  bookmarks: AndroidBookmarkJson[];
  notes: AndroidMarkingJson[];
}

/**
 * 书签导出，对应上游 `io.legado.app.help.bookmark.BookmarkExporter`。
 * 只做文本生成与落盘，不读不写书签仓储，调用方负责取数与提示。
 */
export class ReaderBookmarkExporter {
  /**
   * 生成 Markdown 文本。
   * 版式逐字对齐上游 formatToMarkdown：
   * 一级标题书名 → 作者行 → 分隔线 → 每条「章节名 / 原文引用 / 备注 / 分隔线」。
   * 原文引用按行加 `> ` 前缀，保留原有段落结构。
   */
  static toMarkdown(bookName: string, author: string, bookmarks: ReaderBookmark[]): string {
    let text: string = `# ${bookName}\n`;
    if (author.trim().length > 0) {
      text += `作者：${author}\n`;
    }
    text += '\n---\n\n';
    bookmarks.forEach((bookmark: ReaderBookmark) => {
      text += `#### ${bookmark.chapterName}\n`;
      if (bookmark.bookText.length > 0) {
        text += `> ${bookmark.bookText.replace(/\n/g, '\n> ')}\n\n`;
      }
      if (bookmark.content.trim().length > 0) {
        text += `${bookmark.content}\n\n`;
      }
      text += '---\n\n';
    });
    return text;
  }

  /**
   * 生成 JSON 文本。
   * 输出 Android 实体字段名而非本地字段名，保证跨端可读回；
   * 本地 id / bookId 是 HarmonyOS 侧主键，Android 版没有对应列，故不导出。
   */
  static toJson(bookmarks: ReaderBookmark[]): string {
    const items: AndroidBookmarkJson[] = bookmarks.map((bookmark: ReaderBookmark) =>
      ReaderBookmarkExporter.toAndroidBookmark(bookmark));
    return JSON.stringify(items, null, 2);
  }

  /**
   * 默认文件名，对应上游 `${book.name}_$date.json|.md`（date 为 yyyyMMdd_HHmm）。
   * 书名里的路径分隔符等非法字符替换成下划线，避免保存对话框拒绝。
   */
  static buildFileName(bookName: string, isMarkdown: boolean): string {
    const date = new Date();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    const hour = date.getHours().toString().padStart(2, '0');
    const minute = date.getMinutes().toString().padStart(2, '0');
    const safeName = bookName.replace(/[\\/:*?"<>|]/g, '_').trim();
    const prefix = safeName.length > 0 ? safeName : 'bookmark';
    return `${prefix}_${date.getFullYear()}${month}${day}_${hour}${minute}.${isMarkdown ? 'md' : 'json'}`;
  }

  /**
   * 「所有书签」页的文件名，对应上游 `${key.name}-notes-$stamp.$suffix`。
   * 与阅读页导出刻意不同：上游两个入口命名规则就不一样，保持一致便于对照。
   */
  static buildAllBookmarksFileName(bookName: string, isMarkdown: boolean): string {
    const date = new Date();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    const hour = date.getHours().toString().padStart(2, '0');
    const minute = date.getMinutes().toString().padStart(2, '0');
    const second = date.getSeconds().toString().padStart(2, '0');
    const safeName = bookName.replace(/[\\/:*?"<>|]/g, '_').trim();
    const prefix = safeName.length > 0 ? safeName : 'bookmark';
    return `${prefix}-notes-${date.getFullYear().toString().substring(2)}${month}${day}${hour}${minute}${second}.${isMarkdown ? 'md' : 'json'}`;
  }

  /**
   * 「所有书签」页的 Markdown，逐字对齐上游 AllBookmarkViewModel.writeMarkdown：
   * 书名 → 作者 → 「## 书签（N）」小节 → 「## 笔记（M）」小节，
   * 条目用三级标题（阅读页那套是四级，两者本就不同）。
   */
  static toAllBookmarksMarkdown(bookName: string, author: string, bookmarks: ReaderBookmark[],
    markings: ReaderMarking[]): string {
    let text: string = `# ${bookName}\n\n`;
    if (author.trim().length > 0) {
      text += `作者：${author}\n\n`;
    }
    text += `## 书签（${bookmarks.length}）\n\n`;
    bookmarks.forEach((bookmark: ReaderBookmark) => {
      text += `### ${bookmark.chapterName}\n\n> ${bookmark.bookText}\n\n`;
      if (bookmark.content.trim().length > 0) {
        text += `${bookmark.content}\n\n`;
      }
    });
    text += `## 笔记（${markings.length}）\n\n`;
    markings.forEach((marking: ReaderMarking) => {
      text += `### ${marking.chapterName}\n\n> ${marking.selectedText}\n\n`;
      if (marking.note.trim().length > 0) {
        text += `${marking.note}\n\n`;
      }
    });
    return text;
  }

  /**
   * 「所有书签」页的 JSON，对应上游 `GSON.writeToOutputStream(ExportData(bookmarks, markings))`。
   * 顶层是 { bookmarks, notes } 双数组，与阅读页导出的纯数组不同。
   */
  static toAllBookmarksJson(bookmarks: ReaderBookmark[], markings: ReaderMarking[]): string {
    const payload: AndroidAllBookmarksExport = {
      bookmarks: bookmarks.map((bookmark: ReaderBookmark) => ReaderBookmarkExporter.toAndroidBookmark(bookmark)),
      notes: markings.map((marking: ReaderMarking) => ReaderBookmarkExporter.toAndroidMarking(marking))
    };
    return JSON.stringify(payload, null, 2);
  }

  /** 单条书签转 Android 实体字段。 */
  private static toAndroidBookmark(bookmark: ReaderBookmark): AndroidBookmarkJson {
    const item: AndroidBookmarkJson = {
      time: bookmark.createdAt,
      bookName: bookmark.bookName,
      bookAuthor: bookmark.bookAuthor,
      bookUrl: bookmark.bookUrl,
      chapterIndex: bookmark.chapterIndex,
      chapterPos: bookmark.chapterPosition,
      chapterName: bookmark.chapterName,
      bookText: bookmark.bookText,
      content: bookmark.content
    };
    return item;
  }

  /**
   * 单条笔记转 Android BookMarking。
   * 本地 effect + color 是拍平存储，上游是 anchorJson + styleJson 两段 JSON，
   * 这里按 MarkingEffect.toStyle 的映射还原：下划线类写 underlineMode/underlineColor，
   * 背景色剥掉 alpha 后补 0x33（约 20%），字体色写 textColor。
   */
  private static toAndroidMarking(marking: ReaderMarking): AndroidMarkingJson {
    const color = ReaderBookmarkExporter.colorToInt(marking.color);
    const anchor: AndroidTextProcessAnchor = {
      chapterIndex: marking.chapterIndex,
      chapterPosition: marking.chapterPosition,
      selectedText: marking.selectedText,
      contextBefore: marking.contextBefore,
      contextAfter: marking.contextAfter,
      normalizedTextHash: ReaderBookmarkExporter.md5Hex(ReaderBookmarkExporter.normalizeProcessText(marking.selectedText))
    };
    const style: AndroidTextProcessStyle = ReaderBookmarkExporter.effectToStyle(marking.effect, color);
    const item: AndroidMarkingJson = {
      id: marking.id,
      bookUrl: marking.bookUrl,
      bookName: marking.bookName,
      bookAuthor: marking.bookAuthor,
      chapterIndex: marking.chapterIndex,
      anchorJson: JSON.stringify(anchor),
      styleJson: JSON.stringify(style),
      note: marking.note,
      chapterName: marking.chapterName,
      enabled: marking.enabled,
      createdAt: marking.createdAt,
      updatedAt: marking.updatedAt
    };
    return item;
  }

  /**
   * 本地 effect 转上游 TextProcessStyle，逐条对齐 MarkingEffect.toStyle。
   * 本地多一个 'double'（双下划线），上游没有对应值，按实线下划线（1）降级。
   */
  private static effectToStyle(effect: string, color: number): AndroidTextProcessStyle {
    if (effect === 'solid' || effect === 'double') {
      return { underlineMode: 1, underlineColor: color };
    }
    if (effect === 'wave') {
      return { underlineMode: 3, underlineColor: color };
    }
    if (effect === 'dashed') {
      return { underlineMode: 2, underlineColor: color };
    }
    if (effect === 'strike') {
      return { underlineMode: 6, underlineColor: color };
    }
    if (effect === 'highlight') {
      return { underlineMode: 7, underlineColor: color };
    }
    if (effect === 'background') {
      // 与上游一致：背景色固定 0x33 alpha，避免不透明背景盖住正文
      return { bgColor: ((color & 0x00FFFFFF) | 0x33000000) };
    }
    return { textColor: color };
  }

  /** `#RRGGBB` / `#AARRGGBB` 转 Android 的 ARGB 整数；解析失败回退默认绿色。 */
  private static colorToInt(color: string): number {
    const hex = color.startsWith('#') ? color.substring(1) : color;
    if (hex.length === 6) {
      const parsed = Number.parseInt(hex, 16);
      return Number.isNaN(parsed) ? 0xFF63C37D : ((0xFF000000 | parsed) | 0);
    }
    if (hex.length === 8) {
      const parsed = Number.parseInt(hex, 16);
      return Number.isNaN(parsed) ? 0xFF63C37D : (parsed | 0);
    }
    return 0xFF63C37D;
  }

  /**
   * 与上游 BookContentProcessEngine.normalizeProcessText 同口径：
   * 逐行去掉首尾空白（含全角空格 U+3000），再用 \n 连接。
   */
  private static normalizeProcessText(text: string): string {
    return text.split('\n')
      .map((line: string) => line.replace(/^[\s\u3000]+|[\s\u3000]+$/g, ''))
      .join('\n')
      .trim();
  }

  /** 上游 normalizedTextHash 用 MD5；Android 侧匹配不依赖它，但字段需有值才不报错。 */
  private static md5Hex(text: string): string {
    try {
      const md = cryptoFramework.createMd('MD5');
      md.updateSync({ data: new Uint8Array(new util.TextEncoder().encodeInto(text)) });
      const digest = md.digestSync();
      let hex: string = '';
      for (let index = 0; index < digest.data.length; index++) {
        hex += (digest.data[index] as number).toString(16).padStart(2, '0');
      }
      return hex;
    } catch (_) {
      return '';
    }
  }

  /**
   * 弹出系统保存对话框写入文本。
   * 复用项目已验证的写法：内容直接传字符串由底层按 UTF-8 编码，
   * 先 encodeInto 成 Uint8Array 再 writeSync 在模拟器上会报 13900020。
   * @returns 是否真的写入；用户取消返回 false。
   */
  static async saveToFile(context: Context, content: string, fileName: string,
    isMarkdown: boolean): Promise<boolean> {
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [fileName];
    options.fileSuffixChoices = isMarkdown ? ['Markdown 文档|.md'] : ['JSON 文档|.json'];
    const uris = await new picker.DocumentViewPicker(context).save(options);
    const uri = uris[0];
    if (uri === undefined) {
      return false;
    }
    const target = fileIo.openSync(uri, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(target.fd, content);
    } finally {
      fileIo.closeSync(target);
    }
    return true;
  }
}
