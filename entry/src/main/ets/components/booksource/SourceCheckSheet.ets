// 书源校验配置弹层：对齐上游 CheckSourceBottomSheet.kt（115 行）。
// 上游壳 AppModalBottomSheet(title=check_source_config「校验设置」)，
// 超时用 SliderSettingItem（默认 180f、范围 0f..300f），五个 CheckboxItem，
// 目录 enabled=checkInfo、正文 enabled=checkCategory，底部确认/取消。
// 确认只回传配置；执行由页面侧的 BookSourceCheckCoordinator 承担（对齐上游
// CheckSourceBottomSheet 只改草稿、CheckBookSourceSheet 的 Check 才启动的链路）。

import { LABEL_LARGE, TITLE_MEDIUM } from '../typography/TypographyTokens';
import { ROW_PADDING_H, ROW_PADDING_V, SPACE_12, SPACE_8 } from '../UiTokens';
// 选项类型统一由协调器提供（ArkTS 不支持结构化类型：两个同形 interface 不能互传）。
import { BookSourceCheckOptions, defaultCheckOptions } from '../../bookSource/BookSourceCheckCoordinator';

/** 兼容旧调用点的别名（与协调器的 BookSourceCheckOptions 是同一个类型）。 */
export type SourceCheckOptions = BookSourceCheckOptions;

@Component
export struct SourceCheckSheet {
  /** 显隐由调用方持有；弹层关闭时在 onDisappear 里回写 false。 */
  @Link visible: boolean;
  /**
   * 进入时的草稿值（上游 checkOptionsDraft）。调用方每次打开都会传入当前草稿，
   * 使「设置 → 运行 → 再设置」能保留上一轮的选择。
   */
  @Prop @Watch('onOptionsChanged') options: SourceCheckOptions = defaultCheckOptions();
  /** 确认回传当前配置；真正执行由调用方的 BookSourceCheckCoordinator 承担。 */
  onConfirm: (options: SourceCheckOptions) => void = (_options: SourceCheckOptions) => {};

  // 默认值照抄上游 BookSourceContract.kt:33-40（全 true、超时 180 秒）。
  @State private timeoutSeconds: number = 180;
  @State private checkSearch: boolean = true;
  @State private checkDiscovery: boolean = true;
  @State private checkInfo: boolean = true;
  @State private checkCategory: boolean = true;
  @State private checkContent: boolean = true;

  /** options 变化时把草稿搬进本地 state（@Prop 不能直接绑 Slider/Checkbox）。 */
  onOptionsChanged(): void {
    this.timeoutSeconds = this.options.timeoutSeconds;
    this.checkSearch = this.options.checkSearch;
    this.checkDiscovery = this.options.checkDiscovery;
    this.checkInfo = this.options.checkInfo;
    this.checkCategory = this.options.checkCategory;
    this.checkContent = this.options.checkContent;
  }

  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#F5F6F8';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;

  /** 一行复选框：文字 + Checkbox。禁用态整行置灰、不可点（对齐上游 CheckboxItem 的 enabled）。 */
  @Builder
  private CheckRow(title: string, checked: boolean, enabled: boolean, onChange: (value: boolean) => void) {
    Row() {
      Text(title)
        .fontSize(TITLE_MEDIUM)
        .fontColor(this.themeColorTextPrimary)
        .layoutWeight(1)
        .opacity(enabled ? 1 : 0.38)
      Checkbox({ name: title })
        .shape(CheckBoxShape.ROUNDED_SQUARE)
        .select(checked)
        .selectedColor(this.themeColorAccent)
        .enabled(enabled)
        .opacity(enabled ? 1 : 0.38)
        .onChange((value: boolean) => onChange(value))
    }
    .width('100%')
    .padding({ left: ROW_PADDING_H, right: ROW_PADDING_H, top: ROW_PADDING_V, bottom: ROW_PADDING_V })
  }

