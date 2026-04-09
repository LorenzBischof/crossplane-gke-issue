# Patched Crossplane build using Nix flakes
{
  description = "Patched Crossplane Docker images";

  inputs = {
    crossplane.url = "github:crossplane/crossplane/v2.2.0";
    nixpkgs.follows = "crossplane/nixpkgs";
    gomod2nix.follows = "crossplane/gomod2nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      crossplane,
      gomod2nix,
    }:
    let
      # Reference branch/tag
      version = "v2.2.0";
      # Only used for the OCI image tag.
      imageTag =
        let
          envTag = builtins.getEnv "IMAGE_TAG";
        in
        if envTag != "" then envTag else version;

      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ gomod2nix.overlays.default ];
      };

      # Apply our patch to crossplane source
      patchedSource = pkgs.applyPatches {
        src = crossplane;
        patches = [ ./crossplane.patch ];
        name = "crossplane-patched-source";
      };

      # Reuse crossplane's build infrastructure with patched source
      build = import "${crossplane}/nix/build.nix" {
        inherit pkgs;
        self = patchedSource; # Override 'self' to use patched source
      };

      apps = import "${crossplane}/nix/apps.nix" { inherit pkgs; };

      imagePlatforms = [
        {
          os = "linux";
          arch = "amd64";
        }
      ];

      # Build images from patched source
      images = build.images {
        version = imageTag;
        platforms = imagePlatforms;
      };

    in
    {
      packages.${system}.default = build.release {
        inherit version;
        goPlatforms = imagePlatforms;
        inherit imagePlatforms;
      };

      apps.${system}.push-images = apps.pushImages {
        version = imageTag;
        inherit images;
        platforms = imagePlatforms;
      };

      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          docker-client
          yq-go
          kubectl
          kubernetes-helm
          (google-cloud-sdk.withExtraComponents [ google-cloud-sdk.components.gke-gcloud-auth-plugin ])
          kind
        ];
      };
    };
}
