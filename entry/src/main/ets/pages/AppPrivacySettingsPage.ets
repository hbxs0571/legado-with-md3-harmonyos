import curves from '@ohos.curves';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { UiSection } from '../components/settings/UiSection';
import { UiSwitch } from '../components/settings/UiSwitch';
import { UiAction } from '../components/settings/UiAction';
import { UiChoice } from '../components/settings/UiChoice';
import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';
import { PrivateAccessRepository, PrivateBiometricStatus } from '../data/PrivateAccessRepository';
import { BODY_SMALL, LABEL_LARGE, TITLE_MEDIUM, TITLE_SMALL } from '../components/typography/TypographyTokens';

/** 离开后重新验证五档的秒数，对齐上游 private_background_grace_* 格式串取值。 */
const GRACE_OPTION_SECONDS: number[] = [0, 30, 120, 180, 300];
/** 五档显示文案：立即 / %1$d 秒后 / %1$d 分钟后（上游原文逐字）。 */
const GRACE_OPTION_LABELS: string[] = ['立即', '30 秒后', '2 分钟后', '3 分钟后', '5 分钟后'];

@Component
export struct AppPrivacySettingsPage {
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State collapsedHeader: boolean = false;
  /** 私密总开关与是否已设密码：@StorageProp 直读 AppStorage，仓储 publish 后自动重建。 */
  @StorageProp('privateEnabled') privateEnabled: boolean = false;
  @StorageProp('privateHasPassword') privateHasPassword: boolean = false;
  /** 四个验证时机字段：@StorageProp 订阅，仓储 publish 后自动重建。 */
  @StorageProp('privateVerifyOnEnterGroup') verifyOnEnterGroup: boolean = true;
  @StorageProp('privateVerifyOnOpenBook') verifyOnOpenBook: boolean = true;
  @StorageProp('privateVerifyOnAppStart') verifyOnAppStart: boolean = false;
  @StorageProp('privateBackgroundGraceSeconds') backgroundGraceSeconds: number = 0;
  @StorageProp('privateBiometricEnabled') biometricEnabled: boolean = false;
  /** 验证频率的选中档位，初始化时从 AppStorage 对齐（AppStorage 尚未建时取默认 1）。 */
  @State unlockScopeIndex: number = 1;
  /** 生物识别能力状态：进页面时现查，模拟器上应为 NO_HARDWARE。 */
  @State biometricStatus: number = 0;
  /** 本地密码设置面板：有密码时「当前密码 + 新密码」两框，无密码时只一个新密码框。 */
  @State passwordPanelVisible: boolean = false;
  @State currentPasswordInput: string = '';
  @State passwordInput: string = '';
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

  /** 进入页面时对齐验证频率档位，并现查生物识别能力（模拟器应为无硬件）。 */
  aboutToAppear(): void {
    const scope = AppStorage.get<number>('privateUnlockScope');
    this.unlockScopeIndex = scope === undefined ? 1 : scope;
    this.biometricStatus = PrivateAccessRepository.detectBiometricStatus();
  }

