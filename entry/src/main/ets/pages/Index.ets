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

import { Constants } from '../common/Constants';
import router from '@ohos.router';
import PermissionUtils from '../common/utils/PermissionUtils';
import FileUtils from '../common/utils/FileUtils';

@Entry
@Component
struct Index  {
  @State showMask: Visibility = Visibility.Visible
  private buttonItems: string[] = ['app.media.ic_beauty', 'app.media.ic_makeup', 'app.media.ic_sticker', 'app.media.ic_aigc'];

  // aboutToAppear -> build -> onPageShow
  aboutToAppear(): void {
    console.info(Constants.TAG, 'aboutToAppear');
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Image($r('app.media.ic_background')).width('100%')
      Grid() {
        ForEach(this.buttonItems, (item: string) => {
          GridItem() {
            Button() {
              Image($r(item)).width('44%')
            }.onClick(() => {
              PermissionUtils.checkPermissionAndRequest(getContext(this), ['ohos.permission.CAMERA', 'ohos.permission.READ_IMAGEVIDEO', 'ohos.permission.WRITE_IMAGEVIDEO'], ()=>{
                router.pushUrl({
                  url: "pages/EffectPage",
                  params: {
                    effectType: item.substring(item.lastIndexOf("_") + 1)
                  }
                })
              })
            })
          }
        }, (item: string) => item)
      }
      .maxCount(2)
      .layoutDirection(GridDirection.Row)
      .columnsGap('4%')
      .rowsGap('4%')
      .margin({ bottom: '1.5%'})
      // Text('资源加载中，请稍等')
      //   .fontSize(18).textAlign(TextAlign.Center)
      //   .backgroundColor('#AA000000').fontColor(Color.White)
      //   .width('100%').height('100%')
      //   .visibility(this.showMask)
    }
  }

  onPageShow(): void {
    console.log("onPageShow")
  }

  onPageHide(): void {
    console.log("onPageHide")
  }
}