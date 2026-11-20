
import {
  ReadAloudSettingsRepository, ReadAloudSettingsSnapshot,
  DEFAULT_READ_ALOUD_SETTINGS, copyReadAloudSettings
} from '../data/ReadAloudSettingsRepository';
import { HttpTtsPlayer } from '../readaloud/HttpTtsPlayer';
import { glassColor, AloudSliderSetting } from '../components/ReadAloudGlassWidgets';
import { ReaderSheetShell } from '../components/ReaderSheetShell';

/**
 * 朗读设置浮层。视觉对齐上游 ReadAloudConfigContent.kt：
 *   - 半透明磨砂玻璃面板 + 玻璃设置行（GlassCard 的 containerOpacity + 容器背景）；
 *   - 三页 CardTabRow（常规 / 引擎与音色 / 角色与配乐）；
 *   - 滑杆行是 ValueStepper（− 值 +），点标题展开滑杆（TinySliderSettingItem）。
 * 配色全取主题色槽位，跟随日夜主题。
 */
@Component
export struct ReadAloudConfigPanel {
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#494C59';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';

  @Prop settings: ReadAloudSettingsSnapshot = DEFAULT_READ_ALOUD_SETTINGS;
  @State selectedTab: number = 0;
  @State capsuleVisible: boolean = true;
  @State autoCollapse: boolean = true;
  @State paragraphInterval: number = 0;
  @State defaultInterfaceIndex: number = 0;
  @State bgModeIndex: number = 1;
  @State preSynthesisConcurrency: number = 3;
  @State cacheCleanTime: number = 10;
  @State cacheSizeText: string = '0 KB';

  onBack: () => void = () => {};
  onSettingsChange: (settings: ReadAloudSettingsSnapshot) => void = (_settings: ReadAloudSettingsSnapshot) => {};
  /** 复位胶囊位置（上游 reset_read_aloud_capsule_position）。 */
  onResetCapsulePosition: () => void = () => {};
  /** 打开朗读引擎与音色页（上游 read_aloud_engines_and_voices）。 */
  onOpenEngine: () => void = () => {};

  private readonly interfaceLabels: string[] = ['经典面板', '听书界面'];
  private readonly interfaceValues: string[] = ['classic', 'player'];
  private readonly bgLabels: string[] = ['纯色', '封面模糊', '流动光', '透明'];

  aboutToAppear(): void {
    this.capsuleVisible = this.settings.showReadAloudCapsule;
    this.autoCollapse = this.settings.capsuleAutoCollapse;
    this.paragraphInterval = this.settings.ttsParagraphInterval;
    const idx = this.interfaceValues.indexOf(this.settings.defaultInterface);
    this.defaultInterfaceIndex = idx >= 0 ? idx : 0;
    this.bgModeIndex = Math.max(0, Math.min(3, Math.trunc(this.settings.playerBgMode)));
    this.preSynthesisConcurrency = Math.max(1, Math.min(8, Math.trunc(this.settings.preSynthesisConcurrency)));
    this.cacheCleanTime = Math.max(0, Math.min(10080, Math.trunc(this.settings.audioCacheCleanTime)));
    this.refreshCacheSize();
  }

  private commit(): void {
    const updated: ReadAloudSettingsSnapshot = copyReadAloudSettings(this.settings);
    updated.showReadAloudCapsule = this.capsuleVisible;
    updated.capsuleAutoCollapse = this.autoCollapse;
    updated.ttsParagraphInterval = this.paragraphInterval;
    updated.defaultInterface = this.interfaceValues[this.defaultInterfaceIndex] ?? 'classic';
    updated.playerBgMode = this.bgModeIndex;
    updated.preSynthesisConcurrency = this.preSynthesisConcurrency;
    updated.audioCacheCleanTime = this.cacheCleanTime;
    this.onSettingsChange(updated);
  }

  private refreshCacheSize(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const bytes = HttpTtsPlayer.cacheSizeBytes(context);
    this.cacheSizeText = bytes < 1024 ? `${bytes} B`
      : (bytes < 1024 * 1024 ? `${(bytes / 1024).toFixed(1)} KB`
        : `${(bytes / (1024 * 1024)).toFixed(1)} MB`);
  }

  private clearCache(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    HttpTtsPlayer.getInstance().clearCache(context);
    this.refreshCacheSize();
    this.getUIContext().getPromptAction().showToast({ message: '朗读缓存已清空' });
  }

