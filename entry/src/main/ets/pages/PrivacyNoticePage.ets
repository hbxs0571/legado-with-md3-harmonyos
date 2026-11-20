import curves from '@ohos.curves';
import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';
import { LABEL_MEDIUM, LABEL_MEDIUM_LINE_HEIGHT, TITLE_LARGE } from '../components/typography/TypographyTokens';

@Component
export struct PrivacyNoticePage {
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  @State collapsedHeader: boolean = false;
  private noticeScroller: Scroller = new Scroller();

  private updateHeader(): void {
    const offset = this.noticeScroller.currentOffset().yOffset;
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
      CollapsingSettingsHeader({ title: '隐私声明', collapsed: this.collapsedHeader, onBack: () => this.onBack() })

      Scroll(this.noticeScroller) {
        Column() {
          PrivacyNoticeSection({
            title: '本地书籍与阅读进度',
            body: '你通过系统文件选择器主动选择 TXT 或 EPUB 后，应用会把书籍副本存入应用沙箱，并在本机保存书名、作者、章节目录、阅读进度和阅读设置。当前代码不会把书籍正文或阅读进度上传到 Legado 服务端。'
          })
          PrivacyNoticeSection({
            title: '系统文件访问',
            body: '应用使用 HarmonyOS 系统文件选择器读取你选中的文件，不申请访问整个设备存储的权限。移出书架会清理应用沙箱副本，保留原始文件。'
          })
          PrivacyNoticeSection({
            title: '剪贴板',
            body: '仅当你在规则编辑页主动使用“粘贴”并确认系统授权后，应用才会读取剪贴板当前的第一条文本，尝试识别为规则并填入编辑表单。应用不会在后台持续读取剪贴板或将其发送到网络。“复制规则”会把当前规则文本写入系统剪贴板。'
          })
          PrivacyNoticeSection({
            title: '网络请求',
            body: '应用声明 INTERNET 权限，用于在线书源抓取、WebDAV 备份同步与在线朗读（HTTP TTS）。这些请求只在你主动使用对应功能时发起，并直接发往你所配置的目标：书源请求发往书源站点，WebDAV 请求发往你填写的服务器，朗读请求发往你配置的朗读源。应用没有自有服务端接收书籍正文或阅读记录。'
          })
          PrivacyNoticeSection({
            title: '未接入的服务与凭据',
            body: '应用未接入广告、分析统计、远端崩溃收集或 AI 服务；没有自有账号体系，也没有自有服务端。书源登录凭据（Cookie、登录信息）保存在本机书源数据中，会随你主动导出的备份文件一并导出，请勿公开分享备份。'
          })
          Text('本说明根据当前源码整理，属于开发阶段披露，不替代目标发布渠道要求的正式隐私政策。正式发布前需完成资源授权、网络请求和隐私政策审核。')
            .fontSize(LABEL_MEDIUM).fontColor('#D9A6A0').lineHeight(LABEL_MEDIUM_LINE_HEIGHT).padding({ left: 18, right: 18, top: 8, bottom: 22 })
        }.width('100%').padding({ top: 4 })
      }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
  }
}

@Component
struct PrivacyNoticeSection {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @Prop title: string = '';
  @Prop body: string = '';

  @StorageProp('themeCardRadius') themeCardRadius: number = 16;
  @StorageProp('themeCardBorderWidth') themeCardBorderWidth: number = 0;
  @StorageProp('themeCardBorderColor') themeCardBorderColor: string = '#6A6D77';
  @StorageProp('themeCardBackground') themeCardBackground: string = '';
  @StorageProp('themeContainerBackground') themeContainerBackground: string = '';
  build() {
    Column() {
      Text(this.title).fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor(this.themeColorAccent)
        .alignSelf(ItemAlign.Start).margin({ bottom: 8 })
      Text(this.body).fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextSecondary).lineHeight(LABEL_MEDIUM_LINE_HEIGHT).textAlign(TextAlign.Start)
    }.width('100%').padding(16).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
      .margin({ left: 16, right: 16, bottom: 12 })
  }
}
