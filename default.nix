{ pkgs ? import <nixpkgs> {},
  relative-directory ? /.,
  workspace ? {}
}:
let
  inherit (pkgs.lib) fix composeManyExtensions;
  import' = {path, dependencies ? {}}:
    import (path + /build.nix)
    ({
      pkgs = pkgs;
      nozzle = import ./. {
        inherit pkgs;
        relative-directory = relative-directory + ("/" + (builtins.baseNameOf path));
      };
    } // dependencies);
  pkg-wrapper' = import ./impl/pkg-wrapper.nix { pkgs=pkgs; };
  cpp-library' = import ./impl/cpp-library.nix {
                                                 pkgs=pkgs;
                                                 relative-directory=relative-directory;
                                                 pkg-wrapper=pkg-wrapper';
                                               };
  cpp-binary' = import ./impl/cpp-binary.nix {
                                               pkgs=pkgs;
                                               relative-directory=relative-directory;
                                               pkg-wrapper=pkg-wrapper';
                                             };

  add-subdirectories' = {paths, dependencies ? {}}: fix (
    composeManyExtensions (map (path: import' {path=path; dependencies=dependencies;}) paths) workspace
  );

in
{
  add-subdirectories = add-subdirectories';
  add-subdirectory = {path, dependencies ? {}}: add-subdirectories' {paths=[path]; dependencies=dependencies;};
  cpp-library = cpp-library';
  cpp-binary = cpp-binary';
  pkg-wrapper = pkg-wrapper';
}
