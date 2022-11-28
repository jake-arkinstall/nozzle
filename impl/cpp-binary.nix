{
  pkgs,
  workspace-root,
  relative-directory
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
  # get subdependencies from a single dependency
  subdependencies = dep: [dep] ++ dep.propagatedBuildInputs;
  # get all subdependencies across all dependencies
  all-subdependencies = unique (dependencies ++ concatLists (map (d: d.propagatedBuildInputs) dependencies));

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
    for f in ${dependency}/lib/*.so; do
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
      echo "gcc -c -o a.o --std=c++20 -O3 $includes $cflags ${source}";
      gcc -c -o a.o --std=c++20 -O3 $includes $cflags ${source};
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
      objects="";
      shared_objects="";
      ${get-objects}
      ${get-shared-objects}
      echo "gcc -o a.out ${intermediate-object}/a.o $objects $shared_objects";
      gcc -o a.out ${intermediate-object}/a.o $objects $shared_objects -lstdc++
    '';
    installPhase = ''
      mkdir -p $out/bin;
      install -Dm0775 a.out $out/bin/${name};
    '';
  };

in executable
