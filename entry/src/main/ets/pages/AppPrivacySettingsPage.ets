@Component
export struct AppPrivacySettingsPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State unlockScopeIndex: number = 0;

  build() {
    Column() {
      Row() {
        Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
          .width(40).height(40).onClick(() => this.onBack())
        Column() {
          Text('隐私设置').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
          Text('本地密码、验证时机与权限').fontSize(15).fontColor('#92949E').margin({ top: 3 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.padding({ left: 12, right: 16, top: 8, bottom: 10 })

      Scroll() {
        Column() {
          PrivacySettingsSection({ title: '私密凭据' }) {
            PrivacySettingsSwitch({ title: '启用私密功能', detail: '关闭后不验证、不脱敏；已有密码和标记会保留' })
            PrivacySettingsAction({ title: '设置本地密码', detail: '本地密码用于私密内容验证与敏感备份加密', onSelect: () => this.onUnavailableAction('真实本地密码设置尚未接入；本页不会收集密码') })
            PrivacySettingsSwitch({ title: '生物识别快捷解锁', detail: '需要设备支持且先设置本地密码' })
          }

          PrivacySettingsSection({ title: '验证时机' }) {
            PrivacySettingsSwitch({ title: '进入私密分组时验证' })
            PrivacySettingsSwitch({ title: '打开私密书籍时验证' })
            PrivacySettingsSwitch({ title: '应用启动时验证' })
            PrivacySettingsChoice({ title: '解锁有效期', options: ['每次都验证', '应用会话内有效', '离开应用前有效'], selected: this.unlockScopeIndex, onSelect: (index: number) => this.unlockScopeIndex = index })
            if (this.unlockScopeIndex === 2) {
              PrivacySettingsChoice({ title: '切到后台后的宽限期', options: ['立即失效', '30 秒', '2 分钟', '3 分钟', '5 分钟'], selected: 0, onSelect: (_index: number) => this.onUnavailableAction('宽限期暂为界面预览') })
            }
          }

          PrivacySettingsSection({ title: '权限与数据' }) {
            PrivacySettingsAction({ title: '通知权限', detail: '用于显示必要的应用通知', onSelect: () => this.onUnavailableAction('通知权限申请尚未接入') })
            PrivacySettingsAction({ title: '后台运行权限', detail: '查看电池优化状态', onSelect: () => this.onUnavailableAction('系统后台权限尚未接入') })
            PrivacySettingsSwitch({ title: 'Firebase 服务', detail: '此开关当前仅展示设置项，不会更改服务状态' })
          }
          Text('安全提醒：本页面只是原版隐私设置的 UI 预览。没有密码加密、生物识别或权限写入；请勿在此输入真实密码。')
            .fontSize(12).fontColor('#D9A6A0').margin({ left: 18, right: 18, top: 6, bottom: 22 })
        }.width('100%').padding({ top: 6 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct PrivacySettingsSection {
  @Prop title: string = '';
  @BuilderParam content: () => void = this.emptyContent;
  @Builder
  emptyContent() {
  }
  build() {
    Column() {
      Text(this.title).fontSize(18).fontWeight(FontWeight.Medium).fontColor('#AFC2FF')
        .alignSelf(ItemAlign.Start).padding({ left: 18, top: 14, bottom: 8 })
      Column() { this.content() }.margin({ left: 16, right: 16 }).backgroundColor('#1A1B21').borderRadius(16)
    }
  }
}

@Component
struct PrivacySettingsSwitch {
  @Prop title: string = '';
  @Prop detail: string = '';
  @State toggleValue: boolean = false;
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(18).fontColor('#D8D9E0')
        if (this.detail.length > 0) { Text(this.detail).fontSize(15).fontColor('#92949E').margin({ top: 3 }) }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.toggleValue })
        .onChange((value: boolean) => this.toggleValue = value)
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 })
  }
}

@Component
struct PrivacySettingsAction {
  @Prop title: string = '';
  @Prop detail: string = '';
  onSelect: () => void = () => {};
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(18).fontColor('#D8D9E0')
        if (this.detail.length > 0) { Text(this.detail).fontSize(15).fontColor('#92949E').margin({ top: 3 }) }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.reader_next')).width(15).height(15).fillColor('#92949E')
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 }).onClick(() => this.onSelect())
  }
}

@Component
struct PrivacySettingsChoice {
  @Prop title: string = '';
  @Prop options: string[] = [];
  @Prop selected: number = 0;
  onSelect: (index: number) => void = (_index: number) => {};
  private getSelectedLabel(): string {
    if (this.options.length === 0) { return ''; }
    return this.options[Math.min(this.selected, this.options.length - 1)];
  }
  build() {
    Row() {
      Text(this.title).fontSize(18).fontColor('#D8D9E0').layoutWeight(1)
      Text(this.getSelectedLabel()).fontSize(12).fontColor('#AFC2FF')
      Image($r('app.media.reader_next')).width(15).height(15).fillColor('#92949E').margin({ left: 6 })
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 }).onClick(() => {
      if (this.options.length > 0) {
        this.onSelect((this.selected + 1) % this.options.length);
      }
    })
  }
}