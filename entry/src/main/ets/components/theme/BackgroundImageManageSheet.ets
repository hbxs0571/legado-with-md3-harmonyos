/**
 * 亮/暗背景图管理面板，对齐上游
 * `ui/config/themeConfig/BackgroundImageManageSheet.kt`（199 行）。
 *
 * 上游结构（`AppModalBottomSheet(title)` 里一整列，底部留 24dp，元素间距 2dp）：
 *   1. 一行两张 `BackgroundImageTile`，各占 `weight(1f)`，横向间距 12dp：
 *      空图 → `NormalCard(onClick, cornerRadius 12dp, containerColor surfaceContainerHigh)`
 *             里居中一枚 48dp 的 `Add` 图标（tint primary）；
 *      有图 → `NormalCard(cornerRadius 12dp)` 里 `AsyncImage(aspectRatio 1f, Crop)`
 *             + 右上角 8dp 内缩、32dp 的 `SmallTonalButton(Close)`；
 *      图下面一行 `labelSmall` 的标签（左侧缩进 4dp、上 8dp）。
 *   2. 按 `extraOption` 三选一：
 *      `Blur`    → 日间图存在才画「日间背景图片虚化」滑块，夜间同理，范围 0..100，默认 0；
 *      `Opacity` → 画一条透明度滑块，说明文字是「{value}%」，范围 0..100，默认 100；
 *      `null`    → 什么都不画。
 *
 * 本地承接（差异写在这里，报告里同样记）：
 * - 上游 `SliderSettingItem` 的 `valueRange = 0f..100f` 是**上游自己**的范围；
 *   本地背景虚化此前被 `normalizeBackgroundBlur()` 夹在 0..40（`data/ThemeSettingsRepository.ets:222-227`），
 *   本面板按上游口径画 0..100，同一批把夹取上限一并改成 100，两处不再打架。
 * - 上游 `AsyncImage` 走 coil 直接吃路径；本地 `Image` 需要 `file://` 前缀才能读沙箱文件，
 *   由调用方传进来的已经是可用的 uri 或空串。
 * - 上游 `NormalCard` 的默认描边/阴影不在本面板设置；本地沿用 `themeColorSurfaceElevated` 作卡片底色。
 */
import { SPACE_12, SPACE_24, SPACE_4, SPACE_8 } from '../UiTokens';
import { AppGlyph } from '../AppGlyph';
import { LABEL_SMALL } from '../typography/TypographyTokens';

/** 上游 `BackgroundImageExtraOption`：背景图额外选项，Blur 与 Opacity 二选一。 */
export interface BackgroundImageExtraOption {
  /** `'blur'` 或 `'opacity'`；空串表示上游的 `null` 分支（什么都不画）。 */
  kind: string;
  /** Blur 用：日间滑块标题。 */
  lightTitle: string;
  /** Blur 用：夜间滑块标题。 */
  darkTitle: string;
  /** Blur 用：日间值。 */
  lightValue: number;
  /** Blur 用：夜间值。 */
  darkValue: number;
  /** Opacity 用：滑块标题。 */
  title: string;
  /** Opacity 用：当前值。 */
  value: number;
}

/** 上游 `BackgroundImageExtraOption` 的 `null` 分支。 */
export function noExtraOption(): BackgroundImageExtraOption {
  return {
    kind: '', lightTitle: '', darkTitle: '', lightValue: 0, darkValue: 0, title: '', value: 0
  };
}

/**
 * 全 App 背景图的 `Blur` 档，对齐上游 `ThemeConfigScreen.kt:855-862`：
 * 标题「日间背景图片虚化」「夜间背景图片虚化」，值取 `backgroundImageBlurring` /
 * `backgroundImageDarkBlurring`。
 */
export function blurExtraOption(lightValue: number, darkValue: number): BackgroundImageExtraOption {
  return {
    kind: 'blur',
    lightTitle: '日间背景图片虚化',
    darkTitle: '夜间背景图片虚化',
    lightValue: lightValue,
    darkValue: darkValue,
    title: '',
    value: 0
  };
}

/**
 * 容器背景图的 `Opacity` 档，对齐上游 `ThemeConfigScreen.kt:864-874`：
 * 大容器取 `appColumnBackgroundOpacity`、项目取 `glassCardBackgroundOpacity`。
 */
export function opacityExtraOption(title: string, value: number): BackgroundImageExtraOption {
  return {
    kind: 'opacity',
    lightTitle: '',
    darkTitle: '',
    lightValue: 0,
    darkValue: 0,
    title: title,
    value: value
  };
}

@Component
export struct BackgroundImageManageSheet {
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';

  /** 面板标题。上游由调用方按目标传「背景图片 / 大容器背景图片 / 项目背景图片」。 */
  @Prop title: string = '';
  /** 日间图路径，空串等价上游 `null`。 */
  @Prop lightPath: string = '';
  /** 夜间图路径，空串等价上游 `null`。 */
  @Prop darkPath: string = '';
  /** 额外选项。 */
  @Prop extraOption: BackgroundImageExtraOption = noExtraOption();

