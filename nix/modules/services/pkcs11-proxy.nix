{ config, pkgs, lib, ... }:

let
  cfg = config.services.pkcs11Proxy;
in
{
  options.services.pkcs11Proxy = {
    enable = lib.mkEnableOption "PKCS#11 proxy service";

    tlsMode = lib.mkOption {
      type = lib.types.enum [ "psk" "mtls" "none" ];
      default = "psk";
      description = "TLS mode for pkcs11-daemon: pre-shared key (psk), mutual TLS (mtls), or none.";
    };

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

    tlsCaFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/pkcs11-proxy/mtls/ca.crt";
      description = "Path to the mTLS CA certificate.";
    };

    tlsCertFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/pkcs11-proxy/mtls/server.crt";
      description = "Path to the mTLS server certificate.";
    };

    tlsKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/pkcs11-proxy/mtls/server.key";
      description = "Path to the mTLS server private key.";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional environment variables for the pkcs11-daemon service.";
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

    environment.etc."pkcs11-proxy.conf".text =
      let
        tlsBlock = if cfg.tlsMode == "psk" then ''
          tls_mode=psk
          psk_file=${cfg.pskFile}
        '' else if cfg.tlsMode == "mtls" then ''
          tls_mode=cert
          tls_ca_file=${cfg.tlsCaFile}
          tls_cert_file=${cfg.tlsCertFile}
          tls_key_file=${cfg.tlsKeyFile}
          tls_verify_peer=true
        '' else
          "";
      in ''
        so_path=${cfg.socket}
        ${tlsBlock}
      '';

    systemd.tmpfiles.rules = [
      "d /var/lib/pkcs11-proxy 0750 ${cfg.user} ${cfg.group} - -"
      "d /etc/pkcs11-proxy 0750 root ${cfg.group} - -"
      "d /etc/pkcs11-proxy/mtls 0750 root ${cfg.group} - -"
    ];

    systemd.services.pkcs11-proxy = {
      description = "PKCS#11 Proxy";
      after = [ "network.target" "pcscd.service" ];
      wants = [ "network.target" "pcscd.service" ];
      wantedBy = [ "multi-user.target" ];

      environment = lib.mkMerge [
        {
          PKCS11_DAEMON_SOCKET = cfg.socket;
        }
        (lib.mkIf (cfg.tlsMode == "psk") {
          PKCS11_PROXY_TLS_PSK_FILE = cfg.pskFile;
        })
        (lib.mkIf (cfg.tlsMode == "mtls") {
          PKCS11_PROXY_TLS_MODE = "cert";
          PKCS11_PROXY_TLS_CA_FILE = cfg.tlsCaFile;
          PKCS11_PROXY_TLS_CERT_FILE = cfg.tlsCertFile;
          PKCS11_PROXY_TLS_KEY_FILE = cfg.tlsKeyFile;
        })
        cfg.extraEnvironment
      ];

      preStart = ''
        if [ "${cfg.tlsMode}" = "psk" ]; then
          if [ ! -s ${cfg.pskFile} ]; then
            echo "Missing or empty ${cfg.pskFile} (GnuTLS psktool format)." >&2
            echo "Create it with: psktool -u <identity> -p -f ${cfg.pskFile}" >&2
            exit 1
          fi
        elif [ "${cfg.tlsMode}" = "mtls" ]; then
          if [ ! -s ${cfg.tlsCaFile} ] || [ ! -s ${cfg.tlsCertFile} ] || [ ! -s ${cfg.tlsKeyFile} ]; then
            echo "Missing mTLS files. Expected:" >&2
            echo "  CA:   ${cfg.tlsCaFile}" >&2
            echo "  CERT: ${cfg.tlsCertFile}" >&2
            echo "  KEY:  ${cfg.tlsKeyFile}" >&2
            exit 1
          fi
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
