import {
  BOOK_INFO_BACKGROUND_OFF,
  BOOK_INFO_BACKGROUND_OFF_FOR_DEFAULT
} from './ThemeSettingsRepository';

/**
 * 书籍详情页背景封面样式。
 *
 * 与上游 `ui/book/info/BookInfoBackdropStyle.kt` 的 `BookInfoBackdropStyle` 逐字段对应：
 * `showCover` 是否显示背景封面、`blurCover` 是否模糊、`applySeedOverlay` 是否叠一层取色层。
 */
export class BookInfoBackdropStyle {
  showCover: boolean;
  blurCover: boolean;
  applySeedOverlay: boolean;

  constructor(showCover: boolean, blurCover: boolean, applySeedOverlay: boolean) {
    this.showCover = showCover;
    this.blurCover = blurCover;
    this.applySeedOverlay = applySeedOverlay;
  }
}

/**
 * 背景模式转样式，对齐上游 `BookInfoBackdropStyle.kt:9-30 resolveBookInfoBackdropStyle`：
 * `off` → 显示封面但不模糊、仍叠取色层；`off_for_default` → 什么都不显示；其余（`on`）→ 模糊 + 取色层。
 */
export function resolveBookInfoBackdropStyle(backgroundMode: string): BookInfoBackdropStyle {
  if (backgroundMode === BOOK_INFO_BACKGROUND_OFF) {
    return new BookInfoBackdropStyle(true, false, true);
  }
  if (backgroundMode === BOOK_INFO_BACKGROUND_OFF_FOR_DEFAULT) {
    return new BookInfoBackdropStyle(false, false, false);
  }
  return new BookInfoBackdropStyle(true, true, true);
}

/**
 * 按封面来源选背景模式。
 *
 * 上游 `BookInfoScreen.kt:863-875`：使用默认封面时读 `bookInfoDefaultCoverBackground`，
 * 否则读 `bookInfoNetworkCoverBackground`。本地没有内置默认封面图，一律走网络封面那一档。
 */
export function resolveBookInfoBackdropStyleFor(
  usesDefaultCover: boolean,
  defaultCoverBackground: string,
  networkCoverBackground: string
): BookInfoBackdropStyle {
  return resolveBookInfoBackdropStyle(usesDefaultCover ? defaultCoverBackground : networkCoverBackground);
}
