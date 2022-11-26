{
  pkgs ? import <nixpkgs> {},
  workspace-root ? ./.,
  relative-directory ? /.,
  workspace ? {}
}:
let
  inherit (pkgs.lib) fix composeManyExtensions;
  source-dir = workspace-root + relative-directory;
  import' = path:
    import (path + /build.nix)
    {
      pkgs = pkgs;
      nozzle = import ./nozzle.nix {
        pkgs = pkgs;
        workspace-root = workspace-root;
        relative-directory = relative-directory + ("/" + (builtins.baseNameOf path));
      };
    };
  cpp-library' = import ./impl/cpp-library.nix { pkgs=pkgs; workspace-root=workspace-root; relative-directory=relative-directory; };
  cpp-binary' = import ./impl/cpp-binary.nix { pkgs=pkgs; workspace-root=workspace-root; relative-directory=relative-directory; };

  add-subdirectories' = paths: fix (
    composeManyExtensions (map import' paths) workspace
  );

in
{
  add-subdirectories = add-subdirectories';
  add-subdirectory = path: add-subdirectories' [path];
  cpp-library = cpp-library';
  cpp-binary = cpp-binary';
}