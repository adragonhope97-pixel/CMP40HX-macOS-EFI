# INSTALL-LOG — NullMoth 驱动安装实机记录(v1.0,2026-11-01)

> 目标机器实测记录(L4)。主机名/用户名已脱敏。驱动包:nullmoth-nvidia-2.6.5.tar.gz(SHA-256 `cca98ce4…3c3c1`,与官方 SHA256SUMS 一致)。

## 安装执行(install.sh,macOS 26.7.2 Build 25G332)

```
== 1. this Mac
   ok  macOS 26.7.2, x86_64, NVIDIA GPU present
== 2. package integrity
   ok  every file matches SHA256SUMS and both OS accelerators are present
   CHECK runtime payload minimum macOS …(逐二进制校验,全部 ≤ 26.7.2)
== 3. test kernel collection
   ok  test collection holds all four kexts
== 4. back up what is there now -> /Library/NullMoth/backup-<时间戳>
   ok  backup written
== 5. install
   ok  installed
```

- 运行时预检:**通过**(逐二进制 minOS 校验,与 04 报告的静态判定一致)
- 安装器提示(安装时 boot-args 尚未包含 nvfb/nvaccel/gfxrst——当时未重启;**重启后新参数已生效**,见下)

## 重启后加载验证

```
kmutil showloaded --list-only | grep -E "NVRM|NVAccel|NVRMFB|NVRMAGDC"
   com.nullmoth.NVRMAGDC (2.6.5)
   com.nullmoth.NVRMFB (2.6.5)
   com.nullmoth.NVRM (2.6.5)
   com.nullmoth.NVAccel (2.6.5)
```

**四组件全部加载(L4 PASS)。**

## 当时的观察(待下轮取证闭环)

- `system_profiler SPDisplaysDataType` 已出现 "Chipset Model: NVIDIA CMP 40HX"
- 尚未观察到 Metal 行(预期:无头模式下 NVIDIA 设备面向应用、WindowServer 留在核显)
- `sysctl debug.nmxaccel_headless` 当时返回 unknown oid → NVAccel 启动状态需下轮 ioreg/log 取证
- 未观察到 RmInitAdapter 相关日志(需按启动日志重查)

## 状态

| 层级 | 状态 |
|------|------|
| 驱动安装 | ✅ PASS(L4) |
| 驱动加载 | ✅ PASS(L4) |
| 驱动绑定 / GSP / GPU 初始化 | ⏳ 下轮取证 |
| Metal 枚举 / Compute | NOT TESTED |