  /** CardTabRow 单页签：选中 secondaryContainer（本地降级 surfaceElevated）+ 强调色字。 */
  @Builder
  tabCard(label: string, index: number) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontWeight(this.selectedTab === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.selectedTab === index ? this.themeColorAccent : this.themeColorTextSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
    }
    .layoutWeight(1)
    .height(40)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.selectedTab === index
      ? glassColor(this.themeColorSurfaceElevated, 0.95)
      : glassColor(this.themeColorSurfaceSecondary, 0.45))
    .backdropBlur(12)
    .borderRadius(12)
    .padding({ left: 8, right: 8 })
  }

  build() {
    // 上游 AppModalBottomSheet：圆角 28、scrim 平台默认、抓手统一 rsetHandle 去 opacity。
    // glassColor + backdropBlur 是朗读域 GlassCard 本来就有的，通过参数保留。
    ReaderSheetShell({
      scrimColor: '#66000000',
      panelColor: glassColor(this.themeColorSurfacePrimary, 0.82),
      panelHeight: '70%',
      blurRadius: 30,
      onDismiss: () => this.onBack()
    }) {
        Row() {
          Image($r('app.media.reader_back')).width(22).height(22)
            .fillColor(this.themeColorTextPrimary)
            .onClick(() => this.onBack())
          Text('朗读设置').fontSize(16).fontWeight(FontWeight.Medium)
            .fontColor(this.themeColorTextPrimary).margin({ left: 10 })
          Blank()
        }.width('100%').padding({ left: 16, right: 16, bottom: 14 })

        Tabs({ barPosition: BarPosition.Start, index: this.selectedTab }) {
          // ---- 常规 ----
          TabContent() {
            Scroll() {
              Column() {
                ConfigGlassRow({ label: '默认朗读界面',
                  value: this.interfaceLabels[this.defaultInterfaceIndex] ?? '',
                  onNext: (): void => {
                    this.defaultInterfaceIndex = (this.defaultInterfaceIndex + 1) % this.interfaceValues.length;
                    this.commit();
                  } })
                ConfigGlassRow({ label: '听书界面背景',
                  value: this.bgLabels[this.bgModeIndex] ?? '',
                  onNext: (): void => {
                    this.bgModeIndex = (this.bgModeIndex + 1) % this.bgLabels.length;
                    this.commit();
                  } })
                ConfigGlassSwitch({ label: '显示朗读胶囊', checked: this.capsuleVisible,
                  onChange: (value: boolean): void => { this.capsuleVisible = value; this.commit(); } })
                // 上游胶囊样式/自动收起仅在胶囊开启时出现，跟着开关走。
                if (this.capsuleVisible) {
                  ConfigGlassSwitch({ label: '胶囊自动收起', checked: this.autoCollapse,
                    onChange: (value: boolean): void => { this.autoCollapse = value; this.commit(); } })
                  ConfigSectionTitle({ label: '胶囊外观' })
                  ConfigNote({ text: '上游有独立的胶囊样式页（圆角/背景/头像形状），本工程未实现。' })
                  ConfigGlassRow({ label: '复位朗读胶囊位置', value: '',
                    onNext: (): void => this.onResetCapsulePosition() })
                }
              }
            }.width('100%').height('100%')
          }.tabBar(this.tabCard('常规', 0))

          // ---- 引擎与音色 ----
          TabContent() {
            Scroll() {
              Column() {
                ConfigSectionTitle({ label: '引擎' })
                ConfigGlassRow({ label: '朗读引擎与音色', value: '',
                  onNext: (): void => this.onOpenEngine() })
                ConfigNote({ text: '系统 TTS 设置：鸿蒙无对应的系统朗读设置页，未实现。' })

                ConfigSectionTitle({ label: '合成与缓存' })
                AloudSliderSetting({ label: '预合成并发数',
                  valueText: `${this.preSynthesisConcurrency}`,
                  value: this.preSynthesisConcurrency, min: 1, max: 8, step: 1,
                  onChange: (value: number): void => { this.preSynthesisConcurrency = Math.round(value); },
                  onCommit: (): void => this.commit() })
                AloudSliderSetting({ label: '段落间隔', valueText: `${this.paragraphInterval} 毫秒`,
                  value: this.paragraphInterval, min: 0, max: 2000, step: 50,
                  onChange: (value: number): void => { this.paragraphInterval = Math.round(value); },
                  onCommit: (): void => this.commit() })
                AloudSliderSetting({ label: '缓存清理时间', valueText: this.cacheCleanTime === 0
                  ? '不清理' : `${this.cacheCleanTime} 分钟`,
                  value: this.cacheCleanTime, min: 0, max: 10080, step: 30,
                  onChange: (value: number): void => { this.cacheCleanTime = Math.round(value); },
                  onCommit: (): void => this.commit() })
                ConfigGlassRow({ label: '朗读缓存', value: this.cacheSizeText,
                  onNext: (): void => this.clearCache() })

                ConfigSectionTitle({ label: '正文切分' })
                ConfigNote({ text: '按段落/符号切分已由切段器实现，但设置页暂无选择入口；语音分析模式与 AI 推理级别未实现。' })
              }
            }.width('100%').height('100%')
          }.tabBar(this.tabCard('引擎与音色', 1))

          // ---- 角色与配乐 ----
          TabContent() {
            Scroll() {
              Column() {
                ConfigSectionTitle({ label: '角色' })
                ConfigNote({ text: '多角色朗读、角色配音分配、音色池依赖上游 AI 角色体系，本工程未实现。' })
                ConfigSectionTitle({ label: '配乐' })
                ConfigNote({ text: '背景音乐池、配乐场景识别依赖上游音频配乐体系，本工程未实现。' })
              }
            }.width('100%').height('100%')
          }.tabBar(this.tabCard('角色与配乐', 2))
        }
        .onChange((index: number): void => { this.selectedTab = index; })
        .barMode(BarMode.Fixed)
        .barWidth('100%')
        .barHeight(52)
        .layoutWeight(1)
    }
  }
}

