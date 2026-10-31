import { fileIo } from '@kit.CoreFileKit';
import { Book } from '../model/Book';
import { BookRepository } from './BookRepository';

/**
 * 本地书在恢复期的位置状态，对应上游 BookRestorePlanner.kt:17 的 LocalBookLocationStatus。
 *
 * - Available：文件确实在，可以正常挂到这条书目上。
 * - Missing：文件不在了，但所在目录还能访问，说明是文件被删/被移动，可以据此清理重复书目。
 * - Unknown：存储离线、权限失效等原因导致无法确认，**不能据此删除书籍**。
 */
export enum LocalBookLocationStatus {
  Available = 'Available',
  Missing = 'Missing',
  Unknown = 'Unknown'
}

/** 恢复计划，对应上游 BookRestorePlan（BookRestorePlanner.kt:8）。 */
export interface BookRestorePlan {
  /** 已在本地书架上、本次按落点归并到新 bookUrl 的书目。 */
  booksToUpdate: Book[];
  /** 本地书架上没有、需要新增的书目。 */
  booksToInsert: Book[];
  /** 判定为重复、应当删除的已有书目。 */
  booksToDelete: Book[];
  /**
   * 原始 bookUrl → 解析后的落点 bookUrl。
   * 上游把书 `copy(bookUrl = 目标)` 之后原始值就丢了，恢复侧要靠这张表才知道
   * 「这条备份记录最后落到哪本书上」，重定位的书才能把进度合并过去。
   */
  resolvedTargets: Map<string, string>;
}

/** 单本本地书的落点解析结果，对应上游 LocalBookResolution（BookRestorePlanner.kt:81）。 */
interface LocalBookResolution {
  targetBookUrl: string;
  duplicateBookUrls: string[];
}

/**
 * 本地书恢复期的冲突规划，移植自上游 help/storage/BookRestorePlanner.kt（171 行）。
 *
 * 上游在 Restore.kt:130-140 用它的结果做一次事务：
 * `delete(*booksToDelete); update(*booksToUpdate); insert(*booksToInsert)`。
 * 本地原先只做 upsert（不删重复书、不识别重定位），这一层是补齐。
 */
