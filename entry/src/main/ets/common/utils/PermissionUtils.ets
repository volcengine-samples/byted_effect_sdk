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

import { abilityAccessCtrl, Permissions, bundleManager } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';

class PermissionUtils {
  static checkPermissionAndRequest(context: Context, permissions: Array<Permissions>, callback:()=>void, failCallback?:()=>void): number {
    let atManager = abilityAccessCtrl.createAtManager()
    let grantStatus: abilityAccessCtrl.GrantStatus = abilityAccessCtrl.GrantStatus.PERMISSION_DENIED

    let tokenID:number = 0;
    try {
      let bundleInfo: bundleManager.BundleInfo =  bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
      let appInfo: bundleManager.ApplicationInfo = bundleInfo.appInfo
      tokenID = appInfo.accessTokenId
      let bundleId = bundleInfo.name
      console.error("bundleId: ", bundleId)
      // let bundleId: string = bundleInfo.
    } catch (e) {
      console.error('error %{e}');
    }

    try {
      for (let p of permissions) {
        grantStatus += atManager.checkAccessTokenSync(tokenID, p)
        if (grantStatus < 0) {
          console.error("lack of " + p + " authorization !!!")
        }
      }
      if (grantStatus < 0) {
        atManager.requestPermissionsFromUser(context, permissions).then((data)=>{
          let authStatus = 0
          for (let index = 0; index < data.authResults.length; index++) {
            if (data.authResults[index] == -1) {
              promptAction.showToast({
                message:data.permissions[index] + " not auth",
              })
            } else {
              authStatus ++;
            }
          }
          // get all needed auths
          if (authStatus == data.authResults.length) {
            callback()
          } else {
            if (failCallback) failCallback()
          }
        })
      }
    } catch (e) {
      console.error('error %{e}');
      if (failCallback) failCallback()
    }
    return grantStatus
  }
}

export default PermissionUtils;