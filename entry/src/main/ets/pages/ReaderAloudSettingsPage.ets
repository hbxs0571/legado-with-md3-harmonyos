
/**
 * 经典朗读控制面板。视觉对齐上游 ReadAloudScreen.kt + GlassCard.kt：
 *   - 整个面板是半透明磨砂玻璃（containerOpacity + backdropBlur），能透出后面正文；
 *   - 每个设置行也是玻璃卡片；Media 4 个 MediumTonalButton；
 *   - 「朗读语速」行用 ValueStepper（− 值 +），点标题展开滑杆
 *     （TinySliderSettingItem，上游 TinySettingItems.kt:287-373）；
 *   - 「背景音乐总音量」上游有此行，本地无 BGM 混音，做成点开弹「尚未迁移」的提示控件；
 *   - 底栏五个 ActionButton。
 * 配色全取主题色槽位跟随日夜主题。面板不持播放器，所有操作回调给 Index。
 */
import { glassColor, AloudSliderSetting } from '../components/ReadAloudGlassWidgets';
import { resolveGlassBlurRadius } from '../data/GlassColor';
import { ReaderSheetShell } from '../components/ReaderSheetShell';
import { BODY_SMALL, LABEL_LARGE, LABEL_MEDIUM, LABEL_SMALL, TITLE_MEDIUM, TITLE_SMALL, TITLE_SMALL_EMPHASIZED } from '../components/typography/TypographyTokens';

@Component
export struct ReaderAloudSettingsPage {
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#494C59';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';

  // 播放状态来自 SystemTtsPlayer（经 Index 回调同步）。0 空闲 / 1 播放中 / 2 暂停。
  @Prop aloudState: number = 0;
  @Prop unitIndex: number = 0;
  @Prop unitTotal: number = 0;
  @Prop initialRate: number = 5;
  @Prop initialTimerLabel: string = '关闭';
  /** 跟随系统（上游 flow_sys）：为 true 时语速滑杆禁用，HTTP 倍速固定 1.0x。 */
  @Prop followSys: boolean = true;

  @State rate: number = 5;
  /** 背景音乐总音量：上游有此行（相对人声的 BGM 音量），本地朗读无 BGM 混音，仅保留设定值。 */
  @State musicVolume: number = 100;
  @State timerLabel: string = '关闭';
  @State showTimerPicker: boolean = false;
  @State pickerMode: string = 'minute';
  @State timerMinutes: number = 1;
  @State timerChapters: number = 1;

