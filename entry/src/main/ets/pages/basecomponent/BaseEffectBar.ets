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

import { vibrator } from '@kit.SensorServiceKit'
import { BusinessError } from '@ohos.base'

@Component
export struct BaseEffectBar {
  @Link isDown: boolean
  public barHeight: number = 40
  onButtonClick:((name: string) => void) | undefined
  onButtonPress:(() => void) | undefined
  onButtonPressFinish:(() => void) | undefined

  private _triggerVibrate(callback: (()=> void) | undefined) {
    try {
      vibrator.startVibration({
        type: 'preset',
        effectId: 'haptic.effect.hard',
      }, {
        id: 0,
        usage: 'touch'
      }, (error: BusinessError) => {
        if (error) {
          console.error(`Failed to start vibration. Code: ${error.code}, message: ${error.message}`);
        }
        callback?.()
      });
    } catch (err) {
      let e: BusinessError = err as BusinessError;
      console.error(`An unexpected error occurred. Code: ${e.code}, message: ${e.message}`);
    }
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Flex({
        justifyContent: FlexAlign.SpaceBetween,
        alignItems: ItemAlign.Center
      }) {
        Image($r('app.media.ic_arrow_up')).width(25).height(25).rotate({
          angle: this.isDown ? 180 : 0
        })
          .onClick(() => {
            this.isDown = !this.isDown
          })
        Image($r('app.media.ic_record')).width(30).height(30)
          .onClick(() => {
            this.onButtonClick?.("record")
          })
          .priorityGesture(
            LongPressGesture()
              .onAction((event: GestureEvent|undefined) => {
                this._triggerVibrate(this.onButtonPress)
              })
              .onActionEnd(()=> {
                this._triggerVibrate(this.onButtonPressFinish)
              })
          )
        Image($r('app.media.ic_image_default')).width(25).height(25)
          .onClick(() => {
            this.onButtonClick?.("restoreDefault")
          })
      }
      .margin({ left: '5', right: '5', top: '5', bottom: '5' })
    }
    .margin({ left: '5%', right: '5%', top: '5', bottom: '5' })
    .height(this.barHeight)
    .width('90%')
  }

}