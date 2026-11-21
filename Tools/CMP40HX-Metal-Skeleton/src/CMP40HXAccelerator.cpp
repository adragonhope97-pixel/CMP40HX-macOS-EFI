// CMP40HXAccelerator.cpp  v0.2
//
// 这一版只做一件事: 用我们自己的代码回答"显卡在 macOS 下到底活不活"。
//   - 读 PMC_BOOT_0/1/42, 轮询 ~12 秒(NVRM 源码注释: Turing 在 BAR 移动后需要约 10 秒稳定)
//   - 读 PCI 状态(命令寄存器 / BAR 尺寸 / 电源状态), 必要时把设备拉回 D0
//   - 全部结果写入 IORegistry, 供 ioreg 取证
//
// 明确不做: 不发 GPU 命令, 不建 IOAccelerator, 不提供 Metal, 不碰 RM/GSP。

#include "CMP40HXAccelerator.hpp"
#include <IOKit/pci/IOPCIDevice.h>
#include <IOKit/IOMemoryDescriptor.h>
#include <mach/kmod.h>

#define super IOService
OSDefineMetaClassAndStructors(CMP40HXAccelerator, IOService)

// ---------------------------------------------------------------------------
// __kmod_info 段 —— 必须有, 否则内核不认为这是可加载 kext:
//   缺失时 OpenCore 注入后静默跳过, ioreg 无实例、日志无输出(2026-11-21 实测)
// 注意: KMOD_EXPLICIT_DECL 宏在本 SDK + clang 21 + gnu++17 下没有生成该段,
//       因此改为显式声明结构体并强制放进 __DATA,__kmod_info(used 防优化)。
// ---------------------------------------------------------------------------
extern "C" {
    __attribute__((used, section("__DATA,__kmod_info")))
    static kmod_info_t gCMP40HXKmodInfo = {
        /* next            */ 0,
        /* info_version    */ 1,
        /* id              */ 0,
        /* name            */ "com.cmp40hx.skeleton.accelerator",
        /* version         */ "0.2.0",
        /* reference_count */ 0,
        /* reference_list  */ 0,
        /* address         */ 0,
        /* size            */ 0,
        /* hdr_size        */ 0,
        /* start           */ 0,
        /* stop            */ 0,
    };
}

static const char *kTag = "CMP40HX-Probe";
static const UInt32 kPollIntervalMs = 500;
static const UInt32 kPollCount      = 24;   // 24 x 500ms = 12s

bool CMP40HXAccelerator::init(OSDictionary *dictionary)
{
    return super::init(dictionary);
}

void CMP40HXAccelerator::free()
{
    unmapAll();
    super::free();
}

