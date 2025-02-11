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
import { LocalCameraManager } from '../../effect/Camera';
import { MatrixUtils, ScaleType } from '../utils/MatrixUtils';

export class CameraSourceImpl implements  ImageSourceProvider{
  private mCamera: LocalCameraManager
  private mImageId: string = ""
  private mCameraID: number = 1
  private mWidth: number = 0
  private mHeight: number = 0

  constructor() {
    this.mCamera = new LocalCameraManager(getContext(this))
  }

  setPreferSize(width: number, height: number) {
    this.mWidth = width
    this.mHeight = height
  }

  open(surfaceId: number, media: string | number | object){
    this.mImageId = surfaceId.toString()
    this.mCamera.openCamera(this.mCameraID, { width: this.mWidth, height: this.mHeight }, surfaceId.toString())
  }

  close(){
    this.mCamera.releaseCamera()
  }

  getType(): ImageSourceType{
    return ImageSourceType.IMAGE_SOURCE_CAMERA
  }

  getWidth(): number {
    return this.mWidth
  }

  getHeight(): number {
    return this.mHeight
  }

  getOrientation(): number {
    return this.isFront() ? 90 : 270
  }

  isFront(): boolean{
    return this.mCameraID == 1
  }

  switchCamera(): boolean {
    let cameraID = 1 - this.mCameraID;
    if (this.mImageId != "") {
      this.mCamera?.openCamera(cameraID, { width: 1280, height: 720 }, this.mImageId).then(() => {
        this.mCameraID = cameraID
      })
    }
    return true
  }

  getScaleType(): ScaleType {
    return ScaleType.CENTER_CROP
  }
}