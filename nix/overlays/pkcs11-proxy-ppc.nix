{ inputs }:
final: prev: {
  pkcs11-proxy-ppc = prev.stdenv.mkDerivation {
    pname = "pkcs11-proxy";
    version = "ppc-research-main";

    src = inputs.pkcs11-proxy;

    nativeBuildInputs = with prev; [ cmake pkg-config bash coreutils ];
    buildInputs = with prev; [ openssl libseccomp ];

    cmakeFlags = [];

    postPatch = ''
      chmod +x mksyscalls.sh
      substituteInPlace mksyscalls.sh \
        --replace "/usr/bin/env bash" "${prev.bash}/bin/bash" \
        --replace "/usr/bin/env sh" "${prev.bash}/bin/bash"
      patchShebangs mksyscalls.sh
      # Avoid leaking a local CMake cache into the build sandbox.
      rm -rf build
    '';

    doCheck = false;

    meta = with prev.lib; {
      description = "ppc-research fork of pkcs11-proxy";
      homepage = "https://github.com/ppc-research/pkcs11-proxy";
      platforms = platforms.linux;
    };
  };
}
