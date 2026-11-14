import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';
import curves from '@ohos.curves';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { ThemeItemDivider } from '../components/ThemeItemDivider';
import { BackupCategoryOption, BackupEntryPreview, BackupPreview } from '../data/BackupRepository';
import { WebDavSettings, defaultWebDavSettings, cloneWebDavSettings } from '../lib/WebDavConfig';

/** 本地备份与恢复页面，文件格式与 Android 原项目兼容。 */
@Component
export struct AppBackupSettingsPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop localBookCount: number = 0;
  @Prop backupPreview: BackupPreview | undefined = undefined;
  @Prop restoredEntries: BackupEntryPreview[] = [];
  @Prop categoryOptions: BackupCategoryOption[] = [];
  @Prop backupIgnoreKeys: string[] = [];
  @Prop restoreIgnoreKeys: string[] = [];
  @Prop statusMessage: string = '';
  @Prop busy: boolean = false;
  @Prop webDavSettings: WebDavSettings = defaultWebDavSettings();
  @Prop webDavTesting: boolean = false;
  @Prop webDavConfigured: boolean = false;
  @Prop webDavBackupNames: string[] = [];
  onBack: () => void = () => {};
  onCreateBackup: () => void = () => {};
  onSelectRestore: () => void = () => {};
  onApplyRestore: () => void = () => {};
  onCancelRestore: () => void = () => {};
  onToggleBackupIgnore: (key: string, ignored: boolean) => void = (_key: string, _ignored: boolean) => {};
  onToggleRestoreIgnore: (key: string, ignored: boolean) => void = (_key: string, _ignored: boolean) => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  onWebDavSettingsChange: (settings: WebDavSettings) => void = () => {};
  onTestWebDav: () => void = () => {};
  onBackupToWebDav: () => void = () => {};
  onRestoreFromWebDav: () => void = () => {};
  /** 同时备份：本地保存后无条件上传，不看 backupSyncMode。 */
  onCreateBackupBoth: () => void = () => {};
  /** 选择本地备份目录（DocumentViewPicker 的 FOLDER 模式 + 持久授权）。 */
  onChooseBackupPath: () => void = () => {};
  /** 直接把应用内 backups 目录设为固定备份目录（目录选择器在部分设备上选不出可写目录时的等价入口）。 */
  onUseDownloadDir: () => void = () => {};
  /** 清掉已记住的备份目录，回到每次弹 picker。 */
  onClearBackupPath: () => void = () => {};
  /** 导入旧版本 myBookShelf.json。 */
  onImportOldShelf: () => void = () => {};
  @State activeSheet: string = '';
  @State inputTitle: string = '';
  @State inputDraft: string = '';
  @State collapsedHeader: boolean = false;
  @State inputKey: string = '';
  @State inputPassword: boolean = false;
  private backupScroller: Scroller = new Scroller();

  private openSettingInput(key: string, title: string, password: boolean): void {
    this.inputKey = key;
    this.inputTitle = title;
    this.inputDraft = '';
    this.inputPassword = password;
    this.activeSheet = 'input';
  }

  private describeSyncMode(mode: string): string {
    if (mode === 'local') { return '仅本地'; }
    if (mode === 'webdav') { return '仅 WebDAV'; }
    return '本地与 WebDAV';
  }

  private updateHeader(): void {
    const offset = this.backupScroller.currentOffset().yOffset;
    const shouldCollapse = offset > 70 ? true : offset < 24 ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      // 顶部折叠是位移，用弹簧收尾更自然；弹簧不吃 duration，删掉（写了也不生效）。
      this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.86) }, () => {
        this.collapsedHeader = shouldCollapse;
      });
    }
  }

  @StorageProp('themeCardRadius') themeCardRadius: number = 16;
  @StorageProp('themeCardBorderWidth') themeCardBorderWidth: number = 0;
  @StorageProp('themeCardBorderColor') themeCardBorderColor: string = '#6A6D77';
  @StorageProp('themeCardBackground') themeCardBackground: string = '';
  @StorageProp('themeContainerBackground') themeContainerBackground: string = '';
  build() {
    Column() {
      CollapsingSettingsHeader({ title: '备份与恢复', collapsed: this.collapsedHeader, onBack: () => this.onBack() })
      Scroll(this.backupScroller) {
        Column() {
          Text('WebDAV 设置').fontSize(14).fontColor(this.themeColorAccent)
            .alignSelf(ItemAlign.Start).margin({ left: 10, top: 12, bottom: 7 })
          Column() {
            BackupActionRow({ icon: 'cloud', title: 'WebDAV 服务器地址',
              detail: this.webDavSettings.url.trim().length === 0 ? '默认（坚果云）' : this.webDavSettings.url,
              onSelect: () => this.openSettingInput('url', 'WebDAV 服务器地址', false) })
            ThemeItemDivider()
            BackupActionRow({ icon: 'profileSource', title: 'WebDAV 账号',
              detail: this.webDavSettings.account.trim().length === 0 ? '账号与密码尚未配置' :
                (this.webDavSettings.password.length === 0 ? '仅填了账号，密码为空' : this.webDavSettings.account),
              onSelect: () => this.openSettingInput('account', 'WebDAV 账号', false) })
            ThemeItemDivider()
            BackupActionRow({ icon: 'profileSource', title: 'WebDAV 密码',
              detail: this.webDavSettings.password.length > 0 ? '已设置' : '未设置',
              onSelect: () => this.openSettingInput('password', 'WebDAV 密码', true) })
            ThemeItemDivider()
            BackupActionRow({ icon: 'folder', title: '子目录',
              detail: this.webDavSettings.dir.trim().length === 0 ? '（根目录）' : this.webDavSettings.dir,
              onSelect: () => this.openSettingInput('dir', '子目录', false) })
            ThemeItemDivider()
            BackupActionRow({ icon: 'profileSource', title: '设备名称',
              detail: this.webDavSettings.deviceName.trim().length === 0 ? '未设置' : this.webDavSettings.deviceName,
              onSelect: () => this.openSettingInput('deviceName', '设备名称', false) })
            ThemeItemDivider()
            BackupActionRow({ icon: 'cloudSync', title: '测试同步',
              detail: this.webDavTesting ? '正在测试…' : '检查 WebDAV 连接',
              disabled: this.webDavTesting, onSelect: () => this.onTestWebDav() })
            ThemeItemDivider()
            BackupPreviewSwitchRow({ title: '同步书籍进度',
              detail: '停止阅读时把进度写进 WebDAV 的 bookProgress 目录',
              checked: this.webDavSettings.syncBookProgress, onChange: (value: boolean) => {
                const next: WebDavSettings = cloneWebDavSettings(this.webDavSettings);
                next.syncBookProgress = value;
                this.onWebDavSettingsChange(next);
              } })
            ThemeItemDivider()
            if (this.webDavSettings.syncBookProgress) {
              BackupPreviewSwitchRow({ title: '增强进度同步',
                detail: '打开书时比对远端进度，比本地新就提示跳转',
                checked: this.webDavSettings.syncBookProgressPlus, onChange: (value: boolean) => {
                  const next: WebDavSettings = cloneWebDavSettings(this.webDavSettings);
                  next.syncBookProgressPlus = value;
                  this.onWebDavSettingsChange(next);
                } }).transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
            }
            ThemeItemDivider()
            BackupPreviewSwitchRow({ title: '自动检查新备份',
              detail: '启动时检查一次远端是否有更新的备份',
              checked: this.webDavSettings.autoCheckNewBackup, onChange: (value: boolean) => {
                const next: WebDavSettings = cloneWebDavSettings(this.webDavSettings);
                next.autoCheckNewBackup = value;
                this.onWebDavSettingsChange(next);
              } })
            ThemeItemDivider()
            BackupActionRow({ icon: 'settings', title: '备份同步模式',
              detail: this.describeSyncMode(this.webDavSettings.backupSyncMode), last: true,
              onSelect: () => this.activeSheet = 'syncMode' })
          }.width('100%').padding({ top: 2, bottom: 2 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)

          Text('备份与恢复').fontSize(14).fontColor(this.themeColorAccent)
            .alignSelf(ItemAlign.Start).margin({ left: 10, top: 12, bottom: 7 })
          Column() {
            BackupActionRow({ icon: 'folder', title: '备份路径',
              detail: this.webDavSettings.backupPath.trim().length === 0 ? '未选择（每次弹系统保存框）'
                : '已选目录，备份直接写入',
              onSelect: () => this.activeSheet = 'path', disabled: this.busy })
            ThemeItemDivider()
            BackupActionRow({
              icon: 'cloud', title: '备份',
              detail: `导出 Android 兼容 ZIP；当前书架 ${this.localBookCount} 本`,
              onSelect: () => this.activeSheet = 'backup', disabled: this.busy
            })
            ThemeItemDivider()
            BackupActionRow({
              icon: 'download', title: '恢复',
              detail: '选择 Android 阅读 ZIP，预览后导入可映射内容',
              onSelect: () => this.activeSheet = 'restore', disabled: this.busy
            })
            ThemeItemDivider()
            BackupActionRow({ icon: 'settings', title: '恢复排除项',
              detail: `当前跳过 ${this.restoreIgnoreKeys.length} 个数据类别`,
              onSelect: () => this.activeSheet = 'ignoreRestore', disabled: this.busy })
            ThemeItemDivider()
            BackupActionRow({ icon: 'settings', title: '备份排除项',
              detail: `当前排除 ${this.backupIgnoreKeys.length} 个数据类别`,
              onSelect: () => this.activeSheet = 'ignoreBackup', disabled: this.busy })
            ThemeItemDivider()
            BackupActionRow({ icon: 'download', title: '导入旧版数据',
              detail: '从 myBookShelf.json 迁移书架书目与进度',
              onSelect: () => this.onImportOldShelf(), disabled: this.busy })
            ThemeItemDivider()
            BackupPreviewSwitchRow({ title: '只保留最新备份',
              detail: '备份成功后删掉旧的 backup 文件（本地目录与 WebDAV 各清一次）',
              checked: this.webDavSettings.onlyLatestBackup, onChange: (value: boolean) => {
                const next: WebDavSettings = cloneWebDavSettings(this.webDavSettings);
                next.onlyLatestBackup = value;
                this.onWebDavSettingsChange(next);
              } })
          }.width('100%').padding({ top: 2, bottom: 2 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)

          if (this.busy) {
            Row() {
              LoadingProgress().width(18).height(18).color(this.themeColorAccent)
              Text('正在处理 Android 备份…').fontSize(14).fontColor(this.themeColorTextSecondary).margin({ left: 10 })
            }.width('100%').padding(14).margin({ top: 12 }).backgroundColor(this.themeColorSurfaceSecondary).borderRadius(12)
          }

          if (this.backupPreview !== undefined) {
            Column() {
              Text('Android ZIP 预览').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
              Text(`识别 ${this.backupPreview.entryCount} 个根条目；书架 ${this.backupPreview.bookCount} 本，其中本地书籍 ${this.backupPreview.localBookCount} 本`)
                .fontSize(14).fontColor(this.themeColorTextSecondary).lineHeight(20).margin({ top: 8 })
                Text(`ZIP 不含 TXT/EPUB 正文；${this.backupPreview.localBooksWithoutBody} 本本地书未匹配到当前书架中的可读正文。`)
                .fontSize(13).fontColor(this.themeColorTextTertiary).lineHeight(18).margin({ top: 5 })
              Column() {
                ForEach(this.backupPreview.entries, (entry: BackupEntryPreview) => {
                  Row() {
                    Text(entry.name).fontSize(12).fontColor(this.themeColorTextSecondary).layoutWeight(1)
                    Text(entry.recordCount >= 0 ? `${entry.recordCount} 条` : '配置文件')
                      .fontSize(12).fontColor(this.themeColorTextTertiary)
                  }.padding({ top: 5, bottom: 5 })
                }, (entry: BackupEntryPreview) => entry.name)
              }.width('100%').margin({ top: 8 })
              Row() {
                Button('取消').layoutWeight(1).height(42).fontColor(this.themeColorTextSecondary)
                  .backgroundColor('#292B33').onClick(() => this.onCancelRestore())
                Button('导入此 ZIP').layoutWeight(1).height(42).fontColor(this.themeColorSurfacePrimary)
                  .backgroundColor(this.themeColorAccent).margin({ left: 10 }).onClick(() => this.onApplyRestore())
              }.width('100%').margin({ top: 14 })
            }.width('100%').padding(15).margin({ top: 12 }).backgroundColor(this.themeColorSurfaceSecondary).borderRadius(14)
          }

          if (this.statusMessage.length > 0) {
            Text(this.statusMessage).fontSize(14).fontColor(this.themeColorAccent).lineHeight(20)
              .width('100%').padding(13).margin({ top: 12 }).backgroundColor(this.themeColorSurfaceSecondary).borderRadius(12)
          }

          if (this.restoredEntries.length > 0) {
            Column() {
              Text('已恢复的 Android 数据壳').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
              Text('书源、规则、历史等原始 JSON/XML 已保留，可继续导出；尚未接入的功能不会执行其中的脚本或网络请求。')
                .fontSize(13).fontColor(this.themeColorTextTertiary).lineHeight(19).margin({ top: 6, bottom: 8 })
              ForEach(this.restoredEntries, (entry: BackupEntryPreview) => {
                Row() {
                  Text(entry.name).fontSize(12).fontColor(this.themeColorTextSecondary).layoutWeight(1)
                  Text(entry.recordCount >= 0 ? `${entry.recordCount} 条` : '配置文件')
                    .fontSize(12).fontColor(this.themeColorAccent)
                }.padding({ top: 5, bottom: 5 })
              }, (entry: BackupEntryPreview) => entry.name)
            }.width('100%').padding(15).margin({ top: 12 })
              .backgroundColor(this.themeColorSurfaceSecondary).borderRadius(14)
          }

          Text('兼容说明').fontSize(14).fontColor(this.themeColorAccent)
            .alignSelf(ItemAlign.Start).margin({ left: 10, top: 16, bottom: 7 })
          Text('备份沿用 Android 原项目的 ZIP 根目录 JSON/XML 条目和文件名，不增加自定义封装。当前支持的数据会映射到本地书架与阅读设置；尚未迁移的书源、规则、RSS、历史等条目只原样保留，不能在 HarmonyOS 中使用，也不会执行其中的脚本。Android ZIP 不包含 TXT/EPUB 正文。')
            .fontSize(14).fontColor(this.themeColorTextSecondary).lineHeight(20)
            .width('100%').padding(15).backgroundColor(this.themeColorSurfaceSecondary).borderRadius(14)
        }.padding({ left: 16, right: 16, top: 8, bottom: 20 })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      .bindSheet(this.activeSheet.length > 0, this.backupSheetContent(), {
        height: 520,
        dragBar: true,
        showClose: false,
        backgroundColor: this.themeColorSurfaceSecondary,
        onDisappear: () => this.activeSheet = ''
      })
  }

  @Builder
  private backupSheetContent() {
    Column() {
      Row() {
        Text(this.activeSheet === 'backup' ? '备份' : this.activeSheet === 'restore' ? '恢复' :
          this.activeSheet === 'ignoreBackup' ? '备份排除项' : this.activeSheet === 'ignoreRestore' ?
          '恢复排除项' : this.activeSheet === 'path' ? '备份路径' : this.activeSheet === 'syncMode' ?
          '备份同步模式' : this.inputTitle)
          .fontSize(20).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Text('关闭').fontSize(14).fontColor(this.themeColorAccent).onClick(() => this.activeSheet = '')
      }.width('100%').padding({ left: 18, right: 18, top: 12, bottom: 14 })
      if (this.activeSheet === 'backup') {
        BackupSheetOption({ title: '备份到本地', detail: '创建 Android 兼容 ZIP',
          onSelect: () => { this.activeSheet = ''; this.onCreateBackup(); } })
        BackupSheetOption({ title: '备份到 WebDAV', detail: '仅上传到 WebDAV',
          onSelect: () => { this.activeSheet = ''; this.onBackupToWebDav(); } })
        BackupSheetOption({ title: '同时备份到本地和 WebDAV', detail: '先保存到本地，再上传到 WebDAV',
          onSelect: () => { this.activeSheet = ''; this.onCreateBackupBoth(); } })
      } else if (this.activeSheet === 'restore') {
        BackupSheetOption({ title: '从本地恢复', detail: '选择 Android 阅读 ZIP 并预览',
          onSelect: () => { this.activeSheet = ''; this.onSelectRestore(); } })
        BackupSheetOption({ title: '从 WebDAV 恢复',
          detail: !this.webDavConfigured ? '请先填写账号与密码' :
            (this.webDavBackupNames.length > 0 ? `最近：${this.webDavBackupNames[0] ?? ''}` : '尚未发现远端备份'),
          disabled: !this.webDavConfigured,
          onSelect: () => { this.activeSheet = ''; this.onRestoreFromWebDav(); } })
      } else if (this.activeSheet === 'ignoreBackup' || this.activeSheet === 'ignoreRestore') {
        Scroll() {
          BackupIgnoreList({
            options: this.categoryOptions,
            ignoredKeys: this.activeSheet === 'ignoreBackup' ? this.backupIgnoreKeys : this.restoreIgnoreKeys,
            onToggle: (key: string, ignored: boolean) => {
              if (this.activeSheet === 'ignoreBackup') { this.onToggleBackupIgnore(key, ignored); }
              else { this.onToggleRestoreIgnore(key, ignored); }
            }
          })
        }.height(420).scrollBar(BarState.Off)
      } else if (this.activeSheet === 'input') {
        TextInput({ placeholder: this.inputTitle, text: this.inputDraft })
          .fontSize(16).fontColor(this.themeColorTextPrimary).backgroundColor('#292B33').borderRadius(12)
          .type(this.inputPassword ? InputType.Password : InputType.Normal)
          .margin({ left: 18, right: 18, bottom: 16 })
          .onChange((value: string) => this.inputDraft = value)
        Button('完成').margin({ top: 18 }).onClick(() => {
          const next: WebDavSettings = cloneWebDavSettings(this.webDavSettings);
          if (this.inputKey === 'url') { next.url = this.inputDraft.trim(); }
          else if (this.inputKey === 'account') { next.account = this.inputDraft.trim(); }
          else if (this.inputKey === 'password') { next.password = this.inputDraft; }
          else if (this.inputKey === 'dir') { next.dir = this.inputDraft.trim(); }
          else if (this.inputKey === 'deviceName') { next.deviceName = this.inputDraft.trim(); }
          this.onWebDavSettingsChange(next);
          this.inputDraft = '';
          this.activeSheet = '';
        })
      } else if (this.activeSheet === 'path') {
        BackupSheetOption({ title: '选择系统目录',
          detail: this.webDavSettings.backupPath.trim().length === 0 ? '当前未选择，备份时弹系统保存框'
            : '重新选一个目录并记住授权',
          onSelect: () => { this.activeSheet = ''; this.onChooseBackupPath(); } })
        BackupSheetOption({ title: '使用应用备份目录',
          detail: '固定写入应用内 backups，之后不再弹保存框',
          onSelect: () => { this.activeSheet = ''; this.onUseDownloadDir(); } })
        BackupSheetOption({ title: '清除已选目录', detail: '回到每次弹系统保存框',
          disabled: this.webDavSettings.backupPath.trim().length === 0,
          onSelect: () => { this.activeSheet = ''; this.onClearBackupPath(); } })
      } else if (this.activeSheet === 'syncMode') {
        BackupSheetOption({ title: '仅本地',
          detail: this.webDavSettings.backupSyncMode === 'local' ? '当前：仅本地' : '只保存到用户选择的位置',
          onSelect: () => {
            const next: WebDavSettings = cloneWebDavSettings(this.webDavSettings);
            next.backupSyncMode = 'local';
            this.onWebDavSettingsChange(next);
            this.activeSheet = '';
          } })
        BackupSheetOption({ title: '本地与 WebDAV',
          detail: this.webDavSettings.backupSyncMode === 'both' ? '当前：本地与 WebDAV' : '本地保存后顺手上传同一份 ZIP',
          onSelect: () => {
            const next: WebDavSettings = cloneWebDavSettings(this.webDavSettings);
            next.backupSyncMode = 'both';
            this.onWebDavSettingsChange(next);
            this.activeSheet = '';
          } })
        BackupSheetOption({ title: '仅 WebDAV',
          detail: this.webDavSettings.backupSyncMode === 'webdav' ? '当前：仅 WebDAV' : '只上传到 WebDAV，不保存本地文件',
          onSelect: () => {
            const next: WebDavSettings = cloneWebDavSettings(this.webDavSettings);
            next.backupSyncMode = 'webdav';
            this.onWebDavSettingsChange(next);
            this.activeSheet = '';
          } })
      }
    }.width('100%').padding({ bottom: 24 })
  }
}



@Component
struct BackupSheetOption {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop disabled: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Column() {
      Text(this.title).fontSize(16).fontColor(this.disabled ? this.themeColorTextTertiary : this.themeColorTextSecondary)
      Text(this.detail).fontSize(13).fontColor(this.themeColorTextTertiary).margin({ top: 4 })
    }.width('calc(100% - 32vp)').padding(16).alignItems(HorizontalAlign.Start)
      .opacity(this.disabled ? 0.5 : 1)
      .backgroundColor('#292B33').borderRadius(14).margin({ left: 16, right: 16, bottom: 8 })
      .onClick(() => { if (!this.disabled) { this.onSelect(); } })
  }
}

@Component
struct BackupPreviewSwitchRow {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop checked: boolean = false;
  onChange: (checked: boolean) => void = (_checked: boolean) => {};
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(16).fontColor(this.themeColorTextSecondary)
        Text(this.detail).fontSize(13).fontColor(this.themeColorTextTertiary).margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.checked })
        .onChange((checked: boolean) => this.onChange(checked))
    }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }
}

