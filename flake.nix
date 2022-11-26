{
  description "A bazel-inspired build system for Nix";

  outputs = { self }: 
  {
    lib = import ./.;
  };
}
