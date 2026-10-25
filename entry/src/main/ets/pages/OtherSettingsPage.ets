import { AppGlyph } from '../components/AppGlyph';

@Component
export struct OtherSettingsPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @Prop replaceEnableDefault: boolean = true;
  onReplaceEnableDefaultChange: (enabled: boolean) => void = (_enabled: boolean) => {};

  @State language: string = '简体中文';
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
            Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
          }.width(40).height(40).onClick(() => this.onBack())
          Text('高级').fontSize(20).fontWeight(FontWeight.Medium).fontColor('#E3E4E8').margin({ left: 8 })
        }.width('100%').height(56).padding({ left: 12, right: 16, top: 8, bottom: 8 }).backgroundColor('#111217')
      } else {
        Column() {
          Row() {
            Stack({ alignContent: Alignment.Center }) {
              Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
            }.width(40).height(40).onClick(() => this.onBack())
            Blank()
          }.width('100%')
          Text('高级').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
            .alignSelf(ItemAlign.Start).margin({ top: 18, left: 8 })
        }.width('100%').padding({ left: 12, right: 16, top: 8, bottom: 10 })
      }

      Scroll(this.settingsScroller) {
        Column() {
          OtherSettingsSection() {
            OtherSettingsDropdown({
              title: '语言', option: this.language,
              options: ['自动', '简体中文', '繁體中文', 'English'],
              onSelect: (value: string) => this.language = value
            })
            OtherSettingsDropdown({
              title: '检查更新查找版本', detail: '检查更新时查找其他签名版本', option: this.variant,
              options: ['正式版', '测试版', '全部版本', '共存版'],
              onSelect: (value: string) => this.variant = value
            })
            OtherSettingsSwitch({ title: '启动时自动检测更新', detail: '仅在应用进程完全重新启动时检测，从后台返回不会触发', value: this.autoCheckUpdate, onChange: (value: boolean) => this.autoCheckUpdate = value })
            OtherSettingsSwitch({ title: '启动应用时打开Web服务', value: this.webAutoStart, onChange: (value: boolean) => this.webAutoStart = value })
          }

          OtherSettingsSection({ title: '主界面' }) {
            OtherSettingsSwitch({ title: '自动刷新', detail: '打开软件时自动更新书籍', value: this.autoRefresh, onChange: (value: boolean) => this.autoRefresh = value })
            OtherSettingsSwitch({ title: '自动跳转最近阅读', detail: '默认打开书架', value: this.defaultToRead, onChange: (value: boolean) => this.defaultToRead = value })
          }

          OtherSettingsSection({ title: '阅读' }) {
            OtherSettingsAction({ title: '书籍保存位置', detail: '', onSelect: () => this.activeSheet = 'folderPicker' })
            OtherSettingsSwitch({ title: '抗锯齿', detail: '绘制图片时抗锯齿', value: this.antiAlias, onChange: (value: boolean) => this.antiAlias = value })
            OtherSettingsSwitch({ title: '默认启用替换净化', detail: '新加入书架的书是否启用替换净化', value: this.replaceEnableDefault, onChange: (value: boolean) => this.onReplaceEnableDefaultChange(value) })
            OtherSettingsSwitch({ title: '全程响应耳机按键', detail: '即使退出软件也响应耳机按键', value: this.mediaButtonOnExit, onChange: (value: boolean) => this.mediaButtonOnExit = value })
            OtherSettingsSwitch({ title: '耳机按键启动朗读', detail: '通过耳机按键来启动朗读', value: this.readAloudByMediaButton, onChange: (value: boolean) => this.readAloudByMediaButton = value })
            OtherSettingsSwitch({ title: '忽略音频焦点', detail: '允许与其他应用同时播放音频', value: this.ignoreAudioFocus, onChange: (value: boolean) => this.ignoreAudioFocus = value })
            OtherSettingsSwitch({ title: '自动清除过期搜索数据', detail: '超过一天的搜索数据', value: this.autoClearExpired, onChange: (value: boolean) => this.autoClearExpired = value })
            OtherSettingsSwitch({ title: '返回时提示放入书架', detail: '阅读未放入书架的书籍在返回时提示放入书架', value: this.showAddToShelfAlert, onChange: (value: boolean) => this.showAddToShelfAlert = value })
            OtherSettingsSwitch({ title: '漫画浏览', value: this.showMangaUi, onChange: (value: boolean) => this.showMangaUi = value })
          }

          OtherSettingsSection({ title: '高级' }) {
            OtherSettingsAction({ title: '后台保活与电池优化', detail: '未开启无限制，后台可能被系统终止', onSelect: () => this.openBatteryGuide() })
            OtherSettingsSwitch({ title: 'WebService 唤醒锁', detail: '开启 Web 服务的时候启用唤醒锁，有些手机开启唤醒锁会被杀后台', value: this.webServiceWakeLock, onChange: (value: boolean) => this.webServiceWakeLock = value })
            OtherSettingsInput({ title: '源编辑框最大行数', value: '2147483647', onConfirm: () => this.onUnavailableAction('源编辑框最大行数尚未保存') })
            OtherSettingsAction({ title: '直链上传规则', detail: '用于导出书源书单时生成直链 URL', onSelect: () => this.activeSheet = 'directLink' })
            OtherSettingsInput({ title: 'Web 端口', value: '1122', onConfirm: () => this.onUnavailableAction('Web 端口尚未保存') })
            OtherSettingsAction({ title: '清除 WebView 数据', detail: '清除内置浏览器所有数据', onSelect: () => this.confirmClearWebView() })
            OtherSettingsSwitch({ title: '阻止书源打开内置浏览器', detail: '开启后，书源无法通过 java.startBrowser 等接口弹出内置浏览器，等待网页结果的调用会直接报错', value: this.blockSourceBrowser, onChange: (value: boolean) => this.blockSourceBrowser = value })
            OtherSettingsSwitch({ title: '文字操作显示搜索', detail: '长按文字在操作菜单中显示阅读 · 搜索', value: this.processText, onChange: (value: boolean) => this.processText = value })
            OtherSettingsSwitch({ title: '记录日志', detail: '记录调试日志', value: this.recordLog, onChange: (value: boolean) => this.recordLog = value })
            OtherSettingsSwitch({ title: '记录堆转储', detail: '当应用发生OOM崩溃时保存堆转储', value: this.recordHeapDump, onChange: (value: boolean) => this.recordHeapDump = value })
          }
        }.width('100%').padding({ left: 16, right: 16, top: 4, bottom: 120 })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => {
        const shouldCollapse = Math.abs(this.settingsScroller.currentOffset().yOffset) > 70;
        if (this.collapsedHeader !== shouldCollapse) { this.collapsedHeader = shouldCollapse; }
      })
      }.width('100%').height('100%').backgroundColor('#111217')

      if (this.activeDialog.length > 0) {
        Stack({ alignContent: Alignment.Center }) {
          Row().width('100%').height('100%').backgroundColor('#99000000')
            .onClick(() => this.activeDialog = '')
          Column() {
            Text(this.activeDialog === 'battery' ? '后台保活与省电策略设置指引' : '清除 WebView 数据')
              .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
              .textAlign(TextAlign.Center).width('100%')
            Text(this.activeDialog === 'battery'
              ? '后台保活设置指引：\n1. 在系统设置中进入【电池 / 耗电管理】。\n2. 将后台行为设为【无限制】或【不优化】。\n3. 允许应用【后台活动】与【自启动】。'
              : '是否确认删除?')
              .fontSize(15).fontColor('#D8D9E0').lineHeight(24).margin({ top: 22, bottom: 24 })
            Row() {
              Text('取消').fontSize(15).fontColor('#AFC2FF').textAlign(TextAlign.Center)
                .layoutWeight(1).padding({ top: 14, bottom: 14 })
                .onClick(() => this.activeDialog = '')
              Text(this.activeDialog === 'battery' ? '设置' : '确认').fontSize(15).fontColor('#AFC2FF')
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
    }.width('100%').height('100%').backgroundColor('#111217')
      .bindSheet(this.activeSheet.length > 0, this.SettingsSheetContent(), {
        height: this.activeSheet === 'directLink' ? 620 : 300,
        dragBar: true,
        showClose: false,
        backgroundColor: '#1C1D23',
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
    }.backgroundColor('#25262D').fontColor('#E3E4E8').radius(16)
  }

  @Builder
  private SettingsSheetContent() {
    Column() {
      if (this.activeSheet === 'folderPicker') {
        Row() {
          Text('选择操作').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#E3E4E8').layoutWeight(1)
          Text('取消').fontSize(14).fontColor('#AFC2FF').onClick(() => this.activeSheet = '')
        }.width('100%').padding({ left: 18, right: 18, top: 8, bottom: 16 })
        Row() {
          AppGlyph({ name: 'profileFolder', glyphSize: 28, tint: '#AFC2FF' })
          Text('系统文件夹选择器').fontSize(15).fontColor('#E3E4E8').margin({ left: 12 })
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
            AppGlyph({ name: 'profileCheck', glyphSize: 20, tint: '#AFC2FF' })
          }.width(40).height(40).backgroundColor('#25262D').borderRadius(20)
            .onClick(() => this.onUnavailableAction('直链规则测试尚未迁移'))
          Text('直链上传配置').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
            .layoutWeight(1).textAlign(TextAlign.Center)
          Stack({ alignContent: Alignment.Center }) {
            AppGlyph({ name: 'more', glyphSize: 18, tint: '#D8D9E0' })
          }.width(40).height(40).backgroundColor('#25262D').borderRadius(20)
            .bindMenu(this.DirectLinkMenu, { placement: Placement.Bottom })
        }.width('100%').padding({ left: 18, right: 14, top: 8, bottom: 14 })
        Scroll() {
          Column() {
            OtherSettingsSheetField({ title: '上传 URL', value: this.directUploadUrl, onChange: (value: string) => this.directUploadUrl = value })
            OtherSettingsSheetField({ title: '下载 URL 规则', value: this.directDownloadRule, onChange: (value: string) => this.directDownloadRule = value })
            OtherSettingsSheetField({ title: '注释', value: this.directRuleSummary, onChange: (value: string) => this.directRuleSummary = value })
            Row() {
              Text('是否压缩').fontSize(15).fontColor('#E3E4E8').layoutWeight(1)
              Checkbox({ name: 'direct_link_compress' }).shape(CheckBoxShape.ROUNDED_SQUARE)
                .select(this.directCompress)
                .onChange((value: boolean) => this.directCompress = value)
            }.width('100%').padding({ left: 12, right: 12, top: 12, bottom: 12 })
          }.width('100%').padding({ left: 16, right: 16, top: 4 }).constraintSize({ minHeight: '100%' })
        }.layoutWeight(1).scrollBar(BarState.Off)
        Row() {
          Text('取消').fontSize(14).fontColor('#D8D9E0').layoutWeight(1).textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 12 }).backgroundColor('#25262D').borderRadius(20)
            .onClick(() => this.activeSheet = '')
          Text('确认').fontSize(14).fontColor('#111217').layoutWeight(1).textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 12 }).backgroundColor('#AFC2FF').borderRadius(20).margin({ left: 10 })
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
struct OtherSettingsSection {
  @Prop title: string = '';
  @BuilderParam content: () => void = this.emptyContent;
  @Builder emptyContent() {}

  build() {
    Column() {
      if (this.title.length > 0) {
        Text(this.title).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#AFC2FF')
          .alignSelf(ItemAlign.Start).padding({ left: 12, top: 14, bottom: 8 })
      }
      Column() {
        this.content()
      }.width('100%').backgroundColor('#1A1B21').borderRadius(16)
    }.width('100%').margin({ bottom: 8 })
  }
}

@Component
struct OtherSettingsDropdown {
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop option: string = '';
  @Prop options: string[] = [];
  onSelect: (value: string) => void = (_value: string) => {};

  @Builder
  private OptionMenu() {
    Menu() {
      ForEach(this.options, (value: string) => {
        MenuItem({ content: value }).height(48).onClick(() => this.onSelect(value))
      }, (value: string) => value)
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(16)
  }

  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(16).fontColor('#E3E4E8')
        if (this.detail.length > 0) { Text(this.detail).fontSize(12).fontColor('#AEB0BA').margin({ top: 3 }) }
        Text(this.option).fontSize(14).fontColor('#AFC2FF').margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      AppGlyph({ name: 'profileExpandMore', glyphSize: 22, tint: '#AEB0BA' })
    }.width('100%').padding({ left: 16, right: 14, top: 14, bottom: 14 })
      .bindMenu(this.OptionMenu, { placement: Placement.Bottom })
  }
}

@Component
struct OtherSettingsSwitch {
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop value: boolean = false;
  onChange: (value: boolean) => void = (_value: boolean) => {};

  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(16).fontColor('#E3E4E8')
        if (this.detail.length > 0) { Text(this.detail).fontSize(14).fontColor('#AEB0BA').margin({ top: 3 }) }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.value }).onChange((value: boolean) => this.onChange(value))
    }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }
}

