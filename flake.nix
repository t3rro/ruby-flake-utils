{
  description = "produce ruby flakes";

  outputs = { ... }:
    let
      mkFuncs = pkgs: {
        mkRubyScript =
          # take script and dispatch it with the local bundle binary
          script: pkgs.writeShellScriptBin script "${bins.bundle} exec ${script} $@";
      };

      mkScripts = funcs: {
        rake = funcs.mkRubyScript "rake";
        rubyDevScripts = [ scripts.rake ];
      };

      mkEnvs = pkgs: configurations: {
        gems = pkgs.bundlerEnv configurations.bundlerConfig;
      };

      mkBins = envs: {
        ruby = pkgs.ruby_3_1;
        bundle = "${envs.gems}/bin/bundle";
      };

      mkConfigurations = name: pkgs:
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
          configurations = mkConfigurations name pkgs;
          funcs = mkFuncs pkgs;
          scripts = mkScripts funcs;
          envs = mkEnvs pkgs configurations;
          envs = mkBins pkgs configurations;
        };
      };
    };
}
