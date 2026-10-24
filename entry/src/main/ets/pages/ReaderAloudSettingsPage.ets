@Component
export struct ReaderAloudSettingsPage {
  @State followSystem: boolean = true;
  @State rate: number = 40;
  @State musicVolume: number = 100;
  @State timerLabel: string = '关闭';
  onBack: () => void = () => {};
  onOpenCatalog: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column().width('100%').height('100%').backgroundColor('#88000000').onClick(() => this.onBack())
      Column() {
        Row().width(32).height(4).backgroundColor('#C8C9D0').borderRadius(4).margin({ top: 10, bottom: 15 })
        Row() {
          Image($r('app.media.reader_back')).width(22).height(22).fillColor('#E4E5EA').onClick(() => this.onBack())
          Text('朗读设置').fontSize(15).fontColor('#E4E5EA').margin({ left: 10 })
          Blank()
          Image($r('app.media.reader_more')).width(20).height(20).fillColor('#C8C9D0')
        }.width('100%').padding({ left: 16, right: 16, bottom: 12 })

        Row() {
          Stack({ alignContent: Alignment.Center }) {
            Image($r('app.media.app_previous')).width(18).height(18).fillColor('#E6E7EC')
          }.layoutWeight(1).height(38).onClick((): void => { this.onUnavailableAction('朗读播放尚未迁移'); })
          Stack({ alignContent: Alignment.Center }) {
            Image($r('app.media.reader_pause')).width(20).height(20).fillColor('#E6E7EC')
          }.layoutWeight(1).height(38).onClick((): void => { this.onUnavailableAction('朗读播放尚未迁移'); })
          Stack({ alignContent: Alignment.Center }) {
            Image($r('app.media.app_stop_square')).width(18).height(18).fillColor('#E6E7EC')
          }.layoutWeight(1).height(38).onClick((): void => { this.onUnavailableAction('朗读播放尚未迁移'); })
          Row() {
            Image($r('app.media.reader_next')).width(16).height(16).fillColor('#E6E7EC')
            Text('下一句').fontSize(12).fontColor('#E6E7EC').margin({ left: 4 })
          }.layoutWeight(1).height(38).justifyContent(FlexAlign.Center).onClick((): void => { this.onUnavailableAction('朗读播放尚未迁移'); })
        }.padding({ top: 10, bottom: 10 }).backgroundColor('#202127').borderRadius(14).margin({ left: 14, right: 14, bottom: 12 })

        Row() {
          Text('定时\n' + this.timerLabel).fontSize(12).lineHeight(20).fontColor('#D8D9E0').layoutWeight(1)
          Image($r('app.media.reader_next')).width(18).height(18).fillColor('#AEB0B9')
        }.padding(14).backgroundColor('#202127').borderRadius(13).margin({ left: 14, right: 14, bottom: 10 })
          .onClick((): void => { this.onUnavailableAction('朗读定时功能尚未迁移'); })

        Row() {
          Text('上一章').fontSize(12).fontColor('#D8D9E0').layoutWeight(1).textAlign(TextAlign.Center).onClick((): void => { this.onUnavailableAction('朗读播放尚未迁移'); })
          Text('下一章').fontSize(12).fontColor('#D8D9E0').layoutWeight(1).textAlign(TextAlign.Center).onClick((): void => { this.onUnavailableAction('朗读播放尚未迁移'); })
        }.padding(11).backgroundColor('#202127').borderRadius(13).margin({ left: 14, right: 14, bottom: 10 })

        Row() {
          Text('背景音乐总音量').fontSize(12).fontColor('#D8D9E0').layoutWeight(1)
          Image($r('app.media.app_reduce')).width(16).height(16).fillColor('#E5E6EB').width(34).height(34)
            .backgroundColor('#292A31').borderRadius(18).onClick((): void => { this.onUnavailableAction('背景音乐音量设置尚未迁移'); })
          Text(`${this.musicVolume}%`).fontSize(10).fontColor('#E5E6EB').padding({ left: 10, right: 10 })
          Image($r('app.media.app_add')).width(18).height(18).fillColor('#E5E6EB').width(34).height(34)
            .backgroundColor('#292A31').borderRadius(18).onClick((): void => { this.onUnavailableAction('背景音乐音量设置尚未迁移'); })
        }.padding(12).backgroundColor('#202127').borderRadius(13).margin({ left: 14, right: 14, bottom: 10 })

        Row() {
          Text('跟随系统').fontSize(12).fontColor('#D8D9E0').layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.followSystem }).onChange((_value: boolean): void => { this.onUnavailableAction('朗读系统设置尚未迁移'); })
        }.padding(13).backgroundColor('#202127').borderRadius(13).margin({ left: 14, right: 14, bottom: 10 })

        Row() {
          Text('朗读语速').fontSize(12).fontColor('#D8D9E0').layoutWeight(1)
          Image($r('app.media.app_reduce')).width(16).height(16).fillColor('#E5E6EB').width(34).height(34)
            .backgroundColor('#292A31').borderRadius(18).onClick((): void => { this.onUnavailableAction('朗读语速设置尚未迁移'); })
          Text(`${this.rate}`).fontSize(11).fontColor('#E5E6EB').padding({ left: 10, right: 10 })
          Image($r('app.media.app_add')).width(18).height(18).fillColor('#E5E6EB').width(34).height(34)
            .backgroundColor('#292A31').borderRadius(18).onClick((): void => { this.onUnavailableAction('朗读语速设置尚未迁移'); })
        }.padding(12).backgroundColor('#202127').borderRadius(13).margin({ left: 14, right: 14, bottom: 10 })

        Row() {
          Text('主菜单').fontSize(10).fontColor('#D8D9E0').layoutWeight(1).textAlign(TextAlign.Center).onClick(() => this.onBack())
          Text('目录').fontSize(10).fontColor('#D8D9E0').layoutWeight(1).textAlign(TextAlign.Center).onClick(() => this.onOpenCatalog())
          Text('后台').fontSize(10).fontColor('#D8D9E0').layoutWeight(1).textAlign(TextAlign.Center).onClick((): void => { this.onUnavailableAction('后台朗读尚未迁移'); })
          Text('设置').fontSize(10).fontColor('#D8D9E0').layoutWeight(1).textAlign(TextAlign.Center).onClick((): void => { this.onUnavailableAction('朗读设置尚未迁移'); })
          Text('听书界面').fontSize(10).fontColor('#D8D9E0').layoutWeight(1).textAlign(TextAlign.Center).onClick((): void => { this.onUnavailableAction('听书界面尚未迁移'); })
        }.width('100%').padding({ top: 12, bottom: 15 })
      }
      .width('100%')
      .height('92%')
      .backgroundColor('#1A1B21')
      .borderRadius(22)
    }.width('100%').height('100%')
  }
}