@Component
struct BackupActionRow {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop icon: AppGlyphName = 'folder';
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop last: boolean = false;
  @Prop disabled: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Column() {
      Row() {
        AppGlyph({ name: this.icon, glyphSize: 20, tint: this.disabled ? '#656873' : this.themeColorAccent }).width(36)
        Column() {
          Text(this.title).fontSize(16).fontColor(this.disabled ? this.themeColorTextTertiary : this.themeColorTextSecondary)
          Text(this.detail).fontSize(14).fontColor(this.themeColorTextTertiary).margin({ top: 4 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Image($r('app.media.reader_next')).width(18).height(18).fillColor(this.themeColorTextTertiary)
      }.padding({ left: 15, right: 15, top: 16, bottom: 16 }).onClick(() => {
        if (!this.disabled) { this.onSelect(); }
      })
      if (!this.last) { Row().height(1).width('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary)).margin({ left: 51, right: 12 }) }
    }.width('100%')
  }
}

@Component
struct BackupIgnoreList {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @Prop options: BackupCategoryOption[] = [];
  @Prop ignoredKeys: string[] = [];
  onToggle: (key: string, ignored: boolean) => void = (_key: string, _ignored: boolean) => {};
  build() {
    Column() {
      ForEach(this.options, (option: BackupCategoryOption) => {
        Row() {
          Column() {
            Text(option.title).fontSize(14).fontColor(this.themeColorTextSecondary)
            Text(option.files.join('、')).fontSize(11).fontColor('#858792').margin({ top: 3 })
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.ignoredKeys.includes(option.key) })
            .onChange((ignored: boolean) => this.onToggle(option.key, ignored))
        }.width('100%').padding({ left: 12, right: 12, top: 10, bottom: 10 })
      }, (option: BackupCategoryOption) => option.key)
    }.width('100%').margin({ top: 6 }).padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor(this.themeColorSurfaceSecondary).borderRadius(14)
  }
}
