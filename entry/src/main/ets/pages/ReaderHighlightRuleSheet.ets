import { ReaderHighlightRule } from '../model/ReaderHighlightRule';
import { ReaderHighlightRuleEngine } from '../data/ReaderHighlightRuleEngine';
import { ReaderHighlightRulePresets } from '../data/ReaderHighlightRulePresets';

@Component
export struct ReaderHighlightRuleSheet {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop rules: ReaderHighlightRule[] = [];
  @Prop chapterLength: number = 0;
  @State draftRules: ReaderHighlightRule[] = [];
  @State editorVisible: boolean = false;
  @State editId: string = '';
  @State editName: string = '';
  @State editPattern: string = '';
  @State editTextColor: string = '';
  @State editBackgroundColor: string = '';
  @State editUnderlineColor: string = '';
  @State editUnderlineMode: number = 0;
  /** 作用范围：0 全部 / 1 标题 / 2 正文（上游 HighlightRuleEditSheet 的范围下拉）。 */
  @State editTargetScope: number = 2;
  @State editEnabled: boolean = true;
  /** 预览卡里用的示例文字。 */
  @State editSample: string = '这是一行示例正文，命中规则的部分会即时套用样式。';
  @State errorMessage: string = '';
  @State pendingDeleteId: string = '';
  @State saving: boolean = false;
  @State presetVisible: boolean = false;
  /** 预设面板里已勾选的规则 id；用数组是因为 ArkTS 的 @State 不追踪 Set/Map 的内部变更。 */
  @State presetSelectedIds: string[] = [];
  onDismiss: () => void = () => {};
  onSave: (rules: ReaderHighlightRule[]) => Promise<ReaderHighlightRule[]> =
    async (rules: ReaderHighlightRule[]): Promise<ReaderHighlightRule[]> => rules;

  private copyRule(rule: ReaderHighlightRule): ReaderHighlightRule {
    return {
      id: rule.id, name: rule.name, pattern: rule.pattern, sampleText: rule.sampleText,
      targetScope: rule.targetScope, enabled: rule.enabled, position: rule.position,
      textColor: rule.textColor, bgColor: rule.bgColor, underlineMode: rule.underlineMode,
      underlineColor: rule.underlineColor, underlineWidth: rule.underlineWidth,
      underlineOffset: rule.underlineOffset, underlineSvgPath: rule.underlineSvgPath,
      bgImage: rule.bgImage, bgImageFit: rule.bgImageFit, bgImageScale: rule.bgImageScale,
      configName: rule.configName, fontPath: rule.fontPath, fontWeight: rule.fontWeight,
      isItalic: rule.isItalic, fontSizeOffset: rule.fontSizeOffset, npLeft: rule.npLeft,
      npRight: rule.npRight, npTop: rule.npTop, npBottom: rule.npBottom,
      manualNineSlice: rule.manualNineSlice, letterSpacingBefore: rule.letterSpacingBefore,
      letterSpacingAfter: rule.letterSpacingAfter, lineSpacingTop: rule.lineSpacingTop,
      lineSpacingBottom: rule.lineSpacingBottom, bgLengthOffsetLeft: rule.bgLengthOffsetLeft,
      bgLengthOffsetRight: rule.bgLengthOffsetRight
    };
  }

  aboutToAppear(): void {
    this.draftRules = this.rules.map((rule: ReaderHighlightRule) => this.copyRule(rule));
  }

  private colorInput(color: number | null | undefined): string {
    if (color === null || color === undefined) { return ''; }
    const hex = (color >>> 0).toString(16).padStart(8, '0').toUpperCase();
    return hex.substring(0, 2) === 'FF' ? `#${hex.substring(2)}` : `#${hex}`;
  }

  private startCreate(): void {
    this.editId = '';
    this.editName = '';
    this.editPattern = '';
    this.editTextColor = '';
    this.editBackgroundColor = '';
    this.editUnderlineColor = '';
    this.editUnderlineMode = 0;
    this.editTargetScope = 2;
    this.editEnabled = true;
    this.errorMessage = '';
    this.editorVisible = true;
  }