/** Material3 SectionTitle：居中、labelMediumEmphasized（上游 SectionTitle.kt）。 */
@Component
struct ConfigSectionTitle {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#494C59';
  @Prop label: string = '';

  build() {
    Text(this.label).fontSize(13).fontWeight(FontWeight.Medium)
      .fontColor(this.themeColorTextSecondary)
      .width('100%').textAlign(TextAlign.Center)
      .padding({ left: 16, right: 16, top: 14, bottom: 6 })
  }
}

/** 上游未实现项的说明文字，直接铺在弹层底上。 */
@Component
struct ConfigNote {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#494C59';
  @Prop text: string = '';

  build() {
    Text(this.text).fontSize(11).fontColor(this.themeColorTextSecondary)
      .width('100%').padding({ left: 16, right: 16, top: 4, bottom: 8 })
      .lineHeight(17)
  }
}

/** TinySwitchSettingItem：玻璃卡片 + 开关（上游 TinySettingItems.kt:376）。 */
@Component
struct ConfigGlassSwitch {
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @Prop label: string = '';
  @Prop checked: boolean = false;
  onChange: (value: boolean) => void = (_value: boolean): void => {};

  build() {
    Row() {
      Text(this.label).fontSize(14).fontWeight(FontWeight.Medium)
        .fontColor(this.themeColorTextPrimary).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.checked })
        .selectedColor(this.themeColorAccent)
        .onChange((value: boolean): void => this.onChange(value))
    }
    .width('100%').constraintSize({ minHeight: 56 })
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(glassColor(this.themeColorSurfaceSecondary, 0.55))
    .backdropBlur(16)
    .borderRadius(12)
    .margin({ left: 12, right: 12, bottom: 6 })
    .onClick(() => this.onChange(!this.checked))
  }
}

/** TinyClickableSettingItem：玻璃卡片 + 尾部值 TextCard + chevron（上游 :409）。 */
@Component
struct ConfigGlassRow {
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#494C59';
  @Prop label: string = '';
  @Prop value: string = '';
  onNext: () => void = () => {};

  build() {
    Row() {
      Text(this.label).fontSize(14).fontWeight(FontWeight.Medium)
        .fontColor(this.themeColorTextPrimary).layoutWeight(1)
      if (this.value.length > 0) {
        Text(this.value).fontSize(12).fontColor(this.themeColorTextPrimary)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(glassColor(this.themeColorSurfaceElevated, 0.85)).borderRadius(8)
          .margin({ right: 6 })
      }
      Image($r('app.media.reader_next')).width(16).height(16)
        .fillColor(this.themeColorTextSecondary)
    }
    .width('100%').constraintSize({ minHeight: 56 })
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(glassColor(this.themeColorSurfaceSecondary, 0.55))
    .backdropBlur(16)
    .borderRadius(12)
    .margin({ left: 12, right: 12, bottom: 6 })
    .onClick(() => this.onNext())
  }
}
