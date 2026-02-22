{ pkgs, lib, ... }:

{
  imports = [
    ../../modules/platforms/raspberry-pi-4.nix
    ../../modules/hsm/nitrokey-usb.nix
    ../../modules/services/pkcs11-proxy.nix
  ];

  networking.hostName = "rpi-nitrokeyhsm-debug";

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = true;
      PermitRootLogin = "no";
    };
  };

  time.timeZone = "Europe/Helsinki";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  users.users.alextserepov = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBOQxe0N4f5NcLYVyUrhh7jw+SqS1HxcrFDdZ1BLukgU aleksandr.tserepov-savolainen@unikie.com"
    ];
    initialPassword = "test123";
  };

  services.pkcs11Proxy.enable = true;
  services.pkcs11Proxy.provider = "${pkgs.opensc}/lib/opensc-pkcs11.so";

  networking.firewall.allowedTCPPorts = [ 22 2345 ];

  networking.useNetworkd = true;
  systemd.network.networks."10-wlan" = {
    matchConfig.name = "wlan0";
    networkConfig.DHCP = "yes";
    dhcpV4Config.UseHostname = true;
  };

  networking.wireless = {
    enable = true;
    userControlled.enable = false;
    interfaces = [ "wlan0" ];
    extraConfig = "country=FI";
    networks."DNA-WIFI-E4C4".psk = "";
  };
}
