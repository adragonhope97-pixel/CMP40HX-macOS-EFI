// CMP40HXAccelerator.hpp  v0.2
// 目的: 判定 CMP 40HX 在 macOS 下是否响应 PMC 寄存器读 —— 这是 RM 报 0xF
// (NV_ERR_GPU_IS_LOST) 的直接验证手段, 也是"1F0B 不在支持表"这一历史误判的证伪实验。
//
// 背景(源码证据):
//   osapi.c: rm_is_supported_device() 读 PMC_BOOT_0/42, 若两者都是 0xFFFFFFFF 则返回
//            NV_ERR_GPU_IS_LOST (0xF)。它不查 PCI ID 表。
//   hal_mgr.c: halmgrGetHalForGpu() 只按 PMC_BOOT_42 的 ARCH/IMPL 匹配, TU106 = (0x16, 6)。
//   => 0xF 的含义是"卡不响应", 不是"卡不被支持"。

#ifndef CMP40HX_ACCELERATOR_HPP
#define CMP40HX_ACCELERATOR_HPP

#include <IOKit/IOService.h>
#include <IOKit/IOLib.h>

class IOPCIDevice;
class IOMemoryMap;

// PMC 寄存器偏移 (来自 NVIDIA open-gpu-kernel-modules nv_ref.h)
#define CMP_PMC_BOOT_0   0x00000000u
#define CMP_PMC_BOOT_1   0x00000004u
#define CMP_PMC_BOOT_42  0x00000A00u

// TU106 期望值: ARCHITECTURE_TU100 = 0x16, IMPLEMENTATION_6
#define CMP_TU100_ARCH   0x16u
#define CMP_TU106_IMPL   0x06u

class CMP40HXAccelerator : public IOService
{
    OSDeclareDefaultStructors(CMP40HXAccelerator)

public:
    virtual bool     init(OSDictionary *dictionary = nullptr) APPLE_KEXT_OVERRIDE;
    virtual void     free() APPLE_KEXT_OVERRIDE;
    virtual bool     start(IOService *provider) APPLE_KEXT_OVERRIDE;
    virtual void     stop(IOService *provider) APPLE_KEXT_OVERRIDE;

private:
    bool  readIdentity();
    bool  logPCIState();
    bool  ensureD0();
    bool  mapBAR0();
    bool  pollPMC();                  // 轮询 PMC_BOOT_0/1/42, 判定"活着/掉线"
    void  publishStatus(const char *stage, IOReturn result);
    void  unmapAll();

    IOPCIDevice *fPCIDevice = nullptr;
    IOMemoryMap *fBAR0Map   = nullptr;

    UInt16 fVendorID = 0, fDeviceID = 0, fSubSysVendor = 0, fSubSysDevice = 0;
    UInt8  fRevision = 0;
    UInt16 fCommand  = 0;

    UInt32 fBoot0 = 0, fBoot1 = 0, fBoot42 = 0;
    UInt32 fSamples = 0, fAliveSamples = 0;
    bool   fAlive = false;
    bool   fBAR0OK = false;
};

#endif // CMP40HX_ACCELERATOR_HPP