  onBack: () => void = () => {};
  onOpenMainMenu: () => void = () => {};
  onOpenCatalog: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};

  onPrevious: () => void = () => {};
  onPauseToggle: () => void = () => {};
  onStop: () => void = () => {};
  onNext: () => void = () => {};
  onTurnChapter: (delta: number) => void = (_delta: number) => {};
  onRateChange: (rate: number) => void = (_rate: number) => {};
  onTimerChange: (mode: string, minutes: number, chapters: number) => void =
    (_mode: string, _minutes: number, _chapters: number) => {};
  onOpenConfig: () => void = () => {};
  onFollowSysChange: (follow: boolean) => void = (_follow: boolean) => {};
  /** 打开听书界面（上游 OpenReadAloudPlayer -> openPlayer）。 */
  onOpenPlayer: () => void = () => {};
  /** 切后台：退出阅读页但保留朗读（上游 CloseReadBook(keepReadAloud=true)）。 */
  onGoToBackground: () => void = () => {};

  aboutToAppear(): void {
    this.rate = this.initialRate;
    this.timerLabel = this.initialTimerLabel;
  }

  build() {
    // 上游 AppModalBottomSheet：圆角 28、scrim 平台默认、抓手统一 rsetHandle 去 opacity。
    // glassColor + backdropBlur 是朗读域 GlassCard 本来就有的，通过参数保留。
    ReaderSheetShell({
      scrimColor: '#66000000',
      panelColor: glassColor(this.themeColorSurfacePrimary, 0.78),
      panelHeight: '80%',
      blurRadius: resolveGlassBlurRadius(30),
      onDismiss: () => this.onBack()
    }) {
        Row() {
          Image($r('app.media.reader_back'))
            .width(22).height(22)
            .fillColor(this.themeColorTextPrimary)
            .onClick(() => this.onBack())
          Text('朗读设置')
            .fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium)
            .fontColor(this.themeColorTextPrimary)
            .margin({ left: 10 })
          Blank()
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 12 })

        Scroll() {
          Column() {
            // 上游顺序：上一句 / 暂停 / 停止 / 下一句（ReadAloudScreen.kt:77-104）。
            Row() {
              AloudTonalIcon({ icon: 'previous', onAction: () => this.onPrevious() })
              AloudTonalIcon({ icon: this.aloudState === 1 ? 'pause' : 'play',
                onAction: () => this.onPauseToggle() })
              AloudTonalIcon({ icon: 'stop', onAction: () => this.onStop() })
              Row() {
                Image($r('app.media.reader_next')).width(18).height(18)
                  .fillColor(this.themeColorTextPrimary)
                Text('下一句').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextPrimary).margin({ left: 6 })
              }
              .layoutWeight(1).height(48)
              .justifyContent(FlexAlign.Center)
              .backgroundColor(glassColor(this.themeColorSurfaceElevated, 0.7))
              .backdropBlur(resolveGlassBlurRadius(12)).borderRadius(24)
              .onClick(() => this.onNext())
            }
            .width('100%').padding(8)
            .backgroundColor(glassColor(this.themeColorSurfaceSecondary, 0.45))
            .backdropBlur(resolveGlassBlurRadius(16)).borderRadius(20)
            .margin({ left: 12, right: 12, bottom: 8 })

            Text(this.unitTotal > 0 ? `第 ${this.unitIndex + 1} / ${this.unitTotal} 句` : '未开始朗读')
              .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary)
              .width('100%').textAlign(TextAlign.Center).margin({ bottom: 10 })

            // TinyClickableSettingItem：定时（上游 set_timer）。ValueStepper 风格值在右、chevron 尾。
            ConfigGlassRow({ label: '定时', value: this.timerLabel,
              onNext: (): void => { this.showTimerPicker = !this.showTimerPicker; } })

            if (this.showTimerPicker) {
              Column() {
                Row() {
                  Text('关闭').fontSize(TITLE_SMALL_EMPHASIZED).fontColor(this.themeColorTextPrimary).layoutWeight(1)
                  if (this.timerLabel === '关闭') { Text('✓').fontSize(TITLE_SMALL).fontColor(this.themeColorAccent) }
                }.width('100%').padding(12)
                .onClick(() => {
                  this.timerLabel = '关闭';
                  this.onTimerChange('minute', 0, 0);
                  this.showTimerPicker = false;
                })
                Row() {
                  Text('按时长').fontSize(TITLE_SMALL_EMPHASIZED).fontColor(this.themeColorTextPrimary)
                  Blank()
                  Text(`${this.timerMinutes} 分钟`).fontSize(BODY_SMALL).fontColor(this.themeColorTextSecondary)
                }.width('100%').padding(12)
                .onClick(() => { this.pickerMode = 'minute'; })
                if (this.pickerMode === 'minute') {
                  Slider({ value: this.timerMinutes, min: 1, max: 60, step: 1, style: SliderStyle.OutSet })
                    .width('100%').selectedColor(this.themeColorAccent)
                    .onChange((value: number, _mode: SliderChangeMode) => { this.timerMinutes = Math.round(value); })
                }
                Row() {
                  Text('按章节').fontSize(TITLE_SMALL_EMPHASIZED).fontColor(this.themeColorTextPrimary)
                  Blank()
                  Text(`${this.timerChapters} 章`).fontSize(BODY_SMALL).fontColor(this.themeColorTextSecondary)
                }.width('100%').padding(12)
                .onClick(() => { this.pickerMode = 'chapter'; })
                if (this.pickerMode === 'chapter') {
                  Slider({ value: this.timerChapters, min: 1, max: 20, step: 1, style: SliderStyle.OutSet })
                    .width('100%').selectedColor(this.themeColorAccent)
                    .onChange((value: number, _mode: SliderChangeMode) => { this.timerChapters = Math.round(value); })
                }
                Text('确定').fontSize(LABEL_LARGE).fontColor(this.themeColorSurfacePrimary)
                  .width('100%').textAlign(TextAlign.Center).padding(12)
                  .borderRadius(12).backgroundColor(this.themeColorAccent)
                  .onClick(() => {
                    if (this.pickerMode === 'minute') {
                      this.timerLabel = `${this.timerMinutes} 分钟后停止`;
                      this.onTimerChange('minute', this.timerMinutes, 0);
                    } else {
                      this.timerLabel = `${this.timerChapters} 章后停止`;
                      this.onTimerChange('chapter', 0, this.timerChapters);
                    }
                    this.showTimerPicker = false;
                  })
              }
              .width('100%').padding(8)
              .backgroundColor(glassColor(this.themeColorSurfaceElevated, 0.85)).backdropBlur(resolveGlassBlurRadius(16)).borderRadius(12)
              .margin({ left: 12, right: 12, bottom: 6 })
            }

            // 上一章 / 下一章：两个 weight(1) tonal 按钮。
            Row() {
              Text('上一章').fontSize(LABEL_MEDIUM).fontWeight(FontWeight.Medium)
                .fontColor(this.themeColorTextPrimary)
                .layoutWeight(1).height(44).textAlign(TextAlign.Center)
                .backgroundColor(glassColor(this.themeColorSurfaceElevated, 0.7)).backdropBlur(resolveGlassBlurRadius(12)).borderRadius(22)
                .onClick(() => this.onTurnChapter(-1))
              Text('下一章').fontSize(LABEL_MEDIUM).fontWeight(FontWeight.Medium)
                .fontColor(this.themeColorTextPrimary)
                .layoutWeight(1).height(44).textAlign(TextAlign.Center)
                .backgroundColor(glassColor(this.themeColorSurfaceElevated, 0.7)).backdropBlur(resolveGlassBlurRadius(12)).borderRadius(22)
                .margin({ left: 8 })
                .onClick(() => this.onTurnChapter(1))
            }
            .width('100%').padding(8)
            .backgroundColor(glassColor(this.themeColorSurfaceSecondary, 0.45))
            .backdropBlur(resolveGlassBlurRadius(16)).borderRadius(20)
            .margin({ left: 12, right: 12, bottom: 10 })

            // 背景音乐总音量（上游 cast_bgm_master_volume）：上游有此行，本地 TTS 无 BGM 混音。
            // 按用户口径做成点了弹「尚未迁移」提示的控件——有反馈，不假装生效。
            ConfigGlassRow({ label: '背景音乐总音量', value: '尚未迁移',
              onNext: (): void => this.onUnavailableAction('背景音乐混音尚未迁移') })

            // 跟随系统（上游 flow_sys）：TinySwitchSettingItem。
            ConfigGlassSwitch({ label: '跟随系统', checked: this.followSys,
              onChange: (value: boolean): void => this.onFollowSysChange(value) })

            // 朗读语速（上游 read_aloud_speed，range 0..80，enabled=!followSys）：ValueStepper。
            AloudSliderSetting({ label: '朗读语速',
              description: '全局播放倍速，本地只对 HTTP 朗读源生效',
              valueText: `${this.rate}`,
              value: this.rate, min: 0, max: 80, step: 1, settingEnabled: !this.followSys,
              onChange: (value: number): void => {
                this.rate = Math.round(value);
                // 系统朗读不支持调速：滑杆只存值，松手后回调 Index 写偏好，不调任何 TTS API、不弹「尚未迁移」。
                this.onRateChange(this.rate);
              },
              onCommit: (): void => {} })

            // 底栏五格 ActionButton（上游 :177-206）。
            Row() {
              AloudActionButton({ icon: 'home', label: '主菜单', action: () => this.onOpenMainMenu() })
              AloudActionButton({ icon: 'catalog', label: '目录', action: () => this.onOpenCatalog() })
              AloudActionButton({ icon: 'hide', label: '后台', action: () => this.onGoToBackground() })
              AloudActionButton({ icon: 'reader_settings', label: '设置', action: () => this.onOpenConfig() })
              AloudActionButton({ icon: 'voice', label: '听书界面', action: () => this.onOpenPlayer() })
            }
            .width('100%').padding({ top: 14, bottom: 18 })
          }
          .width('100%')
        }.edgeEffect(EdgeEffect.None)
        .layoutWeight(1)
        .scrollBar(BarState.Off)
    }
  }
}

