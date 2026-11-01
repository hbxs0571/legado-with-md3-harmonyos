import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';
import { ThemeItemDivider } from '../components/ThemeItemDivider';
import {
  CUSTOM_COLOR_SLOT_LABELS,
  CUSTOM_CONTRASTS,
  CUSTOM_CONTRAST_LABELS,
  CUSTOM_MATERIAL_VERSIONS,
  CUSTOM_MATERIAL_VERSION_LABELS,
  CUSTOM_PALETTE_STYLES,
  CUSTOM_PALETTE_STYLE_LABELS,
  CustomThemeColorSet,
  CustomThemeSnapshot,
  normalizeCustomColor
} from '../data/CustomThemeColors';

/**
 * 自定义主题配色页，对应上游 `ui/config/customTheme/CustomThemeScreen.kt`（269 行）。
 *
 * 结构逐块对齐：
 * ① 顶部「使用色板生成颜色」开关（上游是取反的 `enableDeepPersonalization`）；
 * ② 开关打开（= 深度个性化开）→ 「白天」「夜间」两组，各 6 个色位；
 * ③ 开关关闭 → 「种子色（日间）」「种子色（夜间）」+ 色板风格 / 对比度 / Material 版本三个下拉。
 *
 * 与上游的一处差异：上游点色位弹 `ColorPickerSheet`（Miuix 的 `ColorPalette` 色环 + hex 输入），
 * 本地 ArkUI 没有 ColorPicker 组件（`ets/component` 下零命中），所以色位点开是
 * 「hex 输入框 + 预览方块 + 重置/保存」的底部面板，能力边界（可输入、可重置、可预览）
 * 与上游一致，只是少了色环取色。
 */
