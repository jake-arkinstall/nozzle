{
  pkgs,
  relative-directory,
  pkg-wrapper
}:
let
  inherit (pkgs.lib.strings) concatStrings concatStringsSep;
  inherit (pkgs.lib.lists) concatLists unique length;
  spaced = concatStringsSep " ";
in
{name, source, dependencies ? []}:
let
  dependencies' = map (x: pkg-wrapper{name=x.name; derivation=x;}) dependencies;
  subdependencies = dep: [dep] ++ dep.dependencies;
  all-subdependencies = unique (dependencies' ++ concatLists (map (d: d.dependencies) dependencies'));
  all-libs = map (x: x.library) (builtins.filter (x: x.has-library) all-subdependencies);



  single-include = dependency:
    if dependency.is-external
    then "-isystem ${dependency.headers}/include"
    else "-I${dependency.headers}/include";
  all-includes = spaced (map single-include all-subdependencies);
  remove-references = spaced ((map (d: d.headers) all-subdependencies) ++ (map (d: d.library) (builtins.filter (x: x.has-library) all-subdependencies)));

  cflags = spaced (map (d: spaced d.cflags) all-subdependencies);


  ###############
  # Derivations #
  ###############

  # build the source file as an object before linking
  intermediate-object = pkgs.stdenv.mkDerivation{
    name = "${name}-intermediate";
    phases=["unpackPhase" "buildPhase" "installPhase"];
    src = source;
    unpackPhase = ''
      runHook preUnpack
      cp $src source.cpp;
      all_includes="${all-includes}";
      cflags="${cflags}";
      runHook postUnpack
    '';
    buildPhase = ''
      runHook preBuild
      $CXX -c -o a.o --std=c++20 -O3 $all_includes $cflags source.cpp;
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir $out;
      install -Dm0775 a.o $out/a.o
      runHook postInstall
    '';
  };

  # link the built source with dependencies
  executable = pkgs.stdenv.mkDerivation{
    inherit name;
    nozzle-target = true;
    phases=["unpackPhase" "buildPhase" "installPhase"];
    buildInputs = all-libs;
    src = ["${intermediate-object}/a.o"];
    nativeBuildInputs = [pkgs.removeReferencesTo];
    unpackPhase = ''
      runHook preUnpack
      cp $src .
      runHook postUnpack
    '';
    buildPhase = ''
      runHook preBuild

      objects="";
      shared_objects="";
      for lib in $buildInputs; do
        for f in $lib/lib/*.a; do
           objects="$objects $f";
        done
        for f in $lib/lib/*.so $lib/lib/*.dylib; do
           shared_objects="$shared_objects $f";
        done
      done

      echo "$CXX -o a.out a.o -Wl,--start-group $objects $shared_objects -Wl,--end-group -lstdc++;";
      $CXX -o a.out a.o -Wl,--start-group $objects $shared_objects -Wl,--end-group -lstdc++;
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin;
      install -Dm0775 a.out $out/bin/$name;
      runHook postInstall
    '';
    postInstall = if length all-subdependencies == 0 then "" else ''
      for ref in ${remove-references}; do
        echo "Checking $ref";
        if [ -z "$(find $ref -name '*.so' -o -name '*.dylib')" ]; then
          echo "No shared libraries found, removing reference";
          remove-references-to -t $ref $out/bin/$name
        else
          echo "Shared libraries identifier, not removing reference";
        fi;
      done;
    '';
  };

in executable
