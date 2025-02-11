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

import { MatrixUtils, ScaleType } from '../utils/MatrixUtils';

export enum ImageSourceType {
  IMAGE_SOURCE_CAMERA = 0,
  IMAGE_SOURCE_VIDEO,
  IMAGE_SOURCE_IMAGE,
}

export class ImageSourceConfig{
  imageSourceType: ImageSourceType = ImageSourceType.IMAGE_SOURCE_CAMERA
  srcPath: string = ""
}

export interface ImageSourceProvider {
  open: (surfaceId: number, media: number | string | object) => void
  close: () => void
  getType: () => ImageSourceType
  getWidth: () => number
  getHeight: () => number
  getOrientation: () => number
  isFront: () => boolean
  getScaleType: () => ScaleType
}