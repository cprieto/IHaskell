let
  fetcher = { owner, repo, rev, sha256 }: builtins.fetchTarball {
    inherit sha256;
    url = "https://github.com/${owner}/${repo}/archive/${rev}.tar.gz";
  };
  nixpkgs' = fetcher {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "9bbb84f622e8c421419e6ca9949a5b55e25c4be8";
    sha256 = "0kv30544nl7a33icd952ya4zkwrqjla53cdpiqhmyng9kyd3zbrp";
  };
in
{ compiler ? "ghc861"
, nixpkgs ? import nixpkgs' {}
, packages ? (_: [])
, pythonPackages ? (_: [])
, rtsopts ? "-M3g -N2"
, systemPackages ? (_: [])
}:

let
  inherit (builtins) any elem filterSource listToAttrs;
  lib = nixpkgs.lib;
  cleanSource = name: type: let
    baseName = baseNameOf (toString name);
  in lib.cleanSourceFilter name type && !(
    (type == "directory" && (elem baseName [ ".stack-work" "dist"])) ||
    any (lib.flip lib.hasSuffix baseName) [ ".hi" ".ipynb" ".nix" ".sock" ".yaml" ".yml" ]
  );
  ihaskellSourceFilter = src: name: type: let
    relPath = lib.removePrefix (toString src + "/") (toString name);
  in cleanSource name type && ( any (lib.flip lib.hasPrefix relPath) [
    "src" "main" "html" "Setup.hs" "ihaskell.cabal" "LICENSE"
  ]);
  ihaskell-src         = filterSource (ihaskellSourceFilter ./.) ./.;
  ipython-kernel-src   = filterSource cleanSource ./ipython-kernel;
  ghc-parser-src       = filterSource cleanSource ./ghc-parser;
  ihaskell-display-src = filterSource cleanSource ./ihaskell-display;
  basement-src         = fetcher {
    owner = "haskell-foundation";
    repo = "foundation";
    rev = "65b5cb8a4d3e00584a30d53218c18f7acdd6acc8";
    sha256 = "1vfmnlh305k7ygvzyxmvnfx3zy28x6lpkfkbgx7v72n8968d9b9x";
  };
  entropy-src          = fetcher {
    owner = "TomMD";
    repo = "entropy";
    rev = "24495599ee9a2e9ce26e99285ab17ee882afdc7e";
    sha256 = "083mkmqg37ai3jijn4nnzyh95ifr558pgnn1grk6w8aisirgnfin";
  };
  memory-src          = fetcher {
    owner = "vincenthz";
    repo = "hs-memory";
    rev = "feee6256e19ed178dc75b071dc54983bc6320f26";
    sha256 = "1vv1js5asaxbahvryxlxch14x3jq15a09xixhz330m3d77zfyiw9";
  };
  tasty-src          = fetcher {
    owner = "feuerbach";
    repo = "tasty";
    rev = "540c85d14e6601bb8c92e9fea22dbb8bd27cbe85";
    sha256 = "1grqmbw62zpm94wv712ipmgf1li628s3i489q9ibbingdby4d6b9";
  };
  displays = self: listToAttrs (
    map
      (display: { name = display; value = self.callCabal2nix display "${ihaskell-display-src}/${display}" {}; })
      [
        "ihaskell-aeson"
        "ihaskell-blaze"
        "ihaskell-charts"
        "ihaskell-diagrams"
        "ihaskell-gnuplot"
        "ihaskell-hatex"
        "ihaskell-juicypixels"
        "ihaskell-magic"
        "ihaskell-plot"
        "ihaskell-rlangqq"
        "ihaskell-static-canvas"
        "ihaskell-widgets"
      ]);
  haskellPackages = nixpkgs.haskell.packages."${compiler}".extend (self: super: {
    ihaskell          = nixpkgs.haskell.lib.overrideCabal (
                        self.callCabal2nix "ihaskell" ihaskell-src {}) (_drv: {
      preCheck = ''
        export HOME=$(${nixpkgs.pkgs.coreutils}/bin/mktemp -d)
        export PATH=$PWD/dist/build/ihaskell:$PATH
        export GHC_PACKAGE_PATH=$PWD/dist/package.conf.inplace/:$GHC_PACKAGE_PATH
      '';
    });
    ghc-parser        = self.callCabal2nix "ghc-parser" ghc-parser-src {};
    ipython-kernel    = self.callCabal2nix "ipython-kernel" ipython-kernel-src {};
    basement          = self.callCabal2nix "basement" "${basement-src}/basement" {};
    foundation        = self.callCabal2nix "foundation" "${basement-src}/foundation" {};
    memory            = self.callCabal2nix "memory" memory-src {};
    primitive         = self.callHackage "primitive" "0.6.4.0" {};
    tagged            = self.callHackage "tagged" "0.8.6" {};
    tasty             = self.callCabal2nix "tasty" "${tasty-src}/core" {};

    async             = nixpkgs.haskell.lib.doJailbreak super.async;
    cabal-doctest     = nixpkgs.haskell.lib.doJailbreak super.cabal-doctest;
    contravariant     = nixpkgs.haskell.lib.doJailbreak super.contravariant;
    ChasingBottoms    = nixpkgs.haskell.lib.doJailbreak super.ChasingBottoms;
    doctest           = nixpkgs.haskell.lib.doJailbreak super.doctest;
    entropy           = nixpkgs.haskell.lib.appendPatch (self.callCabal2nix "entropy" entropy-src {}) (nixpkgs.fetchurl {
      url = "https://raw.githubusercontent.com/hvr/head.hackage/7df01566f337a166ef2aa8939c35f6b9322c5d42/patches/entropy-0.4.1.1.patch";
      sha256 = "0r06zi0rbasn3gkqwy07jla96a52h656xvmd82mjydc8g5f6m3lc";
    });
    hashable          = nixpkgs.haskell.lib.doJailbreak super.hashable;
    hashable-time     = nixpkgs.haskell.lib.doJailbreak super.hashable-time;
    integer-logarithms= nixpkgs.haskell.lib.doJailbreak super.integer-logarithms;
    patience          = nixpkgs.haskell.lib.appendPatch super.patience ./patience-0.1.1.patch;
    split             = nixpkgs.haskell.lib.doJailbreak super.split;
    static-canvas     = nixpkgs.haskell.lib.doJailbreak super.static-canvas;
    StateVar          = nixpkgs.haskell.lib.doJailbreak super.StateVar;
    test-framework    = nixpkgs.haskell.lib.doJailbreak super.test-framework;
    th-lift           = nixpkgs.haskell.lib.doJailbreak super.th-lift;
    unix-compat       = self.callCabal2nix "unix-compat" ../unix-compat {};
    unliftio-core     = nixpkgs.haskell.lib.doJailbreak super.unliftio-core;
    unordered-containers = nixpkgs.haskell.lib.dontCheck super.unordered-containers;
    vector            = nixpkgs.haskell.lib.doJailbreak super.vector;
    vector-algorithms = nixpkgs.haskell.lib.appendPatch super.vector-algorithms ./vector-algorithms-0.7.0.1.patch;
  } // displays self);
  ihaskellEnv = haskellPackages.ghcWithPackages (self: [ self.ihaskell ] ++ packages self);
  jupyter = nixpkgs.python3.withPackages (ps: [ ps.jupyter ps.notebook ] ++ pythonPackages ps);
  ihaskellSh = cmd: extraArgs: nixpkgs.writeScriptBin "ihaskell-${cmd}" ''
    #! ${nixpkgs.stdenv.shell}
    export GHC_PACKAGE_PATH="$(echo ${ihaskellEnv}/lib/*/package.conf.d| tr ' ' ':'):$GHC_PACKAGE_PATH"
    export PATH="${nixpkgs.stdenv.lib.makeBinPath ([ ihaskellEnv jupyter ] ++ systemPackages nixpkgs)}:$PATH"
    ${ihaskellEnv}/bin/ihaskell install -l $(${ihaskellEnv}/bin/ghc --print-libdir) --use-rtsopts="${rtsopts}" && ${jupyter}/bin/jupyter ${cmd} ${extraArgs} "$@"
  '';
in
nixpkgs.buildEnv {
  name = "ihaskell-with-packages";
  buildInputs = [ nixpkgs.makeWrapper ];
  paths = [ ihaskellEnv jupyter ];
  postBuild = ''
    ln -s ${ihaskellSh "notebook" ""}/bin/ihaskell-notebook $out/bin/
    ln -s ${ihaskellSh "nbconvert" ""}/bin/ihaskell-nbconvert $out/bin/
    ln -s ${ihaskellSh "console" "--kernel=haskell"}/bin/ihaskell-console $out/bin/
    for prg in $out/bin"/"*;do
      if [[ -f $prg && -x $prg ]]; then
        wrapProgram $prg --set PYTHONPATH "$(echo ${jupyter}/lib/*/site-packages)"
      fi
    done
  '';
}