/** MediumTonalButton 近似：玻璃底 + onSurface 图标（上游 tonal 用 secondaryContainer）。 */
@Component
struct AloudTonalIcon {
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @Prop icon: string = 'reader_play';
  onAction: () => void = () => {};

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.icon === 'previous') {
        Image($r('app.media.app_previous')).width(20).height(20).fillColor(this.themeColorTextPrimary)
      } else if (this.icon === 'pause') {
        Image($r('app.media.reader_pause')).width(20).height(20).fillColor(this.themeColorTextPrimary)
      } else if (this.icon === 'stop') {
        Image($r('app.media.app_stop_square')).width(20).height(20).fillColor(this.themeColorTextPrimary)
      } else {
        Image($r('app.media.reader_play')).width(20).height(20).fillColor(this.themeColorTextPrimary)
      }
    }
    .layoutWeight(1).height(48)
    .backgroundColor(glassColor(this.themeColorSurfaceElevated, 0.75)).backdropBlur(resolveGlassBlurRadius(12)).borderRadius(24)
    .onClick(() => this.onAction())
    .accessibilityText(this.icon === 'previous' ? '上一句' : (this.icon === 'pause' ? '暂停' : (this.icon === 'stop' ? '停止' : '播放')))
  }
}

/** TinySwitchSettingItem 玻璃行（上游 flow_sys）。 */
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
      Text(this.label).fontSize(TITLE_SMALL_EMPHASIZED).fontWeight(FontWeight.Medium)
        .fontColor(this.themeColorTextPrimary).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.checked })
        .selectedColor(this.themeColorAccent)
        .onChange((value: boolean): void => this.onChange(value))
    }
    .width('100%').constraintSize({ minHeight: 56 })
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(glassColor(this.themeColorSurfaceSecondary, 0.55)).backdropBlur(resolveGlassBlurRadius(16)).borderRadius(12)
    .margin({ left: 12, right: 12, bottom: 6 })
    .onClick(() => this.onChange(!this.checked))
  }
}