  private startEdit(rule: ReaderHighlightRule): void {
    this.editId = rule.id;
    this.editName = rule.name;
    this.editPattern = rule.pattern;
    this.editTextColor = this.colorInput(rule.textColor);
    this.editBackgroundColor = this.colorInput(rule.bgColor);
    this.editUnderlineColor = this.colorInput(rule.underlineColor);
    this.editUnderlineMode = rule.underlineMode;
    this.editTargetScope = rule.targetScope;
    this.editEnabled = rule.enabled;
    this.errorMessage = '';
    this.editorVisible = true;
  }

  /** 下划线档位，顺序对齐上游 HighlightRuleEditSheet.kt:477-493 的 7 种。 */
  private cycleUnderlineMode(): void {
    const modes: number[] = [0, 1, 2, 3, 4, 5, 6, 7];
    const index = modes.indexOf(this.editUnderlineMode);
    this.editUnderlineMode = modes[(index + 1) % modes.length] ?? 0;
  }

  private underlineLabel(): string {
    if (this.editUnderlineMode === 1) { return '实线下划线'; }
    if (this.editUnderlineMode === 2) { return '虚线下划线'; }
    if (this.editUnderlineMode === 3) { return '波浪下划线'; }
    if (this.editUnderlineMode === 4) { return '双线下划线'; }
    if (this.editUnderlineMode === 5) { return 'SVG 下划线'; }
    if (this.editUnderlineMode === 6) { return '删除线'; }
    if (this.editUnderlineMode === 7) { return '荧光下划线'; }
    return '无下划线';
  }

  private targetScopeLabel(): string {
    if (this.editTargetScope === 0) { return '全部'; }
    if (this.editTargetScope === 1) { return '仅标题'; }
    return '仅正文';
  }

  private cycleTargetScope(): void {
    this.editTargetScope = (this.editTargetScope + 1) % 3;
  }

  /** 预览卡用的示例文字：没填就用默认示例。 */
  private previewSample(): string {
    const sample = this.editSample.trim();
    return sample.length > 0 ? sample : '这是一行示例正文';
  }

  private previewTextColor(): string {
    return this.editTextColor.trim().length > 0 ? this.editTextColor.trim() : '#E5E6EB';
  }

  private previewBackgroundColor(): string {
    return this.editBackgroundColor.trim().length > 0 ? this.editBackgroundColor.trim() : Color.Transparent.toString();
  }

  /** 上游 HighlightRuleEditSheet 的 SectionTitle：整宽、居中、上下 8dp。 */
  @Builder
  private SectionTitle(label: string) {
    Text(label).fontSize(12).fontColor('#9AA0B2').width('100%')
      .textAlign(TextAlign.Center).padding({ top: 8, bottom: 8 }).margin({ bottom: 4 })
  }

  /** 预览卡的下划线装饰：只映射系统支持的线型。 */
  private previewDecorationType(): TextDecorationType {
    if (this.editUnderlineMode === 2) { return TextDecorationType.Underline; }
    if (this.editUnderlineMode === 6) { return TextDecorationType.LineThrough; }
    if (this.editUnderlineMode === 0) { return TextDecorationType.None; }
    return TextDecorationType.Underline;
  }

  private async commit(next: ReaderHighlightRule[]): Promise<void> {
    if (this.saving) { return; }
    const previous = this.draftRules.map((rule: ReaderHighlightRule) => this.copyRule(rule));
    this.draftRules = next.map((rule: ReaderHighlightRule) => this.copyRule(rule));
    this.saving = true;
    this.errorMessage = '';
    try {
      this.draftRules = await this.onSave(next);
    } catch (_) {
      this.draftRules = previous;
      this.errorMessage = '保存失败，请重试';
    }
    this.saving = false;
  }

