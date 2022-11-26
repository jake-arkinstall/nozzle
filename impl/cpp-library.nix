{
  pkgs,
  workspace-root,
  relative-directory
}:
let
  inherit (pkgs.lib.strings) concatStrings concatStringsSep;
  inherit (builtins) length;
in
{name, headers, sources ? []}:
let
  ###########
  # Helpers #
  ###########

  # headers can't be placed in the derivation root directory,
  # because source files will refer to them by their path relative
  # to the workspace root.
  target-directory = builtins.toString relative-directory;
  header-destination = header: "$out/${target-directory}/${builtins.baseNameOf header}";
  copy-header = header: "cp ${header} ${header-destination header}; ";
  copy-all-headers = map copy-header headers;

  sub-library = source: "${build-source source}/lib.o";
  sub-library-list = map sub-library sources;
  sub-libraries = concatStringsSep " " sub-library-list;

  ###############
  # Derivations #
  ###############

  # build the resulting include directory
  target-headers = pkgs.stdenv.mkDerivation {
    name = "${name}-headers";
    phases=["installPhase"];
    installPhase = ''
      mkdir -p $out/${target-directory};
      ${concatStrings copy-all-headers}
    '';
  };

  # build an individual library object into lib.o files
  build-source = source: pkgs.stdenv.mkDerivation {
    name = builtins.toString source;
    phases = ["buildPhase" "installPhase"];
    buildPhase = ''
      gcc -c -o lib.o --std=c++20 -O3 -I${target-headers} ${source};
    '';
    installPhase = ''
      mkdir -p $out;
      install -Dm0775 lib.o $out/lib.o;
    '';
  };

  # combine all library objects into a lib.a file
  build-library = pkgs.stdenv.mkDerivation {
    name = "${name}-lib";
    phases = ["buildPhase" "installPhase"];
    buildPhase =
      if (length sources) == 0
      then ""
      else ''
        ar rcs lib.a ${sub-libraries};
      '';
    installPhase = 
      if (length sources) == 0
      then ''
        mkdir -p $out;
      '' else ''
        mkdir -p $out;
        install -Dm0775 lib.a $out/lib.a;
      '';
  };
  
  # combine headers and library into one derivation
  complete-library = pkgs.stdenv.mkDerivation{
    inherit name;
    phases = ["installPhase"];
    installPhase = ''
       mkdir -p $out;
       cp -r ${target-headers} $out/include;
       cp -r ${build-library} $out/lib;
    '';
  };

in complete-library