@Component
export struct CustomThemePage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @StorageProp('themeCardRadius') themeCardRadius: number = 16;
  @StorageProp('themeCardBorderWidth') themeCardBorderWidth: number = 0;
  @StorageProp('themeCardBorderColor') themeCardBorderColor: string = '#6A6D77';
  @StorageProp('themeCardBackground') themeCardBackground: string = '';
  @StorageProp('themeContainerBackground') themeContainerBackground: string = '';
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  /** 当前快照，由 Index 传入；每次改动都通过 `onChange` 整份写回。 */
  @Prop customTheme: CustomThemeSnapshot = {
    enableDeepPersonalization: false,
    paletteStyle: 'tonalSpot',
    customContrast: 'Default',
    materialVersion: 'material3',
    seedColorDay: '',
    seedColorNight: '',
    day: { primary: '', secondary: '', primaryText: '', secondaryText: '', background: '', labelContainer: '' },
    night: { primary: '', secondary: '', primaryText: '', secondaryText: '', background: '', labelContainer: '' }
  };
  /** 整份快照回调，对齐上游 `CustomThemeViewModel` 每次 intent 都写一次网关。 */
  onChange: (snapshot: CustomThemeSnapshot) => void = (_snapshot: CustomThemeSnapshot) => {};
  @State collapsedHeader: boolean = false;
  /** 正在编辑的色位：-1 未开面板，0..5 是日间六项，6..11 是夜间六项。 */
  @State editingSlot: number = -1;
  /** 编辑面板里的 hex 文本（含 `#`）。 */
  @State editingHex: string = '';
  private settingsScroller: Scroller = new Scroller();

  private updateHeader(): void {
    const offset = this.settingsScroller.currentOffset().yOffset;
    const shouldCollapse = offset > 70 ? true : offset < 24 ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      animateTo({ duration: 220, curve: Curve.EaseInOut }, () => this.collapsedHeader = shouldCollapse);
    }
  }

  /** 复制一份快照再改，避免直接改 `@Prop` 传进来的对象。 */
  private cloneSnapshot(): CustomThemeSnapshot {
    const cloneSet = (set: CustomThemeColorSet): CustomThemeColorSet => {
      return {
        primary: set.primary, secondary: set.secondary, primaryText: set.primaryText,
        secondaryText: set.secondaryText, background: set.background, labelContainer: set.labelContainer
      };
    };
    return {
      enableDeepPersonalization: this.customTheme.enableDeepPersonalization,
      paletteStyle: this.customTheme.paletteStyle,
      customContrast: this.customTheme.customContrast,
      materialVersion: this.customTheme.materialVersion,
      seedColorDay: this.customTheme.seedColorDay,
      seedColorNight: this.customTheme.seedColorNight,
      day: cloneSet(this.customTheme.day),
      night: cloneSet(this.customTheme.night)
    };
  }

  /**
   * 取第 slot 个色位的当前值。
   *
   * 0..5 是日间六项、6..11 是夜间六项；12/13 是种子色模式下的日间/夜间种子色
   * （上游 `customPrimary` / `customNightPrimary`，与六项颜色是两组不同的键）。
   */
  private slotValue(slot: number): string {
    if (slot === 12) { return this.customTheme.seedColorDay; }
    if (slot === 13) { return this.customTheme.seedColorNight; }
    const set = slot < 6 ? this.customTheme.day : this.customTheme.night;
    switch (slot % 6) {
      case 0: return set.primary;
      case 1: return set.secondary;
      case 2: return set.primaryText;
      case 3: return set.secondaryText;
      case 4: return set.background;
      default: return set.labelContainer;
    }
  }

  private slotLabel(slot: number): string {
    if (slot === 12) { return '种子色（日间）'; }
    if (slot === 13) { return '种子色（夜间）'; }
    return `${slot < 6 ? '白天' : '夜间'} · ${CUSTOM_COLOR_SLOT_LABELS[slot % 6]}`;
  }

  private writeSlot(snapshot: CustomThemeSnapshot, slot: number, value: string): void {
    if (slot === 12) { snapshot.seedColorDay = value; return; }
    if (slot === 13) { snapshot.seedColorNight = value; return; }
    const set = slot < 6 ? snapshot.day : snapshot.night;
    switch (slot % 6) {
      case 0: set.primary = value; break;
      case 1: set.secondary = value; break;
      case 2: set.primaryText = value; break;
      case 3: set.secondaryText = value; break;
      case 4: set.background = value; break;
      default: set.labelContainer = value; break;
    }
  }

  /** 打开某个色位的编辑面板。 */
  private openSlot(slot: number): void {
    this.editingSlot = slot;
    this.editingHex = this.slotValue(slot);
  }

  /** 保存当前编辑的色位；空串表示「未设置」，等价上游 `Color.Transparent`。 */
  private commitSlot(value: string): void {
    if (this.editingSlot < 0) { return; }
    const snapshot = this.cloneSnapshot();
    this.writeSlot(snapshot, this.editingSlot, normalizeCustomColor(value));
    this.editingSlot = -1;
    this.editingHex = '';
    this.onChange(snapshot);
  }

  private styleLabel(value: string): string {
    const index = CUSTOM_PALETTE_STYLES.indexOf(value);
    return index >= 0 ? CUSTOM_PALETTE_STYLE_LABELS[index] : CUSTOM_PALETTE_STYLE_LABELS[0];
  }

  private contrastLabel(value: string): string {
    const index = CUSTOM_CONTRASTS.indexOf(value);
    return index >= 0 ? CUSTOM_CONTRAST_LABELS[index] : CUSTOM_CONTRAST_LABELS[0];
  }

  private materialLabel(value: string): string {
    const index = CUSTOM_MATERIAL_VERSIONS.indexOf(value);
    return index >= 0 ? CUSTOM_MATERIAL_VERSION_LABELS[index] : CUSTOM_MATERIAL_VERSION_LABELS[0];
  }

  /** 色位行的右侧：有值显示色块 + hex，无值显示「点击选择」。 */
  @Builder
  private SlotRow(slot: number) {
    Row() {
      Text(this.slotLabel(slot)).fontSize(16).fontColor(this.themeColorTextSecondary).layoutWeight(1)
      if (this.slotValue(slot).length > 0) {
        Row() {
          Text(this.slotValue(slot)).fontSize(14).fontColor(this.themeColorTextTertiary).margin({ right: 8 })
          Row().width(28).height(28).borderRadius(14).backgroundColor(this.slotValue(slot))
            .border({ width: 1, color: this.themeColorTextTertiary })
        }
      } else {
        Text('点击选择').fontSize(14).fontColor(this.themeColorAccent)
      }
      Image($r('app.media.reader_next')).width(16).height(16).fillColor(this.themeColorTextTertiary)
        .margin({ left: 4 })
    }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .onClick(() => this.openSlot(slot))
  }

  @Builder
  private ColorEditor() {
    Column() {
      Row() {
        Text('选择颜色').fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
          .layoutWeight(1)
        Text('重置').fontSize(15).fontColor(this.themeColorTextTertiary)
          .onClick(() => { this.editingHex = ''; this.commitSlot(''); })
        Text('保存').fontSize(15).fontColor(this.themeColorAccent).margin({ left: 18 })
          .onClick(() => this.commitSlot(this.editingHex))
      }.width('100%').padding({ bottom: 12 })
      Row() {
        // 预览方块：对齐上游 `ColorPickerSheet` 的 40dp 预览块，未设置时显示棋盘底。
        Row().width(48).height(48).borderRadius(8)
          .backgroundColor(this.editingHex.length > 0 ? this.editingHex : this.themeColorSurfacePrimary)
          .border({ width: 1, color: this.themeColorTextTertiary })
        TextInput({ text: this.editingHex, placeholder: '#RRGGBB' })
          .layoutWeight(1).margin({ left: 12 })
          .onChange((value: string) => this.editingHex = value)
      }.width('100%')
      Text('留空表示沿用日间颜色（夜间）或未设置（日间）。')
        .fontSize(12).fontColor(this.themeColorTextTertiary).margin({ top: 10 })
    }.width('100%').padding(16)
      .backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceElevated)
      .borderRadius(this.themeCardRadius)
      .border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor })
      .margin({ left: 16, right: 16, bottom: 12 })
  }

  /**
   * 下拉行：点开菜单选一项。
   *
   * 这里用 `bindMenu(Array<MenuElement>)` 而不是 `@Builder Menu`，因为选项是逐行不同的入参，
   * 而 `@Builder` 无法按行参数化菜单内容（`ThemeSettingsDropdown` 那种单实例写法不适用）。
   */
  private dropdownElements(options: string[], onPick: (value: string) => void): MenuElement[] {
    const elements: MenuElement[] = [];
    for (let index = 0; index < options.length; index++) {
      const option = options[index];
      elements.push({ value: option, action: () => onPick(option) });
    }
    return elements;
  }

  @Builder
  private DropdownRow(title: string, value: string, options: string[], onPick: (value: string) => void) {
    Row() {
      Text(title).fontSize(16).fontColor(this.themeColorTextSecondary).layoutWeight(1)
      Text(value).fontSize(14).fontColor(this.themeColorAccent)
      Image($r('app.media.reader_next')).width(16).height(16).fillColor(this.themeColorTextTertiary)
        .margin({ left: 4 })
    }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .bindMenu(this.dropdownElements(options, onPick), { placement: Placement.Bottom })
  }

  build() {
    Column() {
      CollapsingSettingsHeader({
        title: '自定义颜色', collapsed: this.collapsedHeader, onBack: () => this.onBack()
      })

      Scroll(this.settingsScroller) {
        Column() {
          // ① 「使用色板生成颜色」：上游 checked = !enableDeepPersonalization，取反关系必须保留。
          Column() {
            Row() {
              Column() {
                Text('使用色板生成颜色').fontSize(16).fontColor(this.themeColorTextSecondary)
                Text('关闭后由种子色自动生成整套配色').fontSize(12)
                  .fontColor(this.themeColorTextTertiary).margin({ top: 3 })
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: !this.customTheme.enableDeepPersonalization })
                .onChange((enabled: boolean) => {
                  const snapshot = this.cloneSnapshot();
                  snapshot.enableDeepPersonalization = !enabled;
                  this.onChange(snapshot);
                })
            }.padding({ left: 16, right: 16, top: 14, bottom: 14 })
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16, top: 12 })
            .backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary)
            .borderRadius(this.themeCardRadius)
            .border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor })
            .backgroundImage(this.themeContainerBackground.length > 0
              ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)

          if (this.customTheme.enableDeepPersonalization) {
            // ② 深度个性化开：日/夜各 6 个色位，顺序对齐 `strings.xml:1729-1734`。
            Text('白天').fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.themeColorAccent)
              .alignSelf(ItemAlign.Start).padding({ left: 18, top: 20, bottom: 8 })
            Column() {
              ForEach([0, 1, 2, 3, 4, 5], (slot: number) => {
                if (slot > 0) { ThemeItemDivider() }
                this.SlotRow(slot)
              }, (slot: number) => `day-${slot}`)
            }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 })
              .backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary)
              .borderRadius(this.themeCardRadius)
              .border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor })
              .backgroundImage(this.themeContainerBackground.length > 0
                ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)

            Text('夜间').fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.themeColorAccent)
              .alignSelf(ItemAlign.Start).padding({ left: 18, top: 20, bottom: 8 })
            Column() {
              ForEach([6, 7, 8, 9, 10, 11], (slot: number) => {
                if (slot > 6) { ThemeItemDivider() }
                this.SlotRow(slot)
              }, (slot: number) => `night-${slot}`)
            }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 })
              .backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary)
              .borderRadius(this.themeCardRadius)
              .border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor })
              .backgroundImage(this.themeContainerBackground.length > 0
                ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
          } else {
            // ③ 种子色模式：两个种子色 + 三个下拉。上游这三个下拉的消费者是 HCT 生成器，
            // 本地只落盘（ArkUI 无等价算法），差异写在 ZIP-THEME A6 行备注。
            Text('自定义颜色').fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.themeColorAccent)
              .alignSelf(ItemAlign.Start).padding({ left: 18, top: 20, bottom: 8 })
            Column() {
              this.SlotRow(12)
              ThemeItemDivider()
              this.SlotRow(13)
              ThemeItemDivider()
              this.DropdownRow('色板风格', this.styleLabel(this.customTheme.paletteStyle),
                CUSTOM_PALETTE_STYLE_LABELS, (value: string) => {
                  const index = CUSTOM_PALETTE_STYLE_LABELS.indexOf(value);
                  const snapshot = this.cloneSnapshot();
                  snapshot.paletteStyle = index >= 0 ? CUSTOM_PALETTE_STYLES[index] : 'tonalSpot';
                  this.onChange(snapshot);
                })
              ThemeItemDivider()
              this.DropdownRow('对比度', this.contrastLabel(this.customTheme.customContrast),
                CUSTOM_CONTRAST_LABELS, (value: string) => {
                  const index = CUSTOM_CONTRAST_LABELS.indexOf(value);
                  const snapshot = this.cloneSnapshot();
                  snapshot.customContrast = index >= 0 ? CUSTOM_CONTRASTS[index] : 'Default';
                  this.onChange(snapshot);
                })
              ThemeItemDivider()
              this.DropdownRow('Material 版本', this.materialLabel(this.customTheme.materialVersion),
                CUSTOM_MATERIAL_VERSION_LABELS, (value: string) => {
                  const index = CUSTOM_MATERIAL_VERSION_LABELS.indexOf(value);
                  const snapshot = this.cloneSnapshot();
                  snapshot.materialVersion = index >= 0 ? CUSTOM_MATERIAL_VERSIONS[index] : 'material3';
                  this.onChange(snapshot);
                })
            }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 })
              .backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary)
              .borderRadius(this.themeCardRadius)
              .border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor })
              .backgroundImage(this.themeContainerBackground.length > 0
                ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
          }

          Column().height(32)
        }.width('100%')
      }.layoutWeight(1).scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
        .onDidScroll(() => this.updateHeader())

      // 色位编辑面板：上游是 `ColorPickerSheet`（底部弹层），这里用底部固定面板对齐。
      if (this.editingSlot >= 0) {
        this.ColorEditor()
      }
    }.width('100%').height('100%')
      .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent
        : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      .backgroundImage(this.themeAppBackground.length > 0
        ? `file://${this.themeAppBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
  }
}