  private async saveRule(): Promise<void> {
    if (this.saving) { return; }
    const name = this.editName.trim();
    const pattern = this.editPattern.trim();
    if (name.length === 0 || pattern.length === 0) {
      this.errorMessage = '规则名称和正则表达式不能为空';
      return;
    }
    if (!ReaderHighlightRuleEngine.isSupported(pattern)) {
      this.errorMessage = '该正则超出 HOS RegExp 安全兼容范围或语法不兼容';
      return;
    }
    const textColor = this.editTextColor.trim().length === 0
      ? undefined : ReaderHighlightRuleEngine.colorFromCss(this.editTextColor);
    const bgColor = this.editBackgroundColor.trim().length === 0
      ? undefined : ReaderHighlightRuleEngine.colorFromCss(this.editBackgroundColor);
    const underlineColor = this.editUnderlineColor.trim().length === 0
      ? undefined : ReaderHighlightRuleEngine.colorFromCss(this.editUnderlineColor);
    if ((this.editTextColor.trim().length > 0 && textColor === undefined) ||
      (this.editBackgroundColor.trim().length > 0 && bgColor === undefined) ||
      (this.editUnderlineColor.trim().length > 0 && underlineColor === undefined)) {
      this.errorMessage = '颜色请填写 #RRGGBB 或 #AARRGGBB';
      return;
    }
    const existing = this.draftRules.find((rule: ReaderHighlightRule) => rule.id === this.editId);
    const rule: ReaderHighlightRule = existing === undefined ? {
      id: `reader_highlight_${Date.now().toString()}`,
      name: name,
      pattern: pattern,
      targetScope: 2,
      enabled: true,
      position: this.draftRules.length,
      underlineMode: this.editUnderlineMode,
      textColor: textColor,
      bgColor: bgColor,
      underlineColor: underlineColor
    } : this.copyRule(existing);
    rule.name = name;
    rule.pattern = pattern;
    rule.targetScope = this.editTargetScope;
    rule.enabled = this.editEnabled;
    rule.textColor = textColor;
    rule.bgColor = bgColor;
    rule.underlineMode = this.editUnderlineMode;
    rule.underlineColor = underlineColor;
    const next = this.editId.length > 0
      ? this.draftRules.map((item: ReaderHighlightRule) => item.id === rule.id ? rule : item)
      : [...this.draftRules, rule];
    await this.commit(next);
    if (this.errorMessage.length === 0) { this.editorVisible = false; }
  }

  private async setEnabled(id: string, enabled: boolean): Promise<void> {
    if (this.saving) { return; }
    const next = this.draftRules.map((rule: ReaderHighlightRule) => {
      const copy = this.copyRule(rule);
      if (copy.id === id) { copy.enabled = enabled; }
      return copy;
    });
    await this.commit(next);
  }

  private async moveRule(id: string, direction: number): Promise<void> {
    if (this.saving) { return; }
    const from = this.draftRules.findIndex((rule: ReaderHighlightRule) => rule.id === id);
    const to = from + direction;
    if (from < 0 || to < 0 || to >= this.draftRules.length) { return; }
    const next = [...this.draftRules];
    const moved = next.splice(from, 1)[0];
    if (moved === undefined) { return; }
    next.splice(to, 0, moved);
    await this.commit(next);
  }

  private async confirmDelete(): Promise<void> {
    if (this.saving) { return; }
    const id = this.pendingDeleteId;
    if (id.length === 0) { return; }
    await this.commit(this.draftRules.filter((rule: ReaderHighlightRule) => rule.id !== id));
    if (this.errorMessage.length === 0) { this.pendingDeleteId = ''; }
  }

  // ForEach 的 key 必须覆盖会影响条目外观的字段；只用 id 时切换启停后 ArkUI 会复用旧节点，
  // 导致存储已改而条目仍显示「已启用」。与替换净化列表页 ruleRowKey 同一思路。
  private ruleItemKey(rule: ReaderHighlightRule): string {
    return `${rule.id}_${rule.enabled ? 1 : 0}_${rule.position}_${rule.name}_${rule.pattern}_${rule.underlineMode}`;
  }

