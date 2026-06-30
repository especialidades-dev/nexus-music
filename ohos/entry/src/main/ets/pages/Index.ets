import { FlutterView } from '@ohos/flutter_ohos';

@Entry
@Component
struct Index {
  @State message: string = 'Nexus Music';

  build() {
    Column() {
      FlutterView({
        width: '100%',
        height: '100%'
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#191622')
  }
}
