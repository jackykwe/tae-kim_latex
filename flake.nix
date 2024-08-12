# Adapted from the template from https://github.com/NixOS/templates/blob/master/latexmk/flake.nix
# and with heavy reference to "Build LaTeX Documents Reproducibly" @ https://flyx.org/nix-flakes-latex/
{
  description = "An isolated environment for converting Tae Kim's webpages into a PDF";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self, # directory of this flake in the Nix store (see https://nixos.wiki/wiki/Flakes#Output_schema)
    nixpkgs,
    utils,
  }:
    utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};
        tex = pkgs.texlive.combine {
          inherit
            (pkgs.texlive)
            scheme-minimal
            latex-bin # for lualatex binary
            latexmk # for helper script to build the document
            ;
        };
        perl = pkgs.perl.withPackages (p:
          with p; [
            WWWMechanize
            GD
          ]);
      in {
        devShell = pkgs.mkShell {
          # For nix develop (used as a tool to debug nix build, see https://blog.ysndr.de/posts/guides/2021-12-01-nix-shells/#a-development-aid).
          # These are dependencies that should only exist in the build environment (tools you need to build). Read more at https://gist.github.com/CMCDragonkai/45359ee894bc0c7f90d562c4841117b5 and https://discourse.nixos.org/t/use-buildinputs-or-nativebuildinputs-for-nix-shell/8464/2
          nativeBuildInputs = [perl];
        };

        # stdenvNoCC used because no C component is required
        packages.default = pkgs.stdenvNoCC.mkDerivation rec {
          name = "tae-kim-grammar";
          src = self;
          buildInputs = [pkgs.coreutils tex];
          phases = ["unpackPhase" "buildPhase" "installPhase"];
          # unpack: (to access our source code)
          # build: (to typeset the document)
          # install: (to copy the PDF into $out).
          buildPhase = ''
            export PATH="${pkgs.lib.makeBinPath buildInputs}";
            mkdir -p .cache/texmf-var
            env TEXMFHOME=.cache TEXMFVAR=.cache/texmf-var \
              SOURCE_DATE_EPOCH=$(date -d "1970-11-30" +%s) \
              latexmk -interaction=nonstopmode -pdf -lualatex \
              -pretex="\pdfvariable suppressoptionalinfo 512\relax" \
              -usepretex document.tex
          '';
          # TODO change document.tex here to your actual document's name
          # self.lastModified is the latest commit's time
          # ${toString self.lastModified} or $(date -d "2021-11-30" +%s): choose one
          installPhase = ''
            mkdir -p $out
            cp document.pdf $out/
          '';
        };
      }
    );
}
