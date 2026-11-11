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
  /** 标题居中。对应上游 PreferKey.bookshelfTitleCenter，上游默认 true。 */
  bookshelfTitleCenter: boolean;
  /** 标题用小字号。对应上游 PreferKey.bookshelfTitleSmallFont。 */
  bookshelfTitleSmallFont: boolean;
  /** 网格封面宽度上限（vp）。对应上游 PreferKey.bookshelfGridCoverWidth，默认 120。 */
  bookshelfGridCoverWidth: number;
  /** 列表封面宽度（vp）。对应上游 PreferKey.bookshelfListCoverWidth，默认 84。 */
  bookshelfListCoverWidth: number;
  /** 网格样式：0 标准，1 紧凑（标题进封面），2 仅封面。对应上游 PreferKey 字符串值 bookshelfGridLayout。 */
  bookshelfGridLayout: number;
  /** 精简详情，开启后卡片只留封面与书名。对应上游 PreferKey 字符串值 bookshelfLayoutCompact。 */
  bookshelfLayoutCompact: boolean;
  /** 日间卡片底色，0 为跟随主题。对应上游 PreferKey 字符串值 bookshelfCardColor。 */
  bookshelfCardColor: number;
  /** 夜间卡片底色，0 为跟随主题。对应上游 PreferKey 字符串值 bookshelfCardColorDark。 */
  bookshelfCardColorDark: number;
  /** 列表模式显示分隔线。对应上游 PreferKey 字符串值 bookshelfShowDivider。 */
  bookshelfShowDivider: boolean;
  /** 列表模式封面垂直居中。对应上游 PreferKey 字符串值 bookshelfListCoverCenter。 */
  bookshelfListCoverCenter: boolean;
  /** 列表模式简介显示在书名下方。对应上游 PreferKey 字符串值 bookshelfListIntroBelowContent。 */
  bookshelfListIntroBelowContent: boolean;
  /** 列表模式显示简介。对应上游 PreferKey 字符串值 bookshelfShowIntro。 */
  bookshelfShowIntro: boolean;
  /** 列表模式显示最新章节。对应上游 PreferKey 字符串值 bookshelfShowLatestChapter。 */
  bookshelfShowLatestChapter: boolean;
  /** 列表模式简介最大行数，0 为不限制。对应上游 PreferKey 字符串值 bookshelfIntroMaxLines。 */
  bookshelfIntroMaxLines: number;
  /** 搜索按钮点击直接进搜索页（关闭则点击先进筛选）。对应上游 PreferKey 字符串值 bookshelfSearchActionDirectToSearch。 */
  bookshelfSearchActionDirectToSearch: boolean;
  /** 书架显示快速滚动条。对应上游 PreferKey 字符串值 showBookshelfFastScroller。 */
  showBookshelfFastScroller: boolean;
  /** 进书架时自动刷新目录，上游键名为 auto_refresh。对应上游 PreferKey 字符串值 auto_refresh。 */
  autoRefreshBook: boolean;
  /** 记住上次所在分组，上游写入键为 bookshelfSelectedGroupId。对应上游 PreferKey 字符串值 bookshelfSelectedGroupId。 */
  saveTabPosition: string;
  /** 横屏布局模式：0 列表，1 网格，上游键名为 bookshelf_layout_landscape。对应上游 PreferKey 字符串值 bookshelf_layout_landscape。 */
  bookshelfLayoutModeLandscape: number;
  /** 横屏网格列数。对应上游 PreferKey 字符串值 bookshelfLayoutGridLandscape。 */
  bookshelfLayoutGridLandscape: number;
  /** 横屏列表每屏行数。对应上游 PreferKey 字符串值 bookshelfLayoutListLandscape。 */
  bookshelfLayoutListLandscape: number;
  /** 文件夹竖屏布局模式。对应上游 PreferKey 字符串值 bookshelfFolderLayoutModePortrait。 */
  bookshelfFolderLayoutModePortrait: number;
  /** 文件夹横屏布局模式。对应上游 PreferKey 字符串值 bookshelfFolderLayoutModeLandscape。 */
  bookshelfFolderLayoutModeLandscape: number;
  /** 文件夹竖屏网格列数。对应上游 PreferKey 字符串值 bookshelfFolderLayoutGridPortrait。 */
  bookshelfFolderLayoutGridPortrait: number;
  /** 文件夹横屏网格列数。对应上游 PreferKey 字符串值 bookshelfFolderLayoutGridLandscape。 */
  bookshelfFolderLayoutGridLandscape: number;
  /** 文件夹竖屏列表行数。对应上游 PreferKey 字符串值 bookshelfFolderLayoutListPortrait。 */
  bookshelfFolderLayoutListPortrait: number;
  /** 文件夹横屏列表行数。对应上游 PreferKey 字符串值 bookshelfFolderLayoutListLandscape。 */
  bookshelfFolderLayoutListLandscape: number;
  /** 分组列表样式：0 分组，1 紧凑列表，2 横排封面数量。对应上游 PreferKey 字符串值 bookshelfGroupListStyle。 */
  bookshelfGroupListStyle: number;
  /** 分组卡片横排封面数量。对应上游 PreferKey 字符串值 bookshelfGroupCoverCount。 */
  bookshelfGroupCoverCount: number;
  /** 列表模式显示详情区总开关（封面垂直居中/最新章节/简介/简介行数四项的外层）。
   *  对应上游 PreferKey.showBookIntro，默认 false；不在 bookshelfPrefKeys 39 键内，备份时无条件写出。 */
  showBookIntro: boolean;
  /** 批量更新数量限制，0 为不限制。对应上游 PreferKey 字符串值 bookshelfRefreshingLimit。 */
  bookshelfRefreshingLimit: number;
  /** 页签栏右端分组管理按钮是否显示。上游键名 shouldShowExpandButton，默认 true。 */
  showBookshelfTabMenu: boolean;
  /** 是否显示书籍标签行；上游键名 bookshelfShowTag，默认 true。 */
  bookshelfShowTag: boolean;
  /** 标签行是否含自定义标签；上游键名 bookshelfShowCustomTags，默认 true。 */
  bookshelfShowCustomTags: boolean;
  /** 标签行是否含来源分类；上游键名 bookshelfShowSourceTags，默认 true。 */
  bookshelfShowSourceTags: boolean;
  /** 标签行是否含字数；上游键名 bookshelfShowWordCount，默认 true。 */
  bookshelfShowWordCount: boolean;
  /** 是否显示未读章节数；上游键名 showUnread，默认 true。 */
  showUnread: boolean;
  /** 是否显示更新红点（与 showUnread 耦合）；上游键名 showUnreadNew，默认 true。 */
  showUnreadNew: boolean;
  /** 是否显示标题级待更新数；上游键名 showWaitUpCount，默认 false。 */
  showWaitUpCount: boolean;
  /** 分组卡是否显示书籍计数；上游键名 showBookCount，默认 true。 */
  showBookCount: boolean;
  /** 是否显示最后更新时间；上游键名 showLastUpdateTime，默认 false。 */
  showLastUpdateTime: boolean;
  /** 是否显示书籍类型标签；上游键名 showTip，默认 false。 */
  showTip: boolean;
}

