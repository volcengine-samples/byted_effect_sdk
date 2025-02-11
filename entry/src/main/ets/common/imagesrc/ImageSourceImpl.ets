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

import { ImageSourceProvider, ImageSourceType, ImageSourceConfig } from './ImageSourceProvider';
import { fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { EglWrapper, GlWrapper } from 'effectapi';
import { TextureType, GlResourceType } from 'effectapi/src/main/ets/components/MainPage';
import { MatrixUtils, ScaleType } from '../utils/MatrixUtils';

enum ImageRenderStatus {
  IMAGE_RENDER_STATUS_FINISH = 0,
  IMAGE_RENDER_STATUS_BEGIN,
  IMAGE_RENDER_STATUS_RENDERING,
  IMAGE_RENDER_STATUS_STOP,
}

export class ImageSourceImpl implements  ImageSourceProvider{
  private surfaceID: number = 0
  private photoSize: number = 0
  private mEglCore:EglWrapper | undefined
  private mGlUtils:GlWrapper | undefined
  private pixel: image.PixelMap | undefined = undefined
  private bIsReady: boolean = false
  private mSharedContext: number = 0
  private mSrcTexture: number = 0
  private transform = new MatrixUtils().flip(false, true).rotate(0)
  private intervalID: number = -1
  private mSurfaceWidth = 0
  private mSurfaceHeight = 0
  private status: ImageRenderStatus = ImageRenderStatus.IMAGE_RENDER_STATUS_FINISH
  
  constructor(sharedContext: number) {
    this.mSharedContext = sharedContext
  }

  private prepareEGL(sharedContext: number): boolean {
    if (!this.bIsReady) {
      if (this.surfaceID == 0)
        return false

      this.mEglCore = new EglWrapper(this.getWidth(), this.getHeight(), this.surfaceID, sharedContext, true)
      this.mEglCore.makeCurrent()
      this.mGlUtils = new GlWrapper()

      this.mSrcTexture = this.mGlUtils.genTexture(TextureType.TextureType2D, this.getWidth(), this.getHeight(), 4)
      this.mGlUtils?.transferPixmapTo2DTex(this.pixel, this.mSrcTexture, this.getWidth(), this.getHeight(), this.transform.getData())
      this.bIsReady = true
      this.status = ImageRenderStatus.IMAGE_RENDER_STATUS_RENDERING
    }

    return this.bIsReady
  }

  private releaseEGL(){
    this.mEglCore?.release()
    this.status = ImageRenderStatus.IMAGE_RENDER_STATUS_FINISH
  }

  private frameAvailable(){
    if (this.status == ImageRenderStatus.IMAGE_RENDER_STATUS_BEGIN) {
      this.prepareEGL(this.mSharedContext)
    } else if (this.status == ImageRenderStatus.IMAGE_RENDER_STATUS_RENDERING) {
      this.mEglCore!.makeCurrent()
      this.mGlUtils?.bindFrameBuffer(0)
      this.mGlUtils?.renderTexture(TextureType.TextureType2D, this.mSrcTexture, this.getWidth(), this.getHeight(), this.transform.getData())
      this.mEglCore!.swap()
    } else if (this.status == ImageRenderStatus.IMAGE_RENDER_STATUS_STOP) {
      if (this.mSrcTexture) {
        this.mGlUtils?.destroy(GlResourceType.GlResourceTexture2D, this.mSrcTexture)
        this.mSrcTexture = 0
      }
      this.releaseEGL()
    }
  }

  open(surfaceId: number, path: string | number | object) {
    this.surfaceID = surfaceId
    this.bIsReady = false
    if (typeof path === 'string') {
      let file = fs.openSync(path);
      this.photoSize = fs.statSync(file.fd).size;
      let buffer = new ArrayBuffer(this.photoSize);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file);
      const imageSource = image.createImageSource(buffer);
      this.pixel = imageSource.createPixelMapSync({});
      let fps = 30;
      this.status = ImageRenderStatus.IMAGE_RENDER_STATUS_BEGIN
      this.intervalID = setInterval(() => {
          this.frameAvailable()
        }, 1000 / fps
      )
    }
  }

  close() {
    this.status = ImageRenderStatus.IMAGE_RENDER_STATUS_FINISH
    if (this.mSrcTexture) {
      this.mGlUtils?.destroy(GlResourceType.GlResourceTexture2D, this.mSrcTexture)
      this.mSrcTexture = 0
    }
    this.mEglCore?.release()
    clearInterval(this.intervalID)
    this.pixel?.release()
    this.pixel = undefined
    this.bIsReady = false
  }

  getType(): ImageSourceType {
    return ImageSourceType.IMAGE_SOURCE_IMAGE
  }

  getWidth(): number {
    let imageInfo = this.pixel?.getImageInfoSync()
    if (this.pixel)
      return this.pixel.getImageInfoSync().size.width

    return 0;
  }

  getHeight(): number {

    if (this.pixel)
      return this.pixel.getImageInfoSync().size.height

    return 0;
  }

  getOrientation(): number {
    return 0;
  }

  isFront(): boolean {
    return false;
  }

  getScaleType(): ScaleType {
    return ScaleType.CENTER_INSIDE
  }

}