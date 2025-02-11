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

import { ImageSourceType, ImageSourceConfig } from '../../common/imagesrc/ImageSourceProvider'
import { CameraSourceImpl } from '../../common/imagesrc/CameraSourceImpl'
import { VideoSourceImpl } from '../../common/imagesrc/VideoSourceImpl'
import { ImageSourceImpl } from '../../common/imagesrc/ImageSourceImpl'
import EffectManager from '../../effect/EffectManager'
import { router, promptAction } from '@kit.ArkUI';
import hilog from '@ohos.hilog';

@Component
export struct BaseEffectGLPage {
  private mXComponentController: XComponentController = new XComponentController();
  @Link mImageSourceConfig: ImageSourceConfig
  @Link mEffectManager: EffectManager | null
  @Link isIcPlayShow: boolean
  oViewClick: (()=>void) | undefined
  onPerformanceCallBack: ((fps: number, renderTimeCon: number, resolution: string ) => void) | undefined
  build() {
    RelativeContainer() {
      XComponent({
        id: '',
        type: 'surface',
        controller: this.mXComponentController,
        libraryname: 'effectapi',
      })
        .onLoad(() => {
          getContext(this)
          this.mEffectManager = new EffectManager()
          if (this.onPerformanceCallBack)
            this.mEffectManager.setPerformanceCallBack(this.onPerformanceCallBack)

          //mXComponentController is used to get the window size
          this.mEffectManager.init(this.mXComponentController)
          let mImageId = this.mEffectManager.getNativeImageSurfaceId()?.toString()
          if (mImageId) {
            if (this.mImageSourceConfig.imageSourceType == ImageSourceType.IMAGE_SOURCE_VIDEO) {
              let videoImpl = new VideoSourceImpl( ()=> {
                videoImpl.close()
                this.mEffectManager?.stopRecord()
                promptAction.showToast({ message: "视频处理完成，已保存到相册", duration: 2000, });
                router.back()
              }, (width: number, height: number)=>{}
              )
              videoImpl.open(this.mEffectManager.getNativeImageSurfaceId()!, this.mImageSourceConfig.srcPath)
              this.mEffectManager.setImageSourceProvider(videoImpl)
              this.isIcPlayShow = true
            } else if (this.mImageSourceConfig.imageSourceType == ImageSourceType.IMAGE_SOURCE_CAMERA) {
              let cameraImpl = new CameraSourceImpl()
              cameraImpl.setPreferSize(1280, 720)
              cameraImpl.open(this.mEffectManager.getNativeImageSurfaceId()!, 1)
              this.mEffectManager.setImageSourceProvider(cameraImpl)
            } else if (this.mImageSourceConfig.imageSourceType == ImageSourceType.IMAGE_SOURCE_IMAGE) {
              let imageImpl = new ImageSourceImpl(this.mEffectManager.getGLContext())
              imageImpl.open(this.mEffectManager.getNativeImageSurfaceId()!, this.mImageSourceConfig.srcPath)
              this.mEffectManager.setImageSourceProvider(imageImpl)
            }
          }
        })
        .border({
          width: {
            top: 0.5,
            bottom: 0.5
          },
          color: Color.Black
        })

      if (this.isIcPlayShow) {
        Row() {
          Image($r('app.media.ic_play_icon'))
            .width(50).height(50)
            .onClick(() => {
              let videoSourceImpl = this.mEffectManager?.getImageSourceProvider() as VideoSourceImpl | undefined
              if (videoSourceImpl && videoSourceImpl.play()){
                this.isIcPlayShow = false
                this.mEffectManager?.startRecord('', 5, 30)
              }

            })
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)
      }
    }.onClick(()=>{
      this.oViewClick?.()
    }).onTouch((event: TouchEvent)=>{
      this.mEffectManager?.processTouch(event)
    })
  }
}