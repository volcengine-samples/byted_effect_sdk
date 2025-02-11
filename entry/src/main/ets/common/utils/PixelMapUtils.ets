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

import { image } from "@kit.ImageKit";
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class PixelMapUtils {
  savePixelmap(pixelMap: image.PixelMap, callback: ((isTrue :boolean)=>void)): void{
    let imageInfo = pixelMap.getImageInfoSync()
    const imagePackerApi = image.createImagePacker();
    let options: photoAccessHelper.CreateOptions = {
      title: Date.now().toString()
    }
    let accessHelper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(getContext(this))

    accessHelper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg', options).then((photoUri: string) => {
      let file = fs.openSync(photoUri, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      if (file.fd > 0) {
        let packOpts: image.PackingOption = { format: "image/jpeg", quality: 98 };
        imagePackerApi.packToFile(pixelMap, file.fd, packOpts).then(() => {
          fs.closeSync(file)
          imagePackerApi.release()
          pixelMap.release()
          callback(true)
        }).catch((error: BusinessError) => {
          callback(false)
        })
      } else {
        callback(false)
      }
    })
  }
}