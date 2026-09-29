{
  description = "Development environment for Kubernetes The Hard Way";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forEachSupportedSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        pkgs = import nixpkgs { inherit system; };
      });
    in
    {
      devShells = forEachSupportedSystem ({ pkgs }:
        let
          # Real binary wrapper so 'terraform' works seamlessly inside direnv and scripts
          terraform-wrapper = pkgs.writeShellScriptBin "terraform" ''
            exec "${pkgs.opentofu}/bin/tofu" "$@"
          '';
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              opentofu            # provides the 'tofu' binary
              terraform-wrapper   # provides the 'terraform' binary (forwarding to tofu)
              cfssl               # includes cfssl and cfssljson
              etcd                # includes etcdctl
              openssl             # for inspecting certs
            ];

            shellHook = ''
              echo "=========================================================="
              echo "🚀 Kubernetes The Hard Way: Development Shell Active"
              echo "   • OpenTofu  : $(tofu version 2>/dev/null | head -n 1 || echo 'ready')"
              echo "   • Terraform : available (redirects to OpenTofu)"
              echo "   • CFSSL     : $(cfssl version 2>/dev/null | grep -oP '(?<=Version: )[^ ]+' || echo 'ready')"
              echo "   • etcdctl   : $(etcdctl version 2>/dev/null | grep -oP '(?<=etcdctl version: )[^ ]+' || echo 'ready')"
              echo "=========================================================="
            '';
          };
        });
    };
}
