// 封面模糊背景（上游 `ui/widget/components/image/cover/CoverBlurBackdrop.kt`）。
//
// 上游三层，逐层照搬，顺序不能换：
//   1. 封面图铺满 + 高斯模糊（默认 48dp，`contentScale = Crop`）
//   2. `lerp(secondaryContainer, seedColor, 0.42f)` 铺满，alpha 0.38
//   3. `surface` 铺满，alpha 0.52
//
// 第 2 层的插值基色是主题的 secondaryContainer，不是 surfaceContainerHigh ——
// 上游 `CoverBlurBackdrop.kt:25` 写的就是 `LegadoTheme.colorScheme.secondaryContainer`。
//
// 消费方（上游）：`ui/widget/components/player/PlayerBackground.kt:34`（Blur 档，blur 48）
// 与 `:45`（FlowingLight 档且设备支持运行时着色器时，blur 64）。

import { lerpHexColor, withAlphaHex } from '../data/ColorLerp';

@Component
export struct CoverBlurBackdrop {
  /** 封面 `file://` 地址；空串时不画封面层，只留两层遮罩。 */
  @Prop coverUri: string = '';
  /** 取色得到的主色 `#RRGGBB`；空串表示没有 seed，第 2 层退化为 secondaryContainer 本身。 */
  @Prop seedColor: string = '';
  /** 高斯模糊半径，上游默认 48dp，FlowingLight 档 64dp。 */
  @Prop blurRadius: number = 48;
  /** 封面层放大倍数：模糊后边缘会露出底色，上游靠 Crop 撑满，本地用轻微放大补足。 */
  @Prop coverScale: number = 1.2;

  @StorageProp('themeColorSecondaryContainer') themeColorSecondaryContainer: string = '#DCE7C8';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';

  /** 第 2 层基色：`lerp(secondaryContainer, seedColor, 0.42)`；无 seed 时就是 secondaryContainer。 */
  private tintColor(): string {
    const base: string = this.themeColorSecondaryContainer;
    if (this.seedColor.length < 7 || base.length < 7) {
      return base;
    }
    return lerpHexColor(base, this.seedColor, 0.42);
  }

  /** 给 `#RRGGBB` 拼 alpha 前缀，上游 `copy(alpha = ...)` 的等价物。 */
  private withAlpha(color: string, alpha: number): string {
    return withAlphaHex(color, alpha);
  }

  build() {
    Stack() {
      if (this.coverUri.length > 0) {
        Image(this.coverUri)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .blur(this.blurRadius)
          .scale({ x: this.coverScale, y: this.coverScale })
      }
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.withAlpha(this.tintColor(), 0.38))
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.withAlpha(this.themeColorSurfacePrimary, 0.52))
    }
    .width('100%')
    .height('100%')
  }
}
