{pkgs}:
let
  pkg-wrapper = {name, derivation, cflags ? ""}: pkgs.stdenv.mkDerivation{
    name = "${derivation.name}-wrapped";
    phases=["installPhase"];
    # wrap dependencies as further pkg-wrappers
    propagatedBuildInputs = map (x: pkg-wrapper{name=x.name; derivation=x; cflags=cflags;}) derivation.propagatedBuildInputs;
    inherit cflags;
    installPhase = ''
      mkdir $out;
      cp -r ${derivation.dev.outPath}/include $out;
      cp -r ${derivation.out.outPath}/lib $out;
    '';
  };

in pkg-wrapper
