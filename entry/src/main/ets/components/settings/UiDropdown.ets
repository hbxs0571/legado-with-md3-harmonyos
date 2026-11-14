import { ThemeItemDivider } from '../ThemeItemDivider';
import curves from '@ohos.curves';
import { AppGlyph } from '../AppGlyph';
import {
  FONT_ROW_DETAIL, FONT_ROW_OPTION, FONT_ROW_TITLE, RADIUS_MENU, ROW_PADDING_H, ROW_PADDING_V, SPACE_2, SPACE_4
} from '../UiTokens';

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

  /** 菜单开闭状态，驱动右侧箭头旋转（bindMenu 的 onAppear/onDisappear 写它）。 */
  @State menuVisible: boolean = false;

  @Builder
  OptionMenu() {
    Menu() {
      ForEach(this.options, (item: string) => {
        // 菜单显示文案，回传的仍是原始值。
        MenuItem({ content: this.labelOf(item) })
          .height(48)
          .onClick(() => {
            this.onSelect(item);
          });
      }, (item: string) => item)
    }
    // 跟随主界面背景图与纯黑深色模式（两处原有实现都是这么处理的，不要写死单一底色）
    .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent :
      (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated))
    .fontColor(this.themeColorTextPrimary)
    .radius(RADIUS_MENU)
  }

  build() {
    Column() {
    Row() {
      Column() {
        Text(this.title).fontSize(FONT_ROW_TITLE).fontColor(this.themeColorTextPrimary).width('100%')
        if (this.detail.length > 0) {
          Text(this.detail)
            .fontSize(FONT_ROW_DETAIL)
            .fontColor(this.themeColorTextTertiary)
            .width('100%')
            .margin({ top: SPACE_2 });
        }
        Text(this.labelOf(this.option))
          .fontSize(FONT_ROW_OPTION)
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
    .bindMenu(this.OptionMenu, {
      placement: Placement.Bottom,
      onAppear: () => { this.menuVisible = true; },
      onDisappear: () => { this.menuVisible = false; }
    })
      if (this.showDivider) {
        ThemeItemDivider()
      }
    }.width('100%')
  }
}
