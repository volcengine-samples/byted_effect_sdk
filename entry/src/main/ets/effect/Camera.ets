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


import camera from '@ohos.multimedia.camera'
import { BusinessError } from '@kit.BasicServicesKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { Constants } from '../common/Constants'

export class LocalCameraManager {
  private mCameraManager: camera.CameraManager | undefined = undefined;
  private mCameraDevices: Array<camera.CameraDevice> | Array<camera.CameraDevice> = [];
  private mCaptureSession: camera.PhotoSession | undefined = undefined;
  private mCameraInput: camera.CameraInput | undefined = undefined;
  private mPreviewOutput: camera.PreviewOutput | undefined = undefined;
  private mPhotoOutput: camera.PhotoOutput | undefined = undefined;
  private mHandlePhotoAssetCB: (photoAsset: photoAccessHelper.PhotoAsset) => void = () => {};
  private mCurCameraDevice: camera.CameraDevice | undefined = undefined;
  private mCurSceneMode: camera.SceneMode = camera.SceneMode.NORMAL_PHOTO;

  // mCameraManager: camera.CameraManager
  constructor(context:Context) {
    // 获取相机管理器实例
    this.mCameraManager = this.getCameraManagerFn(context)
    // 获取支持指定的相机设备对象
    this.mCameraDevices = this.getSupportedCamerasFn(this.mCameraManager!)
  }

  async openCamera(cameraIndex:number, requestSize:camera.Size, surfaceId:string) {
    console.debug(Constants.TAG, `initCamera cameraDeviceIndex: ${cameraIndex}`);
    try{
      await this.releaseCamera();
      this.mCurCameraDevice = this.mCameraDevices[cameraIndex];
      let isSupported = this.isSupportedSceneMode(this.mCameraManager!, this.mCurCameraDevice);
      if (!isSupported) {
        console.error(Constants.TAG, 'The current scene mode is not supported.');
        return;
      }
      let cameraOutputCapability =
        this.mCameraManager!.getSupportedOutputCapability(this.mCurCameraDevice, this.mCurSceneMode);
      let previewProfile = this.getPreviewProfile(cameraOutputCapability, requestSize);
      if (previewProfile === undefined) {
        console.error(Constants.TAG, 'The resolution of the current preview stream is not supported.');
        return;
      }
      // 创建previewOutput输出对象
      this.mPreviewOutput = this.createPreviewOutputFn(this.mCameraManager!, previewProfile, surfaceId);
      if (this.mPreviewOutput === undefined) {
        console.error(Constants.TAG, 'Failed to create the preview stream.');
        return;
      }
      this.previewOutputCallBack(this.mPreviewOutput);
      if (this.mCurSceneMode === camera.SceneMode.NORMAL_PHOTO) {
        let photoProfile = this.getPhotoProfile(cameraOutputCapability, requestSize);
        if (photoProfile === undefined) {
          console.error(Constants.TAG, 'The resolution of the current photo stream is not supported.');
          return;
        }
        // 创建photoOutPut输出对象
        this.mPhotoOutput = this.createPhotoOutputFn(this.mCameraManager!, photoProfile);
        if (this.mPhotoOutput === undefined) {
          console.error(Constants.TAG, 'Failed to create the photo stream.');
          return;
        }
      } else {
        console.error(Constants.TAG, 'Scene Mode Selected is not supported yet.');
        return;
      }
      // 创建cameraInput输出对象
      this.mCameraInput = this.createCameraInputFn(this.mCameraManager!, this.mCurCameraDevice);
      if (this.mCameraInput === undefined) {
        console.error(Constants.TAG, 'Failed to create the camera input.');
        return;
      }
      // 打开相机
      let isOpenSuccess = await this.cameraInputOpenFn(this.mCameraInput);
      if (!isOpenSuccess) {
        console.error(Constants.TAG, 'Failed to open the camera.');
        return;
      }
      // 镜头状态回调
      this.onCameraStatusChange(this.mCameraManager!);
      // 监听CameraInput的错误事件
      this.onCameraInputChange(this.mCameraInput, this.mCurCameraDevice);
      // 会话流程
      await this.sessionFlowFn(this.mCameraManager!, this.mCameraInput, this.mPreviewOutput, this.mPhotoOutput);
    } catch (error) {
      let err = error as BusinessError;
      console.error(Constants.TAG, `initCamera fail: ${JSON.stringify(err)}`);
    }
  }

