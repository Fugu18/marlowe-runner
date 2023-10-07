{ repoRoot, inputs, pkgs, lib, system }:

let

  npmlock2nix = import inputs.npmlock2nix { inherit pkgs; };

  spagoPkgs = import (inputs.self + "/spago-packages.nix") { inherit pkgs; };

in

npmlock2nix.v2.build {

  nodejs = pkgs.nodejs-18_x;

  src = lib.sourceByRegex ../. [
    "^prototype.*"
    "^public.*"
    "^src.*"
    "^test.*"
    "^.tidyrc.json$"
    "^jsconfig.json$"
    "^package-lock.json$"
    "^package.json$"
    "^packages.dhall$"
    "^prod.dhall$"
    "^spago-packages.nix$"
    "^spago.dhall$"
    "^tsconfig.json$"
    "^webpack.js$"
  ];

  buildInputs = [
    spagoPkgs.installSpagoStyle
    spagoPkgs.buildSpagoStyle
    repoRoot.nix.purescript.purs-0_15_10
    repoRoot.nix.purescript.spago2nix
  ];

  buildCommands = [
    "mkdir -p dist"
    "cp -r $src/* dist"

    # webpack-cli will want to write file to dist/public, so we need perissions.     
    "chmod -R u+w dist"

    "cd dist"

    # We want to use prod.dhall, but `install-spago-style` below uses 
    # spago.dhall by default and there doesn't seem to be a way to override it.
    "mv prod.dhall spago.dhall"
    "install-spago-style"
    "build-spago-style \"./src/**/*.purs\""

    # This will create the public/*bundle.js* and public/*.module.wasm files.   
    "webpack-cli --mode=production -c webpack.js"
  ];

  # The output of the nix build is the contents of the ./public folder 
  installPhase = "cp -r public $out";
}