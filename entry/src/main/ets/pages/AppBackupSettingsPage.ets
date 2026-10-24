import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { BackupCategoryOption, BackupEntryPreview, BackupPreview } from '../data/BackupRepository';

/** 本地备份与恢复页面，文件格式与 Android 原项目兼容。 */
@Component
export struct AppBackupSettingsPage {
  @Prop localBookCount: number = 0;
  @Prop backupPreview: BackupPreview | undefined = undefined;
  @Prop restoredEntries: BackupEntryPreview[] = [];
  @Prop categoryOptions: BackupCategoryOption[] = [];
  @Prop backupIgnoreKeys: string[] = [];
  @Prop restoreIgnoreKeys: string[] = [];
  @Prop statusMessage: string = '';
  @Prop busy: boolean = false;
  onBack: () => void = () => {};
  onCreateBackup: () => void = () => {};
  onSelectRestore: () => void = () => {};
  onApplyRestore: () => void = () => {};
  onCancelRestore: () => void = () => {};
  onToggleBackupIgnore: (key: string, ignored: boolean) => void = (_key: string, _ignored: boolean) => {};
  onToggleRestoreIgnore: (key: string, ignored: boolean) => void = (_key: string, _ignored: boolean) => {};
  @State showBackupIgnore: boolean = false;
  @State showRestoreIgnore: boolean = false;