  onDismissRequest: () => void = () => {};
  onSelectLight: () => void = () => {};
  onSelectDark: () => void = () => {};
  onRemoveLight: () => void = () => {};
  onRemoveDark: () => void = () => {};
  onLightBlurChange: (value: number) => void = (_value: number) => {};
  onDarkBlurChange: (value: number) => void = (_value: number) => {};
  onOpacityChange: (value: number) => void = (_value: number) => {};

  /**
   * 一张背景图卡（上游 `BackgroundImageTile`，`:138-199`）。
   *
   * `label` 是图下面那行小字（上游 `day` / `night`）；`path` 空则画添加卡。
   */
  @Builder
  private BackgroundImageTile(label: string, path: string, isNight: boolean) {
    Column() {
      if (path.length === 0) {
        // 空态：整块 1:1 的添加卡，居中 48dp 的加号，色 primary。
        Column() {
          AppGlyph({ name: 'add', glyphSize: 48, tint: this.themeColorAccent })
        }
        .width('100%')
        .aspectRatio(1)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.themeColorSurfaceElevated)
        .borderRadius(12)
        .onClick(() => {
          if (isNight) {
            this.onSelectDark();
          } else {
            this.onSelectLight();
          }
        })
        .accessibilityText(label)
      } else {
        Stack({ alignContent: Alignment.TopEnd }) {
          // 有图：1:1 裁切铺满，圆角 12。
          Image(path)
            .width('100%')
            .aspectRatio(1)
            .objectFit(ImageFit.Cover)
            .borderRadius(12)
            .onClick(() => {
              if (isNight) {
                this.onSelectDark();
              } else {
                this.onSelectLight();
              }
            })
          // 右上角 8dp 内缩的 32dp 关闭钮（上游 `SmallTonalButton`）。
          Column() {
            AppGlyph({ name: 'profileClose', glyphSize: 18, tint: this.themeColorTextPrimary })
          }
          .width(32)
          .height(32)
          .borderRadius(16)
          .backgroundColor(this.themeColorSurfaceTertiary)
          .justifyContent(FlexAlign.Center)
          .margin(SPACE_8)
          .onClick(() => {
            if (isNight) {
              this.onRemoveDark();
            } else {
              this.onRemoveLight();
            }
          })
          .accessibilityText('关闭')
        }
        .width('100%')
      }
      // 图下面的标签：左侧缩进 4、上 8。
      Text(label)
        .fontSize(LABEL_SMALL)
        .fontColor(this.themeColorTextTertiary)
        .width('100%')
        .padding({ left: SPACE_4, top: SPACE_8 })
    }
    .layoutWeight(1)
  }

  /** 一条虚化/透明度滑块（上游 `SliderSettingItem` 的最小等价物）。 */
  @Builder
  private OptionSlider(label: string, detail: string, value: number, defaultValue: number,
    onChange: (value: number) => void) {
    Column() {
      Row() {
        Text(label).fontSize(16).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Text(detail).fontSize(13).fontColor(this.themeColorAccent)
      }
      .width('100%')
      .padding({ top: SPACE_12 })

      Slider({ value: value, min: 0, max: 100, step: 1, style: SliderStyle.OutSet })
        .width('100%')
        .selectedColor(this.themeColorAccent)
        .trackColor(this.themeColorSurfaceTertiary)
        .onChange((next: number, mode: SliderChangeMode) => {
          // 与 `UiSlider` 同一口径：只在拖动结束/点击时上报，拖动中的每一帧不回调。
          if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click ||
            mode === SliderChangeMode.Begin) {
            onChange(Math.round(next));
          }
        })
        .padding({ bottom: SPACE_4 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: SPACE_8, bottom: SPACE_8 })
    .accessibilityText(`${label}，默认 ${defaultValue}`)
  }

  build() {
    Column() {
      // 标题（上游 `AppModalBottomSheet(title)` 的标题行）。
      Text(this.title)
        .fontSize(20)
        .fontColor(this.themeColorTextPrimary)
        .width('100%')
        .padding({ left: 16, right: 16, top: SPACE_24, bottom: SPACE_12 })

      Column() {
        // 两张图并排，横向间距 12（上游 `Row(spacedBy 12dp)`）。
        Row({ space: SPACE_12 }) {
          this.BackgroundImageTile('白天', this.lightPath, false)
          this.BackgroundImageTile('夜间', this.darkPath, true)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .padding({ left: 16, right: 16 })

        // 额外选项（上游 `when (extraOption)`）。
        if (this.extraOption.kind === 'blur') {
          // 上游只在对应图存在时才画那条滑块。
          if (this.lightPath.length > 0) {
            this.OptionSlider(this.extraOption.lightTitle, `${this.extraOption.lightValue}`,
              this.extraOption.lightValue, 0, (value: number) => this.onLightBlurChange(value))
          }
          if (this.darkPath.length > 0) {
            this.OptionSlider(this.extraOption.darkTitle, `${this.extraOption.darkValue}`,
              this.extraOption.darkValue, 0, (value: number) => this.onDarkBlurChange(value))
          }
        } else if (this.extraOption.kind === 'opacity') {
          this.OptionSlider(this.extraOption.title, `${this.extraOption.value}%`,
            this.extraOption.value, 100, (value: number) => this.onOpacityChange(value))
        }
      }
      .width('100%')
      .padding({ bottom: SPACE_24 })
    }
    .width('100%')
  }
}
