import curves from '@ohos.curves';
import { UiSection } from '../components/settings/UiSection';
import { UiAction } from '../components/settings/UiAction';
import { UiSlider } from '../components/settings/UiSlider';
import { UiSwitch } from '../components/settings/UiSwitch';
import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';
import { Book } from '../model/Book';
import { BookRepository } from '../data/BookRepository';
import { CacheSettings, DEFAULT_CACHE_SETTINGS, copyCacheSettings, CacheSettingsRepository } from '../data/CacheSettingsRepository';
import { RdbStore } from '../data/RdbStore';

@Component
export struct AppDownloadCacheSettingsPage {
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  /** 清理缓存要逐本丢掉应用内导入副本（:484）；由 Index 挂载处传入。 */
  @Prop books: Book[] = [];
  /** 6 个滑块、1 个开关与正文缓存上限都从偏好读进来，改动即落盘。 */
  @State cacheSettings: CacheSettings = CacheSettingsRepository.get();
  @State collapsedHeader: boolean = false;
  private settingsScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    // 启动恢复是异步的，进页时再取一次，保证滑块显示的是偏好里的当前值。
    this.cacheSettings = CacheSettingsRepository.get();
  }

  private saveSettings(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    CacheSettingsRepository.save(context, this.cacheSettings);
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
          UiSection({ title: 'HTTP 缓存' }) {
            UiAction({ title: '封面缓存', detail: '本地书籍封面即时生成', onSelect: () => this.onUnavailableAction('本地书籍封面即时生成，无独立缓存') })
            UiAction({showDivider: false,  title: '漫画缓存', detail: '本地无漫画形态', onSelect: () => this.onUnavailableAction('本地书籍封面即时生成，无独立缓存') })
          }
          UiSection({ title: '下载设置' }) {
            UiSlider({ title: '更新和搜索线程', detail: '控制请求并发数量', value: this.cacheSettings.updateSearchThreads, minValue: 1, maxValue: 256, onChange: (v: number) => { this.cacheSettings.updateSearchThreads = v; this.saveSettings(); } })
            UiSlider({ title: '书籍缓存下载线程', detail: '并发越高越不稳定', value: this.cacheSettings.bookDownloadThreads, minValue: 1, maxValue: 8, onChange: (v: number) => { this.cacheSettings.bookDownloadThreads = v; this.saveSettings(); } })
            UiSlider({ title: '向后预下载', detail: '预先下载后续章节', value: this.cacheSettings.preloadBehind, minValue: 0, maxValue: 100, onChange: (v: number) => { this.cacheSettings.preloadBehind = v; this.saveSettings(); } })
            UiSlider({ title: '向前预下载', detail: '预先下载前面的章节', value: this.cacheSettings.preloadAhead, minValue: 0, maxValue: 100, onChange: (v: number) => { this.cacheSettings.preloadAhead = v; this.saveSettings(); } })
            UiSlider({showDivider: false,  title: '整本正文内存缓存上限', detail: '单位 MB；超过就不缓存整本正文', value: this.cacheSettings.bookContentCacheMb, minValue: 1, maxValue: 512, onChange: (v: number) => { this.cacheSettings.bookContentCacheMb = v; this.saveSettings(); } })
          }
          UiSection({ title: '图片缓存' }) {
            UiSlider({ title: '图片绘制缓存', detail: '最大缓存大小（MB）', value: this.cacheSettings.imageDrawCacheMb, minValue: 1, maxValue: 2047, onChange: (v: number) => { this.cacheSettings.imageDrawCacheMb = v; this.saveSettings(); } })
            UiSlider({showDivider: false,  title: '漫画保留数量', detail: '保留已读章节数量', value: this.cacheSettings.comicKeepCount, minValue: 0, maxValue: 100, onChange: (v: number) => { this.cacheSettings.comicKeepCount = v; this.saveSettings(); } })
          }
          UiSection({ title: '网络' }) {
            CacheSettingsInput({ title: '用户代理', value: this.cacheSettings.userAgent, onValueChange: (v: string) => { this.cacheSettings.userAgent = v; this.saveSettings(); } })
            UiSwitch({showDivider: false,  title: 'Cronet', detail: '使用 Cronet 网络组件', value: this.cacheSettings.cronetEnabled, onChange: (v: boolean) => { this.cacheSettings.cronetEnabled = v; this.saveSettings(); } })
          }
          UiSection({ title: '其它' }) {
            UiAction({ title: '清理缓存', detail: '清应用内正文副本与章节缓存', onSelect: () => this.clearBookCache() })
            UiAction({showDivider: false,  title: '压缩数据库', detail: '整理本地数据库空间', onSelect: () => { this.vacuumDatabase(); } })
          }
          Text('滑块与开关改动即落盘；清理缓存与压缩数据库已接入，封面/漫画缓存本地即时生成无独立缓存。')
            .fontSize(15).fontColor('#858792').margin({ left: 18, right: 18, top: 6, bottom: 22 })
        }.width('100%').padding({ top: 6 })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
  }
}

@Component
struct CacheSettingsInput {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop title: string = '';
  @Prop value: string = '';
  /** 用户代理改动后落盘（:484）。 */
  onValueChange: (value: string) => void = () => {};
  @State currentValue: string = '';
  aboutToAppear(): void { this.currentValue = this.value; }
  build() {
    Row() {
      Text(this.title).fontSize(18).fontColor(this.themeColorTextSecondary).layoutWeight(1)
      TextInput({ text: this.currentValue, placeholder: '默认' })
        .fontSize(12).fontColor(this.themeColorTextSecondary).textAlign(TextAlign.End)
        .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary)).width(130).borderRadius(8)
        .onChange((value: string) => { this.currentValue = value; this.onValueChange(value); })
    }.padding({ left: 14, right: 14, top: 10, bottom: 10 })
  }
}
