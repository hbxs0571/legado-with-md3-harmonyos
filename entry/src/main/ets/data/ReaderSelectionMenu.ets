/**
 * 划词菜单条目模型与配置串编解码。
 *
 * 上游 `ui/book/read/ReadBookController.kt:3316` 的 `ActionMenuItem` 有 `id`/`title`/`showState`
 * 三个关键字段，`showState` 取 0（一级）/ 1（折叠）/ 2（隐藏）；持久化格式见同文件 `:3351`
 * `data class SelectionMenuConfigItem(val id: String, val enabled: Boolean?, val showState: Int?)`，
 * 由 `:2246` `saveMenuConfig` 写出、`:2204` 读回，存进 `ReadSettings.textSelectMenuConfig`。
 *
 * 本地只保留两端都确认存在的 14 个内置条目（`R.id.menu_*` → `menu_*`），不额外发明条目。
 */

/** 菜单条目。`group` 与上游 `showState` 同义：0 一级、1 折叠、2 隐藏。 */
export interface ReaderSelectionMenuItem {
  id: string;
  title: string;
  group: number;
}

/** 配置串里单条记录的形状，字段与上游 `SelectionMenuConfigItem` 一一对应，全部可选以容纳旧配置。 */
interface SelectionMenuConfigRecord {
  id?: string;
  enabled?: boolean;
  showState?: number;
}

/**
 * 内置条目的出厂顺序，与上游 `getActionMenuItems()` 的 items 顺序一致。
 * 前 3 项是本地已有真实能力的（复制 / 书签 / 划线笔记），其余 11 项上游有实现、本地尚无能力，
 * 在配置面板里照常列出（配置项本身是真实的，可分组可排序可隐藏），但不会出现在阅读页菜单里，
 * 避免给出点了没有反应的假按钮。
 */
export const READER_SELECTION_MENU_DEFAULTS: ReaderSelectionMenuItem[] = [
  { id: 'menu_copy', title: '复制', group: 0 },
  { id: 'menu_bookmark', title: '书签', group: 0 },
  { id: 'menu_mark', title: '划线 / 笔记', group: 0 },
  { id: 'menu_share_str', title: '分享', group: 0 },
  { id: 'menu_browser', title: '浏览器', group: 0 },
  { id: 'menu_aloud', title: '朗读', group: 0 },
  { id: 'menu_dict', title: '字典', group: 0 },
  { id: 'menu_replace', title: '替换', group: 0 },
  { id: 'menu_edit', title: '编辑', group: 0 },
  { id: 'menu_ai_clean', title: 'AI 净化', group: 0 },
  { id: 'menu_ai_rewrite', title: 'AI 改写', group: 0 },
  { id: 'menu_search_content', title: '全文搜索', group: 0 },
  { id: 'menu_insert_bgm_before', title: '插入(前)', group: 0 },
  { id: 'menu_insert_bgm_after', title: '插入(后)', group: 0 }
];

/**
 * 本地已有真实处理函数的条目 id。
 * 只有这些会出现在阅读页的划词菜单里；配置面板对全部条目开放编辑。
 */
export const READER_SELECTION_MENU_SUPPORTED: string[] = ['menu_copy', 'menu_bookmark', 'menu_mark'];

/** 出厂条目表的一份拷贝，调用方可以放心改。 */
export function defaultReaderSelectionMenuItems(): ReaderSelectionMenuItem[] {
  return READER_SELECTION_MENU_DEFAULTS.map((item: ReaderSelectionMenuItem): ReaderSelectionMenuItem => {
    const copy: ReaderSelectionMenuItem = { id: item.id, title: item.title, group: item.group };
    return copy;
  });
}

/** 把配置串解析成条目表；空串、坏 JSON、坏条目都回落到出厂顺序，对齐上游 `getOrDefault(allItems)`。 */
export function parseReaderSelectionMenuConfig(
  config: string,
  fallback: ReaderSelectionMenuItem[] = defaultReaderSelectionMenuItems()
): ReaderSelectionMenuItem[] {
  if (config.length === 0) {
    return fallback;
  }
  let saved: SelectionMenuConfigRecord[] | null = null;
  try {
    const parsed = JSON.parse(config) as SelectionMenuConfigRecord[];
    if (!Array.isArray(parsed)) {
      return fallback;
    }
    saved = parsed;
  } catch (_) {
    return fallback;
  }
  if (saved === null) {
    return fallback;
  }
  const known: Map<string, ReaderSelectionMenuItem> = new Map<string, ReaderSelectionMenuItem>();
  for (let index = 0; index < fallback.length; index++) {
    const item = fallback[index];
    if (item !== undefined) {
      known.set(item.id, item);
    }
  }
  // 上游保持配置里已存在条目的顺序，再把配置里没提到的条目追加到末尾（新增条目不能因为旧配置而消失）。
  const ordered: ReaderSelectionMenuItem[] = [];
  const seen: Set<string> = new Set<string>();
  for (let index = 0; index < saved.length; index++) {
    const record = saved[index];
    if (record === undefined || record === null) {
      continue;
    }
    const id = record.id;
    if (typeof id !== 'string' || seen.has(id)) {
      continue;
    }
    const base = known.get(id);
    if (base === undefined) {
      // 配置里出现本地已经不认识的 id（上游被删除的条目），直接跳过。
      continue;
    }
    seen.add(id);
    const item: ReaderSelectionMenuItem = { id: base.id, title: base.title, group: resolveShowState(record) };
    ordered.push(item);
  }
  for (let index = 0; index < fallback.length; index++) {
    const item = fallback[index];
    if (item !== undefined && !seen.has(item.id)) {
      ordered.push(item);
    }
  }
  return ordered;
}

/**
 * 取某条的 showState。上游兼容两种写法：显式 `showState`，
 * 或早期只有 `enabled` 的配置（`enabled == false` 视为 `1` 折叠），见 `ReadBookController.kt:2213-2214`。
 */
function resolveShowState(record: SelectionMenuConfigRecord): number {
  const rawShowState = record.showState;
  if (typeof rawShowState === 'number' && Number.isFinite(rawShowState)) {
    const rounded = Math.round(rawShowState);
    if (rounded === 0 || rounded === 1 || rounded === 2) {
      return rounded;
    }
    return 0;
  }
  const rawEnabled = record.enabled;
  if (typeof rawEnabled === 'boolean') {
    return rawEnabled ? 0 : 1;
  }
  return 0;
}

/** 把条目表序列化成上游能读的配置串，字段与 `SelectionMenuConfigItem` 一一对应。 */
export function serializeReaderSelectionMenuConfig(items: ReaderSelectionMenuItem[]): string {
  const payload: SelectionMenuConfigRecord[] = [];
  for (let index = 0; index < items.length; index++) {
    const item = items[index];
    if (item === undefined) {
      continue;
    }
    const group = item.group === 1 || item.group === 2 ? item.group : 0;
    const record: SelectionMenuConfigRecord = {
      id: item.id,
      enabled: group === 0,
      showState: group
    };
    payload.push(record);
  }
  try {
    return JSON.stringify(payload);
  } catch (_) {
    return '';
  }
}