  async releaseCamera(): Promise<void> {
    console.info(Constants.TAG, 'releaseCamera is called');
    try {
      await this.mPreviewOutput?.release();
    } catch (error) {
      let err = error as BusinessError;
      console.error(Constants.TAG, `previewOutput release fail: error: ${JSON.stringify(err)}`);
    } finally {
      this.mPreviewOutput = undefined;
    }
    try {
      await this.mPhotoOutput?.release();
    } catch (error) {
      let err = error as BusinessError;
      console.error(Constants.TAG, `photoOutput release fail: error: ${JSON.stringify(err)}`);
    } finally {
      this.mPhotoOutput = undefined;
    }

    try {
      await this.mCaptureSession?.release();
    } catch (error) {
      let err = error as BusinessError;
      console.error(Constants.TAG, `captureSession release fail: error: ${JSON.stringify(err)}`);
    } finally {
      this.mCaptureSession = undefined;
    }
    try {
      await this.mCameraInput?.close();
    } catch (error) {
      let err = error as BusinessError;
      console.error(Constants.TAG, `cameraInput close fail: error: ${JSON.stringify(err)}`);
    } finally {
      this.mCameraInput = undefined;
    }
    this.offCameraStatusChange();
    console.info(Constants.TAG, 'releaseCamera success');
  }

  setSceneMode(sceneMode: camera.SceneMode): void {
    this.mCurSceneMode = sceneMode;
  }

  getSceneMode(): camera.SceneMode {
    return this.mCurSceneMode;
  }

  getPreviewProfile(cameraOutputCapability: camera.CameraOutputCapability, requestSize:camera.Size): camera.Profile | undefined {
    let previewProfiles = cameraOutputCapability.previewProfiles;
    if (previewProfiles.length < 1) {
      return undefined;
    }
    // currently only consider yuv input
    let index = previewProfiles.findIndex((previewProfile: camera.Profile) => {
      console.log("相机支持分辨率", previewProfile.size.width, previewProfile.size.height);
      return previewProfile.size.width === requestSize.width &&
        previewProfile.size.height === requestSize.height &&
        previewProfile.format === camera.CameraFormat.CAMERA_FORMAT_YUV_420_SP;
    });
    if (index === -1) {
      return undefined;
    }
    return previewProfiles[index];
  }

  getPhotoProfile(cameraOutputCapability: camera.CameraOutputCapability, requestSize:camera.Size): camera.Profile | undefined {
    let photoProfiles = cameraOutputCapability.photoProfiles;
    if (photoProfiles.length < 1) {
      return undefined;
    }
    // save photo with jpeg format
    let index = photoProfiles.findIndex((photoProfile: camera.Profile) => {
      return photoProfile.size.width === requestSize.width &&
        photoProfile.size.height === requestSize.height &&
        photoProfile.format === camera.CameraFormat.CAMERA_FORMAT_JPEG;
    });
    if (index === -1) {
      return undefined;
    }
    return photoProfiles[index];
  }

  isSupportedSceneMode(cameraManager: camera.CameraManager, cameraDevice: camera.CameraDevice): boolean {
    let sceneModes = cameraManager.getSupportedSceneModes(cameraDevice);
    if (sceneModes === undefined) {
      return false;
    }
    let index = sceneModes.findIndex((sceneMode: camera.SceneMode) => {
      return sceneMode === this.mCurSceneMode;
    });
    if (index === -1) {
      return false;
    }
    return true;
  }

  getCameraManagerFn(context:Context): camera.CameraManager | undefined {
    if (this.mCameraManager) {
      return this.mCameraManager;
    }
    let cameraManager: camera.CameraManager | undefined = undefined;
    try {
      cameraManager = camera.getCameraManager(context);
      console.info(Constants.TAG, `getCameraManager success: ${cameraManager}`);
    } catch (error) {
      let err = error as BusinessError;
      console.error(Constants.TAG, `getCameraManager failed: ${JSON.stringify(err)}`);
    }
    return cameraManager;
  }

  getSupportedCamerasFn(cameraManager: camera.CameraManager): Array<camera.CameraDevice> {
    let supportedCameras: Array<camera.CameraDevice> = [];
    try {
      supportedCameras = cameraManager.getSupportedCameras();
      console.info(Constants.TAG, `getSupportedCameras success: ${supportedCameras}, length: ${supportedCameras.length}`);
    } catch (error) {
      let err = error as BusinessError;
      console.error(Constants.TAG, `getSupportedCameras failed: ${JSON.stringify(err)}`);
    }
    return supportedCameras;
  }

