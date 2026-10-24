@Component
export struct AppAiSettingsPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};

  build() {
    Column() {
      Row() {
        Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
          .width(40).height(40).onClick(() => this.onBack())
        Column() {
          Text('AI 设置').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
          Text('供应商、模型与任务配置').fontSize(15).fontColor('#92949E').margin({ top: 3 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.padding({ left: 12, right: 16, top: 8, bottom: 10 })

      Scroll() {
        Column() {
          AiSettingsSection({ title: '供应商' }) {
            Column() {
              Text('暂无已配置的 AI 供应商').fontSize(18).fontColor('#D8D9E0')
              Text('添加服务商后可在此管理接口与模型').fontSize(15).fontColor('#92949E').margin({ top: 6 })
              Row() {
                Image($r('app.media.app_add')).width(16).height(16).fillColor('#151720')
                Text('新建供应商').fontSize(12).fontColor('#151720').margin({ left: 7 })
              }.padding({ left: 13, right: 13, top: 9, bottom: 9 }).backgroundColor('#AFC2FF')
                .borderRadius(18).margin({ top: 12 }).onClick(() => this.onUnavailableAction('AI 服务商配置尚未迁移'))
            }.alignItems(HorizontalAlign.Center).width('100%').padding(18)
          }

          AiSettingsSection({ title: '模型' }) {
            AiSettingsAction({ title: '当前模型', detail: '未配置模型', onSelect: () => this.onUnavailableAction('AI 模型选择尚未迁移') })
          }

          AiSettingsSection({ title: '任务' }) {
            AiSettingsAction({ title: '翻译设置', onSelect: () => this.onUnavailableAction('AI 翻译服务设置尚未迁移') })
            Row().height(1).width('100%').backgroundColor('#111217')
            AiSettingsAction({ title: '章节梗概', onSelect: () => this.onUnavailableAction('AI 章节梗概设置尚未迁移') })
            Row().height(1).width('100%').backgroundColor('#111217')
            AiSettingsAction({ title: '提示词设置', detail: '编辑各 AI 工具的提示词', onSelect: () => this.onUnavailableAction('AI 提示词设置尚未迁移') })
          }

          AiSettingsSection({ title: 'Skills' }) {
            AiSettingsAction({ title: '新建 Skill', onSelect: () => this.onUnavailableAction('AI Skill 尚未迁移') })
          }
          Text('本页仅呈现原项目 AI 配置结构；未连接供应商、网络请求或凭据存储。')
            .fontSize(15).fontColor('#858792').margin({ left: 18, right: 18, top: 6, bottom: 22 })
        }.width('100%').padding({ top: 6 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct AiSettingsSection {
  @Prop title: string = '';
  @BuilderParam content: () => void = this.emptyContent;
  @Builder
  emptyContent() {
  }
  build() {
    Column() {
      Text(this.title).fontSize(18).fontWeight(FontWeight.Medium).fontColor('#AFC2FF')
        .alignSelf(ItemAlign.Start).padding({ left: 18, top: 14, bottom: 8 })
      Column() { this.content() }.margin({ left: 16, right: 16 }).backgroundColor('#1A1B21').borderRadius(16)
    }
  }
}

@Component
struct AiSettingsAction {
  @Prop title: string = '';
  @Prop detail: string = '';
  onSelect: () => void = () => {};
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(18).fontColor('#D8D9E0')
        if (this.detail.length > 0) { Text(this.detail).fontSize(15).fontColor('#92949E').margin({ top: 3 }) }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.reader_next')).width(15).height(15).fillColor('#92949E')
    }.padding({ left: 14, right: 14, top: 13, bottom: 13 }).onClick(() => this.onSelect())
  }
}