@Component
export struct PrivacyNoticePage {
  onBack: () => void = () => {};

  build() {
    Column() {
      Row() {
        Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
          .width(40).height(40).onClick(() => this.onBack())
        Column() {
          Text('隐私声明').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
          Text('当前版本的数据与网络行为').fontSize(15).fontColor('#92949E').margin({ top: 3 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })
      }.padding({ left: 12, right: 16, top: 8, bottom: 12 })

      Scroll() {
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
            body: '当前 HarmonyOS 模块不声明 INTERNET 权限，也没有应用发起的网络请求。Android 书源、规则与 WebDAV 尚未接入；若后续加入网络能力，会先更新权限用途和隐私说明。'
          })
          PrivacyNoticeSection({
            title: '当前未接入的服务',
            body: '当前未配置账号登录、广告、分析 SDK、云同步、AI 服务或在线书源请求。后续如果接入网络服务，会在发布版本前更新本说明并说明相应数据用途。'
          })
          Text('本说明根据当前源码整理，属于开发阶段披露，不替代目标发布渠道要求的正式隐私政策。正式发布前需完成资源授权、网络请求和隐私政策审核。')
            .fontSize(13).fontColor('#D9A6A0').lineHeight(20).padding({ left: 18, right: 18, top: 8, bottom: 22 })
        }.width('100%').padding({ top: 4 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct PrivacyNoticeSection {
  @Prop title: string = '';
  @Prop body: string = '';

  build() {
    Column() {
      Text(this.title).fontSize(18).fontWeight(FontWeight.Medium).fontColor('#AFC2FF')
        .alignSelf(ItemAlign.Start).margin({ bottom: 8 })
      Text(this.body).fontSize(15).fontColor('#D8D9E0').lineHeight(22).textAlign(TextAlign.Start)
    }.width('100%').padding(16).backgroundColor('#1A1B21').borderRadius(16)
      .margin({ left: 16, right: 16, bottom: 12 })
  }
}
