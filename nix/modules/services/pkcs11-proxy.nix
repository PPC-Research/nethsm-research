{ config, pkgs, lib, ... }:

let
  cfg = config.services.pkcs11Proxy;
in
{
  options.services.pkcs11Proxy = {
    enable = lib.mkEnableOption "PKCS#11 proxy service";

    socket = lib.mkOption {
      type = lib.types.str;
      default = "tls://0.0.0.0:2345";
      description = "PKCS#11 proxy listener socket.";
    };

    pskFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/pkcs11-proxy/psk.key";
      description = "Path to the TLS-PSK file in GnuTLS psktool format.";
    };

    provider = lib.mkOption {
      type = lib.types.str;
      default = "${pkgs.opensc}/lib/opensc-pkcs11.so";
      description = "PKCS#11 provider module for pkcs11-daemon.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "pkcs11-proxy";
      description = "User running pkcs11-daemon.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "pkcs11-proxy";
      description = "Group running pkcs11-daemon.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.group} = { };
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ "pcscd" ];
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/pkcs11-proxy 0750 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.pkcs11-proxy = {
      description = "PKCS#11 Proxy (TLS-PSK)";
      after = [ "network.target" "pcscd.service" ];
      wants = [ "network.target" "pcscd.service" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        PKCS11_DAEMON_SOCKET = cfg.socket;
        PKCS11_PROXY_TLS_PSK_FILE = cfg.pskFile;
      };

      preStart = ''
        if [ ! -s ${cfg.pskFile} ]; then
          echo "Missing or empty ${cfg.pskFile} (GnuTLS psktool format)." >&2
          echo "Create it with: psktool -u <identity> -p -f ${cfg.pskFile}" >&2
          exit 1
        fi
      '';

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        SupplementaryGroups = [ "pcscd" ];
        ExecStart = "${pkgs.pkcs11-proxy-ppc}/bin/pkcs11-daemon ${cfg.provider}";
        Restart = "on-failure";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
      };
    };
  };
}