export class LocalBookRestorePlanner {
  /**
   * 规划整批书目的恢复动作，对应上游 planBookRestore（BookRestorePlanner.kt:27）。
   *
   * @param restoredBooks ZIP 里读出来的书目
   * @param existingBooks 本地书架现有的书目
   * @param ignoreLocalBook 是否忽略本地书籍（对应上游 BackupConfig.ignoreLocalBook）
   * @param locationStatus 判定某个 bookUrl 的落地状态
   * @param normalizeLocation 路径规范化；不传则用 normalizeLocalBookLocation
   */
  static planBookRestore(
    restoredBooks: Book[],
    existingBooks: Book[],
    ignoreLocalBook: boolean,
    locationStatus: (bookUrl: string) => LocalBookLocationStatus,
    normalizeLocation?: (bookUrl: string) => string
  ): BookRestorePlan {
    const normalizer: (bookUrl: string) => string = normalizeLocation === undefined
      ? (bookUrl: string): string => LocalBookRestorePlanner.normalizeLocalBookLocation(bookUrl)
      : normalizeLocation;

    const existingBookUrls = new Set<string>();
    // activeBooks 保持插入顺序，对应上游的 linkedMapOf。
    const activeBooks = new Map<string, Book>();
    for (let index = 0; index < existingBooks.length; index++) {
      const existing = existingBooks[index];
      if (existing === undefined) { continue; }
      const existingUrl = LocalBookRestorePlanner.bookUrlOf(existing);
      existingBookUrls.add(existingUrl);
      activeBooks.set(existingUrl, existing);
    }
    const booksToUpsert = new Map<string, Book>();
    const booksToDelete = new Map<string, Book>();
    const resolvedTargets = new Map<string, string>();
    const statusCache = new Map<string, LocalBookLocationStatus>();
    const cachedLocationStatus = (bookUrl: string): LocalBookLocationStatus => {
      const cached = statusCache.get(bookUrl);
      if (cached !== undefined) { return cached; }
      const status = locationStatus(bookUrl);
      statusCache.set(bookUrl, status);
      return status;
    };

    for (let index = 0; index < restoredBooks.length; index++) {
      const restoredBook = restoredBooks[index];
      if (restoredBook === undefined) { continue; }
      // 上游 :44 —— 忽略本地书时，本地书整条跳过，其余书照常处理。
      if (ignoreLocalBook && restoredBook.isLocal) { continue; }
      let resolution: LocalBookResolution;
      if (restoredBook.isLocal) {
        resolution = LocalBookRestorePlanner.resolveLocalBookTarget(
          restoredBook, activeBooks, cachedLocationStatus, normalizer
        );
      } else {
        resolution = {
          targetBookUrl: LocalBookRestorePlanner.bookUrlOf(restoredBook),
          duplicateBookUrls: []
        };
      }

      // 上游 :61 —— 同位置/同重定位的重复书：从待写入里摘掉，只把「本来就在库里」的记进待删除。
      for (let dupIndex = 0; dupIndex < resolution.duplicateBookUrls.length; dupIndex++) {
        const duplicateBookUrl = resolution.duplicateBookUrls[dupIndex];
        if (duplicateBookUrl === undefined) { continue; }
        const duplicateBook = activeBooks.get(duplicateBookUrl);
        if (duplicateBook === undefined) { continue; }
        activeBooks.delete(duplicateBookUrl);
        booksToUpsert.delete(duplicateBookUrl);
        if (existingBookUrls.has(duplicateBookUrl)) {
          booksToDelete.set(duplicateBookUrl, duplicateBook);
        }
      }

      const restoredForSave = LocalBookRestorePlanner.withBookUrl(restoredBook, resolution.targetBookUrl);
      // 上游 :66 —— 目标本身不能出现在待删除里。
      booksToDelete.delete(LocalBookRestorePlanner.bookUrlOf(restoredForSave));
      const savedUrl = LocalBookRestorePlanner.bookUrlOf(restoredForSave);
      // 记下「这条备份记录最终落到哪本书」，重定位的书要靠它合并进度。
      resolvedTargets.set(LocalBookRestorePlanner.bookUrlOf(restoredBook), savedUrl);
      booksToUpsert.set(savedUrl, restoredForSave);
      activeBooks.set(savedUrl, restoredForSave);
    }

    const booksToUpdate: Book[] = [];
    const booksToInsert: Book[] = [];
    booksToUpsert.forEach((book: Book, bookUrl: string) => {
      if (existingBookUrls.has(bookUrl)) {
        booksToUpdate.push(book);
      } else {
        booksToInsert.push(book);
      }
    });
    const booksToDeleteList: Book[] = [];
    booksToDelete.forEach((book: Book) => {
      booksToDeleteList.push(book);
    });
    return {
      booksToUpdate: booksToUpdate,
      booksToInsert: booksToInsert,
      booksToDelete: booksToDeleteList,
      resolvedTargets: resolvedTargets
    };
  }