  @Builder
  private SheetContent() {
    Column() {
      Text('校验设置')
        .fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium)
        .fontColor(this.themeColorTextPrimary)
        .width('100%')
        .padding({ left: ROW_PADDING_H, right: ROW_PADDING_H, top: ROW_PADDING_V })

      // 超时：上游 GlassCard { SliderSettingItem(defaultValue=180f, valueRange=0f..300f) }。
      Column() {
        Row() {
          Text('单个书源校验超时（秒）')
            .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary)
          Blank()
          Text('' + Math.round(this.timeoutSeconds))
            .fontSize(TITLE_MEDIUM).fontColor(this.themeColorAccent)
        }.width('100%')
        Slider({
          value: this.timeoutSeconds,
          min: 0,
          max: 300,
          step: 1,
          style: SliderStyle.OutSet
        })
          .width('100%')
          .selectedColor(this.themeColorAccent)
          .onChange((value: number, mode: SliderChangeMode) => {
            if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Click ||
              mode === SliderChangeMode.End) {
              this.timeoutSeconds = Math.max(0, Math.min(300, Math.round(value)));
            }
          })
      }
      .width('100%')
      .padding({ left: ROW_PADDING_H, right: ROW_PADDING_H, top: ROW_PADDING_V, bottom: ROW_PADDING_V })
      .backgroundColor(this.themePureBlack ? '#17181E' : this.themeColorSurfaceElevated)
      .borderRadius(12)
      .margin({ left: ROW_PADDING_H, right: ROW_PADDING_H, top: SPACE_8 })

      // 五个复选框，顺序与依赖照上游 CheckSourceBottomSheet.kt:67-101。
      this.CheckRow('搜索', this.checkSearch, true, (enabled: boolean) => {
        // 上游 :353-358：关搜索时强制开发现；开搜索不动发现。
        this.checkSearch = enabled;
        if (!enabled) { this.checkDiscovery = true; }
      })
      this.CheckRow('发现', this.checkDiscovery, true, (enabled: boolean) => {
        // 上游 :359-364：关发现时强制开搜索。
        this.checkDiscovery = enabled;
        if (!enabled) { this.checkSearch = true; }
      })
      this.CheckRow('详情', this.checkInfo, true, (enabled: boolean) => {
        // 上游 :365-371：关详情时联动关闭目录与正文。
        this.checkInfo = enabled;
        if (!enabled) { this.checkCategory = false; this.checkContent = false; }
      })
      this.CheckRow('目录', this.checkCategory, this.checkInfo, (enabled: boolean) => {
        // 上游 :372-376：关目录时联动关闭正文。enabled=checkInfo。
        this.checkCategory = enabled;
        if (!enabled) { this.checkContent = false; }
      })
      this.CheckRow('正文', this.checkContent, this.checkCategory, (enabled: boolean) => {
        // 上游 :378：正文直接设置。enabled=checkCategory。
        this.checkContent = enabled;
      })

      // 确认 / 取消（上游 ConfirmDismissButtonsRow，:104-112）。
      Row() {
        Text('取消')
          .fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary)
          .layoutWeight(1).textAlign(TextAlign.Center)
          .padding({ top: SPACE_12, bottom: SPACE_12 })
          .onClick(() => { this.visible = false; })
        Text('确认')
          .fontSize(LABEL_LARGE).fontColor(this.themeColorAccent)
          .layoutWeight(1).textAlign(TextAlign.Center)
          .padding({ top: SPACE_12, bottom: SPACE_12 })
          .onClick(() => {
            this.onConfirm({
              timeoutSeconds: this.timeoutSeconds,
              checkSearch: this.checkSearch,
              checkDiscovery: this.checkDiscovery,
              checkInfo: this.checkInfo,
              checkCategory: this.checkCategory,
              checkContent: this.checkContent
            });
            this.visible = false;
          })
      }.width('100%').margin({ top: SPACE_12 })
    }
    .width('100%')
    .padding({ bottom: 32 })
    .backgroundColor(this.themePureBlack ? '#17181E' : this.themeColorSurfaceElevated)
  }

  build() {
    Column()
      .width(0).height(0)
      .bindSheet(this.visible, this.SheetContent(), {
        height: SheetSize.FIT_CONTENT,
        dragBar: true,
        showClose: true,
        backgroundColor: this.themePureBlack ? '#17181E' : this.themeColorSurfaceElevated,
        onDisappear: () => { this.visible = false; }
      })
  }
}
