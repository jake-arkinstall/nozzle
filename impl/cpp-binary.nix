{
  pkgs,
  workspace-root,
  relative-directory
}:
let
  inherit (pkgs.lib.strings) concatStrings concatStringsSep;
in
{name, source, dependencies ? []}:
let
  ###########
  # helpers #
  ###########
  # Generate a list of include flags
  include-flags = concatStrings (map (d: "-I${d}/include ") dependencies);

  # Linking is more awkward, because header-only libraries don't have
  # lib.a files to link with. We could use nix logic for this, but
  # for the time being pass that logic onto bash - build a list of
  # lib.a files that exist.
  static-files = map (d: "${d}/lib/lib.a") dependencies;
  static-filter = dependency: ''
    if [ -f ${dependency}/lib/lib.a ]; then
       static="$static ${dependency}/lib/lib.a";
    fi;
  '';
  build-static-subset = concatStrings (map static-filter dependencies);


  ###############
  # Derivations #
  ###############

  # build the source file as an object before linking
  intermediate-object = pkgs.stdenv.mkDerivation{
    name = "${name}-intermediate";
    phases=["buildPhase" "installPhase"];
    buildPhase = ''
      gcc -c -o a.o --std=c++20 -O3 ${include-flags} ${source};
    '';
    installPhase = ''
      mkdir $out;
      install -Dm0775 a.o $out/a.o
    '';
  };

  # link the built source with dependencies
  executable = pkgs.stdenv.mkDerivation{
    inherit name;
    phases=["buildPhase" "installPhase"];
    buildPhase = ''
      static="";
      ${build-static-subset}
      gcc ${intermediate-object}/a.o $static -o a.out;
    '';
    installPhase = ''
      mkdir -p $out/bin;
      install -Dm0775 a.out $out/bin/${name};
    '';
  };

in executable
