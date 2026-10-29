/**
 * 书签/笔记跳转前的定位校验与标记重定位。
 * 逻辑严格对齐上游 `domain/usecase/VerifyBookmarkTargetUseCase.kt`
 * 与 `domain/usecase/RelocateMarkingTargetUseCase.kt`。
 */

/** 定位校验结论，对齐上游 `BookmarkTargetVerdict`。 */
export type BookmarkTargetVerdict = 'match' | 'sourceChanged' | 'titleMismatch';

/** 待确认的跳转目标，对齐上游 `PendingBookmarkTarget`。 */
export interface PendingBookmarkTarget {
  bookId: string;
  chapterIndex: number;
  chapterPosition: number;
  verdict: BookmarkTargetVerdict;
  /** 区分书签与笔记，只影响提示文案。 */
  isMarking: boolean;
}

/** 重定位候选：一章的语义正文 + 它在当前目录里的索引。 */
export interface MarkingRelocateCandidate {
  chapterIndex: number;
  content: string;
}

/** 重定位结果，对齐上游 `RelocateMarkingTargetUseCase.Target`。 */
export interface MarkingRelocateTarget {
  chapterIndex: number;
  chapterPosition: number;
}

/** 标记锚点：选中文本加前后文，字段对齐上游 `TextProcessAnchor`。 */
export interface MarkingRelocateAnchor {
  selectedText: string;
  contextBefore: string;
  contextAfter: string;
}

export class ReaderBookmarkTarget {
  /**
   * 判断跳转目标是否仍可靠。
   * 源指纹变了优先报 sourceChanged，其次才是章节标题不符；
   * 旧数据源指纹为空时跳过源校验（上游同样处理）。
   * @param currentBookUrl 当前书的源指纹
   * @param targetChapterTitle 当前目录里目标章节的标题，拿不到时传 undefined 跳过标题校验
   * @param storedBookUrl 创建时的源指纹
   * @param storedChapterName 创建时的章节标题
   */
  static verify(
    currentBookUrl: string,
    targetChapterTitle: string | undefined,
    storedBookUrl: string,
    storedChapterName: string
  ): BookmarkTargetVerdict {
    if (storedBookUrl.trim().length > 0 && storedBookUrl !== currentBookUrl) {
      return 'sourceChanged';
    }
    if (targetChapterTitle !== undefined && storedChapterName.trim().length > 0 &&
      storedChapterName !== targetChapterTitle) {
      return 'titleMismatch';
    }
    return 'match';
  }

  /**
   * 在候选章节里按「选中文本 + 前后文」找唯一最优匹配。
   * 同分即歧义，直接返回 undefined 交给用户确认，绝不瞎猜（上游注释同此意）。
   */
  static locate(anchor: MarkingRelocateAnchor, candidates: MarkingRelocateCandidate[]): MarkingRelocateTarget | undefined {
    const text = anchor.selectedText;
    if (text.trim().length === 0) {
      return undefined;
    }
    let best: MarkingRelocateTarget | undefined = undefined;
    let bestScore = -1;
    let bestCount = 0;
    for (let index = 0; index < candidates.length; index++) {
      const candidate = candidates[index];
      if (candidate === undefined) {
        continue;
      }
      let position = candidate.content.indexOf(text);
      while (position >= 0) {
        const score = ReaderBookmarkTarget.scoreOf(candidate.content, position, anchor);
        if (score > bestScore) {
          bestScore = score;
          best = { chapterIndex: candidate.chapterIndex, chapterPosition: position };
          bestCount = 1;
        } else if (score === bestScore) {
          bestCount++;
        }
        position = candidate.content.indexOf(text, position + text.length);
      }
    }
    if (best === undefined || bestCount !== 1) {
      return undefined;
    }
    return best;
  }

  /** 前后文各命中一次加 4 分；两处都不沾就是 0 分，与上游同分值口径。 */
  private static scoreOf(content: string, position: number, anchor: MarkingRelocateAnchor): number {
    const end = position + anchor.selectedText.length;
    let score = 0;
    if (anchor.contextBefore.trim().length > 0 &&
      content.substring(0, position).endsWith(anchor.contextBefore)) {
      score += 4;
    }
    if (anchor.contextAfter.trim().length > 0 && content.substring(end).startsWith(anchor.contextAfter)) {
      score += 4;
    }
    return score;
  }
}