  /**
   * 解析一本本地书该落到哪条已有书目上，对应上游 resolveLocalBookTarget（BookRestorePlanner.kt:86）。
   *
   * 三个分支按上游顺序：同规范化路径的别名 → 重定位副本 → 保守兜底（不删）。
   */
  private static resolveLocalBookTarget(
    restoredBook: Book,
    activeBooks: Map<string, Book>,
    locationStatus: (bookUrl: string) => LocalBookLocationStatus,
    normalizeLocation: (bookUrl: string) => string
  ): LocalBookResolution {
    const restoredBookUrl = LocalBookRestorePlanner.bookUrlOf(restoredBook);
    const exactBook = activeBooks.get(restoredBookUrl);
    const restoredLocation = normalizeLocation(restoredBookUrl);
    // 上游 :95 —— 同一位置的其它本地书（规范化后路径相同）。
    const sameLocationBooks: Book[] = [];
    activeBooks.forEach((candidate: Book, candidateUrl: string) => {
      if (candidate.isLocal && normalizeLocation(candidateUrl) === restoredLocation) {
        sameLocationBooks.push(candidate);
      }
    });
    let hasSameLocationAlias = false;
    for (let index = 0; index < sameLocationBooks.length; index++) {
      const candidate = sameLocationBooks[index];
      if (candidate === undefined) { continue; }
      if (LocalBookRestorePlanner.bookUrlOf(candidate) !== restoredBookUrl) {
        hasSameLocationAlias = true;
      }
    }

    // 上游 :99 —— 本条位置可用，或存在同路径别名时，按同位置归并。
    if (sameLocationBooks.length > 0 &&
      (locationStatus(restoredBookUrl) === LocalBookLocationStatus.Available || hasSameLocationAlias)) {
      let target = exactBook;
      if (target === undefined) {
        for (let index = 0; index < sameLocationBooks.length; index++) {
          const candidate = sameLocationBooks[index];
          if (candidate === undefined) { continue; }
          if (locationStatus(LocalBookRestorePlanner.bookUrlOf(candidate)) === LocalBookLocationStatus.Available) {
            target = candidate;
            break;
          }
        }
      }
      if (target === undefined) { target = sameLocationBooks[0]; }
      const targetUrl = target === undefined
        ? restoredBookUrl
        : LocalBookRestorePlanner.bookUrlOf(target);
      const duplicateBookUrls: string[] = [];
      for (let index = 0; index < sameLocationBooks.length; index++) {
        const candidate = sameLocationBooks[index];
        if (candidate === undefined) { continue; }
        const candidateUrl = LocalBookRestorePlanner.bookUrlOf(candidate);
        if (candidateUrl !== targetUrl) { duplicateBookUrls.push(candidateUrl); }
      }
      return { targetBookUrl: targetUrl, duplicateBookUrls: duplicateBookUrls };
    }

    // 上游 :117 —— 换过路径的同一本书（重定位副本）。
    const compatibleBooks: Book[] = [];
    activeBooks.forEach((candidate: Book) => {
      if (LocalBookRestorePlanner.isRelocatedCopyOf(candidate, restoredBook)) {
        compatibleBooks.push(candidate);
      }
    });
    const candidateStatuses = new Map<string, LocalBookLocationStatus>();
    candidateStatuses.set(restoredBookUrl, locationStatus(restoredBookUrl));
    for (let index = 0; index < compatibleBooks.length; index++) {
      const candidate = compatibleBooks[index];
      if (candidate === undefined) { continue; }
      const candidateUrl = LocalBookRestorePlanner.bookUrlOf(candidate);
      candidateStatuses.set(candidateUrl, locationStatus(candidateUrl));
    }
    const availableLocations: string[] = [];
    let hasUnknownLocation = false;
    candidateStatuses.forEach((status: LocalBookLocationStatus, candidateUrl: string) => {
      if (status === LocalBookLocationStatus.Available) { availableLocations.push(candidateUrl); }
      if (status === LocalBookLocationStatus.Unknown) { hasUnknownLocation = true; }
    });
    // 上游 :124/:127 —— 存在 Unknown 就一律不动；只有唯一一个 Available 时才敢删其余的 Missing。
    if (!hasUnknownLocation && availableLocations.length === 1) {
      const targetUrl = availableLocations[0] === undefined ? restoredBookUrl : availableLocations[0];
      const duplicateBookUrls: string[] = [];
      for (let index = 0; index < compatibleBooks.length; index++) {
        const candidate = compatibleBooks[index];
        if (candidate === undefined) { continue; }
        const candidateUrl = LocalBookRestorePlanner.bookUrlOf(candidate);
        if (candidateUrl === targetUrl) { continue; }
        if (candidateStatuses.get(candidateUrl) === LocalBookLocationStatus.Missing) {
          duplicateBookUrls.push(candidateUrl);
        }
      }
      return { targetBookUrl: targetUrl, duplicateBookUrls: duplicateBookUrls };
    }

    // 上游 :138 之后的兜底 —— 判断不了就不删任何书。
    const fallbackTarget = exactBook === undefined
      ? restoredBookUrl
      : LocalBookRestorePlanner.bookUrlOf(exactBook);
    return { targetBookUrl: fallbackTarget, duplicateBookUrls: [] };
  }

  /**
   * 判断 candidate 是不是 restoredBook 换过路径的副本，对应上游 isRelocatedCopyOf（BookRestorePlanner.kt:150）。
   * 判据：都是本地书，且来源名（文件名）、书名、作者三者都非空且相等。
   */
  private static isRelocatedCopyOf(candidate: Book, restoredBook: Book): boolean {
    if (!candidate.isLocal || !restoredBook.isLocal) { return false; }
    const candidateOriginName = LocalBookRestorePlanner.originNameOf(candidate);
    const restoredOriginName = LocalBookRestorePlanner.originNameOf(restoredBook);
    if (candidateOriginName.length === 0 || candidateOriginName !== restoredOriginName) { return false; }
    const candidateName = candidate.title.trim();
    const restoredName = restoredBook.title.trim();
    if (candidateName.length === 0 || candidateName !== restoredName) { return false; }
    return candidate.author === restoredBook.author;
  }

