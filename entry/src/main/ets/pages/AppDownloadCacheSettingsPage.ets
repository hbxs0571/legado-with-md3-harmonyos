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
      animateTo({ duration: 220, curve: Curve.EaseInOut }, () => this.collapsedHeader = shouldCollapse);
    }
  }

  build() {
    Column() {
      CollapsingSettingsHeader({ title: '下载与缓存', collapsed: this.collapsedHeader, onBack: () => this.onBack() })

      Scroll(this.settingsScroller) {
        Column() {
          CacheSettingsSection({ title: 'HTTP 缓存' }) {
            CacheSettingsAction({ title: '封面缓存', detail: '本地书籍封面即时生成', onSelect: () => this.onUnavailableAction('本地书籍封面即时生成，无独立缓存') })
            CacheSettingsAction({ title: '漫画缓存', detail: '本地无漫画形态', onSelect: () => this.onUnavailableAction('本地书籍封面即时生成，无独立缓存') })
          }
          CacheSettingsSection({ title: '下载设置' }) {
            CacheSettingsSlider({ title: '更新和搜索线程', detail: '控制请求并发数量', value: this.cacheSettings.updateSearchThreads, min: 1, max: 256, onValueChange: (v: number) => { this.cacheSettings.updateSearchThreads = v; this.saveSettings(); } })
            CacheSettingsSlider({ title: '书籍缓存下载线程', detail: '并发越高越不稳定', value: this.cacheSettings.bookDownloadThreads, min: 1, max: 8, onValueChange: (v: number) => { this.cacheSettings.bookDownloadThreads = v; this.saveSettings(); } })
            CacheSettingsSlider({ title: '向后预下载', detail: '预先下载后续章节', value: this.cacheSettings.preloadBehind, min: 0, max: 100, onValueChange: (v: number) => { this.cacheSettings.preloadBehind = v; this.saveSettings(); } })
            CacheSettingsSlider({ title: '向前预下载', detail: '预先下载前面的章节', value: this.cacheSettings.preloadAhead, min: 0, max: 100, onValueChange: (v: number) => { this.cacheSettings.preloadAhead = v; this.saveSettings(); } })
            CacheSettingsSlider({ title: '整本正文内存缓存上限', detail: '单位 MB；超过就不缓存整本正文', value: this.cacheSettings.bookContentCacheMb, min: 1, max: 512, onValueChange: (v: number) => { this.cacheSettings.bookContentCacheMb = v; this.saveSettings(); } })
          }
          CacheSettingsSection({ title: '图片缓存' }) {
            CacheSettingsSlider({ title: '图片绘制缓存', detail: '最大缓存大小（MB）', value: this.cacheSettings.imageDrawCacheMb, min: 1, max: 2047, onValueChange: (v: number) => { this.cacheSettings.imageDrawCacheMb = v; this.saveSettings(); } })
            CacheSettingsSlider({ title: '漫画保留数量', detail: '保留已读章节数量', value: this.cacheSettings.comicKeepCount, min: 0, max: 100, onValueChange: (v: number) => { this.cacheSettings.comicKeepCount = v; this.saveSettings(); } })
          }
          CacheSettingsSection({ title: '网络' }) {
            CacheSettingsInput({ title: '用户代理', value: this.cacheSettings.userAgent, onValueChange: (v: string) => { this.cacheSettings.userAgent = v; this.saveSettings(); } })
            CacheSettingsSwitch({ title: 'Cronet', detail: '使用 Cronet 网络组件', checkedValue: this.cacheSettings.cronetEnabled, onToggle: (v: boolean) => { this.cacheSettings.cronetEnabled = v; this.saveSettings(); } })
          }
          CacheSettingsSection({ title: '其它' }) {
            CacheSettingsAction({ title: '清理缓存', detail: '清应用内正文副本与章节缓存', onSelect: () => this.clearBookCache() })
            CacheSettingsAction({ title: '压缩数据库', detail: '整理本地数据库空间', onSelect: () => { this.vacuumDatabase(); } })
          }
          Text('滑块与开关改动即落盘；清理缓存与压缩数据库已接入，封面/漫画缓存本地即时生成无独立缓存。')
            .fontSize(15).fontColor('#858792').margin({ left: 18, right: 18, top: 6, bottom: 22 })
        }.width('100%').padding({ top: 6 })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
  }
}

@Component
struct CacheSettingsSection {
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
struct CacheSettingsAction {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @Prop title: string = '';
  @Prop detail: string = '';
  onSelect: () => void = () => {};
  build() {
    Row() {
      Text(this.title).fontSize(18).fontColor(this.themeColorTextSecondary).layoutWeight(1)
      if (this.detail.length > 0) { Text(this.detail).fontSize(15).fontColor(this.themeColorTextTertiary).margin({ right: 8 }) }
      Image($r('app.media.reader_next')).width(15).height(15).fillColor(this.themeColorTextTertiary)
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 }).onClick(() => this.onSelect())
  }
}

@Component
struct CacheSettingsSlider {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop value: number = 0;
  @Prop min: number = 0;
  @Prop max: number = 100;
  /** 值变化时把新值交给页面落盘（:484）。 */
  onValueChange: (value: number) => void = () => {};
  @State currentValue: number = 0;
  aboutToAppear(): void { this.currentValue = this.value; }
  build() {
    Column() {
      Row() {
        Column() {
          Text(this.title).fontSize(18).fontColor(this.themeColorTextSecondary)
          if (this.detail.length > 0) { Text(this.detail).fontSize(15).fontColor(this.themeColorTextTertiary).margin({ top: 3 }) }
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Text(`${Math.round(this.currentValue)}`).fontSize(12).fontColor(this.themeColorAccent)
      }
      Slider({ value: this.currentValue, min: this.min, max: this.max, step: 1 })
        .selectedColor(this.themeColorAccent).trackColor('#454750')
        .onChange((value: number) => { this.currentValue = value; this.onValueChange(value); })
    }.padding({ left: 14, right: 14, top: 9, bottom: 9 })
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

@Component
struct CacheSettingsSwitch {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @Prop title: string = '';
  @Prop detail: string = '';
  /** 页面传进来的持久化初值。 */
  @Prop checkedValue: boolean = false;
  /** 开关改动后落盘（:484）。 */
  onToggle: (value: boolean) => void = () => {};
  @State toggleValue: boolean = false;
  aboutToAppear(): void { this.toggleValue = this.checkedValue; }
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(18).fontColor(this.themeColorTextSecondary)
        if (this.detail.length > 0) { Text(this.detail).fontSize(15).fontColor(this.themeColorTextTertiary).margin({ top: 3 }) }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.toggleValue })
        .onChange((value: boolean) => { this.toggleValue = value; this.onToggle(value); })
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 })
  }
}
