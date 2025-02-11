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

import { fileIo as fs, ReadOptions } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import {EglWrapper, GlWrapper} from 'effectapi/Index'
import MatrixUtils from '../utils/MatrixUtils';
import { TextureType } from 'effectapi/src/main/ets/components/MainPage';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { VideoEncodeHelper } from './VideoEncodeHelper';
import { photoAccessHelper } from '@kit.MediaLibraryKit';

enum VideoEncodeGLWriterStatus {
  STATE_BEGIN = 0,
  STATE_RECORDING,
  STATE_STOP,
  STATE_FINISH
}

export interface VideoEncodeGLWriterConfig {
  fileName: string;
  width: number;
  height: number;
  bitRate: number;
  frameRate: number;
}

export class VideoEncodeGLWriter{
  static readonly MAX_WIDTH_HEIGHT: number                              = 4096
  private mEglCore:EglWrapper | undefined
  private mGlUtils:GlWrapper | undefined
  private mEncodeHelper: VideoEncodeHelper = new VideoEncodeHelper()
  private status: number = VideoEncodeGLWriterStatus.STATE_FINISH
  private mCurFile: fs.File | undefined
  private mIsReady: boolean = false

  async start(config: VideoEncodeGLWriterConfig): Promise<boolean> {
    if (this.status == VideoEncodeGLWriterStatus.STATE_FINISH) {
      let options: photoAccessHelper.CreateOptions = {
        title: config.fileName != "" ? config.fileName : Date.now().toString()
      }
      let accessHelper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(getContext(this));
      let photoUri: string = await accessHelper.createAsset(photoAccessHelper.PhotoType.VIDEO, 'mp4', options);

      let fileFd = this.openFile(photoUri)
      if (fileFd > 0) {
        let ret = await this.mEncodeHelper.initWriter(fileFd, config.width, config.height, config.bitRate, config.frameRate)
        if (!ret) {
          this.closeFile()
          return false
        }

        this.status = VideoEncodeGLWriterStatus.STATE_BEGIN
        return ret
      }
    }
    return false
  }

  stop(): boolean {
    if (this.status == VideoEncodeGLWriterStatus.STATE_RECORDING) {
      this.status = VideoEncodeGLWriterStatus.STATE_STOP
      this.stopRecording()
      return true
    }
    return false
  }

  onVideoData(context: number, dstTexture: number, width: number, height: number, timestamp: number) {
    if (this.status == VideoEncodeGLWriterStatus.STATE_BEGIN) {
      this.startRecording(context)
    } else if (this.status == VideoEncodeGLWriterStatus.STATE_RECORDING) {
      this.frameAvailable(dstTexture, width, height, timestamp)
    }  else if (this.status == VideoEncodeGLWriterStatus.STATE_STOP) {
      this.stopRecording()
    }
  }

  getRecordVideoPath(): string | undefined {
    return this.mCurFile?.path
  }

  private startRecording(sharedContext: number){
    if (this.prepareEncoder(sharedContext)) {
      this.mIsReady = false
      this.mEncodeHelper?.startVideo().then(() => {
        this.mIsReady = true
      })
      this.status = VideoEncodeGLWriterStatus.STATE_RECORDING
    }
  }

  private prepareEncoder(sharedContext: number): boolean {
    if (this.mEncodeHelper.videoOutSurfaceId == "")
      return false

    this.mEglCore = new EglWrapper(this.mEncodeHelper.width, this.mEncodeHelper.height, new Number(this.mEncodeHelper.videoOutSurfaceId).valueOf(), sharedContext, true)
    this.mEglCore.makeCurrent()
    this.mGlUtils = new GlWrapper()
    return true
  }

  private stopRecording() {
    this.mEncodeHelper?.stopVideo()
    this.mEglCore?.release()
    this.closeFile()
    this.status = VideoEncodeGLWriterStatus.STATE_FINISH
    this.mIsReady = false
  }

  private frameAvailable(dstTexture: number, width: number, height: number, timestamp: number) {
    if (this.mEglCore && this.mIsReady) {
      this.mEglCore.setTimestamp(timestamp)
      this.mEglCore?.makeCurrent()
      let tmp2 = new MatrixUtils()
      //hilog.info(0xFF, "VideoEncodeHelper", "setTimestamp: " + timestamp)
      this.mGlUtils?.renderTexture(TextureType.TextureType2D, dstTexture, width, height, tmp2.flip(false, true).getData())
      this.mEglCore.swap()
    }
  }

  private openFile(filePath: string): number {
    if (this.mCurFile)
      this.closeFile()

    //let context = getContext(this) as common.UIAbilityContext;
    //let filePath = context.filesDir + fileName
    if (fs.accessSync(filePath)) {
      fs.unlinkSync(filePath)
    }

    this.mCurFile = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
    return this.mCurFile.fd
  }

  private closeFile() {
    if (this.mCurFile) {
      fs.closeSync(this.mCurFile);
      this.mCurFile = undefined
    }
  }
}