/** TinyClickableSettingItem 玻璃行（定时入口，值 + chevron）。 */
@Component
struct ConfigGlassRow {
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#494C59';
  @Prop label: string = '';
  @Prop value: string = '';
  onNext: () => void = () => {};

  build() {
    Row() {
      Text(this.label).fontSize(TITLE_SMALL_EMPHASIZED).fontWeight(FontWeight.Medium)
        .fontColor(this.themeColorTextPrimary).layoutWeight(1)
      Text(this.value).fontSize(BODY_SMALL).fontColor(this.themeColorTextSecondary).margin({ right: 6 })
      Image($r('app.media.reader_next')).width(16).height(16).fillColor(this.themeColorTextSecondary)
    }
    .width('100%').constraintSize({ minHeight: 56 })
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(glassColor(this.themeColorSurfaceSecondary, 0.55)).backdropBlur(resolveGlassBlurRadius(16)).borderRadius(12)
    .margin({ left: 12, right: 12, bottom: 6 })
    .onClick(() => this.onNext())
  }
}

/** ActionButton：玻璃圆钮 + labelSmall（上游 :227-250）。 */
@Component
struct AloudActionButton {
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @Prop icon: string = 'reader_settings';
  @Prop label: string = '';
  action: () => void = () => {};

  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        if (this.icon === 'home') {
          Image($r('app.media.app_home')).width(22).height(22).fillColor(this.themeColorTextSecondary)
        } else if (this.icon === 'catalog') {
          Image($r('app.media.reader_toc')).width(22).height(22).fillColor(this.themeColorTextSecondary)
        } else if (this.icon === 'hide') {
          Image($r('app.media.reader_visibility_off')).width(22).height(22).fillColor(this.themeColorTextSecondary)
        } else if (this.icon === 'reader_settings') {
          Image($r('app.media.reader_settings')).width(22).height(22).fillColor(this.themeColorTextSecondary)
        } else {
          Image($r('app.media.reader_voice')).width(22).height(22).fillColor(this.themeColorTextSecondary)
        }
      }
      .width(48).height(48).borderRadius(24)
      .backgroundColor(glassColor(this.themeColorSurfaceElevated, 0.75)).backdropBlur(resolveGlassBlurRadius(12))
      Text(this.label).fontSize(LABEL_SMALL).fontColor(this.themeColorTextSecondary)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center).margin({ top: 6 })
    }
    .layoutWeight(1)
    .onClick(() => this.action())
  }
}
