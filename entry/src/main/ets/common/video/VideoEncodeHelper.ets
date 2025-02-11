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

import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';

class VideoSize {
  width: number = 0
  height: number = 0

  constructor(width: number, height: number) {
    this.width = width
    this.height = height
  }
}

export class VideoEncodeHelper {
  static readonly MAX_WIDTH_HEIGHT: number                              = 4096
  videoOutSurfaceId: string = ""
  width: number = 0
  height: number = 0
  private avRecorder: media.AVRecorder | undefined = undefined;
  private avProfile: media.AVRecorderProfile = {
    fileFormat : media.ContainerFormatType.CFT_MPEG_4, // 视频文件封装格式，只支持MP4
    videoBitrate : 100000, // 视频比特率
    videoCodec : media.CodecMimeType.VIDEO_AVC, // 视频文件编码格式，支持avc格式
    videoFrameWidth : 640,  // 视频分辨率的宽
    videoFrameHeight : 480, // 视频分辨率的高
    videoFrameRate : 30 // 视频帧率
  }

  private avConfig: media.AVRecorderConfig = {
    videoSourceType : media.VideoSourceType.VIDEO_SOURCE_TYPE_SURFACE_YUV, // 视频源类型，支持YUV和ES两种格式
    profile : this.avProfile,
    url : 'fd://35', //  参考应用文件访问与管理开发示例新建并读写一个文件
    rotation : 0 // 视频旋转角度，默认为0不旋转，支持的值为0、90、180、270
  }

  private async genVideoSurfaceId(): Promise<boolean>{
    this.avRecorder = await media.createAVRecorder();
    if (this.avRecorder === undefined) {
      return false
    }

    try {
      await this.avRecorder.prepare(this.avConfig);
    } catch (error) {
      let err = error as BusinessError;
      return false
    }

    try {
      this.videoOutSurfaceId = await this.avRecorder.getInputSurface();
    } catch (error) {
      let err = error as BusinessError;
      return false
    }
    return true
  }

  private restrictSize(width: number, height: number): VideoSize{
    if (width > height && width > VideoEncodeHelper.MAX_WIDTH_HEIGHT) {
      height = VideoEncodeHelper.MAX_WIDTH_HEIGHT / width * height
      width = VideoEncodeHelper.MAX_WIDTH_HEIGHT

    } else if (height > width && height > VideoEncodeHelper.MAX_WIDTH_HEIGHT) {
      width = VideoEncodeHelper.MAX_WIDTH_HEIGHT / height * width
      height = VideoEncodeHelper.MAX_WIDTH_HEIGHT
    }
    return new VideoSize(width, height)
  }

  async initWriter(fileFd: number, width: number, height: number, bitRate: number, frameRate: number): Promise<boolean> {
    let size = this.restrictSize(width, height)
    this.width = size.width
    this.height = size.height
    this.avProfile.videoFrameWidth = this.width
    this.avProfile.videoFrameHeight = this.height
    this.avProfile.videoFrameRate = frameRate
    this.avProfile.videoBitrate = bitRate
    this.avConfig.url = 'fd://' + fileFd.toString()
    let ret = await this.genVideoSurfaceId()
    return ret
  }

  async startVideo(): Promise<void> {
    try {
      await this.avRecorder?.start();
    } catch (error) {
      let err = error as BusinessError;
    }
  }

  async stopVideo(): Promise<void> {
    try {
      this.videoOutSurfaceId = ""
      await this.avRecorder?.stop();
      await this.avRecorder?.release();
    } catch (error) {
      let err = error as BusinessError;
      console.error(`avRecorder stop error: ${JSON.stringify(err)}`);
    }
  }

}