bool CMP40HXAccelerator::start(IOService *provider)
{
    if (!super::start(provider)) {
        return false;
    }

    fPCIDevice = OSDynamicCast(IOPCIDevice, provider);
    if (!fPCIDevice) {
        publishStatus("provider-not-pci", kIOReturnUnsupported);
        return false;
    }

    // 打开内存解码: 没有它, BAR0 读一律返回 0xFFFFFFFF —— 与"显卡掉线"无法区分
    fPCIDevice->setMemoryEnable(true);
    fPCIDevice->setBusMasterEnable(false);   // 探针阶段禁止 DMA

    if (!readIdentity()) {
        publishStatus("identity-mismatch", kIOReturnUnsupported);
        return false;
    }

    logPCIState();
    ensureD0();          // 若设备处于 D3hot, BAR 访问必然失败
    mapBAR0();

    fAlive = pollPMC();  // 核心判定

    setProperty("CMP40HX,probe-version", "0.2.0");
    setProperty("CMP40HX,bypasses-RM", true);
    setProperty("CMP40HX,device-id", fDeviceID, 32);
    setProperty("CMP40HX,pmc-boot0", fBoot0, 32);
    setProperty("CMP40HX,pmc-boot1", fBoot1, 32);
    setProperty("CMP40HX,pmc-boot42", fBoot42, 32);
    setProperty("CMP40HX,poll-samples", fSamples, 32);
    setProperty("CMP40HX,alive-samples", fAliveSamples, 32);
    setProperty("CMP40HX,gpu-alive", fAlive);
    setProperty("CMP40HX,bar0-mapped", fBAR0OK);
    setProperty("CMP40HX,pci-command", fCommand, 32);

    // 判定: 0xFFFFFFFF 全采样 = 卡不响应; 读到真实值则解码架构
    if (fAlive) {
        const UInt32 arch = (fBoot0 >> 24) & 0x1F;
        const UInt32 impl = (fBoot0 >> 20) & 0xF;
        setProperty("CMP40HX,arch", arch, 32);
        setProperty("CMP40HX,impl", impl, 32);
        setProperty("CMP40HX,is-tu106",
                    (arch == CMP_TU100_ARCH && impl == CMP_TU106_IMPL));
        setProperty("CMP40HX,verdict", "GPU_ALIVE");
    } else {
        setProperty("CMP40HX,verdict", "GPU_NOT_RESPONDING");
    }

    registerService();
    publishStatus("probe-done", kIOReturnSuccess);
    IOLog("%s: verdict=%s boot0=0x%08X boot42=0x%08X alive=%u/%u\n",
          kTag,
          fAlive ? "GPU_ALIVE" : "GPU_NOT_RESPONDING",
          fBoot0, fBoot42, fAliveSamples, fSamples);
    return true;
}

void CMP40HXAccelerator::stop(IOService *provider)
{
    unmapAll();
    fPCIDevice = nullptr;
    super::stop(provider);
}

bool CMP40HXAccelerator::readIdentity()
{
    fVendorID     = fPCIDevice->configRead16(kIOPCIConfigVendorID);
    fDeviceID     = fPCIDevice->configRead16(kIOPCIConfigDeviceID);
    fRevision     = fPCIDevice->configRead8(kIOPCIConfigRevisionID);
    fSubSysVendor = fPCIDevice->configRead16(kIOPCIConfigSubSystemVendorID);
    fSubSysDevice = fPCIDevice->configRead16(kIOPCIConfigSubSystemID);

    IOLog("%s: %04X:%04X rev %02X subsys %04X:%04X\n",
          kTag, fVendorID, fDeviceID, fRevision, fSubSysVendor, fSubSysDevice);

    return (fVendorID == 0x10DE && fDeviceID == 0x1F0B);
}

bool CMP40HXAccelerator::logPCIState()
{
    fCommand = fPCIDevice->configRead16(kIOPCIConfigCommand);

    for (int i = 0; i < 3; i++) {
        const UInt32 bar = fPCIDevice->configRead32(kIOPCIConfigBaseAddress0 + i * 4);
        IOLog("%s: BAR%d = 0x%08X\n", kTag, i, bar);
    }

    UInt8 pmCap = 0;
    if (fPCIDevice->findPCICapability(kIOPCIPowerManagementCapability, &pmCap)) {
        const UInt16 pmcsr = fPCIDevice->configRead16(pmCap + 4);
        IOLog("%s: PMCSR = 0x%04X (state D%u)\n", kTag, pmcsr, pmcsr & 0x3);
        setProperty("CMP40HX,pmcsr", pmcsr, 16);
    } else {
        IOLog("%s: no PM capability\n", kTag);
    }

    IOLog("%s: PCI command = 0x%04X (memory decode %s, bus master %s)\n",
          kTag, fCommand,
          (fCommand & 0x2) ? "on" : "off",
          (fCommand & 0x4) ? "on" : "off");
    return true;
}