  /**
   * 打开预设面板。默认勾选口径与上游一致：只勾「本地缺失」的预设，
   * 已存在同 id 的标为「已有」且不勾，避免把用户改过样式的旧规则悄悄覆盖掉。
   * 标题作用域的预设本地引擎不执行，默认不勾并在条目上如实标注。
   */
  private openPresets(): void {
    const existingIds: string[] = this.draftRules.map((rule: ReaderHighlightRule) => rule.id);
    const selected: string[] = [];
    const presets = ReaderHighlightRulePresets.rules();
    for (let index = 0; index < presets.length; index++) {
      const preset = presets[index];
      if (preset === undefined) { continue; }
      if (existingIds.includes(preset.id)) { continue; }
      // 本地只跑正文规则，标题预设勾了也不会生效，默认不勾。
      if (preset.targetScope !== ReaderHighlightRulePresets.targetContent) { continue; }
      selected.push(preset.id);
    }
    this.presetSelectedIds = selected;
    this.errorMessage = '';
    this.presetVisible = true;
  }

  private presetStatus(preset: ReaderHighlightRule): string {
    if (this.draftRules.some((rule: ReaderHighlightRule) => rule.id === preset.id)) { return '已有'; }
    if (preset.targetScope !== ReaderHighlightRulePresets.targetContent) { return '标题规则，本地暂不执行'; }
    if (!ReaderHighlightRuleEngine.isSupported(preset.pattern)) { return '此正则在本机不受支持'; }
    return '可添加';
  }

  private isPresetSelectable(preset: ReaderHighlightRule): boolean {
    if (this.draftRules.some((rule: ReaderHighlightRule) => rule.id === preset.id)) { return false; }
    return ReaderHighlightRuleEngine.isSupported(preset.pattern);
  }

  private togglePresetSelection(id: string): void {
    if (this.presetSelectedIds.includes(id)) {
      this.presetSelectedIds = this.presetSelectedIds.filter((item: string) => item !== id);
    } else {
      this.presetSelectedIds = [...this.presetSelectedIds, id];
    }
  }

  /** 把勾选的预设追加到规则末尾；已有同 id 的直接跳过，绝不覆盖用户改过的样式。 */
  private async applyPresets(): Promise<void> {
    if (this.saving) { return; }
    if (this.presetSelectedIds.length === 0) {
      this.errorMessage = '请先勾选要添加的预设规则';
      return;
    }
    const existingIds: string[] = this.draftRules.map((rule: ReaderHighlightRule) => rule.id);
    const next = this.draftRules.map((rule: ReaderHighlightRule) => this.copyRule(rule));
    let added = 0;
    const presets = ReaderHighlightRulePresets.rules();
    for (let index = 0; index < presets.length; index++) {
      const preset = presets[index];
      if (preset === undefined || !this.presetSelectedIds.includes(preset.id)) { continue; }
      if (existingIds.includes(preset.id)) { continue; }
      const rule = this.copyRule(preset);
      rule.position = next.length;
      next.push(rule);
      added += 1;
    }
    if (added === 0) {
      this.errorMessage = '所选预设已全部存在，未添加任何规则';
      return;
    }
    await this.commit(next);
    if (this.errorMessage.length === 0) {
      this.presetVisible = false;
      this.presetSelectedIds = [];
    }
  }

  // 预设面板的 key 要覆盖勾选态，否则点击后勾选框不刷新（与 ruleItemKey 同一类问题）。
  private presetItemKey(preset: ReaderHighlightRule): string {
    return `${preset.id}_${this.presetSelectedIds.includes(preset.id) ? 1 : 0}`;
  }

  private ruleStatus(rule: ReaderHighlightRule): string {
    if (!ReaderHighlightRuleEngine.isSupported(rule.pattern)) { return '此正则在本机不受支持'; }
    if ((rule.targetScope !== 0 && rule.targetScope !== 2) ||
      (rule.configName !== null && rule.configName !== undefined && rule.configName.trim().length > 0)) {
      return '当前仅匹配正文全局规则';
    }
    return rule.enabled ? '正文规则 · 已启用' : '正文规则 · 已停用';
  }

