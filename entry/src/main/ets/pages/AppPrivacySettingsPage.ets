import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';
import { PrivateAccessRepository } from '../data/PrivateAccessRepository';

@Component
export struct AppPrivacySettingsPage {
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State unlockScopeIndex: number = 0;
  @State collapsedHeader: boolean = false;
  /** 私密总开关与是否已设密码：@StorageProp 直读 AppStorage，仓储 publish 后自动重建。 */
  @StorageProp('privateEnabled') privateEnabled: boolean = false;
  @StorageProp('privateHasPassword') privateHasPassword: boolean = false;
  /** 本地密码设置面板（批6）：两次输入一致才落库，密码不进备份。 */
  @State passwordPanelVisible: boolean = false;
  @State passwordInput: string = '';
  @State passwordConfirmInput: string = '';
  @State passwordMessage: string = '';
  private settingsScroller: Scroller = new Scroller();

  /** 启用/关闭私密总开关。关掉只是休眠：密码与标记都留着。 */
  private async applyPrivateEnabled(enabled: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      await PrivateAccessRepository.setEnabled(context, enabled);
    } catch (error) {
      this.onUnavailableAction(error instanceof Error ? error.message : '私密开关保存失败');
    }
  }

  /** 打开密码面板；已设过密码时是「修改」，两个输入框都从空开始。 */
  private openPasswordPanel(): void {
    this.passwordInput = '';
    this.passwordConfirmInput = '';
    this.passwordMessage = '';
    this.passwordPanelVisible = true;
  }

  /** 保存本地密码：空、两次不一致都拦住；成功后就打开私密功能。 */
  private async savePassword(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const password = this.passwordInput.trim();
    if (password.length === 0) {
      this.passwordMessage = '密码不能为空';
      return;
    }
    if (password !== this.passwordConfirmInput.trim()) {
      this.passwordMessage = '两次输入的密码不一致';
      return;
    }
    try {
      await PrivateAccessRepository.setPassword(context, password);
      await PrivateAccessRepository.setEnabled(context, true);
      this.passwordPanelVisible = false;
      this.passwordInput = '';
      this.passwordConfirmInput = '';
      this.passwordMessage = '';
      this.onUnavailableAction('本地密码已保存');
    } catch (error) {
      this.passwordMessage = error instanceof Error ? error.message : '密码保存失败';
    }
  }

  private updateHeader(): void {
    const offset = this.settingsScroller.currentOffset().yOffset;
    const shouldCollapse = offset > 70 ? true : offset < 24 ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      animateTo({ duration: 220, curve: Curve.EaseInOut }, () => this.collapsedHeader = shouldCollapse);
    }
  }

  build() {
    Stack() {
      Column() {
      CollapsingSettingsHeader({ title: '隐私设置', collapsed: this.collapsedHeader, onBack: () => this.onBack() })

      Scroll(this.settingsScroller) {
        Column() {
          PrivacySettingsSection({ title: '私密凭据' }) {
            PrivacySettingsSwitch({
              title: '启用私密功能',
              detail: '关闭后不验证、不脱敏；已有密码和标记会保留',
              controlled: true,
              checkedValue: this.privateEnabled,
              onToggle: (value: boolean) => { void this.applyPrivateEnabled(value); }
            })
            PrivacySettingsAction({
              title: this.privateHasPassword ? '修改本地密码' : '设置本地密码',
              detail: '本地密码用于私密内容验证；只存 PBKDF2 校验值，不保存明文',
              onSelect: () => this.openPasswordPanel()
            })
            PrivacySettingsSwitch({ title: '生物识别快捷解锁', detail: '需要设备支持且先设置本地密码' })
          }

          PrivacySettingsSection({ title: '验证时机' }) {
            PrivacySettingsSwitch({ title: '进入私密分组时验证' })
            PrivacySettingsSwitch({ title: '打开私密书籍时验证' })
            PrivacySettingsSwitch({ title: '应用启动时验证' })
            PrivacySettingsChoice({ title: '解锁有效期', options: ['每次都验证', '应用会话内有效', '离开应用前有效'], selected: this.unlockScopeIndex, onSelect: (index: number) => this.unlockScopeIndex = index })
            if (this.unlockScopeIndex === 2) {
              PrivacySettingsChoice({ title: '切到后台后的宽限期', options: ['立即失效', '30 秒', '2 分钟', '3 分钟', '5 分钟'], selected: 0, onSelect: (_index: number) => this.onUnavailableAction('宽限期暂为界面预览') })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseInOut }))
            }
          }

          PrivacySettingsSection({ title: '权限与数据' }) {
            PrivacySettingsAction({ title: '通知权限', detail: '用于显示必要的应用通知', onSelect: () => this.onUnavailableAction('通知权限申请尚未接入') })
            PrivacySettingsAction({ title: '后台运行权限', detail: '查看电池优化状态', onSelect: () => this.onUnavailableAction('系统后台权限尚未接入') })
            PrivacySettingsSwitch({ title: 'Firebase 服务', detail: '此开关当前仅展示设置项，不会更改服务状态' })
          }
          Text('说明：本地密码以 PBKDF2 校验值存储，不保存明文，也不进备份。生物识别与验证时机细项仍是界面预览。')
            .fontSize(12).fontColor('#D9A6A0').margin({ left: 18, right: 18, top: 6, bottom: 22 })
        }.width('100%').padding({ top: 6 })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
      }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      if (this.passwordPanelVisible) {
        this.PasswordPanel()
      }
    }.width('100%').height('100%')
  }

  /** 本地密码设置面板（批6）：两输入 + 保存，盖在整页之上。 */
  @Builder
  private PasswordPanel() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#99000000')
        .onClick(() => this.passwordPanelVisible = false)
      Column() {
        Text(this.privateHasPassword ? '修改本地密码' : '设置本地密码')
          .fontSize(16).fontColor('#F1F2F6').alignSelf(ItemAlign.Start)
        TextInput({ text: this.passwordInput, placeholder: '本地密码' })
          .type(InputType.Password).fontSize(14).height(44).margin({ top: 14 })
          .onChange((value: string) => { this.passwordInput = value; })
        TextInput({ text: this.passwordConfirmInput, placeholder: '再输一次' })
          .type(InputType.Password).fontSize(14).height(44).margin({ top: 10 })
          .onChange((value: string) => { this.passwordConfirmInput = value; })
        if (this.passwordMessage.length > 0) {
          Text(this.passwordMessage).fontSize(12).fontColor('#FF6B6B')
            .alignSelf(ItemAlign.Start).margin({ top: 8 })
        }
        Row() {
          Text('取消').fontSize(14).fontColor('#B6B8C2').padding(10)
            .onClick(() => this.passwordPanelVisible = false)
          Blank()
          Text('保存').fontSize(14).fontColor(this.themeColorAccent).padding(10)
            .onClick(async () => { await this.savePassword(); })
        }.width('100%').margin({ top: 12 })
      }.width('90%').padding(18).backgroundColor('#1D1E26').borderRadius(18)
    }.width('100%').height('100%')
  }
}

