import { UiSection } from '../components/settings/UiSection';
import { UiDropdown } from '../components/settings/UiDropdown';
import { UiSwitch } from '../components/settings/UiSwitch';
import { UiAction } from '../components/settings/UiAction';
import { UiInput } from '../components/settings/UiInput';
import { AppGlyph } from '../components/AppGlyph';

@Component
export struct OtherSettingsPage {
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

  @State language: string = '跟随系统';
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
  private settingsScroller: Scroller = new Scroller();

  private openBatteryGuide(): void {
    this.activeDialog = 'battery';
  }

  private confirmClearWebView(): void {
    this.activeDialog = 'clearWebView';
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
      if (this.collapsedHeader) {
        Row() {
          Stack({ alignContent: Alignment.Center }) {
            Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.themeColorTextSecondary)
          }.width(40).height(40).onClick(() => this.onBack())
          Text('高级').fontSize(20).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).margin({ left: 8 })
        }.width('100%').height(56).padding({ left: 12, right: 16, top: 8, bottom: 8 }).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      } else {
        Column() {
          Row() {
            Stack({ alignContent: Alignment.Center }) {
              Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.themeColorTextSecondary)
            }.width(40).height(40).onClick(() => this.onBack())
            Blank()
          }.width('100%')
          Text('高级').fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
            .alignSelf(ItemAlign.Start).margin({ top: 18, left: 8 })
        }.width('100%').padding({ left: 12, right: 16, top: 8, bottom: 10 })
      }

      Scroll(this.settingsScroller) {
        Column() {
          UiSection() {
            UiDropdown({
              title: '语言', option: this.language,
              options: ['跟随系统', '简体中文', '繁体中文', '英文'],
              onSelect: (value: string) => this.language = value
            })
            UiDropdown({
              title: '检查更新查找版本', detail: '检查更新时查找其他签名版本', option: this.variant,
              options: ['正式版', '测试版', '全部版本', '共存版'],
              onSelect: (value: string) => this.variant = value
            })
            UiSwitch({ title: '启动时自动检测更新', detail: '仅在应用进程完全重新启动时检测，从后台返回不会触发', value: this.autoCheckUpdate, onChange: (value: boolean) => this.autoCheckUpdate = value })
            UiSwitch({showDivider: false,  title: '启动应用时打开Web服务', value: this.webAutoStart, onChange: (value: boolean) => this.webAutoStart = value })
          }

          UiSection({ title: '主界面' }) {
            UiSwitch({ title: '自动刷新', detail: '打开软件时自动更新书籍', value: this.autoRefresh, onChange: (value: boolean) => this.autoRefresh = value })
            UiSwitch({showDivider: false,  title: '自动跳转最近阅读', detail: '默认打开书架', value: this.defaultToRead, onChange: (value: boolean) => this.defaultToRead = value })
          }

          UiSection({ title: '阅读' }) {
            UiAction({ title: '书籍保存位置', detail: '', onSelect: () => this.activeSheet = 'folderPicker' })
            UiSwitch({ title: '抗锯齿', detail: '绘制图片时抗锯齿', value: this.antiAlias, onChange: (value: boolean) => this.antiAlias = value })
            UiSwitch({ title: '默认启用替换净化', detail: '新加入书架的书是否启用替换净化', value: this.replaceEnableDefault, onChange: (value: boolean) => this.onReplaceEnableDefaultChange(value) })
            UiSwitch({ title: '全程响应耳机按键', detail: '即使退出软件也响应耳机按键', value: this.mediaButtonOnExit, onChange: (value: boolean) => this.mediaButtonOnExit = value })
            UiSwitch({ title: '耳机按键启动朗读', detail: '通过耳机按键来启动朗读', value: this.readAloudByMediaButton, onChange: (value: boolean) => this.readAloudByMediaButton = value })
            UiSwitch({ title: '忽略音频焦点', detail: '允许与其他应用同时播放音频', value: this.ignoreAudioFocus, onChange: (value: boolean) => this.ignoreAudioFocus = value })
            UiSwitch({ title: '自动清除过期搜索数据', detail: '超过一天的搜索数据', value: this.autoClearExpired, onChange: (value: boolean) => this.autoClearExpired = value })
            UiSwitch({ title: '返回时提示放入书架', detail: '阅读未放入书架的书籍在返回时提示放入书架', value: this.showAddToShelfAlert, onChange: (value: boolean) => this.showAddToShelfAlert = value })
            UiSwitch({showDivider: false,  title: '漫画浏览', value: this.showMangaUi, onChange: (value: boolean) => this.showMangaUi = value })
          }

          UiSection({ title: '高级' }) {
            UiAction({ title: '后台保活与电池优化', detail: '未开启无限制，后台可能被系统终止', onSelect: () => this.openBatteryGuide() })
            UiSwitch({ title: 'WebService 唤醒锁', detail: '开启 Web 服务的时候启用唤醒锁，有些手机开启唤醒锁会被杀后台', value: this.webServiceWakeLock, onChange: (value: boolean) => this.webServiceWakeLock = value })
            UiInput({ title: '源编辑框最大行数', value: '2147483647', defaultValue: '2147483647', onConfirm: () => this.onUnavailableAction('源编辑框最大行数尚未保存') })
            UiAction({ title: '直链上传规则', detail: '用于导出书源书单时生成直链 URL', onSelect: () => this.activeSheet = 'directLink' })
            UiInput({ title: 'Web 端口', value: '1122', defaultValue: '1122', onConfirm: () => this.onUnavailableAction('Web 端口尚未保存') })
            UiAction({ title: '清除 WebView 数据', detail: '清除内置浏览器所有数据', onSelect: () => this.confirmClearWebView() })
            UiSwitch({ title: '阻止书源打开内置浏览器', detail: '开启后，书源无法通过 java.startBrowser 等接口弹出内置浏览器，等待网页结果的调用会直接报错', value: this.blockSourceBrowser, onChange: (value: boolean) => this.blockSourceBrowser = value })
            UiSwitch({ title: '文字操作显示搜索', detail: '长按文字在操作菜单中显示阅读 · 搜索', value: this.processText, onChange: (value: boolean) => this.processText = value })
            UiSwitch({ title: '记录日志', detail: '记录调试日志', value: this.recordLog, onChange: (value: boolean) => this.recordLog = value })
            UiSwitch({showDivider: false,  title: '记录堆转储', detail: '当应用发生OOM崩溃时保存堆转储', value: this.recordHeapDump, onChange: (value: boolean) => this.recordHeapDump = value })
          }
        }.width('100%').padding({ top: 4, bottom: 120 })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => {
        const shouldCollapse = Math.abs(this.settingsScroller.currentOffset().yOffset) > 70;
        if (this.collapsedHeader !== shouldCollapse) { this.collapsedHeader = shouldCollapse; }
      })
      }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))

      if (this.activeDialog.length > 0) {
        Stack({ alignContent: Alignment.Center }) {
          Row().width('100%').height('100%').backgroundColor('#99000000')
            .onClick(() => this.activeDialog = '')
          Column() {
            Text(this.activeDialog === 'battery' ? '后台保活与省电策略设置指引' : '清除 WebView 数据')
              .fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
              .textAlign(TextAlign.Center).width('100%')
            Text(this.activeDialog === 'battery'
              ? '后台保活设置指引：\n1. 在系统设置中进入【电池 / 耗电管理】。\n2. 将后台行为设为【无限制】或【不优化】。\n3. 允许应用【后台活动】与【自启动】。'
              : '是否确认删除?')
              .fontSize(15).fontColor(this.themeColorTextSecondary).lineHeight(24).margin({ top: 22, bottom: 24 })
            Row() {
              Text('取消').fontSize(15).fontColor(this.themeColorAccent).textAlign(TextAlign.Center)
                .layoutWeight(1).padding({ top: 14, bottom: 14 })
                .onClick(() => this.activeDialog = '')
              Text(this.activeDialog === 'battery' ? '设置' : '确认').fontSize(15).fontColor(this.themeColorAccent)
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
        backgroundColor: this.themeColorSurfaceElevated,
        onDisappear: () => this.activeSheet = ''
      })
  }

  @Builder
  private DirectLinkMenu() {
    Menu() {
      MenuItem({ content: '导入默认规则' }).height(48)
        .onClick(() => this.onUnavailableAction('默认直链规则尚未接入'))
      MenuItem({ content: '拷贝规则' }).height(48)
        .onClick(() => this.onUnavailableAction('规则复制尚未接入'))
      MenuItem({ content: '粘贴规则' }).height(48)
        .onClick(() => this.onUnavailableAction('规则粘贴尚未接入'))
    }.backgroundColor('#25262D').fontColor(this.themeColorTextPrimary).radius(16)
  }

  @Builder
  private SettingsSheetContent() {
    Column() {
      if (this.activeSheet === 'folderPicker') {
        Row() {
          Text('选择操作').fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).layoutWeight(1)
          Text('取消').fontSize(14).fontColor(this.themeColorAccent).onClick(() => this.activeSheet = '')
        }.width('100%').padding({ left: 18, right: 18, top: 8, bottom: 16 })
        Row() {
          AppGlyph({ name: 'profileFolder', glyphSize: 28, tint: this.themeColorAccent })
          Text('系统文件夹选择器').fontSize(15).fontColor(this.themeColorTextPrimary).margin({ left: 12 })
          Blank()
        }.width('100%').height(84).padding({ left: 20, right: 20 })
          .backgroundColor('#25262D').borderRadius(14)
          .onClick(() => {
            this.activeSheet = '';
            this.onUnavailableAction('系统文件夹选择器尚未接入');
          })
      } else {
        Row() {
          Stack({ alignContent: Alignment.Center }) {
            AppGlyph({ name: 'profileCheck', glyphSize: 20, tint: this.themeColorAccent })
          }.width(40).height(40).backgroundColor('#25262D').borderRadius(20)
            .onClick(() => this.onUnavailableAction('直链规则测试尚未迁移'))
          Text('直链上传配置').fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
            .layoutWeight(1).textAlign(TextAlign.Center)
          Stack({ alignContent: Alignment.Center }) {
            AppGlyph({ name: 'more', glyphSize: 18, tint: this.themeColorTextSecondary })
          }.width(40).height(40).backgroundColor('#25262D').borderRadius(20)
            .bindMenu(this.DirectLinkMenu, { placement: Placement.Bottom })
        }.width('100%').padding({ left: 18, right: 14, top: 8, bottom: 14 })
        Scroll() {
          Column() {
            OtherSettingsSheetField({ title: '上传 URL', value: this.directUploadUrl, onChange: (value: string) => this.directUploadUrl = value })
            OtherSettingsSheetField({ title: '下载 URL 规则', value: this.directDownloadRule, onChange: (value: string) => this.directDownloadRule = value })
            OtherSettingsSheetField({ title: '注释', value: this.directRuleSummary, onChange: (value: string) => this.directRuleSummary = value })
            Row() {
              Text('是否压缩').fontSize(15).fontColor(this.themeColorTextPrimary).layoutWeight(1)
              Checkbox({ name: 'direct_link_compress' }).shape(CheckBoxShape.ROUNDED_SQUARE)
                .select(this.directCompress)
                .onChange((value: boolean) => this.directCompress = value)
            }.width('100%').padding({ left: 12, right: 12, top: 12, bottom: 12 })
          }.width('100%').padding({ left: 16, right: 16, top: 4 }).constraintSize({ minHeight: '100%' })
        }.layoutWeight(1).scrollBar(BarState.Off)
        Row() {
          Text('取消').fontSize(14).fontColor(this.themeColorTextSecondary).layoutWeight(1).textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 12 }).backgroundColor('#25262D').borderRadius(20)
            .onClick(() => this.activeSheet = '')
          Text('确认').fontSize(14).fontColor(this.themeColorSurfacePrimary).layoutWeight(1).textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 12 }).backgroundColor(this.themeColorAccent).borderRadius(20).margin({ left: 10 })
            .onClick(() => {
              this.onUnavailableAction('直链上传规则尚未保存');
              this.activeSheet = '';
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
      Text(this.title).fontSize(13).fontColor('#B6B8C2').alignSelf(ItemAlign.Start).margin({ bottom: 6 })
      TextInput({ text: this.value, placeholder: this.title })
        .fontSize(15).fontColor(this.themeColorTextPrimary).placeholderColor('#858792')
        .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary)).borderRadius(8)
        .onChange((value: string) => this.onChange(value))
    }.width('100%').margin({ bottom: 14 })
  }
}