  @Builder
  private buildRuleItem(rule: ReaderHighlightRule, index: number) {
    Row() {
      Column() {
        Text(rule.name).fontSize(15).fontColor('#E5E6EB').maxLines(1)
        Text(rule.pattern).fontSize(11).fontColor('#AEB0BA').maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 4 })
        Text(this.ruleStatus(rule)).fontSize(11)
          .fontColor(ReaderHighlightRuleEngine.isSupported(rule.pattern) ? '#AEB0BA' : '#FFB4AB')
          .margin({ top: 4 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start).onClick(() => this.startEdit(rule))
      Column() {
        Toggle({ type: ToggleType.Switch, isOn: rule.enabled })
          .onChange((enabled: boolean) => this.setEnabled(rule.id, enabled))
        Row() {
          Text('↑').fontSize(14).fontColor('#B9C6FF').padding(5)
            .onClick(() => this.moveRule(rule.id, -1))
          Text('↓').fontSize(14).fontColor('#B9C6FF').padding(5)
            .onClick(() => this.moveRule(rule.id, 1))
          Text('删').fontSize(12).fontColor('#FFB4AB').padding(5)
            .onClick(() => this.pendingDeleteId = rule.id)
        }
      }.alignItems(HorizontalAlign.End)
    }.width('100%').padding(12).backgroundColor('#24252C').borderRadius(14).margin({ bottom: 8 })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column().width('100%').height('100%').backgroundColor('#99000000')
        .onClick(() => this.onDismiss())
      Column() {
        Row() {
          Text(this.editorVisible ? (this.editId.length > 0 ? '编辑高亮规则' : '新建高亮规则') : '高亮规则')
            .fontSize(18).fontWeight(FontWeight.Medium).fontColor('#E5E6EB').layoutWeight(1)
          Text('关闭').fontSize(13).fontColor('#C7C9D1').padding(8).onClick(() => this.onDismiss())
        }.width('100%').padding({ bottom: 12 })
        if (!this.editorVisible) {
          Text('仅匹配当前章节正文全局规则；不修改原文或划线笔记。')
            .fontSize(12).fontColor('#AEB0BA').width('100%').margin({ bottom: 6 })
          if (this.chapterLength > ReaderHighlightRuleEngine.maximumChapterCharacters) {
            Text('当前章节超过 150000 个 UTF-16 字符，出于防卡顿保护，本章暂不执行正则。')
              .fontSize(11).fontColor('#FFB4AB').width('100%').margin({ bottom: 10 })
          }
          if (this.draftRules.length > ReaderHighlightRuleEngine.maximumRuleCount) {
            Text('规则数超过 64 条，本次阅读暂不执行正则。')
              .fontSize(11).fontColor('#FFB4AB').width('100%').margin({ bottom: 10 })
          }
          if (this.draftRules.length === 0) {
            Column() {
              Text('还没有阅读高亮规则').fontSize(15).fontColor('#E5E6EB')
              Text('添加规则后，命中内容会在正文中即时套用样式。')
                .fontSize(12).fontColor('#AEB0BA').margin({ top: 6 })
            }.width('100%').padding({ top: 26, bottom: 26 }).alignItems(HorizontalAlign.Center)
          } else {
            Scroll() {
              Column() {
                ForEach(this.draftRules, (rule: ReaderHighlightRule, index: number) => {
                  this.buildRuleItem(rule, index)
                }, (rule: ReaderHighlightRule) => this.ruleItemKey(rule))
              }.width('100%')
            }.layoutWeight(1).scrollBar(BarState.Off)
          }
          Row() {
            Text('预设规则').fontSize(14).fontColor('#C7C9D1')
              .padding({ left: 16, right: 16, top: 11, bottom: 11 })
              .backgroundColor('#303139').borderRadius(22)
              .onClick(() => this.openPresets())
            Blank().layoutWeight(1)
            Text('＋ 新建规则').fontSize(14).fontColor('#101116')
              .padding({ left: 18, right: 18, top: 11, bottom: 11 })
              .backgroundColor('#B9C6FF').borderRadius(22).onClick(() => this.startCreate())
          }.width('100%').margin({ top: 12 })
        } else {
          Scroll() {
            Column() {
              // 分区 1：规则信息（上游 HighlightRuleEditSheet.kt:363-418）
              this.SectionTitle('规则信息')
              Text('规则名称').fontSize(12).fontColor('#BFC2CD').width('100%')
              TextInput({ text: this.editName, placeholder: '例如：对话高亮' })
                .onChange((value: string) => this.editName = value)
                .fontSize(14).margin({ top: 6, bottom: 12 })
              Text('HOS 正则表达式').fontSize(12).fontColor('#BFC2CD').width('100%')
              TextInput({ text: this.editPattern, placeholder: '输入正文匹配正则' })
                .onChange((value: string) => this.editPattern = value)
                .fontSize(14).margin({ top: 6, bottom: 6 })
              Text('使用 HOS RegExp 子集；最长 256 字符，拒绝常见高回溯结构；没有硬超时。')
                .fontSize(11).fontColor('#AEB0BA').width('100%').margin({ bottom: 12 })
              Row() {
                Text('作用范围').fontSize(13).fontColor('#C7C9D1').layoutWeight(1)
                Text(this.targetScopeLabel()).fontSize(13).fontColor('#B9C6FF')
                  .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                  .backgroundColor('#303139').borderRadius(12).onClick(() => this.cycleTargetScope())
              }.width('100%').margin({ bottom: 10 })
              Row() {
                Text('启用').fontSize(13).fontColor('#C7C9D1').layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.editEnabled })
                  .selectedColor('#B9C6FF')
                  .onChange((isOn: boolean) => this.editEnabled = isOn)
              }.width('100%').margin({ bottom: 4 })

              // 分区 2：样式设置（上游 :422-673，本地只取渲染支持的色/线型）
              this.SectionTitle('样式设置')
              Text('字色（可空）').fontSize(12).fontColor('#BFC2CD').width('100%')
              TextInput({ text: this.editTextColor, placeholder: '#RRGGBB 或 #AARRGGBB' })
                .onChange((value: string) => this.editTextColor = value)
                .fontSize(14).margin({ top: 6, bottom: 12 })
              Text('背景色（可空）').fontSize(12).fontColor('#BFC2CD').width('100%')
              TextInput({ text: this.editBackgroundColor, placeholder: '#RRGGBB 或 #AARRGGBB' })
                .onChange((value: string) => this.editBackgroundColor = value)
                .fontSize(14).margin({ top: 6, bottom: 12 })
              Row() {
                Text('下划线样式').fontSize(13).fontColor('#C7C9D1').layoutWeight(1)
                Text(this.underlineLabel()).fontSize(13).fontColor('#B9C6FF')
                  .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                  .backgroundColor('#303139').borderRadius(12).onClick(() => this.cycleUnderlineMode())
              }.width('100%').margin({ bottom: 10 })
              Text('线条颜色（可空）').fontSize(12).fontColor('#BFC2CD').width('100%')
              TextInput({ text: this.editUnderlineColor, placeholder: '#RRGGBB 或 #AARRGGBB' })
                .onChange((value: string) => this.editUnderlineColor = value)
                .fontSize(14).margin({ top: 6, bottom: 12 })

              // 分区 3：预览效果（上游 :796-813）
              this.SectionTitle('预览效果')
              TextInput({ text: this.editSample, placeholder: '输入示例文字' })
                .onChange((value: string) => this.editSample = value)
                .fontSize(14).margin({ bottom: 8 })
              Row() {
                Text(this.previewSample())
                  .fontSize(15).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .fontColor(this.previewTextColor())
                  .backgroundColor(this.previewBackgroundColor())
                  .padding({ left: 8, right: 8, top: 6, bottom: 6 })
                  .borderRadius(6)
                  .decoration({
                    type: this.previewDecorationType(),
                    color: this.editUnderlineColor.trim().length > 0 ? this.editUnderlineColor.trim() : '#B9C6FF'
                  })
              }.width('100%').height(72).alignItems(VerticalAlign.Center)
              .padding(10).backgroundColor('#24252C').borderRadius(16).margin({ bottom: 12 })
              Text('九宫格切图与背景图需要画布支持后才能配置，此处暂不提供；表格里的对应行仍记为未接。')
                .fontSize(11).fontColor('#AEB0BA').width('100%').margin({ bottom: 4 })
            }.width('100%')
          }.layoutWeight(1).scrollBar(BarState.Off)
          Row() {
            Text('取消').fontSize(14).fontColor('#C7C9D1').padding(10)
              .onClick(() => this.editorVisible = false)
            Blank().layoutWeight(1)
            if (this.editId.length > 0) {
              Text('删除').fontSize(14).fontColor('#FFB4AB').padding(10)
                .onClick(() => this.pendingDeleteId = this.editId)
            }
            Text(this.saving ? '保存中' : '保存').fontSize(14).fontColor('#101116')
              .padding({ left: 18, right: 18, top: 10, bottom: 10 })
              .backgroundColor('#B9C6FF').borderRadius(20)
              .onClick(() => this.saveRule())
          }.width('100%').margin({ top: 8 })
        }
        if (this.errorMessage.length > 0) {
          Text(this.errorMessage).fontSize(12).fontColor('#FFB4AB').width('100%').margin({ top: 8 })
        }
      }
      .width('100%').height('82%').padding(18).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated))
      .borderRadius({ topLeft: 24, topRight: 24 }).alignItems(HorizontalAlign.Start)
      if (this.pendingDeleteId.length > 0) {
        Column() {
          Text('删除这条阅读高亮规则？').fontSize(16).fontColor('#E5E6EB')
          Row() {
            Text('取消').fontSize(14).fontColor('#C7C9D1').padding(10)
              .onClick(() => this.pendingDeleteId = '')
            Text('删除').fontSize(14).fontColor('#101116')
              .padding({ left: 18, right: 18, top: 9, bottom: 9 })
              .backgroundColor('#FFB4AB').borderRadius(18)
              .onClick(() => this.confirmDelete())
          }.width('100%').justifyContent(FlexAlign.End).margin({ top: 12 })
        }.width('82%').padding(18).backgroundColor('#292A31').borderRadius(18).zIndex(2)
      }
      if (this.presetVisible) {
        Column() {
          Text('预设规则').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#E5E6EB')
            .width('100%')
          Text('勾选后追加到规则列表；已存在的同 id 规则不会被覆盖，只补缺失的。')
            .fontSize(12).fontColor('#AEB0BA').width('100%').margin({ top: 6, bottom: 12 })
          Scroll() {
            Column() {
              ForEach(ReaderHighlightRulePresets.rules(), (preset: ReaderHighlightRule) => {
                Row() {
                  Column() {
                    Text(preset.name).fontSize(15).fontColor('#E5E6EB').maxLines(1)
                    Text(preset.pattern).fontSize(11).fontColor('#AEB0BA').maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 4 })
                    Text(this.presetStatus(preset)).fontSize(11)
                      .fontColor(this.isPresetSelectable(preset) ? '#AEB0BA' : '#FFB4AB')
                      .margin({ top: 4 })
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                  Checkbox()
                    .select(this.presetSelectedIds.includes(preset.id))
                    .enabled(this.isPresetSelectable(preset))
                    .onChange(() => this.togglePresetSelection(preset.id))
                }.width('100%').padding(12).backgroundColor('#24252C').borderRadius(14)
                .margin({ bottom: 8 })
                .onClick(() => {
                  if (this.isPresetSelectable(preset)) { this.togglePresetSelection(preset.id); }
                })
              }, (preset: ReaderHighlightRule) => this.presetItemKey(preset))
            }.width('100%')
          }.layoutWeight(1).scrollBar(BarState.Off)
          Row() {
            Text('取消').fontSize(14).fontColor('#C7C9D1').padding(10)
              .onClick(() => {
                this.presetVisible = false;
                this.presetSelectedIds = [];
                this.errorMessage = '';
              })
            Blank().layoutWeight(1)
            Text(this.saving ? '添加中' : `添加 ${this.presetSelectedIds.length} 条`)
              .fontSize(14).fontColor('#101116')
              .padding({ left: 18, right: 18, top: 10, bottom: 10 })
              .backgroundColor('#B9C6FF').borderRadius(20)
              .onClick(() => this.applyPresets())
          }.width('100%').margin({ top: 10 })
        }
        .width('90%').height('72%').padding(18).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated))
        .borderRadius(20).zIndex(3)
      }
    }
    .width('100%').height('100%').zIndex(1200)
  }
}
