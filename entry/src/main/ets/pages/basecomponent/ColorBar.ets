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

import {ColorItem, EffectButtonItem } from '../../modeldatas/EffectButtonItem'

export  class ColorBarCreaterParams {
  groupItem: EffectButtonItem
  colorItemChangeCallBack: (()=>void)
  constructor(groupItem: EffectButtonItem, colorItemChangeCallBack: (()=>void)) {
    this.groupItem = groupItem
    this.colorItemChangeCallBack = colorItemChangeCallBack
  }
}

@Observed
export class ColorBarController {
  groupItem: EffectButtonItem
  colorIndex: number
  colorItemChangeCallBack: (()=>void)
  constructor(item: EffectButtonItem, callback:(()=>void)) {
    this.groupItem = item
    this.colorIndex = this.groupItem.getSelectColorIndex()
    this.colorItemChangeCallBack = callback
  }

  setColorIndex(index: number) {
    if (this.colorIndex != index) {
      this.colorIndex = index
      this.groupItem.setSelectColorIndex(this.colorIndex)
      this.colorItemChangeCallBack?.()
    }
  }

  getColorIndex(): number {
    this.colorIndex = this.groupItem.getSelectColorIndex()
    return this.colorIndex
  }
}

@Component
export struct ColorBar {

  @ObjectLink controller: ColorBarController

  build() {
    Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
      ForEach(this.controller.groupItem.getColorItems().convertToArray(), (item: ColorItem, index: number) => {
          Circle({ width: 23, height: 23 })
            .margin({ top: 3, bottom: 3 })
            .fill(item.getRgbaColor())
            .strokeWidth(2)
            .stroke(index == this.controller.getColorIndex() ? "rgb(255,255,255)" : "")
            .onClick((event: ClickEvent) => {
              this.controller.setColorIndex(index)
            })

      }, (item: ColorItem) => item.title.toString())
    }
  }
}