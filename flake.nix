{
  description = "produce ruby flakes";

  outputs = { ... }:
    let
      funcs = {
        mkRubyScript =
          # take script and dispatch it with the local bundle binary
          script: pkgs.writeShellScriptBin script "${bins.bundle} exec ${script} $@";
      };

      scripts = {
        rake = lib.gemDefaults.funcs.mkRubyScript "rake";
        rubyDevScripts = [ scripts.rake ];
      };

      envs = {
        gems = pkgs.bundlerEnv configurations.bundlerConfig;
      };

      bins = {
        ruby = pkgs.ruby_3_1;
        bundle = "${envs.gems}/bin/bundle";
      };

      mkConfiguration = name: pkgs:
        {

          bundlerConfig = {
            inherit name;
            ruby = bins.ruby;
            lockfile = ./Gemfile.lock;
            gemfile = ./Gemfile;
            gemset = ./gemset.nix;
          };

          derivationConfig = {
            src = ./.;
            inherit name;
            buildInputs = [
              bins.ruby
              envs.gems
              pkgs.makeWrapper
              pkgs.git
            ] ++ scripts.rubyDevScripts;
            installPhase = ''
              mkdir -p $out/{bin,share/${name}}
              cp -r * $out/share/${name}
            '';

          };
        };
    in
    {
      # use lib keyword on outputs to expose nix functions
      lib = {
        mkGemDefaults = { name, pkgs }: {
          configurations = mkConfiguration name pkgs;
          # configurations = {
          #
          #   bundlerConfig = {
          #     inherit name;
          #     ruby = bins.ruby;
          #     lockfile = ./Gemfile.lock;
          #     gemfile = ./Gemfile;
          #     gemset = ./gemset.nix;
          #   };
          #
          #   derivationConfig = {
          #     src = ./.;
          #     inherit name;
          #     buildInputs = [
          #       bins.ruby
          #       envs.gems
          #       pkgs.makeWrapper
          #       pkgs.git
          #     ] ++ scripts.rubyDevScripts;
          #     installPhase = ''
          #       mkdir -p $out/{bin,share/${name}}
          #       cp -r * $out/share/${name}
          #     '';
          #
          #   };
          # };
        };
      };
    };
}