bool CMP40HXAccelerator::ensureD0()
{
    UInt8 pmCap = 0;
    if (!fPCIDevice->findPCICapability(kIOPCIPowerManagementCapability, &pmCap)) {
        return false;
    }
    UInt16 pmcsr = fPCIDevice->configRead16(pmCap + 4);
    if ((pmcsr & 0x3) == 0) {
        return true;   // already D0
    }
    IOLog("%s: forcing D0 (was D%u)\n", kTag, pmcsr & 0x3);
    fPCIDevice->configWrite16(pmCap + 4, (UInt16)(pmcsr & ~0x3));
    IOSleep(50);
    return true;
}

bool CMP40HXAccelerator::mapBAR0()
{
    fBAR0Map = fPCIDevice->mapDeviceMemoryWithRegister(kIOPCIConfigBaseAddress0,
                                                       kIOMapReadOnly);
    if (!fBAR0Map) {
        IOLog("%s: BAR0 map failed\n", kTag);
        return false;
    }
    fBAR0OK = true;
    IOLog("%s: BAR0 mapped, length=%llu\n", kTag, fBAR0Map->getLength());
    return true;
}

bool CMP40HXAccelerator::pollPMC()
{
    if (!fBAR0Map) {
        return false;
    }
    volatile UInt32 *bar0 = (volatile UInt32 *)fBAR0Map->getVirtualAddress();
    if (!bar0) {
        return false;
    }

    // 边界检查: 必须能覆盖到 PMC_BOOT_42(0xA00), 否则越界读可能触发内核缺页
    const unsigned long long need = (unsigned long long)CMP_PMC_BOOT_42 + sizeof(UInt32);
    if ((unsigned long long)fBAR0Map->getLength() < need) {
        IOLog("%s: BAR0 too small for PMC_BOOT_42 (len=%llu, need=%llu), skip polling\n",
              kTag, fBAR0Map->getLength(), need);
        // 退化为只读 BOOT_0/1
        fSamples = 1;
        fBoot0 = bar0[CMP_PMC_BOOT_0 / 4];
        fBoot1 = bar0[CMP_PMC_BOOT_1 / 4];
        fBoot42 = 0;
        fAliveSamples = (fBoot0 != 0xFFFFFFFFu) ? 1 : 0;
        return fAliveSamples > 0;
    }

    UInt32 last0 = 0, last42 = 0;

    for (UInt32 i = 0; i < kPollCount; i++) {
        // 读三个 PMC 寄存器: BOOT_0/1 在 BAR0+0x0/0x4, BOOT_42 在 BAR0+0xA00
        const UInt32 b0  = bar0[CMP_PMC_BOOT_0  / 4];
        const UInt32 b1  = bar0[CMP_PMC_BOOT_1  / 4];
        const UInt32 b42 = bar0[CMP_PMC_BOOT_42 / 4];

        fSamples++;
        const bool alive = (b0 != 0xFFFFFFFFu) || (b42 != 0xFFFFFFFFu);
        if (alive) {
            fAliveSamples++;
        }
        last0 = b0; last42 = b42;
        fBoot1 = b1;

        if (i == 0 || (alive != (i > 0 && fAliveSamples == i))) {
            IOLog("%s: sample %u: boot0=0x%08X boot1=0x%08X boot42=0x%08X %s\n",
                  kTag, i, b0, b1, b42, alive ? "ALIVE" : "dead");
        }

        if (alive && i >= 2) {
            break;   // 连续可读即可提前结束
        }
        IOSleep(kPollIntervalMs);
    }

    fBoot0  = last0;
    fBoot42 = last42;
    return fAliveSamples > 0;
}

void CMP40HXAccelerator::publishStatus(const char *stage, IOReturn result)
{
    setProperty("CMP40HX,last-stage", stage);
    setProperty("CMP40HX,last-result", (UInt32)result, 32);
    IOLog("%s: stage=%s result=0x%08X\n", kTag, stage, (unsigned)result);
}

void CMP40HXAccelerator::unmapAll()
{
    if (fBAR0Map) {
        fBAR0Map->release();
        fBAR0Map = nullptr;
    }
    fBAR0OK = false;
}
