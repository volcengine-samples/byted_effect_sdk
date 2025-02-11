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

import { EffectManagerData } from '../manager/EffectManagerData'
import { ComToolBar } from './common/ComToolBar'
import FileUtils from '../common/utils/FileUtils';
import EffectManager from '../effect/EffectManager'
import { ComposerNode } from '../modeldatas/ComposerNode'
import { TabItem, BaseEffectTabs, EffectTabsController } from './basecomponent/BaseEffectTabs'
import { hilog } from '@kit.PerformanceAnalysisKit';
import promptAction from '@ohos.promptAction'
import picker from '@ohos.file.picker';
import { BaseEffectGLPage } from './basecomponent/BaseEffectGLPage';
import { router } from '@kit.ArkUI';
import { ImageSourceType, ImageSourceConfig } from  '../common/imagesrc/ImageSourceProvider'
import { CameraSourceImpl } from  '../common/imagesrc/CameraSourceImpl'
import PermissionUtils from '../common/utils/PermissionUtils';

@Entry
@Component
struct EffectPage {
  @State mEffectManager: EffectManager | null = null
  @State showMenu:boolean = true
  @State isShowAblum: boolean = true
  @State mImageSourceConfig: ImageSourceConfig = new ImageSourceConfig()
  @State mVFps: number = 30
  @State mVRenderTimeCon: number = 30
  @State mVResolution: string = '720 * 1280'
  @State isPerformanceShow: boolean = false
  @State isIcPlayShow: boolean = false
  isRecord: boolean = false
  private effectManagerData: EffectManagerData = new EffectManagerData()
  private tabsItems: TabItem[] = []
  private effectType: string = "beauty"

  private effectChangedCallback:(nodes:Set<ComposerNode>)=>void = ()=>{}
  private effectIntensityChangedCallback:(nodes:Set<ComposerNode>)=>void = ()=>{}

  composerValueChangedCallback:((node:string, tag:string, value:number)=>void)|undefined
  composerChangedCallback:((node:string, add:boolean)=>void)|undefined

  private beautyItems: TabItem[] = [
    // new TabItem('套装', EffectManagerData.TYPE_BEAUTY_SUIT, this.effectManagerData.getItemsByType(EffectManagerData.TYPE_BEAUTY_SUIT)),
    new TabItem('美颜', EffectManagerData.TYPE_BEAUTY_FACE, this.effectManagerData.getItemsByType(EffectManagerData.TYPE_BEAUTY_FACE)),
    new TabItem('微整形', EffectManagerData.TYPE_BEAUTY_RESHAPE, this.effectManagerData.getItemsByType(EffectManagerData.TYPE_BEAUTY_RESHAPE)),
    //new TabItem('美体', EffectManagerData.TYPE_BEAUTY_BODY, this.effectManagerData.getItemsByType(EffectManagerData.TYPE_BEAUTY_BODY)),
    new TabItem('美妆', EffectManagerData.TYPE_MAKEUP, this.effectManagerData.getItemsByType(EffectManagerData.TYPE_MAKEUP)),
    new TabItem('滤镜', EffectManagerData.TYPE_FILTER, this.effectManagerData.getItemsByType(EffectManagerData.TYPE_FILTER)),
    new TabItem('画质', EffectManagerData.TYPE_PALETTE, this.effectManagerData.getItemsByType(EffectManagerData.TYPE_PALETTE)),
    //new TabItem('黑科技', EffectManagerData.TYPE_BLACK_TECHNOLOGY, this.effectManagerData.getItemsByType(EffectManagerData.TYPE_BLACK_TECHNOLOGY)),
  ];
  public stickersItems: TabItem[] = [
    new TabItem('AI 贴纸', EffectManagerData.TYPE_STICKER, this.effectManagerData.getItemsByType(EffectManagerData.TYPE_STICKER))
  ];
  public aigcItems: TabItem[] = [
    new TabItem('AIGC 封面', EffectManagerData.TYPE_STICKER, this.effectManagerData.getItemsByType(EffectManagerData.TYPE_AIGC))
  ];
  public styleItems: TabItem[] = [
    new TabItem('AI 美妆', EffectManagerData.TYPE_STYLE_MAKEUP, this.effectManagerData.getItemsByType(EffectManagerData.TYPE_STYLE_MAKEUP)),
  ];

  switchCameraCallback() {
    if (this.mEffectManager?.getImageSourceProvider()) {
      let cameraImpl = this.mEffectManager?.getImageSourceProvider() as CameraSourceImpl
      cameraImpl.switchCamera()
    }
  }