  /** 写一个验证时机字段并落盘（三个开关共用）。 */
  private async applyVerifyOption(key: 'verifyOnEnterGroup' | 'verifyOnOpenBook' | 'verifyOnAppStart', value: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      await PrivateAccessRepository.setVerifyOption(context, key, value);
    } catch (error) {
      this.onUnavailableAction(error instanceof Error ? error.message : '验证设置保存失败');
    }
  }

  /** 改验证频率（解锁有效期）。 */
  private async applyUnlockScope(index: number): Promise<void> {
    this.unlockScopeIndex = index;
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      await PrivateAccessRepository.setUnlockScope(context, index);
    } catch (error) {
      this.onUnavailableAction(error instanceof Error ? error.message : '验证频率保存失败');
    }
  }

  /** 把落库的秒数映射成五档中的索引，未命中任何档位时回到「立即」。 */
  private graceIndex(): number {
    const index = GRACE_OPTION_SECONDS.indexOf(this.backgroundGraceSeconds);
    return index < 0 ? 0 : index;
  }

  /** 改离开后重新验证的宽限期（秒）。 */
  private async applyBackgroundGrace(index: number): Promise<void> {
    const seconds = GRACE_OPTION_SECONDS[index];
    if (seconds === undefined) { return; }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      await PrivateAccessRepository.setVerifyOption(context, 'backgroundGraceSeconds', seconds);
    } catch (error) {
      this.onUnavailableAction(error instanceof Error ? error.message : '宽限期保存失败');
    }
  }

  /** 生物识别能力对应的说明文案（上游 strings 逐字）。 */
  private biometricDetail(): string {
    switch (this.biometricStatus) {
      case PrivateBiometricStatus.NOT_SET_PASSWORD:
        return '请先设置本地密码，才能使用私密分组与私密书籍。';
      case PrivateBiometricStatus.NOT_ENROLLED:
        return '设备尚未录入指纹或人脸。';
      case PrivateBiometricStatus.NO_HARDWARE:
        return '设备没有生物识别硬件。';
      case PrivateBiometricStatus.UNAVAILABLE:
        return '生物识别暂时不可用。';
      case PrivateBiometricStatus.AVAILABLE:
        return '用设备生物识别代替手输密码完成验证。';
      default:
        return '生物识别暂时不可用。';
    }
  }

  /** 生物识别是否可用作开关：必须已设密码且能力可用。 */
  private biometricUsable(): boolean {
    return this.privateHasPassword && this.biometricStatus === PrivateBiometricStatus.AVAILABLE;
  }

  /** 生物识别开关：开时先做一次在场证明，通过后才把开关落库。 */
  private async applyBiometric(enabled: boolean): Promise<void> {
    if (!enabled || !this.biometricUsable()) { return; }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    PrivateAccessRepository.authenticateBiometric(async () => {
      try {
        await PrivateAccessRepository.setBiometricEnabled(context, true);
      } catch (error) {
        this.onUnavailableAction(error instanceof Error ? error.message : '生物识别开关保存失败');
      }
    }, (message: string) => {
      this.onUnavailableAction(message);
    });
  }

  /** 请求通知授权：必须由用户点按触发，这里正是 onClick。用无参重载，SDK 会取当前 UIAbility 上下文。 */
  private async requestNotification(): Promise<void> {
    try {
      await notificationManager.requestEnableNotification();
    } catch (error) {
      this.onUnavailableAction(error instanceof Error ? error.message : '通知权限申请失败');
    }
  }

  /** 打开密码面板：有密码时是「修改」，各输入框从空开始。 */
  private openPasswordPanel(): void {
    this.currentPasswordInput = '';
    this.passwordInput = '';
    this.passwordMessage = '';
    this.passwordPanelVisible = true;
  }

  /** 保存本地密码：已设过密码时先验旧密码，再写新密码；无「再输一次」框（对齐上游两框）。 */
  private async savePassword(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const password = this.passwordInput.trim();
    if (password.length === 0) {
      this.passwordMessage = '密码不能为空';
      return;
    }
    if (this.privateHasPassword) {
      const oldOk = await PrivateAccessRepository.verifyPassword(context, this.currentPasswordInput.trim());
      if (!oldOk) {
        this.passwordMessage = '当前密码不正确';
        return;
      }
    }
    try {
      await PrivateAccessRepository.setPassword(context, password);
      await PrivateAccessRepository.setEnabled(context, true);
      this.passwordPanelVisible = false;
      this.currentPasswordInput = '';
      this.passwordInput = '';
      this.passwordMessage = '';
      this.biometricStatus = PrivateAccessRepository.detectBiometricStatus();
      this.onUnavailableAction('本地密码已保存');
    } catch (error) {
      this.passwordMessage = error instanceof Error ? error.message : '密码保存失败';
    }
  }

  private updateHeader(): void {
    const offset = this.settingsScroller.currentOffset().yOffset;
    const shouldCollapse = offset > 70 ? true : offset < 24 ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      // 顶部折叠是位移，用弹簧收尾更自然；弹簧不吃 duration，删掉（写了也不生效）。
      this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.86) }, () => {
        this.collapsedHeader = shouldCollapse;
      });
    }
  }

  build() {
    Stack() {
      Column() {
      CollapsingSettingsHeader({ title: '隐私设置', collapsed: this.collapsedHeader, onBack: () => this.onBack() })

      Scroll(this.settingsScroller) {
        Column() {
          UiSection({ title: '解锁凭据' }) {
            UiSwitch({
              title: '启用私密功能',
              detail: '关闭后不再验证、不再脱敏；本地密码与书籍/分组标记都保留。',
              value: this.privateEnabled,
              onChange: (value: boolean) => { void this.applyPrivateEnabled(value); }
            })
            UiAction({
              title: '设置本地密码',
              detail: this.privateHasPassword ? '私密分组与私密书籍在验证前保持隐藏。' : '请先设置本地密码，才能使用私密分组与私密书籍。',
              onSelect: () => this.openPasswordPanel()
            })
            UiSwitch({
              showDivider: false,
              title: '生物识别快捷解锁',
              detail: this.biometricDetail(),
              value: this.biometricEnabled,
              disabled: !this.biometricUsable(),
              onChange: (value: boolean) => { void this.applyBiometric(value); }
            })
          }

          UiSection({ title: '验证时机' }) {
            UiSwitch({ title: '进入私密分组时验证', detail: '切换到私密分组后要求验证。', value: this.verifyOnEnterGroup, onChange: (value: boolean) => { void this.applyVerifyOption('verifyOnEnterGroup', value); } })
            UiSwitch({ title: '打开私密书籍时验证', detail: '打开被标记为私密的书籍前要求验证。', value: this.verifyOnOpenBook, onChange: (value: boolean) => { void this.applyVerifyOption('verifyOnOpenBook', value); } })
            UiSwitch({ title: '应用启动时验证', detail: '应用启动后立即要求验证，而不是等首次访问私密内容时再验证。', value: this.verifyOnAppStart, onChange: (value: boolean) => { void this.applyVerifyOption('verifyOnAppStart', value); } })
            UiChoice({ title: '验证频率', options: ['每次验证', '进入应用时验证一次', '离开应用前有效'], selectedIndex: this.unlockScopeIndex, onSelect: (index: number) => { void this.applyUnlockScope(index); } })
            if (this.unlockScopeIndex === 2) {
              UiChoice({showDivider: false, title: '离开后重新验证', options: GRACE_OPTION_LABELS, selectedIndex: this.graceIndex(), onSelect: (index: number) => { void this.applyBackgroundGrace(index); } })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseInOut }))
            }
          }

          UiSection({ title: '权限与数据' }) {
            UiAction({ showDivider: false, title: '通知权限', detail: '阅读需要发送通知来显示朗读控制和下载进度。', onSelect: () => { void this.requestNotification(); } })
          }
        }.width('100%').padding({ top: 6 })
      }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
      }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      if (this.passwordPanelVisible) {
        this.PasswordPanel()
      }
    }.width('100%').height('100%')
  }

  /** 本地密码面板：无密码时一个新密码框，有密码时「当前密码 + 新密码」两框。 */
  @Builder
  private PasswordPanel() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#99000000')
        .onClick(() => this.passwordPanelVisible = false)
      Column() {
        Text(this.privateHasPassword ? '修改本地密码' : '设置本地密码')
          .fontSize(TITLE_MEDIUM).fontColor('#F1F2F6').alignSelf(ItemAlign.Start)
        if (this.privateHasPassword) {
          TextInput({ text: this.currentPasswordInput, placeholder: '当前密码' })
            .type(InputType.Password).fontSize(TITLE_SMALL).height(44).margin({ top: 14 })
            .onChange((value: string) => { this.currentPasswordInput = value; })
        }
        TextInput({ text: this.passwordInput, placeholder: '输入本地密码' })
          .type(InputType.Password).fontSize(TITLE_SMALL).height(44).margin({ top: 10 })
          .onChange((value: string) => { this.passwordInput = value; })
        if (this.passwordMessage.length > 0) {
          Text(this.passwordMessage).fontSize(BODY_SMALL).fontColor('#FF6B6B')
            .alignSelf(ItemAlign.Start).margin({ top: 8 })
        }
        Row() {
          Text('取消').fontSize(TITLE_SMALL).fontColor('#B6B8C2').padding(10)
            .onClick(() => this.passwordPanelVisible = false)
          Blank()
          Text('保存').fontSize(TITLE_SMALL).fontColor(this.themeColorAccent).padding(10)
            .onClick(async () => { await this.savePassword(); })
        }.width('100%').margin({ top: 12 })
      }.width('90%').padding(18).backgroundColor('#1D1E26').borderRadius(18)
    }.width('100%').height('100%')
  }
}