/** 下拉选项的通用结构。 */
export interface BookshelfLayoutOption {
  value: number;
  label: string;
}

/** 分组样式选项，对应上游 R.array.group_style 三档（标签 / 隐藏标签 / 文件夹）。 */
export const BOOK_GROUP_STYLE_OPTIONS: BookshelfLayoutOption[] = [
  { value: 0, label: '页签' },
  { value: 1, label: '隐藏页签' },
  { value: 2, label: '文件夹' }
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

/** 文件夹布局模式选项，对应上游 BOOKSHELF_LAYOUT_MODE_OPTIONS 的列表 / 网格。 */
export const BOOKSHELF_FOLDER_LAYOUT_MODE_OPTIONS: BookshelfLayoutOption[] = [
  { value: 0, label: '列表' },
  { value: 1, label: '网格' }
];

/** 文件夹列表样式三档，对应上游 BookshelfConfigSheet.kt:220-226 的 entryValues "0"/"1"/"2"。 */
export const BOOKSHELF_GROUP_LIST_STYLE_OPTIONS: BookshelfLayoutOption[] = [
  { value: 0, label: '分组' },
  { value: 1, label: '紧凑列表' },
  { value: 2, label: '横排封面数量' }
];

/**
 * 默认值。
 *
 * 逐项对齐上游 app/src/main/java/io/legado/app/data/repository/BookshelfSettingsRepository.kt
 * 的 toBookshelfSettings()：排序 0/倒序 1、竖屏网格、网格 3 列、列表 1 行、标题 2 行、
 * 隐藏空分组 true、封面阴影 false。
 * 封面宽度默认值取上游 BookshelfSettingsRepository.kt:82-83 的 120 / 84；
 * 标题居中 true、小字号 false 也来自上游同名键的默认值。
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
  bookshelfCoverShadow: false,
  bookshelfTitleCenter: true,
  bookshelfTitleSmallFont: false,
  bookshelfGridCoverWidth: 120,
  bookshelfListCoverWidth: 84,
  bookshelfGridLayout: 0,
  bookshelfLayoutCompact: false,
  bookshelfCardColor: 0,
  bookshelfCardColorDark: 0,
  bookshelfShowDivider: true,
  bookshelfListCoverCenter: true,
  bookshelfListIntroBelowContent: false,
  bookshelfShowIntro: true,
  bookshelfShowLatestChapter: true,
  bookshelfIntroMaxLines: 0,
  bookshelfSearchActionDirectToSearch: true,
  showBookshelfFastScroller: false,
  autoRefreshBook: false,
  saveTabPosition: '全部',
  bookshelfLayoutModeLandscape: 1,
  bookshelfLayoutGridLandscape: 7,
  bookshelfLayoutListLandscape: 1,
  bookshelfFolderLayoutModePortrait: 1,
  bookshelfFolderLayoutModeLandscape: 1,
  bookshelfFolderLayoutGridPortrait: 3,
  bookshelfFolderLayoutGridLandscape: 7,
  bookshelfFolderLayoutListPortrait: 1,
  bookshelfFolderLayoutListLandscape: 1,
  bookshelfGroupListStyle: 0,
  bookshelfGroupCoverCount: 4,
  showBookIntro: false,
  bookshelfRefreshingLimit: 0,
  showBookshelfTabMenu: true,
  bookshelfShowTag: true,
  bookshelfShowCustomTags: true,
  bookshelfShowSourceTags: true,
  bookshelfShowWordCount: true,
  showUnread: true,
  showUnreadNew: true,
  showWaitUpCount: false,
  showBookCount: true,
  showLastUpdateTime: false,
  showTip: false,
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
    bookshelfCoverShadow: settings.bookshelfCoverShadow,
    bookshelfTitleCenter: settings.bookshelfTitleCenter,
    bookshelfTitleSmallFont: settings.bookshelfTitleSmallFont,
    bookshelfGridCoverWidth: settings.bookshelfGridCoverWidth,
    bookshelfListCoverWidth: settings.bookshelfListCoverWidth,
    bookshelfGridLayout: settings.bookshelfGridLayout,
    bookshelfLayoutCompact: settings.bookshelfLayoutCompact,
    bookshelfCardColor: settings.bookshelfCardColor,
    bookshelfCardColorDark: settings.bookshelfCardColorDark,
    bookshelfShowDivider: settings.bookshelfShowDivider,
    bookshelfListCoverCenter: settings.bookshelfListCoverCenter,
    bookshelfListIntroBelowContent: settings.bookshelfListIntroBelowContent,
    bookshelfShowIntro: settings.bookshelfShowIntro,
    bookshelfShowLatestChapter: settings.bookshelfShowLatestChapter,
    bookshelfIntroMaxLines: settings.bookshelfIntroMaxLines,
    bookshelfSearchActionDirectToSearch: settings.bookshelfSearchActionDirectToSearch,
    showBookshelfFastScroller: settings.showBookshelfFastScroller,
    autoRefreshBook: settings.autoRefreshBook,
    saveTabPosition: settings.saveTabPosition,
    bookshelfLayoutModeLandscape: settings.bookshelfLayoutModeLandscape,
    bookshelfLayoutGridLandscape: settings.bookshelfLayoutGridLandscape,
    bookshelfLayoutListLandscape: settings.bookshelfLayoutListLandscape,
    bookshelfFolderLayoutModePortrait: settings.bookshelfFolderLayoutModePortrait,
    bookshelfFolderLayoutModeLandscape: settings.bookshelfFolderLayoutModeLandscape,
    bookshelfFolderLayoutGridPortrait: settings.bookshelfFolderLayoutGridPortrait,
    bookshelfFolderLayoutGridLandscape: settings.bookshelfFolderLayoutGridLandscape,
    bookshelfFolderLayoutListPortrait: settings.bookshelfFolderLayoutListPortrait,
    bookshelfFolderLayoutListLandscape: settings.bookshelfFolderLayoutListLandscape,
    bookshelfGroupListStyle: settings.bookshelfGroupListStyle,
    bookshelfGroupCoverCount: settings.bookshelfGroupCoverCount,
    showBookIntro: settings.showBookIntro,
    bookshelfRefreshingLimit: settings.bookshelfRefreshingLimit,
    showBookshelfTabMenu: settings.showBookshelfTabMenu,
    bookshelfShowTag: settings.bookshelfShowTag,
    bookshelfShowCustomTags: settings.bookshelfShowCustomTags,
    bookshelfShowSourceTags: settings.bookshelfShowSourceTags,
    bookshelfShowWordCount: settings.bookshelfShowWordCount,
    showUnread: settings.showUnread,
    showUnreadNew: settings.showUnreadNew,
    showWaitUpCount: settings.showWaitUpCount,
    showBookCount: settings.showBookCount,
    showLastUpdateTime: settings.showLastUpdateTime,
    showTip: settings.showTip,
  };
}
