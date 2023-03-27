{
  pkgs,
  relative-directory,
  pkg-wrapper
}:
let
  inherit (pkgs.lib.strings) concatStrings concatStringsSep;
  inherit (pkgs.lib.lists) concatLists unique;
  inherit (builtins) length;
in
{name, headers ? [], cflags ? "", sources ? [], dependencies ? []}:
let
  ###########
  # Helpers #
  ###########
  # if dependencies are native, e.g. pkgs.fmt instead of a pre-wrapped
  # pkg-wrapper dependencies, they need to be wrapped. pkg-wrapper maps
  # pre-wrapped packages to themselves, so the following won't impact those.
  dependencies' = map (x: pkg-wrapper{name=x.name; derivation=x; cflags="";}) dependencies;
  # get subdependencies from a single dependency
  subdependencies = dep: [dep] ++ dep.propagatedBuildInputs;
  # get all subdependencies across all dependencies
  all-subdependencies = unique (dependencies' ++ concatLists (map (d: d.propagatedBuildInputs) dependencies'));
  get-includes-impl = dependency: ''
    includes="$includes -I${dependency}/include";
  '';
  get-includes = concatStrings (map get-includes-impl all-subdependencies);

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
    name = builtins.baseNameOf source;
    phases = ["buildPhase" "installPhase"];
    buildPhase = ''
      includes="";
      ${get-includes}
      echo "$CXX -c -o lib.o --std=c++20 -O3 $includes -I${target-headers} ${cflags} ${source};"
      $CXX -c -o lib.o --std=c++20 -O3 $includes -I${target-headers} ${cflags} ${source};
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
        mkdir -p $out/lib;
        install -Dm0775 lib.a $out/lib/lib${name}.a;
      '';
  };
  
  # combine headers and library into one derivation
  complete-library = pkgs.stdenv.mkDerivation{
    inherit name;
    inherit cflags;
    nozzle-target = true;

    propagatedBuildInputs = concatLists (map (x: [x] ++ x.propagatedBuildInputs) dependencies');
    phases = ["installPhase"];
    installPhase = ''
       mkdir -p $out;
       cp -r ${target-headers} $out/include;
       if [ -d ${build-library}/lib ]; then
         cp -r ${build-library}/lib $out;
       else
         mkdir $out/lib;
       fi;
    '';
  };

in complete-library
