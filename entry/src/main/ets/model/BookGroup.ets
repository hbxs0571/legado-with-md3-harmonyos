/** 与 Android BookGroup 对应的可见分组元数据。 */
export interface BookGroup {
  groupId: number;
  groupName: string;
  order: number;
  show: boolean;
  enableRefresh: boolean;
  bookSort: number;
  isPrivate: boolean;
  /** 用户为分组指定的封面路径，对应 Android BookGroup.cover。 */
  cover?: string;
}

/**
 * 新建或编辑分组时提交的草稿。
 *
 * 与 BookGroup 分开是因为 order 与 groupId 由仓储分配，调用方不该参与决定。
 */
export interface BookGroupDraft {
  groupName: string;
  enableRefresh: boolean;
  bookSort: number;
  isPrivate: boolean;
  cover?: string;
}

/** 分组排序方式，取值与 Android R.array.book_sort 的 entryValues 一致。 */
export interface BookSortOption {
  value: number;
  label: string;
}

/**
 * 排序选项。
 *
 * 上游 R.array.book_sort 第一项是「默认」，entryValues 由 -1 起递增，
 * 因此这里同样用 -1 表示跟随书架默认排序，0–5 对应上游六种具体方式。
 */
export const BOOK_SORT_OPTIONS: BookSortOption[] = [
  { value: -1, label: '默认' },
  { value: 0, label: '按最近列表' },
  { value: 1, label: '按更新时间' },
  { value: 2, label: '按书名' },
  { value: 3, label: '手动排序' },
  { value: 4, label: '综合排序' },
  { value: 5, label: '按作者' }
];

/** 把排序值翻成界面文案；未知值按「默认」显示。 */
export function bookSortLabel(value: number): string {
  const matched = BOOK_SORT_OPTIONS.find((option: BookSortOption) => option.value === value);
  return matched === undefined ? '默认' : matched.label;
}
