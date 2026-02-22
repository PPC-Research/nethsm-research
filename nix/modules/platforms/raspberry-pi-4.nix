{ lib, ... }:

{
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  boot.blacklistedKernelModules = lib.mkForce [ "dw-hdmi" ];
  boot.initrd.includeDefaultModules = lib.mkForce false;
  boot.initrd.kernelModules = lib.mkForce [ "dm_mod" ];
  boot.kernelModules = lib.mkForce [ "dm_mod" ];

  boot.initrd.availableKernelModules = lib.mkForce [
    "mmc_block"
    "sdhci"
    "sdhci_iproc"
    "sdhci_pltfm"
    "bcm2835_mmc"
    "ext4"
    "vfat"
  ];
}
