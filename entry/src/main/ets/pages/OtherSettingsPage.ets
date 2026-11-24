import { HEADER_COLLAPSE_THRESHOLD, HEADER_EXPAND_THRESHOLD } from '../components/UiTokens';
import { UiMenuItem, UiMenuPanel } from '../components/UiMenu';
import curves from '@ohos.curves';
import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';
import { UiSection } from '../components/settings/UiSection';
import { UiDropdown } from '../components/settings/UiDropdown';
import { UiSwitch } from '../components/settings/UiSwitch';
import { UiAction } from '../components/settings/UiAction';
import { UiInput } from '../components/settings/UiInput';
import { AppGlyph } from '../components/AppGlyph';
import { picker } from '@kit.CoreFileKit';
import { pasteboard } from '@kit.BasicServicesKit';
import {
  DEFAULT_DIRECT_LINK_RULES, DirectLinkError, DirectLinkRule, DirectLinkUpload, DirectLinkUploadStore
} from '../lib/DirectLinkUpload';
import { OtherSettingsRepository, OtherSettings, DEFAULT_OTHER_SETTINGS } from '../data/OtherSettingsRepository';
import { AppLocaleRepository, APP_LANGUAGE_VALUES, appLanguageLabel } from '../lib/AppLocaleRepository';
import { HEADLINE_SMALL, LABEL_LARGE, LABEL_MEDIUM, LABEL_MEDIUM_LINE_HEIGHT, TITLE_MEDIUM, TITLE_SMALL } from '../components/typography/TypographyTokens';

/** 卡片式菜单的统一宽度，与书架页、详情页同口径。 */
const OTHER_SETTINGS_MENU_WIDTH: number = 260;

@Component
export struct OtherSettingsPage {
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @Prop replaceEnableDefault: boolean = true;
  onReplaceEnableDefaultChange: (enabled: boolean) => void = (_enabled: boolean) => {};

