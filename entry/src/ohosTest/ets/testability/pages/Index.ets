@Entry
@Component
struct Index {
  build() {
    Column() {
      Text('Hypium UI 测试正在运行')
        .fontSize(18)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
