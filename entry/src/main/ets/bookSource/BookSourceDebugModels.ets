// 书源调试页数据模型（P10）。
// 对齐上游 Debug.EventKind 与 BookSourceDebugContract 的三个枚举。
// 引擎不提供可读的日志条目流，这里用宿主自己的事件模型（kind/message/elapsedMs/timestamp）。

/** 调试目标，对齐上游 BookSourceDebugTarget。 */
export type DebugTarget = 'Search' | 'Explore' | 'Info' | 'Toc' | 'Content';
/** 调试状态，对齐上游 BookSourceDebugStatus。 */
export type DebugStatus = 'Loading' | 'Idle' | 'Running' | 'Success' | 'Failed' | 'Cancelled';
/** 日志过滤档，对齐上游 BookSourceDebugFilter。 */
export type DebugFilter = 'All' | 'Messages' | 'Sources' | 'Errors';
/** 事件种类，对齐上游 Debug.EventKind 七个取值。 */
export type DebugEventKind =
  'Message' | 'SearchSource' | 'InfoSource' | 'TocSource' | 'ContentSource' | 'Error' | 'Completed';

export const DEBUG_TARGETS: DebugTarget[] = ['Search', 'Explore', 'Info', 'Toc', 'Content'];
export const DEBUG_FILTERS: DebugFilter[] = ['All', 'Messages', 'Sources', 'Errors'];

/** 单条日志条目：id 递增（对齐上游 AtomicLong）。 */
export interface DebugEntry {
  id: number;
  kind: DebugEventKind;
  message: string;
  timestamp: number;
  elapsedMs: number;
}

/** 是否为四种「响应」载荷，对齐上游 EventKind.isSourcePayload。 */
export function isSourcePayload(kind: DebugEventKind): boolean {
  return kind === 'SearchSource' || kind === 'InfoSource' ||
    kind === 'TocSource' || kind === 'ContentSource';
}

/** 过滤判据，逐字对齐上游 BookSourceDebugScreen.kt:58-61。 */
export function matchesFilter(entry: DebugEntry, filter: DebugFilter): boolean {
  if (filter === 'All') return true;
  if (filter === 'Messages') return entry.kind === 'Message' || entry.kind === 'Completed';
  if (filter === 'Sources') return isSourcePayload(entry.kind);
  return entry.kind === 'Error';
}

export function targetTitle(target: DebugTarget): string {
  if (target === 'Search') return '搜索';
  if (target === 'Explore') return '发现';
  if (target === 'Info') return '详情';
  if (target === 'Toc') return '目录';
  return '正文';
}

export function targetHint(target: DebugTarget): string {
  if (target === 'Search') return '搜索关键字';
  if (target === 'Explore') return '发现 URL';
  if (target === 'Info') return '详情页 URL';
  if (target === 'Toc') return '目录页 URL';
  return '正文页 URL';
}

export function filterTitle(filter: DebugFilter): string {
  if (filter === 'All') return '全部';
  if (filter === 'Messages') return '过程';
  if (filter === 'Sources') return '响应';
  return '错误';
}

export function kindTitle(kind: DebugEventKind): string {
  if (kind === 'Message') return '过程';
  // 上游 BookSourceDebugScreen.kt:286 SearchSource 标题就是「搜索/发现响应」，一个 kind 覆盖两条入口。
  if (kind === 'SearchSource') return '搜索/发现响应';
  if (kind === 'InfoSource') return '详情响应';
  if (kind === 'TocSource') return '目录响应';
  if (kind === 'ContentSource') return '正文响应';
  if (kind === 'Error') return '错误';
  return '完成';
}
