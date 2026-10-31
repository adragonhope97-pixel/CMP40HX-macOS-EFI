# Verifying the CMP 40HX model-injection path on YOUR machine

The bundled config injects `model = "NVIDIA CMP 40HX"` (data) at:

    PciRoot(0x0)/Pci(0x1,0x1)/Pci(0x0,0x0)

This path was verified on the author's machine via:
- Windows Device Manager Location Path: PCIROOT(0)#PCI(0101)#PCI(0000)
- Windows ACPI Path: _SB.PCI0.PEG1.PEGP

On a different machine the slot differs. Verify before trusting it:

1. Boot macOS; open Terminal:
   ioreg -p IOService -w 0 -l > ioreg.txt
2. Find the node whose properties contain BOTH
   "vendor-id" = <de100000>  and  "device-id" = <0b1f0000>
   (little-endian on macOS; some builds print <10de0000>)
3. Derive the path from its IOPCIDevice ancestors:
   PciRoot(0x0)/Pci(0x<dev>,0x<func>)... for each ancestor including the GPU itself.
4. Edit EFI/OC/config.plist → DeviceProperties → Add → replace the key path.
5. Reboot and check System Information → PCI.

If the injected path matches no device, the name simply will not change;
PCI enumeration itself is unaffected.
