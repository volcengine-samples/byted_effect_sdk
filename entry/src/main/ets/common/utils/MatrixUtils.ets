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

import { matrix4 } from '@kit.ArkUI';

export enum ScaleType{
  CENTER_CROP,
  CENTER_INSIDE
};

export class MatrixUtils {
  constructor() {
    this.mData = [1, 0, 0, 0,
                  0, 1, 0, 0,
                  0, 0, 1, 0,
                  0, 0, 0, 1]
  }

  getData():number[]{
    return this.mData
  }

  scale(x: number, y: number, z: number) {
    this.mData[0] *= x;
    this.mData[5] *= y;
    this.mData[10] *= z;
    this.mData[15] *= 1;
  }

  getShowMatrix(scaleType: ScaleType, imgWidth: number, imgHeight: number, viewWidth: number, viewHeight: number): MatrixUtils {
    let sWhView = viewWidth / viewHeight;
    let sWhImg =  imgWidth / imgHeight;
    let tmp = new MatrixUtils()
    if (sWhImg>sWhView){
      switch (scaleType) {
        case ScaleType.CENTER_INSIDE:
          tmp.ortho(-1, 1, -sWhImg / sWhView, sWhImg / sWhView, 1, 3)
          break
        case ScaleType.CENTER_CROP:
          tmp.ortho(-sWhView / sWhImg, sWhView / sWhImg, -1, 1, 1, 3)
          tmp.scale(1.0, 1.0, 1.0)
          break;
      }
    } else {
      switch (scaleType) {
        case ScaleType.CENTER_INSIDE:
          tmp.ortho(-sWhView / sWhImg, sWhView / sWhImg, -1, 1, 1, 3)
          break
        case ScaleType.CENTER_CROP:
          tmp.ortho(-1, 1, -sWhImg / sWhView, sWhImg / sWhView, 1, 3)
          tmp.scale(1.0, 1.0, 1.0)
          break;
      }
    }
    let camera = new MatrixUtils().setLookAt(0, 0, 1, 0, 0, 0, 0, 1, 0)
    this.mutil(tmp).mutil(camera)
    return this
  }

  setLookAt(eyeX: number, eyeY: number, eyeZ: number, centerX: number, centerY: number, centerZ: number, upX: number, upY: number, upZ: number) {
    // 计算眼睛位置到焦点位置的向量
    let fx = centerX - eyeX;
    let fy = centerY - eyeY;
    let fz = centerZ - eyeZ;

    // 计算向量的长度
    let rlf = 1.0 / Math.sqrt(fx * fx + fy * fy + fz * fz);
    // 归一化向量
    let fx_ = fx * rlf;
    let fy_ = fy * rlf;
    let fz_ = fz * rlf;

    // 计算上方向向量与视线方向向量的叉积
    let sx = fy_ * upZ - fz_ * upY;
    let sy = fz_ * upX - fx_ * upZ;
    let sz = fx_ * upY - fy_ * upX;

    // 计算叉积向量的长度
    let rls = 1.0 / Math.sqrt(sx * sx + sy * sy + sz * sz);
    // 归一化叉积向量
    let sx_ = sx * rls;
    let sy_ = sy * rls;
    let sz_ = sz * rls;

    // 计算上方向向量
    let ux = sy_ * fz_ - sz_ * fy_;
    let uy = sz_ * fx_ - sx_ * fz_;
    let uz = sx_ * fy_ - sy_ * fx_;

    //let tmp = new MatrixUtils()
    // 填充视图矩阵
    this.mData = [sx_, ux,  -fx_, 0.0,
                 sy_, uy,  -fy_, 0.0,
                 sz_, uz,  -fz,  0.0,
                 0.0, 0.0, 0.0,  1.0]
    // 进行平移变换
    this.mData[12] = -(sx_ * eyeX + sy_ * eyeY + sz_ * eyeZ);
    this.mData[13] = -(ux * eyeX + uy * eyeY + uz * eyeZ);
    this.mData[14] = -(fx_ * eyeX + fy_ * eyeY + fz_ * eyeZ);
    //this.mutil(tmp)
    return this
  }

  ortho(left: number, right: number, bottom: number, top: number, near: number, far: number): MatrixUtils {
    this.mData = [2 / (right - left), 0,                   0,                 -((right + left) / (right - left)),
                 0,                  2 / (top - bottom),  0,                 -((top + bottom) / (top - bottom)),
                 0,                  0,                   -2 / (far - near), -((far + near) / (far - near)),
                 0,                  0,                   0,                 1]
    return this
  }

  // 绕着z轴旋转
  rotate(angle: number):MatrixUtils{
    let tmp = new MatrixUtils()
    let sin = 0
    let cos = 0
    if (angle === 90) {
      sin = 1
      cos = 0
    } else if (angle == 180) {
      sin = 0
      cos = -1
    } else if (angle == 270) {
      sin = -1
      cos = 0
    } else {
      sin = Math.sin(angle / 180 * Math.PI)
      cos = Math.cos(angle / 180 * Math.PI)
    }
    tmp.mData = [cos, -sin ,0 ,0,
                  sin, cos, 0, 0,
                  0, 0, 1, 0,
                  0, 0, 0, 1]
    this.mutil(tmp)
    return this
  }

  flip(x:boolean, y:boolean):MatrixUtils{
    let tmp = new MatrixUtils()
    if (x) {
      tmp.getData()[0] = -1
    }
    if (y) {
      tmp.getData()[5] = -1
    }
    this.mutil(tmp)
    return this
  }

  private  mutil( another: MatrixUtils):MatrixUtils {
    let tmp = new MatrixUtils()
    tmp.mData = this.mData.slice()

    for (let row = 0; row < 4; row ++) {
      let r1 = tmp.mData[row * 4 ]
      let r2 = tmp.mData[row * 4 + 1]
      let r3 = tmp.mData[row * 4 + 2]
      let r4 = tmp.mData[row * 4 + 3]

      for (let line = 0; line < 4; line ++) {
        let l1 = another.mData[line], l2 = another.mData[line + 4]
        let l3 = another.mData[line + 8], l4 = another.mData[line + 12]

        let dst = r1 * l1 + r2 * l2 + r3 * l3 + r4 * l4
        this.mData[row * 4 + line] = dst
      }
    }
    return this
  }
 public mData:number[]
};

export default  MatrixUtils;