  build() {
    Column() {
      BackupHeader({ onBack: () => this.onBack() })
      Scroll() {
        Column() {
          Text('本地备份').fontSize(14).fontColor('#AFC2FF')
            .alignSelf(ItemAlign.Start).margin({ left: 10, top: 12, bottom: 7 })
          Column() {
            BackupActionRow({
              icon: 'cloud', title: '创建本地备份',
              detail: `导出 Android 兼容 ZIP；当前书架 ${this.localBookCount} 本`,
              onSelect: () => this.onCreateBackup(), disabled: this.busy
            })
            BackupActionRow({
              icon: 'download', title: '从本地备份恢复',
              detail: '选择 Android 阅读 ZIP，预览后导入可映射内容', last: true,
              onSelect: () => this.onSelectRestore(), disabled: this.busy
            })
          }.width('100%').padding({ top: 2, bottom: 2 }).backgroundColor('#1A1B21').borderRadius(14)

          BackupActionRow({
            icon: 'settings', title: '备份排除项',
            detail: `当前排除 ${this.backupIgnoreKeys.length} 个数据类别`,
            onSelect: () => this.showBackupIgnore = !this.showBackupIgnore,
            disabled: this.busy
          }).width('100%').margin({ top: 12 }).backgroundColor('#1A1B21').borderRadius(14)
          if (this.showBackupIgnore) {
            BackupIgnoreList({
              options: this.categoryOptions,
              ignoredKeys: this.backupIgnoreKeys,
              onToggle: (key: string, ignored: boolean) => this.onToggleBackupIgnore(key, ignored)
            })
          }

          BackupActionRow({
            icon: 'settings', title: '恢复排除项',
            detail: `当前跳过 ${this.restoreIgnoreKeys.length} 个数据类别`,
            onSelect: () => this.showRestoreIgnore = !this.showRestoreIgnore,
            disabled: this.busy
          }).width('100%').margin({ top: 8 }).backgroundColor('#1A1B21').borderRadius(14)
          if (this.showRestoreIgnore) {
            BackupIgnoreList({
              options: this.categoryOptions,
              ignoredKeys: this.restoreIgnoreKeys,
              onToggle: (key: string, ignored: boolean) => this.onToggleRestoreIgnore(key, ignored)
            })
          }

          if (this.busy) {
            Row() {
              LoadingProgress().width(18).height(18).color('#AFC2FF')
              Text('正在处理 Android 备份…').fontSize(14).fontColor('#D8D9E0').margin({ left: 10 })
            }.width('100%').padding(14).margin({ top: 12 }).backgroundColor('#1A1B21').borderRadius(12)
          }

          if (this.backupPreview !== undefined) {
            Column() {
              Text('Android ZIP 预览').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
              Text(`识别 ${this.backupPreview.entryCount} 个根条目；书架 ${this.backupPreview.bookCount} 本，其中本地书籍 ${this.backupPreview.localBookCount} 本`)
                .fontSize(14).fontColor('#D8D9E0').lineHeight(20).margin({ top: 8 })
                Text(`ZIP 不含 TXT/EPUB 正文；${this.backupPreview.localBooksWithoutBody} 本本地书未匹配到当前书架中的可读正文。`)
                .fontSize(13).fontColor('#92949E').lineHeight(18).margin({ top: 5 })
              Column() {
                ForEach(this.backupPreview.entries, (entry: BackupEntryPreview) => {
                  Row() {
                    Text(entry.name).fontSize(12).fontColor('#D8D9E0').layoutWeight(1)
                    Text(entry.recordCount >= 0 ? `${entry.recordCount} 条` : '配置文件')
                      .fontSize(12).fontColor('#92949E')
                  }.padding({ top: 5, bottom: 5 })
                }, (entry: BackupEntryPreview) => entry.name)
              }.width('100%').margin({ top: 8 })
              Row() {
                Button('取消').layoutWeight(1).height(42).fontColor('#D8D9E0')
                  .backgroundColor('#292B33').onClick(() => this.onCancelRestore())
                Button('导入此 ZIP').layoutWeight(1).height(42).fontColor('#111217')
                  .backgroundColor('#AFC2FF').margin({ left: 10 }).onClick(() => this.onApplyRestore())
              }.width('100%').margin({ top: 14 })
            }.width('100%').padding(15).margin({ top: 12 }).backgroundColor('#1A1B21').borderRadius(14)
          }

          if (this.statusMessage.length > 0) {
            Text(this.statusMessage).fontSize(14).fontColor('#AFC2FF').lineHeight(20)
              .width('100%').padding(13).margin({ top: 12 }).backgroundColor('#1A1B21').borderRadius(12)
          }

          if (this.restoredEntries.length > 0) {
            Column() {
              Text('已恢复的 Android 数据壳').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
              Text('书源、规则、历史等原始 JSON/XML 已保留，可继续导出；尚未接入的功能不会执行其中的脚本或网络请求。')
                .fontSize(13).fontColor('#92949E').lineHeight(19).margin({ top: 6, bottom: 8 })
              ForEach(this.restoredEntries, (entry: BackupEntryPreview) => {
                Row() {
                  Text(entry.name).fontSize(12).fontColor('#D8D9E0').layoutWeight(1)
                  Text(entry.recordCount >= 0 ? `${entry.recordCount} 条` : '配置文件')
                    .fontSize(12).fontColor('#AFC2FF')
                }.padding({ top: 5, bottom: 5 })
              }, (entry: BackupEntryPreview) => entry.name)
            }.width('100%').padding(15).margin({ top: 12 })
              .backgroundColor('#1A1B21').borderRadius(14)
          }

          Text('兼容说明').fontSize(14).fontColor('#AFC2FF')
            .alignSelf(ItemAlign.Start).margin({ left: 10, top: 16, bottom: 7 })
          Text('备份沿用 Android 原项目的 ZIP 根目录 JSON/XML 条目和文件名，不增加自定义封装。当前支持的数据会映射到本地书架与阅读设置；尚未迁移的书源、规则、RSS、历史等条目只原样保留，不能在 HarmonyOS 中使用，也不会执行其中的脚本。Android ZIP 不包含 TXT/EPUB 正文。')
            .fontSize(14).fontColor('#D8D9E0').lineHeight(20)
            .width('100%').padding(15).backgroundColor('#1A1B21').borderRadius(14)
        }.padding({ left: 16, right: 16, top: 8, bottom: 20 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct BackupHeader {
  onBack: () => void = () => {};
  build() {
    Row() {
      Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
        .width(36).onClick(() => this.onBack())
      Column() {
        Text('备份与恢复').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
        Text('Android 兼容 ZIP').fontSize(15).fontColor('#92949E').margin({ top: 3 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.width('100%').padding({ left: 12, right: 10, top: 11, bottom: 9 })
  }
}

@Component
struct BackupActionRow {
  @Prop icon: AppGlyphName = 'folder';
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop last: boolean = false;
  @Prop disabled: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Column() {
      Row() {
        AppGlyph({ name: this.icon, glyphSize: 20, tint: this.disabled ? '#656873' : '#AFC2FF' }).width(36)
        Column() {
          Text(this.title).fontSize(16).fontColor(this.disabled ? '#92949E' : '#D8D9E0')
          Text(this.detail).fontSize(14).fontColor('#92949E').margin({ top: 4 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Image($r('app.media.reader_next')).width(18).height(18).fillColor('#92949E')
      }.padding({ left: 15, right: 15, top: 16, bottom: 16 }).onClick(() => {
        if (!this.disabled) { this.onSelect(); }
      })
      if (!this.last) { Row().height(1).width('100%').backgroundColor('#111217').margin({ left: 51, right: 12 }) }
    }.width('100%')
  }
}

@Component
struct BackupIgnoreList {
  @Prop options: BackupCategoryOption[] = [];
  @Prop ignoredKeys: string[] = [];
  onToggle: (key: string, ignored: boolean) => void = (_key: string, _ignored: boolean) => {};
  build() {
    Column() {
      ForEach(this.options, (option: BackupCategoryOption) => {
        Row() {
          Column() {
            Text(option.title).fontSize(14).fontColor('#D8D9E0')
            Text(option.files.join('、')).fontSize(11).fontColor('#858792').margin({ top: 3 })
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.ignoredKeys.includes(option.key) })
            .onChange((ignored: boolean) => this.onToggle(option.key, ignored))
        }.width('100%').padding({ left: 12, right: 12, top: 10, bottom: 10 })
      }, (option: BackupCategoryOption) => option.key)
    }.width('100%').margin({ top: 6 }).padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor('#1A1B21').borderRadius(14)
  }
}
