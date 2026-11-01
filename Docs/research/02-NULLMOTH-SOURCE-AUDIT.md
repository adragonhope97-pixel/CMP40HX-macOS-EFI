# 02-NULLMOTH-SOURCE-AUDIT(v1.0,2026-11-01)

> 对象:nullmoth/nvidia-macos-driver @ **ceba63c15ba9d81deea7cd1c5dcc4c79497bea8f**(2.6.5)+ nullmoth/1401(★1065,"Install macOS on your PC from Windows")。
> 方法:GitHub API + raw 文件按 commit 固定下载,源码实读(快照在 source-audit/)。

## 1. 版本 / 依赖 / 许可

| 项 | 值 |
|----|-----|
| 驱动版本 | 2.6.5(CHANGELOG);NVAccel/15 与 /26 双构建(build263.sh,NM_TAHOE=1) |
| NVRM 基线 | NVIDIA open-gpu-kernel-modules 移植 XNU(文档一处写 r610、固件栈标 r615/615.78.08 —— 文档不一致,以 615.78.08 为准) |
| GSP 固件 | /Library/NullMoth/nvfw/nvidia/**615.78.08**(未修改 NVIDIA 固件) |
| NVK | Mesa **17ca6174** + nvk-macos.patch;NVK 2.0.5(release 构建;Turing/Ampere/Ada 上传队列改异步 copy 引擎) |
| translator | metal2vulkan 基座,LGPL-3.0+ |
| 1401 app | 2.6.5(与驱动 CHANGELOG 同版) |
| 许可 | kexts/plugin:PolyForm Noncommercial 1.0.0;translator:LGPL-3.0+;固件:NVIDIA LICENCE;Mesa 变更:Mesa 许可 |

## 2. 完整代码路径追踪(设备 → Metal)

```
package/install.sh
  ├─ POST /git/blobs 式安装:拷贝 kexts → /Library/Extensions
  ├─ kmutil 重建 AuxKC(四 kext 链接 Apple 专属 KPI,不能由 OC 注入)
  └─ 门禁:
      ① SUPPORTED_IDS(247,615.78.08 消费卡子集)→ 1F0B 不在
      ② 回退:device-id ≥ 0x1E00 → 接受 1F0B ✅
      ③ 过老(≤0x1DFF)→ die("macOS keeps running on it in basic display")

kexts/NVRM/NVRM.cpp — NVRM::start(IOService*)
  ├─ IOKit 探针:IOPCIPrimaryMatch=0x000010de&0xffff + ClassMatch=0x03xxxxxx → 1F0B 命中 ✅
  ├─ PCI claim + BAR1 放置(无 64-bit 窗口的板卡:保持固件位置)
  ├─ bootHold()(阻止 WindowServer 上固件屏)
  ├─ 加载 GSP:/Library/NullMoth/nvfw/nvidia/615.78.08/
  ├─ rm_init_adapter()("MSI %d armed; calling rm_init_adapter() — GSP boot")
  ├─ nvrm_display_publish():按 nvfbheads(默认 1,max 4)发布 NVRMDisplay nub
  └─ display armed → releaseBootHold()

kexts/NVRMFB/fb/nvrm-fb.cpp — NVRMNVDAFramebuffer::start()
  └─ 每个NVKMS head 发布为 IOFramebuffer;热插拔探测 thread_call

kexts/NVRM/accel/nvrm-accel.cpp — NVAccel(IOAccelerator)
  ├─ armHeadlessCheck():每 kHeadlessPollSec 轮询至 kHeadlessDeadlineSec
  ├─ headlessCheck():fFB 未发布(无显示头)且另一 GPU 显示桌面
  │    → 恢复 MetalPluginName + NVAccelHeadless=true + gNvHeadless=1
  │    日志:"apps get the NVIDIA Metal device, WindowServer stays on the display GPU"
  ├─ sysctl debug.nmxaccel_headless:1 = 应用用 NVIDIA Metal 设备,帧经系统内存拷贝交显示 GPU 合成
  └─ -nvaccelnoheadless 可关闭该检查

plugin/NVMTLDevice.m — Metal 设备层
  └─ 原文:"A headless NVIDIA GPU (the display is on the Intel or AMD GPU) is a
     Metal device for apps only: WindowServer stays …" / "headless GPU: no device
     for WindowServer (it composites on the GPU that owns the display)"

nvk/nvk-macos.patch — SPIR-V → GPU 命令;Turing sm_75 目标;未知芯片名拒绝猜测
translator/ — Apple AIR → SPIR-V(metal2vulkan 基座)

OpenCL:上游无任何实现;macOS OpenCL 框架不覆盖 NVIDIA → 不可用(终局结论)
```

## 3. 1F0B 是否真正进入支持路径?

| 检查点 | 结果 | 证据 |
|--------|------|------|
| IOKit 探针 | ✅ | Info.plist personalities |
| 安装器门禁 | ✅(回退) | install.sh L148-166 |
| NVIDIA 官方表 | ✅ | supportedchips.html 列 "NVIDIA CMP 40HX 1F0B" |
| 615.78.08 提取表 | ❌ | nvidia_gsp_ids.json(消费卡子集口径) |
| 物理显卡验证 | ❌ | CARD-SUPPORT:Turing = Pending;无头卡不承诺桌面 |

**结论:1F0B 能进入"安装 + 探针匹配"路径;从"GSP 初始化"开始的每一层都无公开实证。** GeForce GTX 1660 Ti 案例(TU116)是本栈在 Turing 上最有力的旁证,但按任务书要求不据此推断 CMP 40HX 可用。

## 4. 本机适配相关的上游事实(与 01 实测对应)

| 本机实测 | 上游对应处理 | 风险 |
|----------|--------------|------|
| BAR1 仅 64 MiB | 2.6.3 修复小 BAR1(256MB)卡顿;无 64-bit 窗口时保持固件放置;fallback 时自动等待 100s(nvrm-autogo-settle-ms) | 64MB < 256MB:超小窗行为待 L4 |
| PCIe Gen1 ×4(设备原生) | 队列/通道初始化不假设 Gen3 | 低 |
| 无显示输出(headless) | headlessCheck 显式分支:恢复 Metal 名单、不给 WindowServer 设备 | 需 Intel IOFramebuffer 存在(当前 -igfxvesa 阻断)⇒ 前置修复 |
| macOS 26.7.2 | NM_TAHOE=1 构建 out/26;runtime preflight 脚本 | 小版本未列名,预检裁决 |

## 5. 需要修改驱动源码吗?

**当前结论:不需要。** 门禁放行 + 架构支持 + 无头路径存在。仅当 L4 暴露以下情况才评估补丁(逐条按"文件/函数/上游行为/修改/风险/回滚"格式):

1. headlessCheck 在"Intel FB 存在但 owner 识别失败"时误判 → `headlessDisplayOwner()`。
2. 64MB BAR1 下 rm_init_adapter 失败或死等 → `NVRM.cpp` BAR1 放置段 + settle 参数。
3. 无显示头时 hold 不释放 → `bootHold()/releaseBootHold()` 超时策略。

## 6. 取证文件

source-audit/:NVMTLDevice.m(152KB)、NVRM.cpp(123KB)、nvrm-accel.cpp(147KB)、nvrm-fb.cpp(90KB)、install.sh、Info.plist×6、nvidia_gsp_ids.json、supportedchips.html、docs×5、tree/commit/repo JSON、nvidia-smi 实测输出。