  updateComposerNodesCallback(nodes:Set<ComposerNode>) {
    let nodePaths = new Array<string>()
    for (let node of nodes) {
      let isFilter : boolean = (node.tag == "filter")
      nodePaths.push(FileUtils.getComposerPath(node.path, isFilter))
    }
    this.mEffectManager?.renderManager?.setComposerNodes(nodePaths)
  }

  updateComposerNodesIntensityCallback(nodes:Set<ComposerNode>) {
    for (let node of nodes) {
      for (let i = 0; i < node.keyArray.length; i++){
        let isFilter : boolean = (node.tag == "filter")
        this.mEffectManager?.renderManager?.updateComposerNode(FileUtils.getComposerPath(node.path, isFilter), node.keyArray[i], node.intensityArray[i])
      }
    }
  }

  setStickerCallback(nodes:Set<ComposerNode>) {
    let nodePaths: ComposerNode[] = Array.from(nodes);
    if (nodePaths.length > 0) {
      let nodePath = FileUtils.getStickerPath(nodePaths[0].path)
      this.mEffectManager?.renderManager?.setEffect(nodePath)
    } else {
      this.mEffectManager?.renderManager?.setEffect("")
    }
  }

  private isPicPath(filePath: string): boolean {
    const fileExt: string = filePath.substring(filePath.lastIndexOf('.'))
    if (fileExt.toLowerCase() === ".mp4") {
      return false
    }
    return true
  }

  onButtonClick(button: string) {
    if (button == "restoreDefault") {
      hilog.info(0xFF, "EffectPage", "button restoreDefault")
    } else if (button == "record") {
      if (this.mEffectManager)
        this.mEffectManager.mNeedCapture = true
      hilog.info(0xFF, "EffectPage", "button record")
    } else if (button == "back") {
      router.back();
      hilog.info(0xFF, "EffectPage", "button back")
    } else if (button == "ablum") {
      let photoPicker = new picker.PhotoViewPicker();
      photoPicker.select({
        MIMEType:picker.PhotoViewMIMETypes.IMAGE_VIDEO_TYPE,
        maxSelectNumber:1
      },(err, data)=> {
        if (err) {
          console.info("photoPicker:" + err.message)
          return
        }
        let picPaths = data.photoUris
        if (picPaths.length > 0) {
          console.info("picPath:" + picPaths[0])
          router.pushUrl({
            url: "pages/EffectPage",
            params: {
              imageSourceType: this.isPicPath(picPaths[0]) ? "image" :"video",
              videoSrcPath: picPaths[0],
              effectType: this.effectType
            }
          })
        }
      })
      hilog.info(0xFF, "EffectPage", "button ablum")
    } else if (button == "setting") {
      hilog.info(0xFF, "EffectPage", "button setting")
    } else if (button == "switchCamera") {
      this.switchCameraCallback()
      hilog.info(0xFF, "EffectPage", "button switchCamera")
    }
  }

  onButtonPress() {
    if (this.mImageSourceConfig.imageSourceType == ImageSourceType.IMAGE_SOURCE_CAMERA || this.mImageSourceConfig.imageSourceType == ImageSourceType.IMAGE_SOURCE_IMAGE) {
      this.mEffectManager?.startRecord('', 5, 30).then((isStart: boolean) => {
        if (isStart) {
          let showMsg = '开始录制, 文件保存在: ' + this.mEffectManager!.getRecordVideoPath()
          promptAction.showToast({ message: showMsg, duration: 1000, });
          hilog.info(0xFF, "OH_NativeWindow_NativeWindowHandleOpt", "isRecord true")
          this.isRecord = true
        } else {
          promptAction.showToast({ message: '录制失败，请稍后重试', duration: 2000, });
        }
      })
    }
  }

  onButtonPressFinish() {
    if (this.mImageSourceConfig.imageSourceType == ImageSourceType.IMAGE_SOURCE_CAMERA || this.mImageSourceConfig.imageSourceType == ImageSourceType.IMAGE_SOURCE_IMAGE) {
      this.mEffectManager?.stopRecord()
      let filepath = this.mEffectManager?.getRecordVideoPath()
      let showMsg = '停止录制, 视频已保存到相册'
      promptAction.showToast({ message: showMsg, duration: 2000, });
      this.isRecord = false
      hilog.info(0xFF, "OH_NativeWindow_NativeWindowHandleOpt", "isRecord false")
    }
  }