  /**
   * 规范化本地书路径，对应上游 normalizeLocalBookLocation（BookRestorePlanner.kt:159）。
   *
   * 上游顺序：content:// 原样返回；file:// 转成本地路径；最后取 canonicalPath（失败退 absolutePath）。
   * HarmonyOS 没有 canonicalPath，这里退化成「去掉重复分隔符与 . 段」的绝对路径。
   */
  static normalizeLocalBookLocation(bookUrl: string): string {
    const value = bookUrl.trim();
    if (value.length === 0) { return ''; }
    if (value.toLowerCase().startsWith('content://')) { return value; }
    let path = value;
    if (value.toLowerCase().startsWith('file://')) {
      path = value.substring('file://'.length);
      // file:///data/... 去掉协议后还剩前导斜杠，file://data/... 则要补一个。
      if (!path.startsWith('/')) { path = `/${path}`; }
    }
    return LocalBookRestorePlanner.collapsePath(path);
  }

  /** 把 `a//b/./c/` 这类路径压成 `a/b/c`，作为 canonicalPath 的等价物。 */
  private static collapsePath(path: string): string {
    const segments = path.split('/');
    const kept: string[] = [];
    for (let index = 0; index < segments.length; index++) {
      const segment = segments[index];
      if (segment === undefined || segment.length === 0 || segment === '.') { continue; }
      kept.push(segment);
    }
    const joined = kept.join('/');
    if (path.startsWith('/')) { return `/${joined}`; }
    return joined;
  }

  /**
   * 判定本地书的位置状态，对应上游 localBookLocationStatus（Restore.kt:400-421）。
   *
   * 上游靠 Environment 的挂载态区分 Missing 与 Unknown；HarmonyOS 没有这个概念，
   * 这里改成：文件在 → Available；文件不在但父目录能访问 → Missing；父目录也访问不了 → Unknown。
   * content:// 与空路径一律 Unknown（无法确认，不据此删书）。
   */
  static localBookLocationStatus(bookUrl: string): LocalBookLocationStatus {
    const path = bookUrl.trim();
    if (path.length === 0) { return LocalBookLocationStatus.Unknown; }
    if (path.toLowerCase().startsWith('content://')) { return LocalBookLocationStatus.Unknown; }
    const localPath = LocalBookRestorePlanner.normalizeLocalBookLocation(path);
    try {
      if (fileIo.accessSync(localPath)) { return LocalBookLocationStatus.Available; }
    } catch (_) {
      // accessSync 抛异常同样按「访问不了」处理，交给父目录判断。
    }
    const separator = localPath.lastIndexOf('/');
    if (separator <= 0) { return LocalBookLocationStatus.Unknown; }
    const parent = localPath.substring(0, separator);
    try {
      if (fileIo.accessSync(parent)) { return LocalBookLocationStatus.Missing; }
    } catch (_) {
      return LocalBookLocationStatus.Unknown;
    }
    return LocalBookLocationStatus.Unknown;
  }

  /**
   * 取书目的主键路径，与 BookRepository.deleteBook 同口径（contentPath 优先）。
   * 本地书的 contentPath 是应用内副本，androidOriginalPath 是 Android 原始路径；
   * 只有从 Android 备份恢复的占位书才只有后者。
   */
  static bookUrlOf(book: Book): string {
    return book.contentPath ?? book.androidOriginalPath ?? '';
  }

  /** 取本地书的来源名（文件名，含扩展名），对应上游 Book.originName。 */
  static originNameOf(book: Book): string {
    const source = book.androidOriginalPath ?? book.contentPath ?? '';
    return source.length > 0 ? BookRepository.getFileName(source) : '';
  }

  /**
   * 复制一本书并换掉主键路径。
   * ArkTS 不支持对象展开，所以逐字段拷贝后改 contentPath / androidOriginalPath。
   */
  private static withBookUrl(book: Book, bookUrl: string): Book {
    const copied = BookRepository.copyBook(book);
    if (bookUrl.length === 0) { return copied; }
    if (book.contentPath !== undefined) {
      copied.contentPath = bookUrl;
    } else {
      copied.androidOriginalPath = bookUrl;
    }
    return copied;
  }
}
