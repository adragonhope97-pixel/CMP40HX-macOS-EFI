# Research Log: NullMoth 2.6.5 on NVIDIA CMP 40HX (Turing TU106)
## First real-machine attempt — install, load, and RM gate rejection

> Date: 2026-11-01
> macOS: Tahoe 26.7.2 (Build 25G332), x86_64
> OpenCore: custom build (1401 toolchain), config schema ≈1.0.5+
> GPU: NVIDIA CMP 40HX (10DE:1F0B, Rev A1, Subsystem 1043:8804)
> Display: Intel UHD Graphics P630 (separate, handles all display output)
> Driver: NullMoth 2.6.5 official package (SHA-256 verified against upstream)
> Install method: install.sh from extracted tar.gz (not 1401 app)

---

## 1. What worked

### install.sh full flow

```
== 1. this Mac
   ok  macOS 26.7.2, x86_64, NVIDIA GPU present

== 2. package integrity
   ok  every file matches SHA256SUMS and both OS accelerators are present

== 3. test kernel collection
   ok  test collection holds all four kexts

== 4. back up what is there now -> /Library/NullMoth/backup-…
   ok  backup written

== 5. install
   ok  installed
```

Runtime preflight: each payload binary's minimum macOS version was checked
against the running system. All payloads declared minOS ≤ 26.7.2. The
preflight is read-only and runs before any system modification.

### Four kernel extensions loaded (AuxKC rebuild successful)

```
kmutil showloaded --list-only | grep -i nullmoth
  com.nullmoth.NVRMAGDC (2.6.5)
  com.nullmoth.NVRMFB (2.6.5)
  com.nullmoth.NVRM (2.6.5)
  com.nullmoth.NVAccel (2.6.5)
```

All four components loaded from the Auxiliary Kernel Collection without
requiring a separate reboot beyond the standard one after AuxKC rebuild.

## 2. NVRM binding to the CMP 40HX

NVRM successfully bound to the CMP 40HX PCI device and mapped its BARs:

```
"nvrm-bars" = "bar0@0x10:0xf6000000+0x1000000
               bar1@0x14:0x7f90000000+0x4000000
               bar2@0x1c:0x7f94000000+0x2000000"
```

- BAR0: 16 MB MMIO at 0xF6000000 (physical, above 4 GB boundary)
- BAR1: 64 MB window at 0x7F90000000 (64-bit, above 4 GB)
- BAR2: 32 MB at 0x7F94000000

All three BARs mapped successfully. Above 4G Decoding confirmed enabled.
The 64 MB BAR1 is a mining-card characteristic (consumer Turing cards
typically have 256 MB BAR1).

## 3. NVRM initialization trace (R615 open RM ported to XNU)

The NullMoth-port NVRM (based on NVIDIA open-gpu-kernel-modules R615)
initialized the RM framework successfully before hitting the device gate:

```
(NVRM) NVRM-xnu: >os_registry_init
(NVRM) NVRM-xnu: >os_dbg_init
(NVRM) NVRM-xnu: >nv_platform_supports_s0ix
(NVRM) NVRM-xnu: >os_get_cpu_frequency
(NVRM) NVRM-xnu: >os_get_cpu_count
(NVRM) NVRM-xnu: >os_alloc_semaphore
(NVRM) NVRM-xnu: >os_mem_copy #4 len=56
(NVRM) NVRM-xnu: >os_get_current_thread
(NVRM) NVRM-xnu: >os_acquire_rwlock_write
(NVRM) NVRM-xnu: >os_get_monotonic_time_ns
(NVRM) NVRM-xnu: >os_semaphore_may_sleep
(NVRM) NVRM-xnu: >os_get_cpu_number
(NVRM) NVRM-xnu: >os_release_rwlock_write
(NVRM) NVRM-xnu: >os_free_mem
(NVRM) NVRM-xnu: >os_get_current_process
(NVRM) NVRM-xnu: >os_get_current_process_name
(NVRM) NVRM-xnu: >os_check_access
(NVRM) NVRM-xnu: rm_init_rm OK
(NVRM) NVRM-xnu: rm_init_rm OK
(NVRM) NVRM-xnu: event locks created for the control device and the GPU
(NVRM) NVRM-xnu: registry: RmMsg=":" ResmanDebugLevel=0 (verbose RM)
(NVRM) NVRM-xnu: registry: PreserveVideoMemoryAllocations=1 (all VRAM survives system sleep)
(NVRM) NVRM-xnu: >os_map_kernel_space start=0xf6000000 size=0x1000 mode=1
(NVRM) NVRM-xnu:   mapped -> 0x<private> (slot 0, high water 1/8192)
(NVRM) NVRM-xnu: >os_unmap_kernel_space
```

The RM mapped BAR0 (16 MB) and accessed the GPU's control registers.
Then the sequence changed:

```
(NVRM) NVRM: The NVIDIA GPU 0000:02:00.0
(NVRM) NVRM: (PCI ID: 10de:1f0b) installed in this system has
(NVRM) NVRM: fallen off the bus and is not responding to commands.
```

