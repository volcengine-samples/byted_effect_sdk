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

import {RenderManager, EglWrapper, GlWrapper, NativeImageWrapper, getWindow} from 'effectapi/Index'
import { Method, Request, Response, NetworkProxy } from 'effectapi/Index'
import { TextureType, GlResourceType, BefTouchEvent } from 'effectapi/src/main/ets/components/MainPage';
import { MatrixUtils, ScaleType } from '../common/utils/MatrixUtils';
import hilog from '@ohos.hilog';
import FileUtils from '../common/utils/FileUtils';
import systemDateTime from '@ohos.systemDateTime';
import { VideoEncodeGLWriter } from  '../common/video/VideoEncodeGLWriter'
import { ImageSourceProvider, ImageSourceType } from '../common/imagesrc/ImageSourceProvider';
import { promptAction } from '@kit.ArkUI';
import { http } from '@kit.NetworkKit';
import { BusinessError } from '@ohos.base';
import { PixelMapUtils } from '../common/utils/PixelMapUtils';

class EffectManager {
  private mEglCore:EglWrapper|undefined
  private mGlUtils:GlWrapper|undefined
  private mNativeImage:NativeImageWrapper|undefined
  private mSrcTexture:number|undefined
  private mDstTexture:number|undefined
  private mXComponentController:XComponentController|undefined
  private mWidth:number|undefined
  private mHeight:number|undefined
  private mWindowId: number = 0
  private mInit:boolean = false
  mNeedCapture: boolean = false
  private mImageSourceProvider: ImageSourceProvider | undefined
  private videoWriter: VideoEncodeGLWriter = new VideoEncodeGLWriter()
  private performanceCallBack: ((fps: number, renderTimeCon: number, resolution: string ) => void) | undefined
  renderManager:RenderManager|undefined

  setPerformanceCallBack(callback: (fps: number, renderTimeCon: number, resolution: string) => void) {
    this.performanceCallBack = callback
  }

  frameAvailable():void {
    if (this.mImageSourceProvider == undefined)
      return

    this.mEglCore?.makeCurrent()
    this.mNativeImage?.update()
    this.prepareTexture()
    let oesId = this.mNativeImage?.getTextureId()

    let tmp = new MatrixUtils()
    tmp = tmp.rotate(this.mImageSourceProvider.getOrientation())
    if (this.mImageSourceProvider.isFront())
      tmp = tmp.flip(true, false)

    this.mGlUtils?.transferOesTo2DTex(oesId, this.mSrcTexture, this.mWidth, this.mHeight, tmp.getData())

    this.renderManager?.setWidthHeight(this.mWidth, this.mHeight)
    console.time("effectProcess")
    let startTime = systemDateTime.getTime(false)
    this.renderManager?.processTexture(this.mSrcTexture, this.mDstTexture, systemDateTime.getTime(false)/1000.0)
    let endTime = systemDateTime.getTime(false)
    console.timeEnd("effectProcess")

    this.mGlUtils?.bindFrameBuffer(0)
    let rect = this.mXComponentController?.getXComponentSurfaceRect()

    let tmp2 = new MatrixUtils().getShowMatrix(this.mImageSourceProvider.getScaleType(), this.mWidth!, this.mHeight!, rect!.surfaceWidth, rect!.surfaceHeight)
    if (this.mInit) {
      this.mGlUtils?.renderTexture(TextureType.TextureType2D, this.mDstTexture, rect?.surfaceWidth, rect?.surfaceHeight, tmp2.flip(false, true).getData())
    } else {
      this.mGlUtils?.renderTexture(TextureType.TextureType2D, this.mSrcTexture, rect?.surfaceWidth, rect?.surfaceHeight, tmp2.flip(false, true).getData())
    }
    this.handleSavePic(this.mInit ? this.mDstTexture! : this.mSrcTexture!, this.mWidth!, this.mHeight!)

    this.mEglCore?.swap()
    if (this.mEglCore) {
      this.videoWriter.onVideoData(this.mEglCore?.getCurrentContext(), this.mInit ? this.mDstTexture! : this.mSrcTexture!, this.mWidth!, this.mHeight!, systemDateTime.getTime(true))
    }

    if (this.performanceCallBack) {
      this.performanceCallBack(30, endTime - startTime, ''+ this.mWidth + ' * ' + this.mHeight)
    }
    return
  }

  handleSavePic(textureId: number, width: number, height: number) {
    if (this.mNeedCapture) {
      this.mNeedCapture = false
      let pixelmap = this.mGlUtils?.transfer2DTexToPixmap(textureId, width, height)
      if (pixelmap) {
        let pixelMapUitls = new PixelMapUtils()
        pixelMapUitls.savePixelmap(pixelmap, (isTrue: boolean) => {
          if (isTrue) {
            promptAction.showToast({ message: "图片已保存到相册", duration: 2000, });
          } else {
            promptAction.showToast({ message: "拍照失败", duration: 2000, });
          }
        })
      }

    }
  }

  getRecordVideoPath(): string | undefined{
    return this.videoWriter.getRecordVideoPath()
  }

  async startRecord(fileName: string, bitRateFactor: number, fps: number): Promise<boolean> {
    let ret = false
    if (this.mWidth && this.mHeight) {
      ret = await this.videoWriter.start({
        fileName: fileName,
        width: this.mWidth,
        height: this.mHeight,
        bitRate: this.mWidth * this.mHeight * bitRateFactor,
        frameRate: fps
      })
    }
    return ret
  }

