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

import { ImageSourceProvider, ImageSourceType } from './ImageSourceProvider';
import { media } from '@kit.MediaKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import hilog from '@ohos.hilog';
import { BusinessError } from '@kit.BasicServicesKit';
import { ScaleType } from '../utils/MatrixUtils';

export class VideoSourceImpl implements  ImageSourceProvider{
  private surfaceID: number = 0;
  private fileSize: number = -1;
  private file: fs.File | undefined;
  private count: number = 0;
  private avPlayer: media.AVPlayer | undefined
  private bIsReady: boolean = false
  private onVideoEnd: (() => void) | undefined
  private onPrepared: ((width: number, height: number) => void) | undefined
  constructor(onVideoEnd: (() => void) | undefined, onPrepared?: ((width: number, height: number) => void) | undefined) {
    this.onVideoEnd = onVideoEnd
    this.onPrepared = onPrepared
  }

  private setAVPlayerCallback(avPlayer: media.AVPlayer) {
    this.avPlayer = avPlayer
    avPlayer.on('startRenderFrame', () => {
      hilog.error(0xFF, 'EffectARSDK', 'AVPlayer start render frame');
    })

    avPlayer.on('error', (err: BusinessError) => {
      hilog.error(0xFF, 'EffectARSDK', 'Invoke avPlayer failed, code is ${err.code}, message is ${err.message}');
      avPlayer.reset(); // 调用reset重置资源，触发idle状态
    })

    avPlayer.on('stateChange', async (state: string, reason: media.StateChangeReason) => {
      switch (state) {
        case 'idle':
          hilog.error(0xFF, 'EffectARSDK', 'AVPlayer state idle called.');
          break;
        case 'initialized': // avplayer 设置播放源后触发该状态上报
          hilog.error(0xFF, 'EffectARSDK','AVPlayer state initialized called.');
          avPlayer.surfaceId = this.surfaceID.toString(); // 设置显示画面，当播放的资源为纯音频时无需设置
          avPlayer.prepare();
          break;
        case 'prepared': // prepare调用成功后上报该状态机
          hilog.error(0xFF, 'EffectARSDK','AVPlayer state prepared called.');
          if (this.onPrepared) {
            this.onPrepared(this.getWidth(), this.getHeight())
          }
          avPlayer.play(); // 调用播放接口开始播放
          break;
        case 'playing': // play成功调用后触发该状态机上报
          hilog.error(0xFF, 'EffectARSDK', 'AVPlayer state playing called.');
          this.count++;
          if (!this.bIsReady) {
            avPlayer.pause()
            this.bIsReady = true
          }
          break;
        case 'paused': // pause成功调用后触发该状态机上报
          hilog.error(0xFF, 'EffectARSDK', 'AVPlayer state paused called.');
          break;
        case 'completed': // 播放结束后触发该状态机上报
          hilog.error(0xFF, 'EffectARSDK', 'AVPlayer state completed called.');
          avPlayer.stop()
          break;
        case 'stopped': // stop接口成功调用后触发该状态机上报
          hilog.error(0xFF, 'EffectARSDK', 'AVPlayer state stopped called.');
          if (this.onVideoEnd)
            this.onVideoEnd()

          this.bIsReady = false
          break;
        case 'released':
          hilog.error(0xFF, 'EffectARSDK', 'AVPlayer state released called.');
          break;
        default:
          hilog.error(0xFF, 'EffectARSDK', 'AVPlayer state unknown called.');
          break;
      }
    })
  }

  getType(): ImageSourceType{
    return ImageSourceType.IMAGE_SOURCE_VIDEO
  }

  async open(surfaceId: number, path: string | number | object) {
    this.surfaceID = surfaceId
    this.bIsReady = false
    if (typeof path === 'string') {
      media.createAVPlayer().then((avPlayer: media.AVPlayer) => {
        this.setAVPlayerCallback(avPlayer);
        this.file = fs.openSync(path);
        let fdPath = 'fd://' + this.file.fd;
        avPlayer.url = fdPath;
      })
    }
  }

  play(): boolean{
    if (this.isReady()) {
      this.avPlayer?.play()
      return true
    }
    return false
  }

  close(){
    if (this.avPlayer) {
      this.avPlayer.release()
    }
    this.avPlayer = undefined
  }

  isReady(): boolean {
    return this.bIsReady
  }

  getWidth(){
    if (this.avPlayer) {
      return this.avPlayer.width
    }
    return 0
  }

  getHeight(){
    if (this.avPlayer) {
      return this.avPlayer.height
    }
    return 0
  }

  getOrientation(){
    return 0
  }

  isFront(){
    return false
  }

  getScaleType(): ScaleType {
    return ScaleType.CENTER_INSIDE
  }

}