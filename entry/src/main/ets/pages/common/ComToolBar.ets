// Copyright (2024) Beijing Volcano Engine Technology Ltd.

// Licensed under the Apache License, Version 2.0 (the "License"); 
// you may not use this file except in compliance with the License. 
// You may obtain a copy of the License at 

//     http://www.apache.org/licenses/LICENSE-2.0 

// Unless required by applicable law or agreed to in writing, software 
// distributed under the License is distributed on an "AS IS" BASIS, 
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
// See the License for the specific language governing permissions and 
// limitations under the License. 

@Component
export struct ComToolBar {
  public barHeight: number = 40
  onButtonClick: ((name: string) => void) | undefined
  @State isPopupShow: boolean = false
  @Link isPerformanceShow: boolean
  @State resolutionType:number = 0
  @Prop  isShowAblum: boolean

  @Builder popupBuilder() {
    Grid() {
      GridItem() {
        Text('分辨率').fontColor(Color.White).margin({left: "10%"})
      }.align(Alignment.Start)
      GridItem() {
        Flex({ justifyContent: FlexAlign.End, }) {
          Button('1280*720').controlSize(ControlSize.SMALL).height(20).fontSize(10).fontColor(Color.White).margin({right: 5}).id('button1')
            .backgroundColor(this.resolutionType == 0 ? 'rgb(128, 128, 128)' : Color.Transparent)
            .onClick(()=>{
              this.resolutionType = 0
            })
          /*Button('1920*1080').controlSize(ControlSize.SMALL).height(20).fontSize(10).fontColor(Color.White)
            .backgroundColor(this.resolutionType == 1 ? 'rgb(128, 128, 128)' : Color.Transparent)
            .onClick(()=>{
              this.resolutionType = 1
            })*/
        }.margin({ right: "10%" })
      }.align(Alignment.End)
      GridItem() {
        Text('性能').fontColor(Color.White).margin({left: "10%"})
      }.align(Alignment.Start)
      GridItem() {
        Toggle({ type: ToggleType.Switch, isOn: this.isPerformanceShow }).selectedColor('#007DFF').switchPointColor('#FFFFFF')
          .onChange((isOn: boolean) => {
            this.isPerformanceShow = isOn
          }).margin({right: "10%"})
      }.align(Alignment.End)
    }
    .width('90%')
    .height(this.barHeight * 2)
    .borderRadius(10)
    .backgroundColor(Color.Transparent)
    .rowsTemplate('1fr 1fr')
    .columnsTemplate('1fr 1fr')
  }

  build() {
    RelativeContainer() {
      Flex({
        justifyContent: FlexAlign.SpaceBetween,
        alignItems: ItemAlign.Center
      }) {
        Image($r('app.media.ic_arrow_left')).width(25).height(25)
          .onClick(() => { this.onButtonClick?.("back") })
        Image($r('app.media.ic_ablum')).width(30).height(30)
          .visibility(this.isShowAblum ? Visibility.Visible : Visibility.Hidden)
          .onClick(() => { this.onButtonClick?.("ablum") })
        Image($r('app.media.ic_setting')).width(25).height(25)
          .onClick(() => {
            this.isPopupShow = true
          })
          .bindPopup(this.isPopupShow, {
            builder: this.popupBuilder,
            placement: Placement.Top,
            showInSubWindow: true,
            backgroundBlurStyle:BlurStyle.NONE,
            popupColor: ('rgba(50, 50, 50, 0.8)'),
            radius: 10,
            onStateChange: (e) => { if (!e.isVisible) { this.isPopupShow = false } },
            transition:TransitionEffect.scale({ x: 1}).animation({ duration: 500, curve: Curve.Ease })
          })

        Image($r('app.media.ic_rotate')).width(25).height(25)
          .onClick(() => { this.onButtonClick?.("switchCamera") })
          .visibility(this.isShowAblum ? Visibility.Visible : Visibility.Hidden)
      }
      .alignRules({ top: {anchor: '__container__', align: VerticalAlign.Top} })
      .height(this.barHeight)
      .margin({ left: '5', right: '5', top: '5', bottom: '5' })

    }
    .height(this.barHeight)
    .margin({ left: '5%', right: '5%', top: '15', bottom: '5' })
    .width('90%')
  }

}