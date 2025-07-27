{
  description = "Kubernetes dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
        with pkgs; {
          devShells.default = mkShell {
            buildInputs =
              [
                kubectl
                kubernetes-helm
                fluxcd
                sops
                age
                jinja2-cli
              ]
              ++ [
                (pkgs.writeShellScriptBin "k" "${kubectl}/bin/kubectl $@")
                (pkgs.writeShellScriptBin "sops-encrypt" "${sops}/bin/sops --encrypt --encrypted-regex '^(data|stringData)$' --in-place $1")
                (pkgs.writeShellScriptBin "b64" "read -s -p 'Enter string to encode: ' input; echo; echo -n \"\$input\" | base64")
              ];

            shellHook = ''
              echo -e "Welcome to the Kubernetes dev environment!\n"

              echo -e "Generating kube-config...\n"

              config_file="$PWD/.kube/config"
              ${sops}/bin/sops --decrypt --output-type json kube-secrets.yaml | ${jinja2-cli}/bin/jinja2 --format=json kube-config.yml.j2 > "$config_file"
              export KUBECONFIG="$config_file"

              if ${kubectl}/bin/kubectl cluster-info &> /dev/null; then
                echo -e "Successfully connected to Kubernetes cluster\n"
              else
                echo -e "Config generated but connection test failed\n"
              fi

              echo -e "$(${kubectl}/bin/kubectl version)\n"

              # To pre-unlock the GPG agent
              if [[ -f "$(which gpg)" ]]; then
                echo "" | gpg --clearsign >> /dev/null 2>&1 || true
              fi
            '';
          };
          formatter = alejandra;
        }
    );
}
