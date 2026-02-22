{
  description = "Poor man's NetHSM (Raspberry Pi + Nitrokey HSM + pkcs11-proxy)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    pkcs11-proxy.url = "github:ppc-research/pkcs11-proxy";
    pkcs11-proxy.flake = false;
    mtls-keys.url = "path:./keys";
    mtls-keys.flake = false;
  };

  outputs = { self, nixpkgs, nixos-hardware, ... }@inputs:
    let
      overlayPkcs11ProxyPpc = import ./nix/overlays/pkcs11-proxy-ppc.nix { inherit inputs; };
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
    in
    {
      nixosConfigurations = {
        rpi-nitrokeyhsm-debug = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ({ ... }: { nixpkgs.overlays = [ overlayPkcs11ProxyPpc ]; })
            nixos-hardware.nixosModules.raspberry-pi-4
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
            ./nix/hosts/rpi-nitrokeyhsm-debug/configuration.nix
          ];
        };
      };

      packages = forAllSystems (system:
        {
          rpi-nitrokeyhsm-debug = self.nixosConfigurations.rpi-nitrokeyhsm-debug.config.system.build.sdImage;
        }
      );

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlayPkcs11ProxyPpc ];
          };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nix
              git
              opensc
              openssl
              pcsc-tools
              gnutls
              pkcs11-proxy-ppc
            ];
          };
        }
      );
    };
}
