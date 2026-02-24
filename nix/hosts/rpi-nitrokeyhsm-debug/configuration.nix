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

  services.pkcs11Proxy.enable = true;
  services.pkcs11Proxy.tlsMode = "mtls";
  services.pkcs11Proxy.provider = "${pkgs.opensc}/lib/opensc-pkcs11.so";

  environment.etc."pkcs11-proxy/mtls/ca.crt" = {
    source = "${inputs.mtls-keys}/ca.crt";
    mode = "0440";
    group = "pkcs11-proxy";
  };
  environment.etc."pkcs11-proxy/mtls/server.crt" = {
    source = "${inputs.mtls-keys}/server.crt";
    mode = "0440";
    group = "pkcs11-proxy";
  };
  environment.etc."pkcs11-proxy/mtls/server.key" = {
    source = "${inputs.mtls-keys}/server.key";
    mode = "0440";
    group = "pkcs11-proxy";
  };
  environment.etc."pkcs11-proxy/mtls/client.crt" = {
    source = "${inputs.mtls-keys}/client.crt";
    mode = "0440";
    group = "pkcs11-proxy";
  };
  environment.etc."pkcs11-proxy/mtls/client.key" = {
    source = "${inputs.mtls-keys}/client.key";
    mode = "0440";
    group = "pkcs11-proxy";
  };

  networking.firewall.allowedTCPPorts = [ 22 2345 ];

  # Wi-Fi configuration lives in ./wlan.nix (user-provided).
}