  // aboutToAppear -> build -> onPageShow
  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as Record<string, string>;
    if (params) {
      this.effectType = params.effectType as string;
      switch (this.effectType) {
        case "aigc":
          this.tabsItems = this.aigcItems; break;
        case "sticker":
          this.tabsItems = this.stickersItems; break;
        case "makeup":
          this.tabsItems = this.styleItems; break;
        default:
          this.tabsItems = this.beautyItems;
      }
      if (this.effectType == "sticker" || this.effectType == "aigc") {
        this.effectChangedCallback = this.setStickerCallback.bind(this)
      } else {
        this.effectChangedCallback = this.updateComposerNodesCallback.bind(this)
        this.effectIntensityChangedCallback = this.updateComposerNodesIntensityCallback.bind(this)
      }
    }
  }

  onPageShow() {
    PermissionUtils.checkPermissionAndRequest(getContext(this), ['ohos.permission.CAMERA', 'ohos.permission.READ_IMAGEVIDEO', 'ohos.permission.WRITE_IMAGEVIDEO'], ()=>{}, ()=>{ router.back() })
    const params = this.getUIContext().getRouter().getParams() as Record<string, string>;
    if (params) {
      const imageSourceType: string = params.imageSourceType as string;
      const videoSrcPath: string = params.videoSrcPath as string;
      if (imageSourceType == "video") {
        this.mImageSourceConfig.imageSourceType = ImageSourceType.IMAGE_SOURCE_VIDEO
        this.mImageSourceConfig.srcPath = videoSrcPath
        this.isIcPlayShow = true
      } else if (imageSourceType == "camera") {
        this.mImageSourceConfig.imageSourceType = ImageSourceType.IMAGE_SOURCE_CAMERA
      } else if (imageSourceType == "image") {
        this.mImageSourceConfig.imageSourceType = ImageSourceType.IMAGE_SOURCE_IMAGE
        this.mImageSourceConfig.srcPath = videoSrcPath
      }
    }
    this.isShowAblum = this.mImageSourceConfig.imageSourceType == ImageSourceType.IMAGE_SOURCE_CAMERA
    if (this.mEffectManager?.getImageSourceProvider()){
      if (this.mEffectManager.getNativeImageSurfaceId() != undefined)
        this.mEffectManager.getImageSourceProvider()!.open(this.mEffectManager.getNativeImageSurfaceId()!,
          this.isShowAblum ? (this.mEffectManager.getImageSourceProvider()!.isFront() ? 1 : 0) : this.mImageSourceConfig.srcPath)
    }
  }

  onPageHide() {
    this.mEffectManager?.getImageSourceProvider()?.close()
  }

  build() {
    RelativeContainer() {
      BaseEffectGLPage({
        isIcPlayShow: this.isIcPlayShow,
        mImageSourceConfig: this.mImageSourceConfig,
        mEffectManager: this.mEffectManager,
        oViewClick: () => {
          if (this.showMenu)
            this.showMenu = false
        },
        onPerformanceCallBack: (fps: number, renderTimeCon: number, resolution: string) => {
          this.mVFps = fps
          this.mVRenderTimeCon = renderTimeCon
          this.mVResolution = resolution
        }
      }).alignRules({
        top: { anchor: '__container__', align: VerticalAlign.Top },
        bottom: { anchor: '__container__', align: VerticalAlign.Bottom }
      })

      ComToolBar({
        isPerformanceShow: this.isPerformanceShow,
        isShowAblum: this.isShowAblum,
        onButtonClick: this.onButtonClick.bind(this)
      }).id("comToolBar1")
        .alignRules({
          top: { anchor: '__container__', align: VerticalAlign.Top }
        })
      if (this.isPerformanceShow) {
        Flex({
          direction: FlexDirection.Column,
          justifyContent: FlexAlign.Start,
        }) {
          Text('FPS: ' + this.mVFps).fontColor(Color.White).fontSize(12).height(18)
          Text('渲染时间: ' + this.mVRenderTimeCon).fontColor(Color.White).fontSize(12).height(18)
          Text('输入分辨率: ' + this.mVResolution).fontColor(Color.White).fontSize(12).height(18)
        }.margin({ left: 30 })
        .alignRules({
          'top': { 'anchor': 'comToolBar1', 'align': VerticalAlign.Bottom },
          'left': { 'anchor': 'comToolBar1', 'align': HorizontalAlign.Start }
        })
      }

      BaseEffectTabs({
        showMenu: this.showMenu,
        tabsItems: this.tabsItems,
        onButtonClick: this.onButtonClick.bind(this),
        mController: new EffectTabsController(this.effectChangedCallback, this.effectIntensityChangedCallback),
        onButtonPress: this.onButtonPress.bind(this),
        onButtonPressFinish: this.onButtonPressFinish.bind(this)
      }).alignRules({
        bottom: { anchor: '__container__', align: VerticalAlign.Bottom }
      })
    }
  }
}