  @State language: string = 'auto';
  @State variant: string = '正式版';
  @State autoCheckUpdate: boolean = false;
  @State webAutoStart: boolean = false;
  @State autoRefresh: boolean = false;
  @State defaultToRead: boolean = false;
  @State antiAlias: boolean = false;
  @State mediaButtonOnExit: boolean = true;
  @State readAloudByMediaButton: boolean = false;
  @State ignoreAudioFocus: boolean = false;
  @State autoClearExpired: boolean = true;
  @State showAddToShelfAlert: boolean = true;
  @State showMangaUi: boolean = true;
  @State webServiceWakeLock: boolean = false;
  @State blockSourceBrowser: boolean = false;
  @State processText: boolean = true;
  @State recordLog: boolean = false;
  @State recordHeapDump: boolean = false;
  @State collapsedHeader: boolean = false;
  @State activeDialog: string = '';
  @State activeSheet: string = '';
  @State directUploadUrl: string = '';
  @State directDownloadRule: string = '';
  @State directRuleSummary: string = '';
  @State directCompress: boolean = false;
  @State directLinkVisible: boolean = false;
  @State otherSettings: OtherSettings = OtherSettingsRepository.get();
  private settingsScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    // 进页取一次偏好，保证书籍保存位置/两个输入框显示的是落盘值。
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      OtherSettingsRepository.load(context).then((settings: OtherSettings) => {
        this.otherSettings = settings;
        // 「记录日志」开关是落盘偏好，进页时把真实值同步到 @State，
        // 否则开关永远显示 false，用户以为没打开（对齐上游 recordLog 持久化）。
        this.recordLog = settings.recordLog;
        // 「记录堆转储」同样是落盘偏好（上游 PreferKey.recordHeapDump），进页同步真实值，
        // 否则开关永远显示 false，用户以为没打开，OOM 时也不会抓堆转储。
        this.recordHeapDump = settings.recordHeapDump;
      });
      // 语言是独立偏好（上游 PreferKey.language），进页读一次让下拉显示落盘值。
      AppLocaleRepository.load(context).then((language: string) => {
        this.language = language;
      });
      // 直链规则是独立一份偏好（上游 ACache 的 directLinkUploadRule.json），进页读一次
      // 让面板里显示的是落盘值而不是空框（对齐 OtherConfigViewModel.kt:257-266）。
      DirectLinkUploadStore.loadRule(context).then((rule: DirectLinkRule) => {
        this.directUploadUrl = rule.uploadUrl;
        this.directDownloadRule = rule.downloadUrlRule;
        this.directRuleSummary = rule.summary;
        this.directCompress = rule.compress;
      });
    }
  }

  /** 把四个输入框组装成一条规则。 */
  private currentDirectLinkRule(): DirectLinkRule {
    return {
      uploadUrl: this.directUploadUrl,
      downloadUrlRule: this.directDownloadRule,
      summary: this.directRuleSummary,
      compress: this.directCompress
    };
  }

  /** 导入默认规则：取第一条填进四个输入框（上游 import_default_rule 选中的那条）。 */
  private importDefaultDirectRule(): void {
    if (DEFAULT_DIRECT_LINK_RULES.length === 0) {
      return;
    }
    const rule = DEFAULT_DIRECT_LINK_RULES[0];
    this.directUploadUrl = rule.uploadUrl;
    this.directDownloadRule = rule.downloadUrlRule;
    this.directRuleSummary = rule.summary;
    this.directCompress = rule.compress;
  }

  /** 拷贝规则：把四个字段写成 JSON 放剪贴板（上游 copy_rule 的 GSON.toJson(DirectLinkRuleUi)）。 */
  private copyDirectLinkRule(): void {
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, JSON.stringify(this.currentDirectLinkRule()));
    pasteboard.getSystemPasteboard().setData(data).then(() => {
      this.onUnavailableAction('规则已复制到剪贴板');
    }).catch((error: Error) => {
      this.onUnavailableAction(`复制失败：${error.message}`);
    });
  }

  /** 粘贴规则：读剪贴板解析成四个字段，坏 JSON 保持原样并提示（上游 clipboard_empty_or_invalid）。 */
  private async pasteDirectLinkRule(): Promise<void> {
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      const text = data.getPrimaryText();
      const rule = DirectLinkUploadStore.parse(text);
      if (rule === undefined) {
        this.onUnavailableAction('剪贴板内容为空或不是合法规则');
        return;
      }
      this.directUploadUrl = rule.uploadUrl;
      this.directDownloadRule = rule.downloadUrlRule;
      this.directRuleSummary = rule.summary;
      this.directCompress = rule.compress;
    } catch (error) {
      this.onUnavailableAction(`粘贴失败：${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /** 保存：三项必填校验后落盘（对齐 OtherConfigViewModel.kt:275-291 saveDirectLinkRule）。 */
  private async saveDirectLinkRule(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    if (this.directUploadUrl.trim().length === 0
      || this.directDownloadRule.trim().length === 0
      || this.directRuleSummary.trim().length === 0) {
      this.onUnavailableAction('上传 URL、下载 URL 规则、注释都不能为空');
      return;
    }
    try {
      await DirectLinkUploadStore.saveRule(context, this.currentDirectLinkRule());
      this.activeSheet = '';
    } catch (error) {
      this.onUnavailableAction(`保存失败：${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 测试：拿当前四个字段上传一份 "{}"（test.json / application/json），
   * 把返回的直链或错误显示在对话框里（对齐上游 testRule 与 AppAlertDialog title=Result）。
   */
  private async testDirectLinkRule(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    let message = '';
    try {
      message = await DirectLinkUpload.upload(context, 'test.json', '{}', 'application/json', this.currentDirectLinkRule());
    } catch (error) {
      message = error instanceof DirectLinkError
        ? error.message
        : `测试失败：${error instanceof Error ? error.message : String(error)}`;
    }
    this.getUIContext().showAlertDialog({
      title: 'Result',
      message: message,
      primaryButton: {
        value: '关闭',
        action: () => {}
      }
    });
  }

  private saveOtherSettings(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    OtherSettingsRepository.save(context, this.otherSettings);
  }

  /**
   * 切换应用语言：落盘 + 交给平台，下一次冷启动按新语言加载资源。
   * 对齐上游 `OtherConfigViewModel.kt:84` 的 `appLocaleGateway.setLanguage(intent.value)`。
   */
  private changeLanguage(value: string): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    this.language = value;
    AppLocaleRepository.setLanguage(context, value).catch((error: Error) => {
      this.onUnavailableAction(`切换语言失败：${error.message}`);
    });
  }

  private confirmSourceEditMaxLine(text: string): void {
    const value = parseInt(text, 10);
    this.otherSettings = {
      defaultBookTreeUri: this.otherSettings.defaultBookTreeUri,
      sourceEditMaxLine: isNaN(value) ? DEFAULT_OTHER_SETTINGS.sourceEditMaxLine : Math.max(1, value),
      webPort: this.otherSettings.webPort,
      recordLog: this.otherSettings.recordLog,
      recordHeapDump: this.otherSettings.recordHeapDump,
      fontSort: this.otherSettings.fontSort,
      deleteBookOriginal: this.otherSettings.deleteBookOriginal,
    };
    this.saveOtherSettings();
  }

  private confirmWebPort(text: string): void {
    const value = parseInt(text, 10);
    const port = (isNaN(value) || value < 1 || value > 65535)
      ? DEFAULT_OTHER_SETTINGS.webPort : value;
    this.otherSettings = {
      defaultBookTreeUri: this.otherSettings.defaultBookTreeUri,
      sourceEditMaxLine: this.otherSettings.sourceEditMaxLine,
      webPort: port,
      recordLog: this.otherSettings.recordLog,
      recordHeapDump: this.otherSettings.recordHeapDump,
      fontSort: this.otherSettings.fontSort,
      deleteBookOriginal: this.otherSettings.deleteBookOriginal,
    };
    this.saveOtherSettings();
  }

  /** 「记录日志」开关：写回偏好（上游 PreferKey.recordLog），AppLog.putDebug 按它门控。 */
  private confirmRecordLog(value: boolean): void {
    this.recordLog = value;
    this.otherSettings = {
      defaultBookTreeUri: this.otherSettings.defaultBookTreeUri,
      sourceEditMaxLine: this.otherSettings.sourceEditMaxLine,
      webPort: this.otherSettings.webPort,
      recordLog: value,
      recordHeapDump: this.otherSettings.recordHeapDump,
      fontSort: this.otherSettings.fontSort,
      deleteBookOriginal: this.otherSettings.deleteBookOriginal,
    };
    this.saveOtherSettings();
  }

  /** 「记录堆转储」开关：写回偏好（上游 PreferKey.recordHeapDump），OOM 崩溃与关于页按它门控。 */
  private confirmRecordHeapDump(value: boolean): void {
    this.recordHeapDump = value;
    this.otherSettings = {
      defaultBookTreeUri: this.otherSettings.defaultBookTreeUri,
      sourceEditMaxLine: this.otherSettings.sourceEditMaxLine,
      webPort: this.otherSettings.webPort,
      recordLog: this.otherSettings.recordLog,
      recordHeapDump: value,
      fontSort: this.otherSettings.fontSort,
      deleteBookOriginal: this.otherSettings.deleteBookOriginal,
    };
    this.saveOtherSettings();
  }

  /** 系统文件夹选择器真接：选完把 URI 存偏好，回写「书籍保存位置」detail。 */
  private async pickBookFolder(): Promise<void> {
    this.activeSheet = '';
    try {
      const options = new picker.DocumentSelectOptions();
      options.selectMode = picker.DocumentSelectMode.FOLDER;
      options.maxSelectNumber = 1;
      const context = this.getUIContext().getHostContext();
      if (context === undefined) { return; }
      const uris = await new picker.DocumentViewPicker(context).select(options);
      const uri = uris[0];
      if (uri === undefined) { return; }
      this.otherSettings = {
        defaultBookTreeUri: uri,
        sourceEditMaxLine: this.otherSettings.sourceEditMaxLine,
        webPort: this.otherSettings.webPort,
        recordLog: this.otherSettings.recordLog,
        recordHeapDump: this.otherSettings.recordHeapDump,
        fontSort: this.otherSettings.fontSort,
        deleteBookOriginal: this.otherSettings.deleteBookOriginal,
      };
      this.saveOtherSettings();
    } catch (error) {
      console.error(`选择书籍目录失败：${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private openBatteryGuide(): void {
    this.activeDialog = 'battery';
  }

  private confirmClearWebView(): void {
    this.activeDialog = 'clearWebView';
  }

  private updateHeader(): void {
    const offset = this.settingsScroller.currentOffset().yOffset;
    const shouldCollapse = offset > HEADER_COLLAPSE_THRESHOLD ? true : offset < HEADER_EXPAND_THRESHOLD ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.86) }, () => {
        this.collapsedHeader = shouldCollapse;
      });
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
      CollapsingSettingsHeader({ title: '高级', collapsed: this.collapsedHeader, onBack: () => this.onBack() })

      Scroll(this.settingsScroller) {
        Column() {
          UiSection() {
            UiDropdown({
              title: '语言', option: this.language,
              options: APP_LANGUAGE_VALUES,
              labelOf: (value: string) => appLanguageLabel(value),
              onSelect: (value: string) => this.changeLanguage(value)
            })
            UiDropdown({
              title: '检查更新查找版本', detail: '检查更新时查找其他签名版本', option: this.variant,
              options: ['正式版', '测试版', '全部版本', '共存版'],
              onSelect: (value: string) => this.variant = value
            })
            UiSwitch({ title: '启动时自动检测更新', detail: '仅在应用进程完全重新启动时检测，从后台返回不会触发', value: this.autoCheckUpdate, onChange: (value: boolean) => this.autoCheckUpdate = value })
            UiSwitch({showDivider: false, title: '启动应用时打开Web服务', value: this.webAutoStart, onChange: (value: boolean) => this.webAutoStart = value })
          }

          UiSection({ title: '主界面' }) {
            UiSwitch({ title: '自动刷新', detail: '打开软件时自动更新书籍', value: this.autoRefresh, onChange: (value: boolean) => this.autoRefresh = value })
            UiSwitch({showDivider: false, title: '自动跳转最近阅读', detail: '默认打开书架', value: this.defaultToRead, onChange: (value: boolean) => this.defaultToRead = value })
          }

          UiSection({ title: '阅读' }) {
            UiAction({ title: '书籍保存位置', detail: this.otherSettings.defaultBookTreeUri, detailMaxLines: 1, onSelect: () => this.activeSheet = 'folderPicker' })
            UiSwitch({ title: '抗锯齿', detail: '绘制图片时抗锯齿', value: this.antiAlias, onChange: (value: boolean) => this.antiAlias = value })
            UiSwitch({ title: '默认启用替换净化', detail: '新加入书架的书是否启用替换净化', value: this.replaceEnableDefault, onChange: (value: boolean) => this.onReplaceEnableDefaultChange(value) })
            UiSwitch({ title: '全程响应耳机按键', detail: '即使退出软件也响应耳机按键', value: this.mediaButtonOnExit, onChange: (value: boolean) => this.mediaButtonOnExit = value })
            UiSwitch({ title: '耳机按键启动朗读', detail: '通过耳机按键来启动朗读', value: this.readAloudByMediaButton, onChange: (value: boolean) => this.readAloudByMediaButton = value })
            UiSwitch({ title: '忽略音频焦点', detail: '允许与其他应用同时播放音频', value: this.ignoreAudioFocus, onChange: (value: boolean) => this.ignoreAudioFocus = value })
            UiSwitch({ title: '自动清除过期搜索数据', detail: '超过一天的搜索数据', value: this.autoClearExpired, onChange: (value: boolean) => this.autoClearExpired = value })
            UiSwitch({ title: '返回时提示放入书架', detail: '阅读未放入书架的书籍在返回时提示放入书架', value: this.showAddToShelfAlert, onChange: (value: boolean) => this.showAddToShelfAlert = value })
            UiSwitch({showDivider: false, title: '漫画浏览', value: this.showMangaUi, onChange: (value: boolean) => this.showMangaUi = value })
          }

          UiSection({ title: '高级' }) {
            UiAction({ title: '后台保活与电池优化', detail: '未开启无限制，后台可能被系统终止', onSelect: () => this.openBatteryGuide() })
            UiSwitch({ title: 'WebService 唤醒锁', detail: '开启 Web 服务的时候启用唤醒锁，有些手机开启唤醒锁会被杀后台', value: this.webServiceWakeLock, onChange: (value: boolean) => this.webServiceWakeLock = value })
            UiInput({ title: '源编辑框最大行数', value: `${this.otherSettings.sourceEditMaxLine}`, defaultValue: '2147483647', onConfirm: (text: string) => this.confirmSourceEditMaxLine(text) })
            UiAction({ title: '直链上传规则', detail: '用于导出书源书单时生成直链 URL', onSelect: () => this.activeSheet = 'directLink' })
            UiInput({ title: 'Web 端口', value: `${this.otherSettings.webPort}`, defaultValue: '1122', onConfirm: (text: string) => this.confirmWebPort(text) })
            UiAction({ title: '清除 WebView 数据', detail: '清除内置浏览器所有数据', onSelect: () => this.confirmClearWebView() })
            UiSwitch({ title: '阻止书源打开内置浏览器', detail: '开启后，书源无法通过 java.startBrowser 等接口弹出内置浏览器，等待网页结果的调用会直接报错', value: this.blockSourceBrowser, onChange: (value: boolean) => this.blockSourceBrowser = value })
            UiSwitch({ title: '文字操作显示搜索', detail: '长按文字在操作菜单中显示阅读 · 搜索', value: this.processText, onChange: (value: boolean) => this.processText = value })
            UiSwitch({ title: '记录日志', detail: '记录调试日志', value: this.recordLog, onChange: (value: boolean) => this.confirmRecordLog(value) })
            UiSwitch({showDivider: false, title: '记录堆转储', detail: '当应用发生OOM崩溃时保存堆转储', value: this.recordHeapDump, onChange: (value: boolean) => this.confirmRecordHeapDump(value) })
          }
        }.width('100%').padding({ top: 4, bottom: 120 })
      }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
      }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))

      if (this.activeDialog.length > 0) {
        Stack({ alignContent: Alignment.Center }) {
          Row().width('100%').height('100%').backgroundColor('#99000000')
            .onClick(() => this.activeDialog = '')
          Column() {
            Text(this.activeDialog === 'battery' ? '后台保活与省电策略设置指引' : '清除 WebView 数据')
              .fontSize(HEADLINE_SMALL).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
              .textAlign(TextAlign.Center).width('100%')
            Text(this.activeDialog === 'battery'
              ? '后台保活设置指引：\n1. 在系统设置中进入【电池 / 耗电管理】。\n2. 将后台行为设为【无限制】或【不优化】。\n3. 允许应用【后台活动】与【自启动】。'
              : '是否确认删除?')
              .fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextSecondary).lineHeight(LABEL_MEDIUM_LINE_HEIGHT).margin({ top: 22, bottom: 24 })
            Row() {
              Text('取消').fontSize(LABEL_LARGE).fontColor(this.themeColorAccent).textAlign(TextAlign.Center)
                .layoutWeight(1).padding({ top: 14, bottom: 14 })
                .onClick(() => this.activeDialog = '')
              Text(this.activeDialog === 'battery' ? '设置' : '确认').fontSize(LABEL_LARGE).fontColor(this.themeColorAccent)
                .textAlign(TextAlign.Center).layoutWeight(1).padding({ top: 14, bottom: 14 })
                .onClick(() => {
                  const dialogType = this.activeDialog;
                  this.activeDialog = '';
                  this.onUnavailableAction(dialogType === 'battery'
                    ? '跳转系统电池设置尚未接入'
                    : 'WebView 数据清理尚未迁移，未清理数据');
                })
            }.width('100%').backgroundColor('#22232A').borderRadius(16)
          }.width('calc(100% - 48vp)').padding(22).backgroundColor('#292A31').borderRadius(24)
        }.width('100%').height('100%').zIndex(10)
      }
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      .bindSheet(this.activeSheet.length > 0, this.SettingsSheetContent(), {
        height: this.activeSheet === 'directLink' ? 620 : 300,
        dragBar: true,
        showClose: false,
        backgroundColor: this.themeColorSurfaceTertiary,
        onDisappear: () => this.activeSheet = ''
      })
  }

  private directLinkMenuItems(): UiMenuItem[] {
    return [
      { key: 'import_default', title: '导入默认规则' },
      { key: 'copy_rule', title: '拷贝规则' },
      { key: 'paste_rule', title: '粘贴规则' }
    ];
  }

  @Builder
  private DirectLinkMenu() {
    UiMenuPanel({
      items: this.directLinkMenuItems(),
      panelWidth: OTHER_SETTINGS_MENU_WIDTH,
      onSelect: (key: string) => {
        this.directLinkVisible = false;
        if (key === 'import_default') {
          this.importDefaultDirectRule();
        } else if (key === 'copy_rule') {
          this.copyDirectLinkRule();
        } else if (key === 'paste_rule') {
          this.pasteDirectLinkRule();
        }
      }
    })
  }

  @Builder
  private SettingsSheetContent() {
    Column() {
      if (this.activeSheet === 'folderPicker') {
        Row() {
          Text('选择操作').fontSize(HEADLINE_SMALL).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).layoutWeight(1)
          Text('取消').fontSize(LABEL_LARGE).fontColor(this.themeColorAccent).onClick(() => this.activeSheet = '')
        }.width('100%').padding({ left: 18, right: 18, top: 8, bottom: 16 })
        Row() {
          AppGlyph({ name: 'profileFolder', glyphSize: 28, tint: this.themeColorAccent })
          Text('系统文件夹选择器').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).margin({ left: 12 })
          Blank()
        }.width('100%').height(84).padding({ left: 20, right: 20 })
          .backgroundColor(this.themeColorSurfaceElevated).borderRadius(14)
          .onClick(() => this.pickBookFolder())
      } else {
        Row() {
          Stack({ alignContent: Alignment.Center }) {
            AppGlyph({ name: 'profileCheck', glyphSize: 20, tint: this.themeColorAccent })
          }.width(40).height(40).backgroundColor(this.themeColorSurfaceElevated).borderRadius(20)
            .onClick(() => { void this.testDirectLinkRule(); })
            // 上游取 DirectLinkUploadBottomSheet.kt:67 test
            .accessibilityText('测试')
          Text('直链上传配置').fontSize(HEADLINE_SMALL).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
            .layoutWeight(1).textAlign(TextAlign.Center)
          Stack({ alignContent: Alignment.Center }) {
            AppGlyph({ name: 'more', glyphSize: 18, tint: this.themeColorTextSecondary })
          }.width(40).height(40).backgroundColor(this.themeColorSurfaceElevated).borderRadius(20)
            .onClick(() => { this.directLinkVisible = !this.directLinkVisible; })
            // 上游取 DirectLinkUploadBottomSheet.kt:75 more_menu
            .accessibilityText('更多菜单')
            .bindPopup(this.directLinkVisible, {
              builder: this.DirectLinkMenu,
              placement: Placement.Bottom,
              popupColor: '#00000000',
              enableArrow: false,
              autoCancel: true,
              width: OTHER_SETTINGS_MENU_WIDTH,
              onStateChange: (event: PopupStateChangeParam) => { this.directLinkVisible = event.isVisible; }
            })
        }.width('100%').padding({ left: 18, right: 14, top: 8, bottom: 14 })
        Scroll() {
          Column() {
            OtherSettingsSheetField({ title: '上传 URL', value: this.directUploadUrl, onChange: (value: string) => this.directUploadUrl = value })
            OtherSettingsSheetField({ title: '下载 URL 规则', value: this.directDownloadRule, onChange: (value: string) => this.directDownloadRule = value })
            OtherSettingsSheetField({ title: '注释', value: this.directRuleSummary, onChange: (value: string) => this.directRuleSummary = value })
            Row() {
              Text('是否压缩').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).layoutWeight(1)
              Checkbox({ name: 'direct_link_compress' }).shape(CheckBoxShape.ROUNDED_SQUARE)
                .select(this.directCompress)
                .onChange((value: boolean) => this.directCompress = value)
            }.width('100%').padding({ left: 12, right: 12, top: 12, bottom: 12 })
          }.width('100%').padding({ left: 16, right: 16, top: 4 }).constraintSize({ minHeight: '100%' })
        }.edgeEffect(EdgeEffect.None).layoutWeight(1).scrollBar(BarState.Off)
        Row() {
          Text('取消').fontSize(LABEL_LARGE).fontColor(this.themeColorTextSecondary).layoutWeight(1).textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 12 }).backgroundColor(this.themeColorSurfaceElevated).borderRadius(20)
            .onClick(() => this.activeSheet = '')
          Text('确认').fontSize(LABEL_LARGE).fontColor(this.themeColorSurfacePrimary).layoutWeight(1).textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 12 }).backgroundColor(this.themeColorAccent).borderRadius(20).margin({ left: 10 })
            .onClick(() => {
              this.saveDirectLinkRule();
            })
        }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 22 })
      }
    }.width('100%').height('100%').padding({ top: 8 })
  }
}

@Component
struct OtherSettingsSheetField {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop title: string = '';
  @Prop value: string = '';
  onChange: (value: string) => void = (_value: string) => {};

  build() {
    Column() {
      Text(this.title).fontSize(LABEL_MEDIUM).fontColor('#B6B8C2').alignSelf(ItemAlign.Start).margin({ bottom: 6 })
      TextInput({ text: this.value, placeholder: this.title })
        .fontSize(LABEL_LARGE).fontColor(this.themeColorTextPrimary).placeholderColor('#858792')
        .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary)).borderRadius(8)
        .onChange((value: string) => this.onChange(value))
    }.width('100%').margin({ bottom: 14 })
  }
}
