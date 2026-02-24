{ pkgs, lib, inputs, ... }:

{
  imports = [
    ../../modules/platforms/raspberry-pi-4.nix
    ../../modules/hsm/nitrokey-usb.nix
    ../../modules/services/pkcs11-proxy.nix
  ]
  ++ lib.optional (builtins.pathExists ./wlan.nix) ./wlan.nix
  ++ lib.optional (builtins.pathExists ./users.nix) ./users.nix;

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

  security.sudo.wheelNeedsPassword = false;

  services.pkcs11Proxy.enable = true;
  services.pkcs11Proxy.tlsMode = "mtls";
  services.pkcs11Proxy.provider = "${pkgs.opensc}/lib/opensc-pkcs11.so";

  networking.firewall.allowedTCPPorts = [ 22 2345 ];

  # Wi-Fi configuration lives in ./wlan.nix (user-provided).
}
