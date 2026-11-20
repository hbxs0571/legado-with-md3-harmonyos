import { LABEL_MEDIUM, LABEL_SMALL } from '../typography/TypographyTokens';

/**
 * 日夜双色行，对齐上游 TinyColorModeSettingItem：一个控件里并排两个色点，
 * 点左边改日间、点右边改夜间。点色点就地展开预设色板；showFollow 为真时
 * 末尾附一个「跟随正文」chip（写回空串，等价于上游颜色取 0 回落正文色）。
 *
 * 色板与色值语义由调用方传入，配色键与 MenuSettingPalette 同款（rset* 广播），
 * 因此浮层形态保持深色、全屏形态跟随主题。
 */
@Component
export struct UiColorModeRow {
  @StorageProp('rsetAccent') rsetAccent: string = '#C6D3FF';
  @StorageProp('rsetTextPrimary') rsetTextPrimary: string = '#E5E6EB';
  @StorageProp('rsetTextTertiary') rsetTextTertiary: string = '#AEB0B9';
  @StorageProp('rsetCardBg') rsetCardBg: string = '#202127';

  @Prop title: string = '';
  @Prop dayColor: string = '';
  @Prop nightColor: string = '';
  @Prop dayLabel: string = '日间';
  @Prop nightLabel: string = '夜间';
  @Prop colors: string[] = [];
  @Prop showFollow: boolean = false;
  onDayChange: (color: string) => void = (_color: string) => {};
  onNightChange: (color: string) => void = (_color: string) => {};

  // -1 收起，0 展开日间色板，1 展开夜间色板。
  @State expanded: number = -1;

  build() {
    Column() {
      Row() {
        Text(this.title).fontSize(LABEL_MEDIUM).fontColor(this.rsetTextPrimary).layoutWeight(1)
        Row({ space: 8 }) {
          // 日间色点。
          Stack({ alignContent: Alignment.Center }) {
            Circle().width(28).height(28)
              .fill(this.dayColor.length > 0 ? this.dayColor : this.rsetTextTertiary)
            if (this.expanded === 0) {
              Circle().width(34).height(34).fill(Color.Transparent)
                .stroke(this.rsetAccent).strokeWidth(2)
            }
          }.width(38).height(38)
            .onClick(() => { this.expanded = this.expanded === 0 ? -1 : 0 })
          // 夜间色点。
          Stack({ alignContent: Alignment.Center }) {
            Circle().width(28).height(28)
              .fill(this.nightColor.length > 0 ? this.nightColor : this.rsetTextTertiary)
            if (this.expanded === 1) {
              Circle().width(34).height(34).fill(Color.Transparent)
                .stroke(this.rsetAccent).strokeWidth(2)
            }
          }.width(38).height(38)
            .onClick(() => { this.expanded = this.expanded === 1 ? -1 : 1 })
        }
      }.width('100%')

      if (this.expanded >= 0) {
        Row() {
          ForEach(this.colors, (color: string) => {
            Stack({ alignContent: Alignment.Center }) {
              Circle().width(24).height(24).fill(color)
            }.width(34).height(34)
              .onClick(() => {
                if (this.expanded === 0) {
                  this.onDayChange(color);
                } else {
                  this.onNightChange(color);
                }
                this.expanded = -1;
              })
          }, (color: string) => color)
          if (this.showFollow) {
            Text('跟随正文').fontSize(LABEL_SMALL).fontColor(this.rsetAccent)
              .padding({ left: 8, right: 8 })
              .onClick(() => {
                if (this.expanded === 0) {
                  this.onDayChange('');
                } else {
                  this.onNightChange('');
                }
                this.expanded = -1;
              })
          }
        }.width('100%').margin({ top: 8 })
      }
    }.width('100%').padding(12).backgroundColor(this.rsetCardBg).borderRadius(12)
  }
}
