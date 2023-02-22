{
  description = "produce ruby flakes";

  outputs = { ... }: rec {
    # use lib keyword on outputs to expose nix functions
    lib = {
      mkGemDefaults = { name, pkgs }: {
        funcs = {
          mkRubyScript =
            # take script and dispatch it with the local bundle binary
            script: pkgs.writeShellScriptBin script "${lib.gemDefaults.bins.bundle} exec ${script} $@";
        };

        scripts = {
          rake = lib.gemDefaults.funcs.mkRubyScript "rake";
          rubyDevScripts = [ lib.gemDefaults.scripts.rake ];
        };

        envs = {
          gems = pkgs.bundlerEnv lib.gemDefaults.configurations.bundlerConfig;
        };

        bins = {
          ruby = pkgs.ruby_3_1;
          bundle = "${lib.gemDefaults.envs.gems}/bin/bundle";
        };

        configurations = {

          bundlerConfig = {
            inherit name;
            ruby = lib.gemDefaults.bins.ruby;
            lockfile = ./Gemfile.lock;
            gemfile = ./Gemfile;
            gemset = ./gemset.nix;
          };

          derivationConfig = {
            src = ./.;
            inherit name;
            buildInputs = [
              lib.gemDefaults.bins.ruby
              lib.gemDefaults.envs.gems
              pkgs.makeWrapper
              pkgs.git
            ] ++ lib.gemDefaults.scripts.rubyDevScripts;
            installPhase = ''
              mkdir -p $out/{bin,share/${name}}
              cp -r * $out/share/${name}
            '';

          };
        };
      };
    };
  };
}
