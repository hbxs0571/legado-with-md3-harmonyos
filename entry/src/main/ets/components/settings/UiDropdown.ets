import { BODY_SMALL_EMPHASIZED, LABEL_MEDIUM_EMPHASIZED, TITLE_MEDIUM } from '../typography/TypographyTokens';

import { ThemeItemDivider } from '../ThemeItemDivider';
import curves from '@ohos.curves';
import { AppGlyph } from '../AppGlyph';
import { UiMenuItem, UiMenuPanel } from '../UiMenu';
import { ROW_PADDING_H, ROW_PADDING_V, SPACE_2, SPACE_4 } from '../UiTokens';

/** 卡片式菜单面板宽；上游由内容驱动，本地给固定宽。 */
const DROPDOWN_MENU_WIDTH: number = 260;

/**
 * 设置行：点一下弹菜单选值。当前值显示在标题下方的副行（与上游 DropdownListSettingItem 一致）。
 *
 * 值→文案的映射由 labelOf 注入，默认原样显示：OtherSettingsDropdown 传的就是中文文案本身；
 * ThemeSettingsDropdown 传的是枚举值（on / off / #3F5BD9 之类），必须注入映射。
 */
@Component
export struct UiDropdown {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;

  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop option: string = '';
  @Prop options: string[] = [];
  @Prop showDivider: boolean = true;

  /** 值→显示文案。默认原样返回，给「options 里本来就是中文」的页面用。 */
  labelOf: (value: string) => string = (value: string) => value;
  onSelect: (value: string) => void = (_value: string) => {};

  /** 菜单开闭状态，驱动右侧箭头旋转（bindPopup 的 onStateChange 与本行点击都写它）。 */
  @State menuVisible: boolean = false;

  /** options → 面板条目。菜单显示文案，key 回传的仍是原始值；当前值带勾。 */
  private menuItems(): UiMenuItem[] {
    const result: UiMenuItem[] = [];
    for (const item of this.options) {
      result.push({ key: item, title: this.labelOf(item), selected: item === this.option });
    }
    return result;
  }

  @Builder
  OptionMenu() {
    UiMenuPanel({
      items: this.menuItems(),
      panelWidth: DROPDOWN_MENU_WIDTH,
      onSelect: (key: string) => {
        this.menuVisible = false;
        this.onSelect(key);
      }
    })
  }

  /**
   * 按压时的整行底色：照 UiAction 用强调色 15% alpha，避免满宽行缩放挤内容。
   * 主题色不是 #RRGGBB 时退回 surfaceContainer。
   */
  private pressedBackground(): string {
    const accent = this.themeColorAccent;
    if (accent.length === 7 && accent.charAt(0) === '#') {
      return '#26' + accent.substring(1);
    }
    return this.themeColorSurfaceTertiary;
  }

  build() {
    Column() {
    Row() {
      Column() {
        Text(this.title).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).width('100%')
        if (this.detail.length > 0) {
          Text(this.detail)
            .fontSize(BODY_SMALL_EMPHASIZED).fontWeight(FontWeight.Medium)
            .fontColor(this.themeColorTextTertiary)
            .width('100%')
            .margin({ top: SPACE_2 });
        }
        Text(this.labelOf(this.option))
          .fontSize(LABEL_MEDIUM_EMPHASIZED).fontWeight(FontWeight.Medium)
          .fontColor(this.themeColorAccent)
          .width('100%')
          .margin({ top: SPACE_4 });
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      AppGlyph({ name: 'profileExpandMore', glyphSize: 22, tint: this.themeColorTextTertiary })
        .rotate({ angle: this.menuVisible ? 180 : 0 })
        .animation({ curve: curves.springMotion(0.35, 0.9) });
    }
    .width('100%')
    .padding({ left: ROW_PADDING_H, right: ROW_PADDING_H, top: ROW_PADDING_V, bottom: ROW_PADDING_V })
    .stateStyles({
      pressed: { .backgroundColor(this.pressedBackground()) },
      normal: { .backgroundColor(Color.Transparent) }
    })

    .onClick(() => { this.menuVisible = !this.menuVisible; })
    // 整行合并成一个无障碍节点：上游 `SettingItem.kt:84` 的 `.semantics(mergeDescendants = true)`。
    .accessibilityGroup(true)
    .bindPopup(this.menuVisible, {
      builder: this.OptionMenu,
      placement: Placement.Bottom,
      popupColor: '#00000000',
      enableArrow: false,
      autoCancel: true,
      width: DROPDOWN_MENU_WIDTH,
      onStateChange: (event: PopupStateChangeParam) => { this.menuVisible = event.isVisible; }
    })
      if (this.showDivider) {
        ThemeItemDivider()
      }
    }.width('100%')
  }
}
