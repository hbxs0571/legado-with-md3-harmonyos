import { HEADER_COLLAPSE_THRESHOLD, HEADER_EXPAND_THRESHOLD } from '../components/UiTokens';
import curves from '@ohos.curves';
import { util } from '@kit.ArkTS';
import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';
import { BODY_SMALL, BODY_SMALL_LINE_HEIGHT, LABEL_LARGE, LABEL_MEDIUM, LABEL_MEDIUM_LINE_HEIGHT, TITLE_SMALL } from '../components/typography/TypographyTokens';

@Component
export struct OpenSourceLicensePage {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  @State selectedLicense: string = 'GPL-3.0';
  @State licenseText: string = '';
  @State loadError: string = '';
  @State collapsedHeader: boolean = false;
  private licenseScroller: Scroller = new Scroller();

  private updateHeader(): void {
    const offset = this.licenseScroller.currentOffset().yOffset;
    const shouldCollapse = offset > HEADER_COLLAPSE_THRESHOLD ? true : offset < HEADER_EXPAND_THRESHOLD ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      // 顶部折叠是位移，用弹簧收尾更自然；弹簧不吃 duration，删掉（写了也不生效）。
      this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.86) }, () => {
        this.collapsedHeader = shouldCollapse;
      });
    }
  }

  aboutToAppear(): void {
    this.loadLicense(this.selectedLicense);
  }

  private loadLicense(name: string): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.loadError = '无法读取随应用提供的许可证文本';
      this.licenseText = '';
      return;
    }
    try {
      const data = context.resourceManager.getRawFileContentSync(`licenses/${name}.txt`);
      this.licenseText = util.TextDecoder.create('utf-8').decodeToString(data);
      this.loadError = '';
    } catch (_) {
      this.licenseText = '';
      this.loadError = '许可证文本读取失败';
    }
  }

  private selectLicense(name: string): void {
    this.selectedLicense = name;
    this.loadLicense(name);
  }

  build() {
    Column() {
      CollapsingSettingsHeader({ title: '开源许可证', collapsed: this.collapsedHeader, onBack: () => this.onBack() })

      Text('应用主体遵循 GPL-3.0；图标遵循 Apache-2.0；在线书源引擎及其内嵌的 QuickJS 遵循 MIT（另有 Apache-2.0 的 NAPI wrapper）。')
        .fontSize(LABEL_MEDIUM).lineHeight(LABEL_MEDIUM_LINE_HEIGHT).fontColor('#C6C8D2')
        .width('100%').padding(14).backgroundColor(this.themeColorSurfaceSecondary).borderRadius(12)
        .margin({ left: 16, right: 16, bottom: 10 })

      // 页签横向滚动：四个页签在窄屏上一行放不下。
      Scroll() {
        Row() {
          LicenseChoice({ title: 'GPL-3.0', selected: this.selectedLicense === 'GPL-3.0' })
            .onClick(() => this.selectLicense('GPL-3.0'))
          LicenseChoice({ title: 'Apache-2.0', selected: this.selectedLicense === 'Apache-2.0' })
            .onClick(() => this.selectLicense('Apache-2.0'))
          LicenseChoice({ title: 'MIT', selected: this.selectedLicense === 'MIT' })
            .onClick(() => this.selectLicense('MIT'))
          LicenseChoice({ title: '第三方组件', selected: this.selectedLicense === 'THIRD-PARTY' })
            .onClick(() => this.selectLicense('THIRD-PARTY'))
        }
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
        .padding({ left: 16, right: 16, bottom: 10 })

      if (this.loadError.length > 0) {
        Text(this.loadError).fontSize(TITLE_SMALL).fontColor('#F0B2A8').padding(16)
      } else {
        Scroll(this.licenseScroller) {
          Text(this.licenseText).fontSize(BODY_SMALL).lineHeight(BODY_SMALL_LINE_HEIGHT).fontColor(this.themeColorTextSecondary)
            .width('100%').padding(16).textAlign(TextAlign.Start)
        }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).layoutWeight(1).width('100%').scrollBar(BarState.Off).onScroll(() => this.updateHeader())
      }
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
  }
}

@Component
struct LicenseChoice {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @Prop title: string = '';
  @Prop selected: boolean = false;

  build() {
    Text(this.title).fontSize(TITLE_SMALL).fontColor(this.selected ? '#151720' : this.themeColorTextSecondary)
      .padding({ left: 14, right: 14, top: 9, bottom: 9 })
      .backgroundColor(this.selected ? this.themeColorAccent : this.themeColorSurfaceSecondary)
      .borderRadius(18).margin({ right: 8 })
  }
}
