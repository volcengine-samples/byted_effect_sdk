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


@Observed
export  class ComposerNode {
  public path : string = ""
  public keyArray : string[] = [];
  public tag : string = ""
  public intensityArray : number[] = [];

  constructor(path:string, key?:string | string[], intensity?: number | number[], tag?: string) {
    this.path = path;
    if (key) {
      if (typeof key === 'string') {
        this.keyArray = [key]
      } else {
        this.keyArray = key
      }
    }

    if (intensity != null && intensity != undefined) {
      if (typeof intensity === 'number') {
        this.intensityArray = [intensity]
      } else {
        this.intensityArray = intensity
      }
    }

    if (tag) {
      this.tag = tag
    }
  }
}