@Component
export struct ReaderAloudSettingsPage {
  @State followSystem: boolean = true;
  @State rate: number = 40;
  @State musicVolume: number = 100;
  @State timerLabel: string = '关闭';
  onBack: () => void = () => {};
  onOpenMainMenu: () => void = () => {};
  onOpenCatalog: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};

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
          .backgroundColor('#C8C9D0')
          .borderRadius(4)
          .margin({ top: 10, bottom: 15 })

        Row() {
          Image($r('app.media.reader_back'))
            .width(22)
            .height(22)
            .fillColor('#E4E5EA')
            .onClick(() => this.onBack())
          Text('朗读设置')
            .fontSize(15)
            .fontColor('#E4E5EA')
            .margin({ left: 10 })
          Blank()
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 12 })

        Scroll() {
          Column() {
            Row() {
              AloudTransportButton({ icon: 'previous', actionLabel: '上一句',
                onAction: () => this.onUnavailableAction('朗读播放尚未迁移') })
              AloudTransportButton({ icon: 'pause', actionLabel: '暂停',
                onAction: () => this.onUnavailableAction('朗读播放尚未迁移') })
              AloudTransportButton({ icon: 'stop', actionLabel: '停止',
                onAction: () => this.onUnavailableAction('朗读播放尚未迁移') })
              Row() {
                Image($r('app.media.reader_next')).width(18).height(18).fillColor('#E6E7EC')
                Text('下一句').fontSize(12).fontColor('#E6E7EC').margin({ left: 5 })
              }
              .layoutWeight(1)
              .height(42)
              .justifyContent(FlexAlign.Center)
              .backgroundColor('#303139')
              .borderRadius(22)
              .onClick(() => this.onUnavailableAction('朗读播放尚未迁移'))
            }
            .width('100%')
            .padding(10)
            .backgroundColor('#202127')
            .borderRadius(16)
            .margin({ left: 14, right: 14, bottom: 12 })

            Row() {
              Column() {
                Text('定时').fontSize(13).fontColor('#E2E3E8')
                Text(this.timerLabel).fontSize(11).fontColor('#AEB0B9').margin({ top: 3 })
              }
              .layoutWeight(1)
              Image($r('app.media.reader_next')).width(18).height(18).fillColor('#AEB0B9')
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#202127')
            .borderRadius(14)
            .margin({ left: 14, right: 14, bottom: 10 })
            .onClick(() => this.onUnavailableAction('朗读定时功能尚未迁移'))

            Row() {
              Text('上一章')
                .fontSize(12)
                .fontColor('#E4E5EA')
                .layoutWeight(1)
                .height(38)
                .textAlign(TextAlign.Center)
                .backgroundColor('#303139')
                .borderRadius(20)
                .onClick(() => this.onUnavailableAction('朗读播放尚未迁移'))
              Text('下一章')
                .fontSize(12)
                .fontColor('#E4E5EA')
                .layoutWeight(1)
                .height(38)
                .textAlign(TextAlign.Center)
                .backgroundColor('#303139')
                .borderRadius(20)
                .margin({ left: 8 })
                .onClick(() => this.onUnavailableAction('朗读播放尚未迁移'))
            }
            .width('100%')
            .padding(10)
            .backgroundColor('#202127')
            .borderRadius(14)
            .margin({ left: 14, right: 14, bottom: 10 })

            Column() {
              Row() {
                Text('背景音乐总音量').fontSize(12).fontColor('#E2E3E8')
                Blank()
                Text(this.musicVolume.toString() + '%').fontSize(11).fontColor('#D5D6DD')
              }
              Slider({ value: this.musicVolume, min: 0, max: 100, step: 1, style: SliderStyle.OutSet })
                .onChange((value: number, mode: SliderChangeMode) => {
                  this.musicVolume = Math.round(value)
                  if (mode === SliderChangeMode.End) {
                    this.onUnavailableAction('背景音乐音量设置尚未迁移')
                  }
                })
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 12, bottom: 8 })
            .backgroundColor('#202127')
            .borderRadius(14)
            .margin({ left: 14, right: 14, bottom: 10 })

            Row() {
              Column() {
                Text('跟随系统').fontSize(12).fontColor('#E2E3E8')
                Text('语速由系统朗读服务控制').fontSize(10).fontColor('#AEB0B9').margin({ top: 3 })
              }
              .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.followSystem })
                .onChange((value: boolean) => {
                  this.followSystem = value
                  this.onUnavailableAction('朗读系统设置尚未迁移')
                })
            }
            .padding(13)
            .backgroundColor('#202127')
            .borderRadius(14)
            .margin({ left: 14, right: 14, bottom: 10 })

            Column() {
              Row() {
                Text('朗读语速').fontSize(12)
                  .fontColor(this.followSystem ? '#8D8F98' : '#E2E3E8')
                Blank()
                Text(this.rate.toString()).fontSize(11)
                  .fontColor(this.followSystem ? '#8D8F98' : '#D5D6DD')
              }
              Slider({ value: this.rate, min: 0, max: 80, step: 1, style: SliderStyle.OutSet })
                .enabled(!this.followSystem)
                .onChange((value: number, mode: SliderChangeMode) => {
                  this.rate = Math.round(value)
                  if (mode === SliderChangeMode.End) {
                    this.onUnavailableAction('朗读语速设置尚未迁移')
                  }
                })
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
                action: () => this.onUnavailableAction('后台朗读尚未迁移') })
              AloudBottomAction({ icon: 'reader_settings', label: '设置',
                action: () => this.onUnavailableAction('朗读设置尚未迁移') })
              AloudBottomAction({ icon: 'voice', label: '听书界面',
                action: () => this.onUnavailableAction('听书界面尚未迁移') })
            }
            .width('100%')
            .padding({ top: 12, bottom: 15 })
          }
          .width('100%')
          .padding({ bottom: 6 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('84%')
      .backgroundColor('#1A1B21')
      .borderRadius(22)
    }
    .width('100%')
    .height('100%')
  }
}

