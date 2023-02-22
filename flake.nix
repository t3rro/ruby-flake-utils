{
  description = "produce ruby flakes";

  outputs = rec {
    lib = {
      gemDefaults = { name, pkgs }: {
        funcs = {
          mkRubyScript =
            # take script and dispatch it with the local bundle binary
            script: pkgs.writeShellScriptBin script "${gemDefaults.bins.bundle} exec ${script} $@";
        };

        scripts = {
          rake = outputs.lib.gemDefaults.funcs.mkRubyScript "rake";
          rubyDevScripts = [ outputs.lib.gemDefaults.scripts.rake ];
        };

        envs = {
          gems = pkgs.bundlerEnv configurations.bundlerConfig;
        };

        bins = {
          ruby = pkgs.ruby_3_1;
          bundle = "${outputs.lib.gemDefaults.envs.gems}/bin/bundle";
        };

        configurations = {

          bundlerConfig = {
            inherit name;
            ruby = outputs.lib.gemDefaults.bins.ruby;
            lockfile = ./Gemfile.lock;
            gemfile = ./Gemfile;
            gemset = ./gemset.nix;
          };

          derivationConfig = {
            src = ./.;
            inherit name;
            buildInputs = [
              outputs.lib.gemDefaults.bins.ruby
              outputs.lib.gemDefaults.envs.gems
              pkgs.makeWrapper
              pkgs.git
            ] ++ outputs.lib.gemDefaults.scripts.rubyDevScripts;
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
