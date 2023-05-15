{
  description = "NixOS images";

  inputs.nixos-unstable.url = "github:NixOS/nixpkgs/nixos-unstable-small";
  inputs.nixos-2211.url = "github:NixOS/nixpkgs/release-22.11";

  nixConfig.extra-substituters = [
    "https://cache.garnix.io"
  ];
  nixConfig.extra-trusted-public-keys = [
    "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
  ];

  outputs = { self, nixos-unstable, nixos-2211 }: let
    supportedSystems = [ "aarch64-linux" "x86_64-linux" ];
    forAllSystems = nixos-unstable.lib.genAttrs supportedSystems;
  in {
    packages = forAllSystems (system: let
      netboot = nixpkgs: (import (nixpkgs + "/nixos/release.nix") {}).netboot.${system};
      kexec-installer = nixpkgs: modules: (nixpkgs.legacyPackages.${system}.nixos (modules ++ [self.nixosModules.kexec-installer])).config.system.build.kexecTarball;
    in {
      netboot-nixos-unstable = netboot nixos-unstable;
      netboot-nixos-2211 = netboot nixos-2211;
      kexec-installer-nixos-unstable = kexec-installer nixos-unstable [];
      kexec-installer-nixos-2211 = kexec-installer nixos-2211 [];

      kexec-installer-nixos-unstable-noninteractive = kexec-installer nixos-unstable [ 
        { system.kexec-installer.name = "nixos-kexec-installer-noninteractive"; }
        self.nixosModules.noninteractive 
      ];
      kexec-installer-nixos-2211-noninteractive = kexec-installer nixos-2211 [ 
        { system.kexec-installer.name = "nixos-kexec-installer-noninteractive"; }
        self.nixosModules.noninteractive 
      ];
    });
    nixosModules = {
      kexec-installer = ./nix/kexec-installer/module.nix;
      noninteractive = ./nix/noninteractive.nix;
    };
    checks.x86_64-linux = let
      pkgs = nixos-unstable.legacyPackages.x86_64-linux;
    in {
      kexec-installer-unstable = pkgs.callPackage ./nix/kexec-installer/test.nix {
        kexecTarball = self.packages.x86_64-linux.kexec-installer-nixos-unstable-noninteractive;
      };
      shellcheck = pkgs.runCommand "shellcheck" {
        nativeBuildInputs = [ pkgs.shellcheck ];
      } ''
        shellcheck ${(pkgs.nixos [self.nixosModules.kexec-installer]).config.system.build.kexecRun}
        touch $out
      '';
      kexec-installer-2211 = nixos-2211.legacyPackages.x86_64-linux.callPackage ./nix/kexec-installer/test.nix {
        kexecTarball = self.packages.x86_64-linux.kexec-installer-nixos-2211-noninteractive;
      };
    };
  };
}
