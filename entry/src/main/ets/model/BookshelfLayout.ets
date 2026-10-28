/**
 * 书架布局设置。
 *
 * 字段名与 Android PreferKey 保持一致，备份写入 config.xml 时可直接用同名字段，
 * 恢复时也能被 Android 端原样读回。
 */
export interface BookshelfLayoutSettings {
  /** 分组样式：0 页签，1 隐藏页签。对应上游 PreferKey.bookGroupStyle。 */
  bookGroupStyle: number;
  /** 隐藏没有书籍的分组页签。对应上游 PreferKey.hideEmptyGroups。 */
  hideEmptyGroups: boolean;
  /** 书架全局排序方式。对应上游 PreferKey.bookshelfSort。 */
  bookshelfSort: number;
  /** 书架全局排序方向，1 为倒序。对应上游 PreferKey.bookshelfSortOrder。 */
  bookshelfSortOrder: number;
  /** 竖屏布局模式：0 列表，1 网格。对应上游 PreferKey.bookshelfLayoutModePortrait。 */
  bookshelfLayoutModePortrait: number;
  /** 竖屏网格列数。对应上游 PreferKey.bookshelfLayoutGridPortrait。 */
  bookshelfLayoutGridPortrait: number;
  /** 竖屏列表每屏行数。对应上游 PreferKey.bookshelfLayoutListPortrait。 */
  bookshelfLayoutListPortrait: number;
  /** 书封标题最大行数。对应上游 PreferKey.bookshelfTitleMaxLines。 */
  bookshelfTitleMaxLines: number;
  /** 书封阴影。对应上游 PreferKey.bookshelfCoverShadow。 */
  bookshelfCoverShadow: boolean;
}

/** 下拉选项的通用结构。 */
export interface BookshelfLayoutOption {
  value: number;
  label: string;
}

/** 分组样式选项，对应上游 R.array.group_style 的前两项。 */
export const BOOK_GROUP_STYLE_OPTIONS: BookshelfLayoutOption[] = [
  { value: 0, label: '页签' },
  { value: 1, label: '隐藏页签' }
];

/** 布局模式选项，对应上游 R.string.layout_mode_list / layout_mode_grid。 */
export const BOOKSHELF_LAYOUT_MODE_OPTIONS: BookshelfLayoutOption[] = [
  { value: 0, label: '列表' },
  { value: 1, label: '网格' }
];

/** 排序方向选项，对应上游 R.string.ascending_order / descending_order。 */
export const BOOKSHELF_SORT_ORDER_OPTIONS: BookshelfLayoutOption[] = [
  { value: 0, label: '升序' },
  { value: 1, label: '降序' }
];

/**
 * 默认值。
 *
 * 逐项对齐上游 app/src/main/java/io/legado/app/data/repository/BookshelfSettingsRepository.kt
 * 的 toBookshelfSettings()：排序 0/倒序 1、竖屏网格、网格 3 列、列表 1 行、标题 2 行、
 * 隐藏空分组 true、封面阴影 false。
 */
export const DEFAULT_BOOKSHELF_LAYOUT: BookshelfLayoutSettings = {
  bookGroupStyle: 0,
  hideEmptyGroups: true,
  bookshelfSort: 0,
  bookshelfSortOrder: 1,
  bookshelfLayoutModePortrait: 1,
  bookshelfLayoutGridPortrait: 3,
  bookshelfLayoutListPortrait: 1,
  bookshelfTitleMaxLines: 2,
  bookshelfCoverShadow: false
};

/** 按值取文案，未知值返回空串由调用方兜底。 */
export function bookshelfLayoutOptionLabel(options: BookshelfLayoutOption[], value: number): string {
  const matched = options.find((option: BookshelfLayoutOption) => option.value === value);
  return matched === undefined ? '' : matched.label;
}

/** 复制一份，避免 @State 直接持有常量对象被就地修改。 */
export function copyBookshelfLayout(settings: BookshelfLayoutSettings): BookshelfLayoutSettings {
  return {
    bookGroupStyle: settings.bookGroupStyle,
    hideEmptyGroups: settings.hideEmptyGroups,
    bookshelfSort: settings.bookshelfSort,
    bookshelfSortOrder: settings.bookshelfSortOrder,
    bookshelfLayoutModePortrait: settings.bookshelfLayoutModePortrait,
    bookshelfLayoutGridPortrait: settings.bookshelfLayoutGridPortrait,
    bookshelfLayoutListPortrait: settings.bookshelfLayoutListPortrait,
    bookshelfTitleMaxLines: settings.bookshelfTitleMaxLines,
    bookshelfCoverShadow: settings.bookshelfCoverShadow
  };
}