  createPreviewOutputFn(cameraManager: camera.CameraManager, previewProfileObj: camera.Profile,
    surfaceId: string): camera.PreviewOutput | undefined {
    let previewOutput: camera.PreviewOutput | undefined = undefined;
    try {
      previewOutput = cameraManager.createPreviewOutput(previewProfileObj, surfaceId);
      console.info(Constants.TAG, `createPreviewOutput success: ${previewOutput}`);
    } catch (error) {
      let err = error as BusinessError;
      console.error(Constants.TAG, `createPreviewOutput failed: ${JSON.stringify(err)}`);
    }
    return previewOutput;
  }

  previewOutputCallBack(previewOutput: camera.PreviewOutput): void {
    console.info(Constants.TAG, 'previewOutputCallBack is called');
    try {
      previewOutput.on('frameStart', (): void => {
        console.debug(Constants.TAG, 'Preview frame started');
      });
      previewOutput.on('frameEnd', (): void => {
        console.debug(Constants.TAG, 'Preview frame ended');
      });
      previewOutput.on('error', (previewOutputError: BusinessError): void => {
        console.info(Constants.TAG, `Preview output previewOutputError: ${JSON.stringify(previewOutputError)}`);
      });
    } catch (err) {
      console.error(Constants.TAG, 'previewOutputCallBack error');
    }
  }

  createPhotoOutputFn(cameraManager: camera.CameraManager,
    photoProfileObj: camera.Profile): camera.PhotoOutput | undefined {
    let photoOutput: camera.PhotoOutput | undefined = undefined;
    try {
      photoOutput = cameraManager.createPhotoOutput(photoProfileObj);
      console.info(Constants.TAG, `createPhotoOutputFn success: ${photoOutput}`);
    } catch (error) {
      let err = error as BusinessError;
      console.error(Constants.TAG, `createPhotoOutputFn failed: ${JSON.stringify(err)}`);
    }
    return photoOutput;
  }

  createCameraInputFn(cameraManager: camera.CameraManager,
    cameraDevice: camera.CameraDevice): camera.CameraInput | undefined {
    console.info(Constants.TAG, 'createCameraInputFn is called.');
    let cameraInput: camera.CameraInput | undefined = undefined;
    try {
      cameraInput = cameraManager.createCameraInput(cameraDevice);
      console.info(Constants.TAG, 'createCameraInputFn success');
    } catch (error) {
      let err = error as BusinessError;
      console.error(Constants.TAG, `createCameraInputFn failed: ${JSON.stringify(err)}`);
    }
    return cameraInput;
  }

  async cameraInputOpenFn(cameraInput: camera.CameraInput): Promise<boolean> {
    let isOpenSuccess = false;
    try {
      await cameraInput.open();
      isOpenSuccess = true;
      console.info(Constants.TAG, 'cameraInput open success');
    } catch (error) {
      let err = error as BusinessError;
      console.error(Constants.TAG, `createCameraInput failed : ${JSON.stringify(err)}`);
    }
    return isOpenSuccess;
  }

  onCameraStatusChange(cameraManager: camera.CameraManager): void {
    console.info(Constants.TAG, 'onCameraStatusChange is called');
    try {
      cameraManager.on('cameraStatus', this.registerCameraStatusChange);
    } catch (error) {
      console.error(Constants.TAG, 'onCameraStatusChange error');
    }
  }

  // 注册相机状态变化的回调函数
  registerCameraStatusChange(err: BusinessError, cameraStatusInfo: camera.CameraStatusInfo): void {
    console.info(Constants.TAG, `cameraId: ${cameraStatusInfo.camera.cameraId},status: ${cameraStatusInfo.status}`);
  }

  onCameraInputChange(cameraInput: camera.CameraInput, cameraDevice: camera.CameraDevice): void {
    console.info(Constants.TAG, `onCameraInputChange is called`);
    try {
      cameraInput.on('error', cameraDevice, (cameraInputError: BusinessError): void => {
        console.info(Constants.TAG, `onCameraInputChange cameraInput error code: ${cameraInputError.code}`);
      });
    } catch (error) {
      console.error(Constants.TAG, 'onCameraInputChange error');
    }
  }