  stopRecord() {
    this.videoWriter.stop()
  }

  getGLContext(): number{
    if (this.mEglCore)
      return this.mEglCore.getCurrentContext()

    return 0
  }

  init(controller:XComponentController) {
    this.mWindowId = getWindow()
    this.mEglCore = new EglWrapper(10, 10, this.mWindowId, 0, false)
    this.mNativeImage = new NativeImageWrapper()
    this.mNativeImage.setOnFrameAvailAbleLister(this, this.frameAvailable)
    this.mGlUtils = new GlWrapper()
    this.mXComponentController = controller
    this.renderManager = new RenderManager()
    let ret = this.renderManager.create(FileUtils.getModelFilePath(), FileUtils.getLicensePath(), 0)
    if (ret >= 0) {
      this.mInit = true;
    } else {
      this.mInit = false;
      console.error("RenderManager create failed! " + ret)
    }

    let callback = (req: Request) => {
      EffectManager.makeHttpRequest(req);
    }
    NetworkProxy.onRequest(callback)
  }

  private prepareTexture() {
    if ((this.mSrcTexture && this.mDstTexture) || this.mImageSourceProvider == undefined) {
      return
    }

    if (this.mImageSourceProvider.getOrientation() == 90 || this.mImageSourceProvider.getOrientation() == 270) {
      this.mWidth = this.mImageSourceProvider.getHeight()
      this.mHeight = this.mImageSourceProvider.getWidth()
    } else {
      this.mWidth = this.mImageSourceProvider.getWidth()
      this.mHeight = this.mImageSourceProvider.getHeight()
    }
    this.mSrcTexture = this.mGlUtils?.genTexture(TextureType.TextureType2D, this.mWidth, this.mHeight, 4)
    this.mDstTexture = this.mGlUtils?.genTexture(TextureType.TextureType2D, this.mWidth, this.mHeight, 4)
  }

  getImageSourceProvider() : ImageSourceProvider | undefined {
    return this.mImageSourceProvider
  }

  setImageSourceProvider(imageSourceProvider: ImageSourceProvider) {
    this.mImageSourceProvider = imageSourceProvider
  }

  resetNativeImage() {
    if (this.mNativeImage) {
      this.mNativeImage.release()
      this.mNativeImage = new NativeImageWrapper()
      this.mNativeImage.setOnFrameAvailAbleLister(this, this.frameAvailable)
    }
  }

  getNativeImageSurfaceId():number|undefined {
    return this.mNativeImage?.getSurfaceId()
  }

  processTouch(event: TouchEvent): number|undefined {
    switch (event.type) {
      case TouchType.Down:
        return this.renderManager?.processTouch(BefTouchEvent.BEGAN, event.touches[0].x, event.touches[0].y, 0, 0, event.touches[0].id, event.touches.length);
      case TouchType.Up:
        return this.renderManager?.processTouch(BefTouchEvent.ENDED, event.touches[0].x, event.touches[0].y, 0, 0, event.touches[0].id, event.touches.length);
      case TouchType.Move:
        return this.renderManager?.processTouch(BefTouchEvent.MOVED, event.touches[0].x, event.touches[0].y, 0, 0, event.touches[0].id, event.touches.length);
      case TouchType.Cancel:
        return this.renderManager?.processTouch(BefTouchEvent.CANCELLED, event.touches[0].x, event.touches[0].y, 0, 0, event.touches[0].id, event.touches.length);
    }
    return -1;
  }

  static async makeHttpRequest(req: Request) {
    let httpRequest = http.createHttp();
    // 用于订阅HTTP响应头，此接口会比request请求先返回。可以根据业务需要订阅此消息
    httpRequest.on('headersReceive', (header: Object) => {
      console.info('header: ' + JSON.stringify(header));
    });

    let method: http.RequestMethod = http.RequestMethod.GET;
    switch (req.method) {
      case Method.Get:
        method = http.RequestMethod.GET; break;
      case Method.Post:
        method = http.RequestMethod.POST; break;
    }
    httpRequest.request(
      req.url,
      {
        method: method,
        header: req.headers,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        extraData: req.body
      },
      (err: BusinessError, data: http.HttpResponse) => {
        let resp = new Response(req);
        if (!err) {
          console.info('Result:' + JSON.stringify(data.result));
          console.info('code:' + JSON.stringify(data.responseCode));
          console.info('type:' + JSON.stringify(data.resultType));
          console.info('header:' + JSON.stringify(data.header));
          console.info('cookies:' + JSON.stringify(data.cookies)); // 自API version 8开始支持cookie

          if (data.resultType == http.HttpDataType.ARRAY_BUFFER) {
            resp.success = true;
            resp.statusCode = data.responseCode;
            resp.data = data.result as ArrayBuffer;
            resp.headers = data.header;
          } else {
            console.error("wrong response data type");
          }

          httpRequest.off('headersReceive');
          httpRequest.destroy();
        } else {
          resp.success = false;
          resp.errorMsg = JSON.stringify(err);
          console.info('error:' + JSON.stringify(err));
          httpRequest.off('headersReceive');
          httpRequest.destroy();
        }
        NetworkProxy.onResponse(resp)
      }
    )
  }
}

export default  EffectManager;
