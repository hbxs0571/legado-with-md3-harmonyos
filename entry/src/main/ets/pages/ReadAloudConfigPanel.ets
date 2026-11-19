
import {
  ReadAloudSettingsRepository, ReadAloudSettingsSnapshot,
  DEFAULT_READ_ALOUD_SETTINGS, copyReadAloudSettings
} from '../data/ReadAloudSettingsRepository';
import { HttpTtsPlayer } from '../readaloud/HttpTtsPlayer';

/**
 * 朗读设置浮层。对齐上游 ReadAloudConfigContent.kt 第一页里本地有真实消费者的项：
 * default_read_aloud_interface / read_aloud_player_background / show_read_aloud_capsule /
 * capsule_auto_collapse / reset_read_aloud_capsule_position / tts_pre_synthesis_concurrency /
 * tts_paragraph_interval / audio_cache_clean_time / tts_cache_manage / clear_cache。
 * 上游依赖 AI 角色体系、Android 专有能力或平台无对应 API 的项不在这里铺空壳。
 */
@Component
export struct ReadAloudConfigPanel {
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#494C59';

  @Prop settings: ReadAloudSettingsSnapshot = DEFAULT_READ_ALOUD_SETTINGS;
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
  /** 复位胶囊位置（上游 ReadAloudConfigContent.kt:243 reset_read_aloud_capsule_position）。 */
  onResetCapsulePosition: () => void = () => {};

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

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%').height('100%')
        .backgroundColor('#88000000')
        .onClick(() => this.onBack())

      Column() {
        Row() {
          Image($r('app.media.reader_back')).width(22).height(22)
            .fillColor(this.themeColorTextPrimary)
            .onClick(() => this.onBack())
          Text('朗读设置').fontSize(15).fontColor(this.themeColorTextPrimary).margin({ left: 10 })
          Blank()
        }.width('100%').padding({ left: 16, right: 16, bottom: 14 })

        Scroll() {
          Column() {
            ConfigSelectRow({ label: '默认朗读界面', value: this.interfaceLabels[this.defaultInterfaceIndex] ?? '',
              onNext: (): void => {
                this.defaultInterfaceIndex = (this.defaultInterfaceIndex + 1) % this.interfaceValues.length;
                this.commit();
              } })
            ConfigSelectRow({ label: '听书界面背景', value: this.bgLabels[this.bgModeIndex] ?? '',
              onNext: (): void => {
                this.bgModeIndex = (this.bgModeIndex + 1) % this.bgLabels.length;
                this.commit();
              } })
            ConfigSwitchRow({ label: '显示朗读胶囊', checked: this.capsuleVisible,
              onChange: (value: boolean): void => { this.capsuleVisible = value; this.commit(); } })
            ConfigSwitchRow({ label: '胶囊自动收起', checked: this.autoCollapse,
              onChange: (value: boolean): void => { this.autoCollapse = value; this.commit(); } })

            ConfigSliderRow({ label: '预合成并发数', valueText: `${this.preSynthesisConcurrency}`,
              value: this.preSynthesisConcurrency, min: 1, max: 8, step: 1,
              onChange: (value: number): void => { this.preSynthesisConcurrency = Math.round(value); },
              onCommit: (): void => this.commit() })
            ConfigSliderRow({ label: '段落间隔', valueText: `${this.paragraphInterval} 毫秒`,
              value: this.paragraphInterval, min: 0, max: 2000, step: 50,
              onChange: (value: number): void => { this.paragraphInterval = Math.round(value); },
              onCommit: (): void => this.commit() })
            ConfigSliderRow({ label: '缓存清理时间', valueText: this.cacheCleanTime === 0
              ? '不清理' : `${this.cacheCleanTime} 分钟`,
              value: this.cacheCleanTime, min: 0, max: 10080, step: 30,
              onChange: (value: number): void => { this.cacheCleanTime = Math.round(value); },
              onCommit: (): void => this.commit() })

            ConfigSelectRow({ label: '朗读缓存', value: this.cacheSizeText,
              onNext: (): void => this.clearCache() })

            Text('复位朗读胶囊位置')
              .fontSize(13).fontColor(this.themeColorTextPrimary)
              .width('100%').textAlign(TextAlign.Center).padding({ top: 14, bottom: 14 })
              .backgroundColor('#202127').borderRadius(14)
              .margin({ left: 14, right: 14, bottom: 10 })
              .onClick(() => this.onResetCapsulePosition())
          }
        }.width('100%').layoutWeight(1)
      }
      .width('100%').height('64%')
      .backgroundColor(this.themeColorSurfaceSecondary)
      .borderRadius(22)
    }
    .width('100%').height('100%')
  }
}

@Component
struct ConfigSwitchRow {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @Prop label: string = '';
  @Prop checked: boolean = false;
  onChange: (value: boolean) => void = (_value: boolean): void => {};

  build() {
    Row() {
      Text(this.label).fontSize(13).fontColor(this.themeColorTextPrimary).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.checked })
        .onChange((value: boolean): void => this.onChange(value))
    }
    .width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor('#202127').borderRadius(14)
    .margin({ left: 14, right: 14, bottom: 10 })
  }
}

@Component
struct ConfigSelectRow {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#494C59';
  @Prop label: string = '';
  @Prop value: string = '';
  onNext: () => void = () => {};

  build() {
    Row() {
      Text(this.label).fontSize(13).fontColor(this.themeColorTextPrimary).layoutWeight(1)
      Text(this.value).fontSize(12).fontColor(this.themeColorTextSecondary).margin({ right: 8 })
      Image($r('app.media.reader_next')).width(14).height(14).fillColor(this.themeColorTextSecondary)
    }
    .width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor('#202127').borderRadius(14)
    .margin({ left: 14, right: 14, bottom: 10 })
    .onClick(() => this.onNext())
  }
}

@Component
struct ConfigSliderRow {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#494C59';
  @Prop label: string = '';
  @Prop valueText: string = '';
  @Prop value: number = 0;
  @Prop min: number = 0;
  @Prop max: number = 100;
  @Prop step: number = 1;
  onChange: (value: number) => void = (_value: number): void => {};
  onCommit: () => void = () => {};

  build() {
    Column() {
      Row() {
        Text(this.label).fontSize(13).fontColor(this.themeColorTextPrimary)
        Blank()
        Text(this.valueText).fontSize(11).fontColor(this.themeColorTextSecondary)
      }.width('100%')
      Slider({ value: this.value, min: this.min, max: this.max, step: this.step, style: SliderStyle.OutSet })
        .width('100%')
        .onChange((value: number, mode: SliderChangeMode): void => {
          this.onChange(value);
          if (mode === SliderChangeMode.End) { this.onCommit(); }
        })
    }
    .width('100%').padding({ left: 16, right: 16, top: 14, bottom: 16 })
    .backgroundColor('#202127').borderRadius(14)
    .margin({ left: 14, right: 14, bottom: 10 })
  }
}
