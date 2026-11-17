import curves from '@ohos.curves';
import { fileIo } from '@kit.CoreFileKit';
import { UiSection } from '../components/settings/UiSection';
import { UiAction } from '../components/settings/UiAction';
import { UiSlider } from '../components/settings/UiSlider';
import { UiSwitch } from '../components/settings/UiSwitch';
import { UiInput } from '../components/settings/UiInput';
import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';
import { Book } from '../model/Book';
import { BookRepository } from '../data/BookRepository';
import { CacheSettings, DEFAULT_CACHE_SETTINGS, copyCacheSettings, CacheSettingsRepository } from '../data/CacheSettingsRepository';
import { RdbStore } from '../data/RdbStore';

@Component
export struct AppDownloadCacheSettingsPage {
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#858792';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  /** 清理缓存要逐本丢掉应用内导入副本（:484）；由 Index 挂载处传入。 */
  @Prop books: Book[] = [];
  /** 7 个滑块与 1 个开关都从偏好读进来，改动即落盘。 */
  @State cacheSettings: CacheSettings = CacheSettingsRepository.get();
  @State collapsedHeader: boolean = false;
  /** 封面缓存目录大小（MB 文案），进页与清理后各算一次，由 build 直接读取。 */
  @State coverCacheSize: string = '0.0 MB';
  private settingsScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    // 启动恢复是异步的，进页时再取一次，保证滑块显示的是偏好里的当前值。
    this.cacheSettings = CacheSettingsRepository.get();
    this.coverCacheSize = this.computeCoverCacheSizeMb();
  }

  private saveSettings(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    CacheSettingsRepository.save(context, this.cacheSettings);
  }

  /**
   * 封面缓存真算：本地封面落盘在 ${filesDir}/covers（BookRepository / EpubRepository
   * / PdfRepository / UmdRepository 都在写），遍历目录累加字节数，不显示假数字。
   */
  private computeCoverCacheSizeMb(): string {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return '0.0 MB'; }
    try {
      const dir = `${context.filesDir}/covers`;
      if (!fileIo.accessSync(dir)) { return '0.0 MB'; }
      let total = 0;
      const names = fileIo.listFileSync(dir);
      for (const name of names) {
        try { total += fileIo.statSync(`${dir}/${name}`).size; } catch (error) { /* 跳过已消失的文件 */ }
      }
      return `${(total / 1024 / 1024).toFixed(1)} MB`;
    } catch (error) {
      return '0.0 MB';
    }
  }

  /** 封面缓存二次确认，确认后清空 covers 目录下所有文件。 */
  private confirmClearCoverCache(): void {
    this.getUIContext().showAlertDialog({
      title: '封面缓存',
      message: '是否确认删除?',
      autoCancel: true,
      primaryButton: { value: '删除', action: () => { this.doClearCoverCache(); } },
      secondaryButton: { value: '取消', fontColor: this.themeColorTextTertiary, action: () => {} }
    });
  }

  private doClearCoverCache(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      const dir = `${context.filesDir}/covers`;
      if (fileIo.accessSync(dir)) {
        const names = fileIo.listFileSync(dir);
        for (const name of names) {
          try { fileIo.unlinkSync(`${dir}/${name}`); } catch (error) { /* 单文件失败不打断整批 */ }
        }
      }
      this.coverCacheSize = this.computeCoverCacheSizeMb();
      this.onUnavailableAction('封面缓存已清理');
    } catch (error) {
      this.onUnavailableAction('封面缓存清理失败');
    }
  }

  /** 清理缓存二次确认（上游 sure_del）。 */
  private confirmClearBookCache(): void {
    this.getUIContext().showAlertDialog({
      title: '清理缓存',
      message: '是否确认删除?',
      autoCancel: true,
      primaryButton: { value: '删除', action: () => { this.clearBookCache(); } },
      secondaryButton: { value: '取消', fontColor: this.themeColorTextTertiary, action: () => {} }
    });
  }

  /** 压缩数据库二次确认（上游 sure）。 */
  private confirmVacuumDatabase(): void {
    this.getUIContext().showAlertDialog({
      title: '压缩数据库',
      message: '确认',
      autoCancel: true,
      primaryButton: { value: '确认', action: () => { this.vacuumDatabase(); } },
      secondaryButton: { value: '取消', fontColor: this.themeColorTextTertiary, action: () => {} }
    });
  }

  /** 清理缓存：逐本删应用内导入副本 + 清内存章节行与当前书正文缓存；不删书目。 */
  private clearBookCache(): void {
    this.books.forEach((book: Book) => {
      try { BookRepository.discardImportedCopy(book); } catch (error) {
        // 单本失败不打断整批；正文缺失的书下次可从原文件恢复。
      }
    });
    BookRepository.clearChapterCache();
    this.onUnavailableAction('已清理应用内正文副本与章节缓存');
  }

  private async vacuumDatabase(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { this.onUnavailableAction('无法访问数据库'); return; }
    try {
      const store = await RdbStore.getStore(context);
      await store.executeSql('VACUUM');
      this.onUnavailableAction('数据库已压缩');
    } catch (error) {
      this.onUnavailableAction('数据库压缩失败');
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
    Column() {
      CollapsingSettingsHeader({ title: '下载与缓存', collapsed: this.collapsedHeader, onBack: () => this.onBack() })

      Scroll(this.settingsScroller) {
        Column() {
          UiSection({ title: 'HTTP缓存' }) {
            UiAction({showDivider: false, title: '封面缓存', detail: `当前 ${this.coverCacheSize}`, onSelect: () => this.confirmClearCoverCache() })
          }
          UiSection({ title: '下载' }) {
            UiSlider({ title: '更新和搜索线程', detail: '控制更新和搜索线程的并发数量。数值越高越不稳定', value: this.cacheSettings.updateSearchThreads, minValue: 1, maxValue: 256, onChange: (v: number) => { this.cacheSettings.updateSearchThreads = v; this.saveSettings(); } })
            UiSlider({ title: '书籍缓存下载线程', detail: '控制离线缓存章节下载的并发数量。数值越高越不稳定', value: this.cacheSettings.bookDownloadThreads, minValue: 1, maxValue: 8, onChange: (v: number) => { this.cacheSettings.bookDownloadThreads = v; this.saveSettings(); } })
            UiSlider({ title: '向后预下载', value: this.cacheSettings.preloadBehind, minValue: 0, maxValue: 100, onChange: (v: number) => { this.cacheSettings.preloadBehind = v; this.saveSettings(); } })
            UiSlider({ title: '向前预下载', value: this.cacheSettings.preloadAhead, minValue: 0, maxValue: 100, onChange: (v: number) => { this.cacheSettings.preloadAhead = v; this.saveSettings(); } })
            // 上游无此字段，本地架构差异（整本正文缓存策略）引入；detail 为本地可读说明。
            UiSlider({showDivider: false, title: '整本正文内存缓存上限', detail: '单位 MB；超过就不缓存整本正文', value: this.cacheSettings.bookContentCacheMb, minValue: 1, maxValue: 512, onChange: (v: number) => { this.cacheSettings.bookContentCacheMb = v; this.saveSettings(); } })
          }
          UiSection({ title: '图片缓存' }) {
            UiSlider({ title: '图片绘制缓存', detail: `当前最大缓存 ${this.cacheSettings.imageDrawCacheMb} MB`, value: this.cacheSettings.imageDrawCacheMb, minValue: 1, maxValue: 2047, onChange: (v: number) => { this.cacheSettings.imageDrawCacheMb = v; this.saveSettings(); } })
            UiSlider({showDivider: false, title: '漫画保留数量', detail: `保留已读章节数量 ${this.cacheSettings.comicKeepCount}`, value: this.cacheSettings.comicKeepCount, minValue: 0, maxValue: 100, onChange: (v: number) => { this.cacheSettings.comicKeepCount = v; this.saveSettings(); } })
          }
          UiSection({ title: '网络' }) {
            UiInput({showDivider: false,
              title: '用户代理', value: this.cacheSettings.userAgent, defaultValue: '',
              onConfirm: (v: string) => { this.cacheSettings.userAgent = v; this.saveSettings(); }
            })
            // 上游 pref_cronet_summary「使用 Cronet 网络组件」：Cronet 是 Chromium 网络栈，鸿蒙平台无此能力，整行删。
          }
          UiSection({ title: '高级' }) {
            UiAction({ title: '清理缓存', detail: '清除已下载书籍和字体缓存', onSelect: () => this.confirmClearBookCache() })
            UiAction({showDivider: false, title: '压缩数据库', detail: '减小数据库文件的大小', onSelect: () => this.confirmVacuumDatabase() })
          }
        }.width('100%').padding({ top: 6 })
      }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
  }
}