  async sessionFlowFn(cameraManager: camera.CameraManager, cameraInput: camera.CameraInput,
    previewOutput: camera.PreviewOutput, photoOutput: camera.PhotoOutput | undefined): Promise<void> {
    try {
      // 创建CaptureSession实例
      if (this.mCurSceneMode === camera.SceneMode.NORMAL_PHOTO) {
        this.mCaptureSession = cameraManager.createSession(this.mCurSceneMode) as camera.PhotoSession;
      }
      if (this.mCaptureSession === undefined) {
        return;
      }
      this.onSessionErrorChange(this.mCaptureSession);
      // 开始配置会话
      this.mCaptureSession.beginConfig();
      // 把CameraInput加入到会话
      this.mCaptureSession.addInput(cameraInput);
      // 把previewOutput加入到会话
      this.mCaptureSession.addOutput(previewOutput);
      if (this.mCurSceneMode === camera.SceneMode.NORMAL_PHOTO) {
        if (photoOutput === undefined) {
          return;
        }
        // 拍照监听事件
        this.photoOutputCallBack(photoOutput);
        // 把photoOutPut加入到会话
        this.mCaptureSession.addOutput(photoOutput);
      }
      // 提交配置信息
      await this.mCaptureSession.commitConfig();
      this.setFocusMode(camera.FocusMode.FOCUS_MODE_CONTINUOUS_AUTO);
      // 开始会话工作
      await this.mCaptureSession.start();
      console.info(Constants.TAG, 'sessionFlowFn success');
    } catch (error) {
      let err = error as BusinessError;
      console.error(Constants.TAG, `sessionFlowFn fail : ${JSON.stringify(err)}`);
    }
  }

  onSessionErrorChange(session: camera.PhotoSession | camera.VideoSession): void {
    try {
      session.on('error', (captureSessionError: BusinessError): void => {
        console.info(Constants.TAG,
          'onCaptureSessionErrorChange captureSession fail: ' + JSON.stringify(captureSessionError.code));
      });
    } catch (error) {
      console.error(Constants.TAG, 'onCaptureSessionErrorChange error');
    }
  }

  photoOutputCallBack(photoOutput: camera.PhotoOutput): void {
    try {
      // 监听拍照开始
      photoOutput.on('captureStartWithInfo', (err: BusinessError, captureStartInfo: camera.CaptureStartInfo): void => {
        console.info(Constants.TAG, `photoOutputCallBack captureStartWithInfo success: ${JSON.stringify(captureStartInfo)}`);
      });
      // 监听拍照帧输出捕获
      photoOutput.on('frameShutter', (err: BusinessError, frameShutterInfo: camera.FrameShutterInfo): void => {
        console.info(Constants.TAG, `photoOutputCallBack frameShutter captureId:
          ${frameShutterInfo.captureId}, timestamp: ${frameShutterInfo.timestamp}`);
      });
      // 监听拍照结束
      photoOutput.on('captureEnd', (err: BusinessError, captureEndInfo: camera.CaptureEndInfo): void => {
        console.info(Constants.TAG, `photoOutputCallBack captureEnd captureId:
          ${captureEndInfo.captureId}, frameCount: ${captureEndInfo.frameCount}`);
      });
      // 监听拍照异常
      photoOutput.on('error', (data: BusinessError): void => {
        console.info(Constants.TAG, `photoOutPut data: ${JSON.stringify(data)}`);
      });
      photoOutput.on('photoAssetAvailable', (err: BusinessError, photoAsset: photoAccessHelper.PhotoAsset) => {
        console.info(Constants.TAG, 'photoAssetAvailable begin');
        if (photoAsset === undefined) {
          console.error(Constants.TAG, 'photoAsset is undefined');
          return;
        }
        this.mHandlePhotoAssetCB(photoAsset);
      });
    } catch (err) {
      console.error(Constants.TAG, 'photoOutputCallBack error');
    }
  }

  // TODO: remains to be done
  setSavePictureCallback(callback: (photoAsset: photoAccessHelper.PhotoAsset) => void): void {
    this.mHandlePhotoAssetCB = callback;
  }

  setFocusPoint(point: camera.Point): void {
    // 设置焦点
    this.mCaptureSession?.setFocusPoint(point);
    console.info(Constants.TAG, `setFocusPoint success point: ${JSON.stringify(point)}`);
    // 获取当前的焦点
    let nowPoint: camera.Point | undefined = undefined;
    nowPoint = this.mCaptureSession?.getFocusPoint();
    console.info(Constants.TAG, `getFocusPoint success, nowPoint: ${JSON.stringify(nowPoint)}`);
  }

  setFocusMode(focusMode: camera.FocusMode): void {
    // 检测对焦模式是否支持
    console.info(Constants.TAG, `setFocusMode is called`);
    let isSupported = this.mCaptureSession?.isFocusModeSupported(focusMode);
    console.info(Constants.TAG, `setFocusMode isSupported: ${isSupported}`);
    // 设置对焦模式
    if (!isSupported) {
      return;
    }
    this.mCaptureSession?.setFocusMode(focusMode);
  }

  offCameraStatusChange(): void {
    console.info(Constants.TAG, 'offCameraStatusChange is called');
    this.mCameraManager?.off('cameraStatus', this.registerCameraStatusChange);
  }
}