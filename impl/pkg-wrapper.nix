{pkgs}:
let
  pkg-wrapper = {name, derivation, cflags ? ""}:
  if
    (builtins.hasAttr "nozzle-target" derivation)
  then
    derivation
  else
    pkgs.stdenv.mkDerivation{
      name = "${derivation.name}-wrapped";
      nozzle-target = true;
      phases=["installPhase"];
      # wrap dependencies as further pkg-wrappers
      propagatedBuildInputs = if (builtins.hasAttr "propagatedBuildInputs" derivation)
                              then map (x: pkg-wrapper{name=x.name; derivation=x; cflags="";}) derivation.propagatedBuildInputs
                              else [];
      inherit cflags;
      installPhase = ''
        mkdir -p $out/include;
        mkdir -p $out/lib;
      '' +
      (
        builtins.concatStringsSep "\n" (
          builtins.map (
            out-name:
              let
                out-path = (builtins.getAttr out-name derivation).outPath;
              in
                ''
                  if [ -d ${out-path}/include ]; then
                    for f in ${out-path}/include/*; do
                      cp -r $f $out/include;
                    done;
                  fi;
                  if [ -d ${out-path}/lib ]; then
                    for f in ${out-path}/lib/*; do
                      cp -r $f $out/lib;
                    done;
                  fi;
                ''
          ) derivation.outputs));
    };

in pkg-wrapper
