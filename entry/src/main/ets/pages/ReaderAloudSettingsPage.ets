
@Component
export struct ReaderAloudSettingsPage {
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#494C59';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';

  // 批5：播放状态来自 SystemTtsPlayer（经 Index 的回调同步）。0 空闲 / 1 播放中 / 2 暂停。
  @Prop aloudState: number = 0;
  @Prop unitIndex: number = 0;
  @Prop unitTotal: number = 0;
  /** 语速/定时初值由 Index 从 ReadAloudSettingsRepository 读出后传入。 */
  @Prop initialRate: number = 5;
  @Prop initialTimerLabel: string = '关闭';

  @State rate: number = 5;
  @State musicVolume: number = 100;
  @State timerLabel: string = '关闭';
  @State showTimerPicker: boolean = false;
  @State pickerMode: string = 'minute';
  @State timerMinutes: number = 1;
  @State timerChapters: number = 1;

  // 上游 bgmAssign 默认关闭，且 BGM 整块归朗读域后做（用户已定）。本批恒 false，该行隐藏。
  private bgmEnabled: boolean = false;

  onBack: () => void = () => {};
  onOpenMainMenu: () => void = () => {};
  onOpenCatalog: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};

  // 批5：面板自身不持有播放器，所有操作回调给 Index，避免 Index 的 readAloudActive 与播放器状态分裂。
  onPrevious: () => void = () => {};
  onPauseToggle: () => void = () => {};
  onStop: () => void = () => {};
  onNext: () => void = () => {};
  onTurnChapter: (delta: number) => void = (_delta: number) => {};
  onRateChange: (rate: number) => void = (_rate: number) => {};
  onTimerChange: (mode: string, minutes: number, chapters: number) => void =
    (_mode: string, _minutes: number, _chapters: number) => {};
  onOpenConfig: () => void = () => {};

  aboutToAppear(): void {
    this.rate = this.initialRate;
    this.timerLabel = this.initialTimerLabel;
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#88000000')
        .onClick(() => this.onBack())

      Column() {
        Row()
          .width(32)
          .height(4)
          .backgroundColor(this.themeColorTextTertiary)
          .borderRadius(4)
          .margin({ top: 10, bottom: 15 })

        Row() {
          Image($r('app.media.reader_back'))
            .width(22)
            .height(22)
            .fillColor(this.themeColorTextPrimary)
            .onClick(() => this.onBack())
          Text('朗读')
            .fontSize(15)
            .fontColor(this.themeColorTextPrimary)
            .margin({ left: 10 })
          Blank()
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 12 })

        Scroll() {
          Column() {
            // 上游顺序：上一句 / 暂停 / 停止 / 下一句（ReadAloudScreen.kt:77-104）。
            // 暂停格按状态切图标：播放中显示暂停，暂停/空闲显示播放（任务书 5.2）。
            Row() {
              AloudTransportButton({ icon: 'previous', actionLabel: '上一句',
                onAction: () => this.onPrevious() })
              AloudTransportButton({ icon: this.aloudState === 1 ? 'pause' : 'play',
                actionLabel: this.aloudState === 1 ? '暂停' : '播放',
                onAction: () => this.onPauseToggle() })
              AloudTransportButton({ icon: 'stop', actionLabel: '停止',
                onAction: () => this.onStop() })
              Row() {
                Image($r('app.media.reader_next')).width(18).height(18).fillColor(this.themeColorTextPrimary)
                Text('下一句').fontSize(12).fontColor(this.themeColorTextPrimary).margin({ left: 5 })
              }
              .layoutWeight(1)
              .height(42)
              .justifyContent(FlexAlign.Center)
              .backgroundColor('#303139')
              .borderRadius(22)
              .onClick(() => this.onNext())
            }
            .width('100%')
            .padding(10)
            .backgroundColor('#202127')
            .borderRadius(16)
            .margin({ left: 14, right: 14, bottom: 8 })

            Text(this.unitTotal > 0 ? `第 ${this.unitIndex + 1} / ${this.unitTotal} 句` : '未开始朗读')
              .fontSize(11).fontColor(this.themeColorTextTertiary)
              .width('100%').textAlign(TextAlign.Center)
              .margin({ bottom: 12 })

            Row() {
              Column() {
                Text('定时').fontSize(13).fontColor(this.themeColorTextPrimary)
                Text(this.timerLabel).fontSize(11).fontColor(this.themeColorTextSecondary).margin({ top: 3 })
              }
              .layoutWeight(1)
              Image($r('app.media.reader_next')).width(18).height(18).fillColor(this.themeColorTextSecondary)
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#202127')
            .borderRadius(14)
            .margin({ left: 14, right: 14, bottom: 10 })
            .onClick(() => { this.showTimerPicker = !this.showTimerPicker; })

            if (this.showTimerPicker) {
              Column() {
                Row() {
                  Text('关闭').fontSize(13).fontColor(this.themeColorTextPrimary).layoutWeight(1)
                  if (this.timerLabel === '关闭') { Text('✓').fontSize(13).fontColor(this.themeColorTextPrimary) }
                }.width('100%').padding(10)
                .onClick(() => {
                  this.timerLabel = '关闭';
                  this.onTimerChange('minute', 0, 0);
                  this.showTimerPicker = false;
                })
                Row() {
                  Text('按时长').fontSize(13).fontColor(this.themeColorTextPrimary)
                  Blank()
                  Text(`${this.timerMinutes} 分钟`).fontSize(11).fontColor(this.themeColorTextSecondary)
                }.width('100%').padding(10)
                .onClick(() => { this.pickerMode = 'minute'; })
                if (this.pickerMode === 'minute') {
                  Slider({ value: this.timerMinutes, min: 1, max: 60, step: 1, style: SliderStyle.OutSet })
                    .width('100%')
                    .onChange((value: number, _mode: SliderChangeMode) => { this.timerMinutes = Math.round(value); })
                }
                Row() {
                  Text('按章节').fontSize(13).fontColor(this.themeColorTextPrimary)
                  Blank()
                  Text(`${this.timerChapters} 章`).fontSize(11).fontColor(this.themeColorTextSecondary)
                }.width('100%').padding(10)
                .onClick(() => { this.pickerMode = 'chapter'; })
                if (this.pickerMode === 'chapter') {
                  Slider({ value: this.timerChapters, min: 1, max: 20, step: 1, style: SliderStyle.OutSet })
                    .width('100%')
                    .onChange((value: number, _mode: SliderChangeMode) => { this.timerChapters = Math.round(value); })
                }
                Text('确定')
                  .fontSize(13).fontColor(this.themeColorTextPrimary)
                  .width('100%').textAlign(TextAlign.Center).padding(10)
                  .borderRadius(10).backgroundColor('#303139')
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
              .width('100%')
              .padding(10)
              .backgroundColor('#2A2B32')
              .borderRadius(14)
              .margin({ left: 14, right: 14, bottom: 10 })
            }

            Row() {
              Text('上一章')
                .fontSize(12)
                .fontColor(this.themeColorTextPrimary)
                .layoutWeight(1)
                .height(38)
                .textAlign(TextAlign.Center)
                .backgroundColor('#303139')
                .borderRadius(20)
                .onClick(() => this.onTurnChapter(-1))
              Text('下一章')
                .fontSize(12)
                .fontColor(this.themeColorTextPrimary)
                .layoutWeight(1)
                .height(38)
                .textAlign(TextAlign.Center)
                .backgroundColor('#303139')
                .borderRadius(20)
                .margin({ left: 8 })
                .onClick(() => this.onTurnChapter(1))
            }
            .width('100%')
            .padding(10)
            .backgroundColor('#202127')
            .borderRadius(14)
            .margin({ left: 14, right: 14, bottom: 10 })

            // 背景音乐音量：上游 bgmAssign 默认关、BGM 归朗读域后做，本批隐藏该行（不是弹提示）。
            if (this.bgmEnabled) {
              Column() {
                Row() {
                  Text('背景音乐总音量').fontSize(12).fontColor(this.themeColorTextPrimary)
                  Blank()
                  Text(this.musicVolume.toString() + '%').fontSize(11).fontColor(this.themeColorTextSecondary)
                }
                Slider({ value: this.musicVolume, min: 0, max: 100, step: 1, style: SliderStyle.OutSet })
                  .onChange((value: number, _mode: SliderChangeMode) => { this.musicVolume = Math.round(value); })
              }
              .width('100%')
              .padding({ left: 14, right: 14, top: 12, bottom: 8 })
              .backgroundColor('#202127')
              .borderRadius(14)
              .margin({ left: 14, right: 14, bottom: 10 })
            }

            Column() {
              Row() {
                Text('调整语速').fontSize(12)
                  .fontColor(this.themeColorTextPrimary)
                Blank()
                Text(this.rate.toString()).fontSize(11)
                  .fontColor(this.themeColorTextSecondary)
              }
              Slider({ value: this.rate, min: 0, max: 80, step: 1, style: SliderStyle.OutSet })
                .onChange((value: number, mode: SliderChangeMode) => {
                  this.rate = Math.round(value);
                  // 系统朗读不支持调速：滑杆只存值，松手后回调 Index 写偏好，不调任何 TTS API、不弹「尚未迁移」。
                  if (mode === SliderChangeMode.End) {
                    this.onRateChange(this.rate);
                  }
                })
              Text('系统朗读不支持调速，此设置用于 HTTP 朗读源')
                .fontSize(10).fontColor(this.themeColorTextTertiary)
                .margin({ top: 2 })
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 12, bottom: 8 })
            .backgroundColor('#202127')
            .borderRadius(14)
            .margin({ left: 14, right: 14, bottom: 10 })

            Row() {
              AloudBottomAction({ icon: 'home', label: '主菜单', action: () => this.onOpenMainMenu() })
              AloudBottomAction({ icon: 'catalog', label: '目录', action: () => this.onOpenCatalog() })
              AloudBottomAction({ icon: 'hide', label: '后台',
                action: () => this.onUnavailableAction('后台朗读将在后续版本提供') })
              AloudBottomAction({ icon: 'reader_settings', label: '设置',
                action: () => this.onOpenConfig() })
              AloudBottomAction({ icon: 'voice', label: '听书界面',
                action: () => this.onUnavailableAction('听书界面尚未迁移') })
            }
            .width('100%')
            .padding({ top: 12, bottom: 15 })
          }
          .width('100%')
          .padding({ bottom: 6 })
        }.edgeEffect(EdgeEffect.None)
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('84%')
      .backgroundColor(this.themeColorSurfaceSecondary)
      .borderRadius(22)
    }
    .width('100%')
    .height('100%')
  }
}