@Component
struct PrivacySettingsSection {
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @Prop title: string = '';
  @BuilderParam content: () => void = this.emptyContent;
  @Builder
  emptyContent() {
  }
  @StorageProp('themeCardRadius') themeCardRadius: number = 16;
  @StorageProp('themeCardBorderWidth') themeCardBorderWidth: number = 0;
  @StorageProp('themeCardBorderColor') themeCardBorderColor: string = '#6A6D77';
  @StorageProp('themeCardBackground') themeCardBackground: string = '';
  @StorageProp('themeContainerBackground') themeContainerBackground: string = '';
  build() {
    Column() {
      Text(this.title).fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.themeColorAccent)
        .alignSelf(ItemAlign.Start).padding({ left: 18, top: 14, bottom: 8 })
      Column() { this.content() }.margin({ left: 16, right: 16 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
    }
  }
}

@Component
struct PrivacySettingsSwitch {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @Prop title: string = '';
  @Prop detail: string = '';
  /** 受控模式：由外部给值并收回调；不开时保留原来的本地预览行为。 */
  @Prop controlled: boolean = false;
  @Prop checkedValue: boolean = false;
  onToggle: (value: boolean) => void = (_value: boolean) => {};
  @State toggleValue: boolean = false;
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(18).fontColor(this.themeColorTextSecondary)
        if (this.detail.length > 0) { Text(this.detail).fontSize(15).fontColor(this.themeColorTextTertiary).margin({ top: 3 }) }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.controlled ? this.checkedValue : this.toggleValue })
        .onChange((value: boolean) => {
          this.toggleValue = value;
          if (this.controlled) { this.onToggle(value); }
        })
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 })
  }
}

@Component
struct PrivacySettingsAction {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @Prop title: string = '';
  @Prop detail: string = '';
  onSelect: () => void = () => {};
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(18).fontColor(this.themeColorTextSecondary)
        if (this.detail.length > 0) { Text(this.detail).fontSize(15).fontColor(this.themeColorTextTertiary).margin({ top: 3 }) }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.reader_next')).width(15).height(15).fillColor(this.themeColorTextTertiary)
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 }).onClick(() => this.onSelect())
  }
}

@Component
struct PrivacySettingsChoice {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
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
      Text(this.title).fontSize(18).fontColor(this.themeColorTextSecondary).layoutWeight(1)
      Text(this.getSelectedLabel()).fontSize(12).fontColor(this.themeColorAccent)
      Image($r('app.media.reader_next')).width(15).height(15).fillColor(this.themeColorTextTertiary).margin({ left: 6 })
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 }).onClick(() => {
      if (this.options.length > 0) {
        this.onSelect((this.selected + 1) % this.options.length);
      }
    })
  }
}
