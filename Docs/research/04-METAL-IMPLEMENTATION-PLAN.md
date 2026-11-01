# 04-METAL-IMPLEMENTATION-PLAN(v1.0,2026-11-01)

> 状态:**全部资产已预置(Windows 侧 100% 就绪),执行在 macOS 侧,分 4 个门禁批次**。
> 每个批次有独立通过判据与回滚;失败即停在当前批次,不影响已通过状态。

## 1. 已预置资产(全部哈希验证)

| 资产 | 位置 | SHA-256 / 校验 |
|------|------|----------------|
| 官方驱动包 nullmoth-nvidia-2.6.5.tar.gz(264MB) | build/ | `cca98ce4…3c3c1` = 官方 SHA256SUMS ✅ |
| ├── NVAccel 26 构建(kexts/26/) | 包内 | Mach-O 解析:无 minOS 声明(见 §3) |
| ├── NVRM/NVRMFB/NVRMAGDC kext | 包内 | 同上 |
| ├── **GSP 固件 gsp_tu10x.bin + ucodes_tu10x.bin** | 包内 nvfw/nvidia/615.78.08/ | **TU106 覆盖确认** ✅ |
| ├── GPUBundles(NVMTLDriver + NVIDIAShared + nvmtl/Vulkan) | 包内 | libLLVM 145MB / air-opt 92MB / libvulkan 全套 |
| ├── install.sh / uninstall.sh / runtime-check | 包内根 | 预检=只读(04 报告) |
| AMFIPass.kext 1.4.1(com.dhinakg.AMFIPass) | build/amfipass-x/ | `07b26614…961e` |
| **Exp-N1 EFI 变体**(NullMoth 官方要求全集) | build/Exp-N1-EFI/ | ocvalidate 1.0.8 **零错误** ✅;未部署 |

## 2. Exp-N1 与现用 EFI 的差异(仅这些)

| 项 | 现用 | Exp-N1 |
|----|------|--------|
| boot-args | `-v debug=0x100 keepsyms=1 igfxonln=1 revpatch=sbvmm` | + `nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0 gfxrst=4` |
| csr-active-config | 03000000 | **430a0000**(官方测试值) |
| Kernel→Add | 11 kext | + **AMFIPass.kext 1.4.1** |
| Kernel→Block | 空 | + com.apple.iokit.IONDRVSupport(防固件帧缓冲占 display 0) |
| 其余 | — | 逐字节一致 |

## 3. 静态兼容性结论(本次新增,修正此前认知)

- 驱动包内**全部二进制无 minOS 声明**(kext 本就不带;GPUBundles 用户态二进制实测 0 条 LC_BUILD_VERSION/MIN)→ **1401 预检的版本门禁对本包恒为通过**,但保护力也有限——真正的 26.7.2 兼容门禁是安装时的 **AuxKC/kmutil 构建** 与加载。
- GSP:`gsp_tu10x.bin` 在包内 → **TU106 固件覆盖确认(静态)**。
- GPUBundles 内含 ELF 组件(libnvidia-nvvm/ptxjitcompiler .so,为 NVK 编译栈自加载设计)——预检器按设计容忍 .so 非 Mach-O(status 3),非缺陷。

## 4. macOS 侧执行 runbook(4 批次)

### 批次 B1:重启验证 CFL framebuffer(前置门禁)
1. 重启进 macOS(已移除 -igfxvesa 的现用 EFI)。
2. 若黑屏 ≥3 分钟 → 救援:BIOS 菜单进 Windows → `copy "F:\...\G-EFI-config-backup-20261101-015105-pre-igfxvesa-removal.plist" "<系统 EFI 分区>/EFI\OC\config.plist"` → 完结(本计划终止,如实报告)。
3. 到桌面 → 跑 `research/collect-intel-fb-evidence.sh` → 判据:**count-CFLFB-loaded ≥ 1 且 count-Accelerator ≥ 1**。
- 通过 → B2;失败 → 报告(分类:D 证据不足 / 新 BUG)。

### 批次 B2:Exp-N1 切换 + NullMoth 安装
1. 换名启用 Exp-N1 EFI(或 U 盘)。
2. 挂载/解包 `nullmoth-nvidia-2.6.5.tar.gz`(已拷到 U 盘或通过局域网),`sudo ./install.sh`(或运行 1401 app)。
3. 预检(runtime-check)预期:PASS(无 minOS 阻塞);**任何 STOP → 停在此**。
4. 系统设置 → 隐私与安全性 → **允许** NullMoth 扩展 → 重启(再次经 Exp-N1)。
- 失败救援:`-nvoff` boot-arg 或换回 Baseline EFI;`uninstall.sh` 完整卸载。

### 批次 B3:驱动绑定与 GSP 验证
```bash
kmutil showloaded --list-only | grep -E "NVRM|NVAccel|NVRMFB|NVRMAGDC"
sudo dmesg | grep -iE "NVRM|GSP|rm_init"   # 找 "RmInitAdapter succeeded"
ioreg -l | grep -c NVRMNVDAFramebuffer     # 无头检查是否扣留
sysctl debug.nmxaccel_headless             # 1 = 无头模式生效(预期,本卡无输出)
```
- 通过判据:四组件加载 + RmInitAdapter 成功日志 + 无 panic。

### 批次 B4:Metal 与计算验证(验收核心 A–G)
```bash
system_profiler SPDisplaysDataType   # NVIDIA 条目 + Metal 行
# A/B 枚举与设备创建:跑上游推荐冒烟(1401 app 自带诊断或 Metal HUD)
# C–F Compute:llama.cpp GPU offload / Geekbench GPU Compute / MPS 用例
# G 显存与能力:system_profiler 报告值 vs 8GB 实际
```
- 每项 A–G 独立记 PASS/FAIL/BLOCKED;**任何"设备丢失/GPU timeout"立即停并采集 dmesg**。

## 5. 目标 B(显示 GPU)专项说明

上游源码明确:无头 NVIDIA GPU **拒绝为 WindowServer 提供设备**("no device for WindowServer")+ 本卡无物理输出 ⇒ **目标 B 在硬件与上游设计双重约束下不可行,预期结论 = BLOCKED(结构性)**。这不影响目标 A(计算)。

## 6. 回滚矩阵

| 层 | 方法 |
|----|------|
| EFI(Exp-N1) | 换回 Baseline 目录 / G-EFI-config-backup-20261101-015105 / original-backup zip |
| NVRAM(csr/boot-args) | Reset NVRAM 或按记录还原 |
| 驱动 | uninstall.sh + 删除 /Library/NullMoth + AuxKC 备份还原 |
| 系统安全 | csr 还原 03000000(Reset NVRAM 后按需重设) |