@Component
struct AloudTransportButton {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @Prop icon: string = 'reader_play';
  @Prop actionLabel: string = '';
  onAction: () => void = () => {};

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.icon === 'previous') {
        Image($r('app.media.app_previous')).width(19).height(19).fillColor(this.themeColorTextPrimary)
      } else if (this.icon === 'pause') {
        Image($r('app.media.reader_pause')).width(19).height(19).fillColor(this.themeColorTextPrimary)
      } else if (this.icon === 'stop') {
        Image($r('app.media.app_stop_square')).width(19).height(19).fillColor(this.themeColorTextPrimary)
      } else {
        Image($r('app.media.reader_play')).width(19).height(19).fillColor(this.themeColorTextPrimary)
      }
    }
    .layoutWeight(1)
    .height(42)
    .backgroundColor('#303139')
    .borderRadius(22)
    .onClick(() => this.onAction())
  }
}

@Component
struct AloudBottomAction {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @Prop icon: string = 'reader_settings';
  @Prop label: string = '';
  action: () => void = () => {};

  build() {
    Column() {
      if (this.icon === 'home') {
        Image($r('app.media.app_home')).width(21).height(21).fillColor(this.themeColorTextSecondary)
      } else if (this.icon === 'catalog') {
        Image($r('app.media.reader_toc')).width(21).height(21).fillColor(this.themeColorTextSecondary)
      } else if (this.icon === 'hide') {
        Image($r('app.media.reader_visibility_off')).width(21).height(21).fillColor(this.themeColorTextSecondary)
      } else if (this.icon === 'reader_settings') {
        Image($r('app.media.reader_settings')).width(21).height(21).fillColor(this.themeColorTextSecondary)
      } else {
        Image($r('app.media.reader_voice')).width(21).height(21).fillColor(this.themeColorTextSecondary)
      }
      Text(this.label).fontSize(10).fontColor(this.themeColorTextSecondary).margin({ top: 5 })
    }
    .layoutWeight(1)
    .padding({ top: 5, bottom: 5 })
    .onClick(() => this.action())
  }
}
