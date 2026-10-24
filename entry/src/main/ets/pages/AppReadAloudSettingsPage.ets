@Component
export struct AppReadAloudSettingsPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};

  build() {
    Column() {
      Row() {
        Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
          .width(40).height(40).onClick(() => this.onBack())
        Column() {
          Text('朗读设置').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
          Text('声音、引擎与角色规则').fontSize(15).fontColor('#92949E').margin({ top: 3 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.padding({ left: 12, right: 16, top: 8, bottom: 10 })

      Scroll() {
        Column() {
          Column() {
            AppReadAloudLinkRow({ title: '角色声音池', detail: '管理角色声音池以及池内启用的音色', onSelect: () => this.onUnavailableAction('角色声音池页面尚未迁移') })
            Row().height(1).width('100%').backgroundColor('#111217')
            AppReadAloudLinkRow({ title: '背景音乐池', detail: '导入配乐文件，朗读时作为背景音乐播放', onSelect: () => this.onUnavailableAction('背景音乐池页面尚未迁移') })
            Row().height(1).width('100%').backgroundColor('#111217')
            AppReadAloudLinkRow({ title: '变声器', detail: '管理音高、语速、混响与金属感预设', onSelect: () => this.onUnavailableAction('变声器页面尚未迁移') })
            Row().height(1).width('100%').backgroundColor('#111217')
            AppReadAloudLinkRow({ title: '朗读胶囊设置', detail: '设置正文胶囊的圆角、背景与头像形状位置', onSelect: () => this.onUnavailableAction('朗读胶囊设置尚未迁移') })
            Row().height(1).width('100%').backgroundColor('#111217')
            AppReadAloudLinkRow({ title: '朗读引擎与音色', detail: '配置朗读引擎并导入音色', onSelect: () => this.onUnavailableAction('朗读引擎与音色页面尚未迁移') })
            Row().height(1).width('100%').backgroundColor('#111217')
            AppReadAloudLinkRow({ title: '多角色识别', detail: '配置角色标记与声音池分隔符', onSelect: () => this.onUnavailableAction('多角色识别页面尚未迁移') })
            Row().height(1).width('100%').backgroundColor('#111217')
            AppReadAloudLinkRow({ title: '正则角色管理', detail: '按正文匹配更换音色或播放音效', onSelect: () => this.onUnavailableAction('正则角色管理页面尚未迁移') })
          }.margin({ left: 16, right: 16, top: 12 }).backgroundColor('#1A1B21').borderRadius(16)
          Text('这些设置入口已按原版独立列出；各配置页面将逐项迁移。')
            .fontSize(15).fontColor('#858792').margin({ left: 18, right: 18, top: 10, bottom: 20 })
        }
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct AppReadAloudLinkRow {
  @Prop title: string = '';
  @Prop detail: string = '';
  onSelect: () => void = () => {};
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(18).fontColor('#D8D9E0')
        Text(this.detail).fontSize(15).fontColor('#92949E').margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.reader_next')).width(16).height(16).fillColor('#92949E')
    }.padding({ left: 16, right: 14, top: 15, bottom: 15 }).onClick(() => this.onSelect())
  }
}