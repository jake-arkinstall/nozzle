{
  pkgs,
  relative-directory,
  pkg-wrapper
}:
let
  inherit (pkgs.lib.strings) concatStrings;
  inherit (pkgs.lib.lists) concatLists unique;
in
{name, source, dependencies ? []}:
let
  ###########
  # helpers #
  ###########
  # if dependencies are native, e.g. pkgs.fmt instead of a pre-wrapped
  # pkg-wrapper dependencies, they need to be wrapped. pkg-wrapper maps
  # pre-wrapped packages to themselves, so the following won't impact those.
  dependencies' = map (x: pkg-wrapper{name=x.name; derivation=x; cflags="";}) dependencies;
  # get subdependencies from a single dependency
  subdependencies = dep: [dep] ++ dep.propagatedBuildInputs;
  # get all subdependencies across all dependencies
  all-subdependencies = unique (dependencies' ++ concatLists (map (d: d.propagatedBuildInputs) dependencies'));

  # For getting includes, objects, shared objects, and cflags
  # for each dependency, via bash variable appending logic
  get-includes-impl = dependency: ''
    includes="$includes -I${dependency}/include";
  '';
  get-objects-impl = dependency: ''
    for f in ${dependency}/lib/*.a; do
       objects="$objects $f";
    done
  '';
  get-shared-objects-impl = dependency: ''
    for f in ${dependency}/lib/*.so ${dependency}/lib/*.dylib; do
       shared_objects="$shared_objects $f";
    done
  '';
  get-cflags-impl = dependency: '' 
    cflags="$cflags ${dependency.cflags}";
  '';
  get-includes = concatStrings (map get-includes-impl all-subdependencies);
  get-objects = concatStrings (map get-objects-impl all-subdependencies);
  get-shared-objects = concatStrings (map get-shared-objects-impl all-subdependencies);
  get-cflags = concatStrings (map get-cflags-impl all-subdependencies);


  ###############
  # Derivations #
  ###############

  # build the source file as an object before linking
  intermediate-object = pkgs.stdenv.mkDerivation{
    name = "${name}-intermediate";
    phases=["buildPhase" "installPhase"];
    buildPhase = ''
      includes="";
      cflags="";
      ${get-includes}
      ${get-cflags}
      $CXX -c -o a.o --std=c++20 -O3 $includes $cflags ${source};
    '';
    installPhase = ''
      mkdir $out;
      install -Dm0775 a.o $out/a.o
    '';
  };

  # link the built source with dependencies
  executable = pkgs.stdenv.mkDerivation{
    inherit name;
    nozzle-target = true;
    phases=["buildPhase" "installPhase"];
    buildPhase = ''
      objects="";
      shared_objects="";
      ${get-objects}
      ${get-shared-objects}
      $CXX -o a.out ${intermediate-object}/a.o $objects $shared_objects -lstdc++
    '';
    installPhase = ''
      mkdir -p $out/bin;
      install -Dm0775 a.out $out/bin/${name};
    '';
  };

in executable