@Component
struct OtherSettingsAction {
  @Prop title: string = '';
  @Prop detail: string = '';
  onSelect: () => void = () => {};

  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(16).fontColor('#E3E4E8')
        if (this.detail.length > 0) { Text(this.detail).fontSize(14).fontColor('#AEB0BA').margin({ top: 3 }) }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.reader_next')).width(18).height(18).fillColor('#AEB0BA')
    }.width('100%').padding({ left: 16, right: 14, top: 14, bottom: 14 }).onClick(() => this.onSelect())
  }
}

@Component
struct OtherSettingsInput {
  @Prop title: string = '';
  @Prop value: string = '';
  onConfirm: () => void = () => {};
  @State expanded: boolean = false;
  @State editValue: string = '';

  build() {
    Column() {
      Row() {
        Column() {
          Text(this.title).fontSize(16).fontColor('#E3E4E8')
          Text(this.value).fontSize(14).fontColor('#AFC2FF').margin({ top: 4 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        AppGlyph({ name: 'profileExpandMore', glyphSize: 22, tint: '#AEB0BA' })
      }.width('100%').padding({ left: 16, right: 14, top: 14, bottom: 14 }).onClick(() => {
        this.editValue = this.value;
        this.expanded = !this.expanded;
      })
      if (this.expanded) {
        Column() {
          TextInput({ text: this.editValue, placeholder: this.title }).onChange((value: string) => this.editValue = value)
            .fontSize(14).backgroundColor('#111217').borderRadius(8)
          Row() {
            Text('默认').fontSize(14).fontColor('#D8D9E0').onClick(() => this.expanded = false)
            Blank()
            Text('确定').fontSize(14).fontColor('#AFC2FF').onClick(() => {
              this.onConfirm();
              this.expanded = false;
            })
          }.width('100%').padding({ top: 12, bottom: 8 })
        }.padding({ left: 16, right: 16, bottom: 12 })
      }
    }.width('100%')
  }
}

@Component
struct OtherSettingsSheetField {
  @Prop title: string = '';
  @Prop value: string = '';
  onChange: (value: string) => void = (_value: string) => {};

  build() {
    Column() {
      Text(this.title).fontSize(13).fontColor('#B6B8C2').alignSelf(ItemAlign.Start).margin({ bottom: 6 })
      TextInput({ text: this.value, placeholder: this.title })
        .fontSize(15).fontColor('#E3E4E8').placeholderColor('#858792')
        .backgroundColor('#111217').borderRadius(8)
        .onChange((value: string) => this.onChange(value))
    }.width('100%').margin({ bottom: 14 })
  }
}
