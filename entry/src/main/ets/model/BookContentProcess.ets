/** 与 Android book_content_processes 表字段对齐的本地正文处理记录。 */
export interface BookContentProcess {
  id: string;
  bookUrl: string;
  chapterIndex: number | null;
  kind: string;
  stage: string;
  target: string;
  anchorJson: string;
  actionJson: string;
  styleJson: string | null;
  source: string;
  aiArtifactId: string | null;
  sourceContentHash: string | null;
  enabled: boolean;
  sortOrder: number;
  status: number;
  schemaVersion: number;
  createdAt: number;
  updatedAt: number;
}

export interface TextProcessAnchor {
  chapterIndex: number;
  chapterPosition: number | null;
  selectedText: string;
  contextBefore: string;
  contextAfter: string;
  normalizedTextHash: string;
}

export interface TextProcessAction {
  type: string;
  replacement: string | null;
  text: string | null;
}

export interface ContentProcessDisplayItem {
  id: string;
  kind: string;
  actionType: string;
  selectedText: string;
  replacementText: string;
  enabled: boolean;
  chapterIndex: number;
  createdAt: number;
}

export const CONTENT_PROCESS_KIND_AI_CLEAN: string = 'ai_clean';
export const CONTENT_PROCESS_KIND_AI_REWRITE: string = 'ai_rewrite';
export const CONTENT_PROCESS_KIND_USER_UNDERLINE: string = 'user_underline';
export const CONTENT_PROCESS_KIND_USER_HIGHLIGHT: string = 'user_highlight';
export const CONTENT_PROCESS_STAGE_CONTENT: string = 'content';
export const CONTENT_PROCESS_TARGET_SELECTION: string = 'selection';
export const CONTENT_PROCESS_SOURCE_USER: string = 'user';
export const CONTENT_PROCESS_SOURCE_AI: string = 'ai';
export const CONTENT_PROCESS_STATUS_DRAFT: number = 0;
export const CONTENT_PROCESS_STATUS_ACTIVE: number = 1;
export const CONTENT_PROCESS_STATUS_DISABLED: number = 2;
export const CONTENT_PROCESS_STATUS_DELETED: number = 3;

/** 解析一条记录供阅读面板展示；损坏或字段不完整的记录不进入列表。 */
export function toContentProcessDisplayItem(process: BookContentProcess): ContentProcessDisplayItem | undefined {
  try {
    const anchor: TextProcessAnchor = JSON.parse(process.anchorJson);
    const action: TextProcessAction = JSON.parse(process.actionJson);
    if (typeof anchor.selectedText !== 'string' || typeof action.type !== 'string') {
      return undefined;
    }
    return {
      id: process.id,
      kind: process.kind,
      actionType: action.type,
      selectedText: anchor.selectedText,
      replacementText: action.replacement ?? action.text ?? '',
      enabled: process.enabled && process.status === CONTENT_PROCESS_STATUS_ACTIVE,
      chapterIndex: process.chapterIndex ?? anchor.chapterIndex,
      createdAt: process.createdAt
    };
  } catch (_) {
    return undefined;
  }
}
