{
  pkgs,
  lib,
  ...
}:

let
  rustToolchain = pkgs.fenix.stable.withComponents [
    "rustc"
    "cargo"
    "clippy"
    "rustfmt"
    "rust-analyzer"
  ];

  # rustup-like-ish wrapper to allow `+channel` syntax
  mkRustupWrapper =
    toolName:
    with pkgs;
    writeShellScriptBin toolName ''
      set -euo pipefail

      toolchain=""
      # check if toolchain was provided with '+toolchain' syntax
      if [[ "''${1:-}" == "+"* ]]; then
        toolchain="''${1#+}"
        shift
      fi
      # otherwise try to get toolchain from env var
      if [ -n $toolchain ]; then
        toolchain="''${RUSTUP_TOOLCHAIN:-}"
      fi

      case "$toolchain" in
        "" | "stable")
          exec "${fenix.stable.${toolName}}/bin/${toolName}" "$@"
          ;;
        "nightly")
          exec "${fenix.latest.${toolName}}/bin/${toolName}" "$@"
          ;;
        *)
          # toolchain can be provided as a direct path or by a name
          if [ ! -d $toolchain ]; then
            # if it's not an existing directory, interpret it as a name
            toolchain="$(readlink -f "$HOME/.rustup/toolchains/$toolchain")"
          fi
          if [ -x "$toolchain/bin/${toolName}" ]; then
            exec "$toolchain/bin/${toolName}" "$@"
          else
            # fallback
            echo "WARN: ${toolName} not found in $toolchain"
            exec "${fenix.stable.${toolName}}/bin/${toolName}" "$@"
          fi
          ;;
      esac
    '';
in
{
  devShells.default = pkgs.mkShell {
    packages = with pkgs; [
      # c/gnu base
      gnumake
      pkg-config
      stdenv

      # rust - toolchain
      (lib.hiPrio (mkRustupWrapper "cargo"))
      (lib.hiPrio (mkRustupWrapper "rustc"))
      rustToolchain
      cargo-edit

      # sp1
      autoPatchelfHook
      rustup

      # celestia-zkevm-ibc-demo
      bun
      go
      gopls
      just
      protobuf
      foundry-bin
      solc
    ];

    shellHook = ''
      export PATH="$PATH:$HOME/.sp1/bin/:$HOME/cargo/bin"

      if ! rustup toolchain list | grep -q succinct; then
        echo "SP1 toolchain not found, proceeding with install" && sleep 0.2

        ${lib.getExe pkgs.curl} -sSL https://sp1up.succinct.xyz | bash
        sp1up
        autoPatchelf "$HOME/.sp1/"
      fi

      if [ -d "$HOME/.local/share/svm" ]; then
        autoPatchelf "$HOME/.local/share/svm" >/dev/null
      else
        echo "Foundry toolchain not found"
        echo "if you see errors using 'forge', re-enter devshell to patch toolchain"
      fi
    '';
  };
}
