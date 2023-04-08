{pkgs}:
let
  inherit (builtins) hasAttr getAttr;
  get-deps = derivation: 
    if (hasAttr "propagatedBuildInputs" derivation)
    then map (x: pkg-wrapper{name=x.name; derivation=x;}) (derivation.buildInputs ++ derivation.propagatedBuildInputs)
    else [];
  pkg-wrapper = {name, derivation, cflags ? derivation.cmakeFlags}:
    if (hasAttr "nozzle-package" derivation) then
      derivation
    else if (hasAttr "dev" derivation) then
    {
      headers = derivation.dev.outPath;
      library = derivation.out.outPath;
      dependencies = get-deps derivation;
      has-library = true;
      nozzle-package = true;
      is-external = true;
      cflags = cflags;
    }
    else
    {
      headers = derivation.out.outPath;
      library = derivation.out.outPath;
      dependencies = get-deps derivation;
      has-library = true;
      nozzle-package = true;
      is-external = true;
      cflags = cflags;
    };
in pkg-wrapper