@Component
struct AloudTransportButton {
  @Prop icon: string = 'reader_play';
  @Prop actionLabel: string = '';
  onAction: () => void = () => {};

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.icon === 'previous') {
        Image($r('app.media.app_previous')).width(19).height(19).fillColor('#E6E7EC')
      } else if (this.icon === 'pause') {
        Image($r('app.media.reader_pause')).width(19).height(19).fillColor('#E6E7EC')
      } else if (this.icon === 'stop') {
        Image($r('app.media.app_stop_square')).width(19).height(19).fillColor('#E6E7EC')
      } else {
        Image($r('app.media.reader_play')).width(19).height(19).fillColor('#E6E7EC')
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
  @Prop icon: string = 'reader_settings';
  @Prop label: string = '';
  action: () => void = () => {};

  build() {
    Column() {
      if (this.icon === 'home') {
        Image($r('app.media.app_home')).width(21).height(21).fillColor('#D8D9E0')
      } else if (this.icon === 'catalog') {
        Image($r('app.media.reader_toc')).width(21).height(21).fillColor('#D8D9E0')
      } else if (this.icon === 'hide') {
        Image($r('app.media.reader_visibility_off')).width(21).height(21).fillColor('#D8D9E0')
      } else if (this.icon === 'reader_settings') {
        Image($r('app.media.reader_settings')).width(21).height(21).fillColor('#D8D9E0')
      } else {
        Image($r('app.media.reader_voice')).width(21).height(21).fillColor('#D8D9E0')
      }
      Text(this.label).fontSize(10).fontColor('#D8D9E0').margin({ top: 5 })
    }
    .layoutWeight(1)
    .padding({ top: 5, bottom: 5 })
    .onClick(() => this.action())
  }
}
