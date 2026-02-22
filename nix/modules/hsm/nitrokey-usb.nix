{ pkgs, ... }:

{
  services.pcscd.enable = true;
  services.pcscd.plugins = [ pkgs.ccid ];

  users.groups.pcscd = { };

  environment.systemPackages = with pkgs; [
    opensc
    openssl
    pkgs.pkcs11-proxy-ppc
    usbutils
    pcsclite
    pcsc-tools
    gnutls
  ];
}
