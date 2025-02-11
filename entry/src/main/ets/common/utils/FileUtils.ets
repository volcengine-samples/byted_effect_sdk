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

import fs from '@ohos.file.fs';
import { Context } from '@ohos.arkui.UIContext';
import { bundleManager } from '@kit.AbilityKit';
import { taskpool } from '@kit.ArkTS';

@Concurrent
function copyFile(context:Context, srcFile: string, dstFilePath: string){
  let resourceManager =  context.resourceManager
  let content:Uint8Array = resourceManager.getRawFileContentSync(srcFile)
  // console.log('dst file path is ', dstFilePath);
  let dstFile = fs.openSync(dstFilePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
  fs.writeSync(dstFile.fd, content.buffer)
  fs.closeSync(dstFile)
}

export default class FileUtils{
  static kVersion = "version.txt"
  static kLicenseDir = "LicenseBag.bundle"
  static kModelsDir = "ModelResource.bundle"
  static kComposerDir = "ComposeMakeup.bundle/ComposeMakeup"
  static kStickerDir = "StickerResource.bundle"
  static kFilterDir = "FilterResource.bundle/Filter"
  static kLicenseFileName = 'labcv_test_20241201_20250331_com.effectsar.labcv.demo_4.6.2_ohos.licbag'

  static kFilesDir = ""

  static async copyDirs(context:Context, srcDir:string, dstDir:string): Promise<object> {
    let resourceManager =  context.resourceManager
    let fileList = resourceManager.getRawFileListSync(srcDir)
    let tasks: Promise<object>[] = [];
    try {
      for (let file of fileList) {
        let srcFile = srcDir + file
        if (resourceManager.isRawDir(srcFile)) {
          let tmpDstDir = dstDir + "/" + file
          if (!fs.accessSync(tmpDstDir, fs.AccessModeType.EXIST)) {
            fs.mkdirSync(tmpDstDir)
          }
          tasks.push(FileUtils.copyDirs(context, srcFile + '/', tmpDstDir))
          continue;
        }
        let dstFilePath = dstDir + '/' + file
        tasks.push(taskpool.execute(copyFile, context, srcFile, dstFilePath))
      }
      await Promise.all(tasks)
    } catch (e) {
      console.log("error", e)
    }
    return resourceManager
  }

  static getSdkVersionInFile(context:Context): string {
    let version = ""

    let fileDir = context.filesDir
    let versionFile = fileDir + "/"  + FileUtils.kVersion

    try {
      if (!fs.accessSync(versionFile, fs.AccessModeType.EXIST)){
        return version
      }
      let content = fs.readTextSync(versionFile)
      version = content
    }catch (e) {
    }
    return version
  }

  static getSdkVersion(): string {
    let curVersion = ""
    try {
      let bundleInfo =  bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
      curVersion = bundleInfo.versionName
    } catch (e) {
    }
    return curVersion
  }

  static writeVersion(context:Context, version:string){
    let fileDir = context.filesDir
    let versionFile = fileDir + "/"  + FileUtils.kVersion
    let dstFile = fs.openSync(versionFile, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
    fs.writeSync(dstFile.fd, version)
    fs.closeSync(dstFile)
  }

  static async copyResourceIfNeeded(context:Context) {
    let curVersion = FileUtils.getSdkVersion()
    let versionInDisk = FileUtils.getSdkVersionInFile(context)
    FileUtils.kFilesDir = context.filesDir // 第一次进入的时候做保存

    if (versionInDisk == "" || versionInDisk != curVersion) {
      return FileUtils.copyDirs(context, "", context.filesDir)
    }
    return 0
  }

  static getLicensePath(): string {
    return FileUtils.kFilesDir + "/" + FileUtils.kLicenseDir + "/" + FileUtils.kLicenseFileName
  }

  static getModelFilePath(): string {
    return FileUtils.kFilesDir + "/" + FileUtils.kModelsDir
  }

  static getComposerPath(effect:string, isFilter:boolean): string {
    if(isFilter == false){
      return FileUtils.kFilesDir + "/" + FileUtils.kComposerDir + "/" + effect
    }else{
      return FileUtils.getFilterPath(effect)
    }
  }

  static getStickerPath(effect:string): string {
    return FileUtils.kFilesDir + "/" + FileUtils.kStickerDir + "/" + effect
  }

  static getFilterPath(effect:string) {
    return FileUtils.kFilesDir + "/" + FileUtils.kFilterDir + "/" + effect
  }
}