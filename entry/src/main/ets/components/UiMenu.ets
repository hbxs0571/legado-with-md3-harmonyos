// 卡片式菜单：对齐上游 RoundDropdownMenu / RoundDropdownMenuItem 的两层结构。
// 外层容器是「稍亮一档的表面色」，每一项是「更深一档的表面色」独立圆角卡片。

import { display } from '@kit.ArkUI';
import { AppGlyph, AppGlyphName } from './AppGlyph';

/** 一个菜单项。key 由调用方定义，面板只负责把它回传。 */
export interface UiMenuItem {
  key: string;
  title: string;
  /** 右侧打勾。上游不是「不画勾」而是「画一个透明的勾」，这样有无勾行宽不变。 */
  selected?: boolean;
  disabled?: boolean;
  /** 左端图标，对齐上游 RoundDropdownMenuItem 的 leadingIcon。 */
  icon?: AppGlyphName;
}

/** 容器圆角，对齐上游 shapes.medium。 */
const MENU_CORNER: number = 16;
/** 项圆角，对齐上游 shapes.small。 */
const MENU_ITEM_CORNER: number = 8;
/** 项最小高，对齐上游 heightIn(min = 48.dp)。 */
const MENU_ITEM_MIN_HEIGHT: number = 48;
/** 项间间距，对齐上游 Arrangement.spacedBy(8.dp)。 */
const MENU_ITEM_GAP: number = 8;
/** 容器上下内边距，对齐 DropdownMenu 默认 8dp。 */
const MENU_PADDING_V: number = 8;
/** 项左右外边距，对齐上游 modifier.padding(horizontal = 8.dp)。 */
const MENU_PADDING_H: number = 8;
/** 项内边距，对齐 MenuDefaults.DropdownMenuItemContentPadding。 */
const MENU_ITEM_PADDING_H: number = 12;
const MENU_ITEM_PADDING_V: number = 12;
/** 文字与勾之间的间隙，对齐上游 Box(weight = 1f) 后接勾。 */
const MENU_TEXT_CHECK_GAP: number = 8;
/** 文字字号，对齐上游 labelLargeEmphasized。 */
const MENU_FONT_SIZE: number = 14;
/** 勾尺寸，对齐上游 size = 18.dp。 */
const MENU_CHECK_SIZE: number = 18;
/** 左端图标尺寸，与勾同口径。 */
const MENU_ICON_SIZE: number = 18;
/** 禁用整项透明度，对齐上游 alpha = 0.38f。 */
const MENU_DISABLED_OPACITY: number = 0.38;
/** 面板高度上限占屏高比例；超过则内部滚动。 */
const MENU_MAX_SCREEN_RATIO: number = 0.7;
/** 面板阴影半径，对齐上游 RoundDropdownMenu.kt:57 的 `shadowElevation = 4.dp`。 */
const MENU_SHADOW_RADIUS: number = 4;

/**
 * 卡片式菜单面板。
 *
 * 面板自己不关自己：显隐状态在调用方页面里，`onSelect` 回调里一起关，
 * 否则要为「关闭」再加一个回调。
 */
@Component
export struct UiMenuPanel {
  @Prop items: UiMenuItem[] = [];
  @Prop panelWidth: number = 260;
  /** 点中某一项。面板自己不关自己，关闭由调用方在回调里做。 */
  onSelect: (key: string) => void = () => {};

  // 容器 = surfaceContainerLow → 本地 themeColorSurfaceSecondary
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  // 卡片 = surface → 本地 themeColorSurfacePrimary
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#4C6FFF';

  /** 高度上限按屏高 70% 算，保证 19 项的长菜单不会顶出屏幕。 */
  private maxPanelHeight(): number {
    try {
      return this.getUIContext().px2vp(display.getDefaultDisplaySync().height) * MENU_MAX_SCREEN_RATIO;
    } catch (_) {
      return 560;
    }
  }

  @Builder
  MenuItemRow(item: UiMenuItem) {
    Row({ space: MENU_TEXT_CHECK_GAP }) {
      // 有图标时才画，避免无图标的菜单整体右移。
      if (item.icon !== undefined) {
        AppGlyph({
          name: item.icon,
          glyphSize: MENU_ICON_SIZE,
          tint: item.selected ? this.themeColorAccent : this.themeColorTextPrimary
        })
      }
      Text(item.title)
        .fontSize(MENU_FONT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(item.selected ? this.themeColorAccent : this.themeColorTextPrimary)
        .textAlign(TextAlign.Start)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      // 未选中时画一个透明的勾：这样有无勾的行宽与文字右边界完全一致。
      AppGlyph({
        name: 'profileCheck',
        glyphSize: MENU_CHECK_SIZE,
        tint: item.selected ? this.themeColorAccent : '#00000000'
      })
    }
    .width('100%')
    .constraintSize({ minHeight: MENU_ITEM_MIN_HEIGHT })
    .padding({
      left: MENU_ITEM_PADDING_H,
      right: MENU_ITEM_PADDING_H,
      top: MENU_ITEM_PADDING_V,
      bottom: MENU_ITEM_PADDING_V
    })
    .borderRadius(MENU_ITEM_CORNER)
    .backgroundColor(this.themeColorSurfacePrimary)
    .opacity(item.disabled ? MENU_DISABLED_OPACITY : 1)
    // 按压反馈用轻缩放而不是换底色：菜单项底色（surface）与可用的「深一档」
    // （surfaceContainer）在深色主题下只差 1 级，肉眼分不出来。
    // scale 取 0.97 而不是 LIGHT 默认的 0.9：菜单项是满宽行，缩 10% 两侧会露出菜单底色。
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    .onClick(() => {
      if (item.disabled) {
        return;
      }
      this.onSelect(item.key);
    })
  }

  build() {
    Scroll() {
      Column({ space: MENU_ITEM_GAP }) {
        ForEach(this.items, (item: UiMenuItem) => {
          this.MenuItemRow(item)
        }, (item: UiMenuItem) => item.key)
      }
      .width('100%')
      .padding({ top: MENU_PADDING_V, bottom: MENU_PADDING_V, left: MENU_PADDING_H, right: MENU_PADDING_H })
    }
    .width(this.panelWidth)
    .constraintSize({ maxHeight: this.maxPanelHeight() })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .align(Alignment.Top)
    .backgroundColor(this.themeColorSurfaceSecondary)
    .borderRadius(MENU_CORNER)
    // 阴影 4dp：上游 RoundDropdownMenu.kt:57 的 `shadowElevation = 4.dp`。
    // 改前整个组件没有任何阴影，菜单贴在背景上没有「浮起来」的层次。
    .shadow({ radius: MENU_SHADOW_RADIUS, color: '#40000000', offsetX: 0, offsetY: 2 })
  }
}
