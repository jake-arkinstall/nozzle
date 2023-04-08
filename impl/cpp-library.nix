{
  pkgs,
  relative-directory,
  pkg-wrapper
}:
let
  inherit (pkgs.lib.strings) concatStrings concatStringsSep;
  inherit (pkgs.lib.lists) concatLists unique;
  inherit (builtins) length;
  spaced = concatStringsSep " ";
in
{name, headers ? [], cflags ? [], sources ? [], dependencies ? []}:
let
  dependencies' = map (x: pkg-wrapper{name=x.name; derivation=x;}) dependencies;
  subdependencies = dep: [dep] ++ dep.dependencies;
  all-subdependencies = unique (dependencies' ++ concatLists (map (d: d.dependencies) dependencies'));
  single-include = dependency:
    if dependency.is-external
    then "-isystem ${dependency.headers}/include"
    else "-I${dependency.headers}/include";
  meta-self = {is-external = false; headers=target-headers;};
  all-includes = spaced (map single-include (all-subdependencies ++ [meta-self]));
  has-sources = (length sources) > 0;
  all-cflags = spaced (map (d: spaced d.cflags) all-subdependencies);

  target-directory = builtins.toString relative-directory;
  header-destination = header: "${target-directory}/${builtins.baseNameOf header}";
  copy-header = header: "cp ${header} include/${header-destination header}; ";
  copy-all-headers = map copy-header headers;

  target-headers = pkgs.stdenv.mkDerivation {
    name = "${name}-headers";
    phases=["unpackPhase" "installPhase"];
    unpackPhase = ''
      mkdir -p include/${target-directory};
      ${concatStrings copy-all-headers}
    '';
    installPhase = ''
      mkdir -p $out;
      cp -r include $out;
    '';
  };

  build-source = source: pkgs.stdenv.mkDerivation {
    name = builtins.baseNameOf source;
    src = source;
    phases = ["unpackPhase" "buildPhase" "installPhase"];
    buildInputs= [target-headers] ++ map (x: x.headers) all-subdependencies;
    unpackPhase = ''
      runHook preUnpack
      cp $src source.cpp;
      export cflags="${all-cflags}";
      runHook postUnpack
    '';
    buildPhase = ''
      runHook preBuild
      all_includes=""
      for f in $buildInputs; do
         all_includes="$all_includes -I$f/include";
      done;
      echo "$CXX -c -o lib.o --std=c++20 -O3 $all_includes $cflags source.cpp";
      $CXX -c -o lib.o --std=c++20 -O3 $all_includes $cflags source.cpp;
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out;
      install -Dm0775 lib.o $out/lib.o;
      runHook postInstall
    '';
  };

  all-built-sources = map build-source sources;

  built-library = pkgs.stdenv.mkDerivation {
    name = "${name}-lib";
    phases = ["buildPhase" "installPhase"];
    srcs = all-built-sources;
    buildPhase = ''
      runHook preBuild
      sub_libs="";
      for s in $srcs; do
        sub_libs="$sub_libs $s/lib.o";
      done;
      ar rcs lib.a $sub_libs;
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib;
      install -Dm0775 lib.a $out/lib/lib$name.a;
      runHook postInstall
    '';
  };
in
  if (length sources) == 0 then 
  {
    headers = target-headers;
    dependencies= concatLists (map (x: [x] ++ x.dependencies) dependencies');
    has-library = false;
    nozzle-package = true;
    is-external = false;
    cflags = cflags;
  } else {
    headers = target-headers;
    library = built-library;
    dependencies = concatLists (map (x: [x] ++ x.dependencies) dependencies');
    has-library = true;
    nozzle-package = true;
    is-external = false;
    cflags = cflags;
  }
