import { util } from '@kit.ArkTS';
import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';

@Component
export struct OpenSourceLicensePage {
  onBack: () => void = () => {};
  @State selectedLicense: string = 'GPL-3.0';
  @State licenseText: string = '';
  @State loadError: string = '';
  @State collapsedHeader: boolean = false;
  private licenseScroller: Scroller = new Scroller();

  private updateHeader(): void {
    const offset = this.licenseScroller.currentOffset().yOffset;
    const shouldCollapse = offset > 70 ? true : offset < 24 ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      animateTo({ duration: 220, curve: Curve.EaseInOut }, () => this.collapsedHeader = shouldCollapse);
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

      Text('应用主体遵循 GPL-3.0；app_home、app_moon、app_share 图标遵循 Apache-2.0。')
        .fontSize(13).lineHeight(19).fontColor('#C6C8D2')
        .width('100%').padding(14).backgroundColor('#1A1B21').borderRadius(12)
        .margin({ left: 16, right: 16, bottom: 10 })

      Row() {
        LicenseChoice({ title: 'GPL-3.0', selected: this.selectedLicense === 'GPL-3.0' })
          .onClick(() => this.selectLicense('GPL-3.0'))
        LicenseChoice({ title: 'Apache-2.0', selected: this.selectedLicense === 'Apache-2.0' })
          .onClick(() => this.selectLicense('Apache-2.0'))
      }.width('100%').padding({ left: 16, right: 16, bottom: 10 })

      if (this.loadError.length > 0) {
        Text(this.loadError).fontSize(14).fontColor('#F0B2A8').padding(16)
      } else {
        Scroll(this.licenseScroller) {
          Text(this.licenseText).fontSize(12).lineHeight(17).fontColor('#D8D9E0')
            .width('100%').padding(16).textAlign(TextAlign.Start)
        }.layoutWeight(1).width('100%').scrollBar(BarState.Off).onScroll(() => this.updateHeader())
      }
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct LicenseChoice {
  @Prop title: string = '';
  @Prop selected: boolean = false;

  build() {
    Text(this.title).fontSize(14).fontColor(this.selected ? '#151720' : '#D8D9E0')
      .padding({ left: 14, right: 14, top: 9, bottom: 9 })
      .backgroundColor(this.selected ? '#AFC2FF' : '#1A1B21')
      .borderRadius(18).margin({ right: 8 })
  }
}