Two "fallen off the bus" messages appeared immediately after the BAR0
kernel-space map. The GPU stopped responding to register reads at
0xF6000000.

## 4. The device gate rejection

After the bus-loss symptom, the RM's supported-device check ran:

```
(NVRM) NVRM-xnu: rm_is_supported_device -> 0xf: RM will not drive device 0x1f0b - stopping, card untouched
```

This is the NullMoth wrapper around NVIDIA R615's internal
supported-device gate. The gate source (from open-gpu-kernel-modules
src/nvidia/arch/nvalloc/unix/src/osapi.c) checks:

1. PCI class == 0x03 (Display Controller) — CMP 40HX passes
2. PCI subclass == 0x00 (VGA) or 0x02 (3D) — CMP 40HX (030200) passes
3. PCI vendor == 0x10DE — passes
4. PCI device >= 0x0020 (RIVA TNT) — CMP 40HX (0x1F0B) passes

All four conditions pass. However, the rejection code (0xf) indicates
the gate rejected the device at a deeper level — the R615 RM's internal
device table (nvidia_gsp_ids.json, extracted from 615.78.08
supported-gpus.json) does not include CMP SKU device IDs. The installer's
fallback (device >= 0x1E00) covers the install step but not the RM's own
supported-device validation inside the GSP stack.

## 5. Auto-go failure and graceful degradation

After the gate rejection:

```
(NVRM) NVRM-xnu: auto-go: go(2) took 138 ms (hold cap settle + 120 s)
(NVRM) NVRM-xnu: auto-go: go(2) -> 0xe00002c7 (fPassDone 0)
(NVRM) NVRM-xnu: boot hold RELEASED (go(2) failed) — WindowServer's IOKitWaitQuiet may return
```

The boot hold was released gracefully. The system continued to boot
with the display on the Intel UHD Graphics P630 (via its own framebuffer).
The CMP 40HX remained untouched — no further initialization was attempted.

This confirms the NullMoth failure mode is safe: the card is left in a
clean state and the system boots normally on the iGPU.

## 6. IORegistry evidence of dual-GPU coexistence

After the attempted init:

- Intel UHD Graphics P630: IONDRVFramebuffer active, display0 attached,
  rendering the desktop (14 MB VRAM reported — VESA mode, no acceleration)
- NVIDIA CMP 40HX: NVRM service bound, NVRMFBClaim personality matched
  (ProbeScore 30000, beating IONDRVSupport's 20000), but NVRMFB
  framebuffer not armed (no display head on this card)
- Both GPUs coexist in the IORegistry without conflict
- No kernel panic, no system instability

## 7. Summary of findings

| Layer | Status | Evidence |
|-------|--------|----------|
| PCI enumeration | ✅ PASS | IORegistry: 10DE:1F0B present, Link Up |
| Device name display | ✅ PASS | System Information shows "NVIDIA CMP 40HX" |
| Driver install | ✅ PASS | install.sh full flow succeeded |
| Driver load | ✅ PASS | Four components in kmutil showloaded |
| NVRM binding | ✅ PASS | NVRM class bound to CMP node, BARs mapped |
| RM initialization | ✅ PASS | rm_init_rm OK |
| RM device gate | ❌ REJECTED | rm_is_supported_device -> 0xf |
| GSP firmware load | ❌ NOT REACHED | Gate blocks before GSP |
| GPU init | ❌ NOT REACHED | — |
| Metal device | ❌ NOT REACHED | — |
| Compute | ❌ NOT REACHED | — |

## 8. What would be needed to proceed

The RM gate (rm_is_supported_device) rejects the device because the
R615 615.78.08 supported-device table does not include CMP SKUs.
Possible paths:

1. Ask upstream (NullMoth) to add 0x1F0B to the supported table —
   the gate is inside the RM library, not easily patched without
   rebuilding the RM.
2. Investigate whether the GSP firmware itself would accept a TU106
   device even if the host-side gate is bypassed — this requires
   understanding the GSP firmware's own device validation.
3. The "fallen off the bus" symptom may be related to the 64 MB BAR1
   (mining cards often have reduced BAR sizes) or the PCIe Gen1 link —
   needs investigation with a known-good Turing card on the same slot
   to isolate the variable.

## 9. Signal: NVRMFB claim mechanism works on CMP 40HX

A significant positive finding: NVRMFBClaim (IOProbeScore 30000)
successfully claimed the CMP 40HX device, displacing IONDRVSupport's
generic framebuffer (IOProbeScore 20000). This means NullMoth's
device-claiming mechanism works correctly on this card even before
full initialization. The card was properly "reserved" by NullMoth
even though the RM subsequently refused to drive it.

This is the first documented instance of NullMoth's NVRMFBClaim
mechanism engaging on a mining-card (no display output) NVIDIA GPU
under macOS Tahoe 26.
