{
  description = "produce ruby flakes";

  outputs = { ... }:
    let
      # understanding that flake-utils.lib.eachDefaultSystem creates a system
      # thsi creates a gem system for a gem.
      mkGemSystem = system: name:
        let
          wrapped = rec {
            inherit name system;
            gems = pkgs.bundlerEnv configurations.bundlerConfig;
            pkgs = import nixpkgs { inherit system; };
            rflutils = ruby-flake-utils.lib;
            funcs = rflutils.mkFuncs pkgs bins;
            scripts = rflutils.mkScripts funcs;
            envs = rflutils.mkEnvs pkgs configurations;
            bins = rflutils.mkBins envs pkgs;
            configurations = rflutils.mkConfigurations name pkgs envs scripts bins {
              lockfile = ./Gemfile.lock;
              gemfile = ./Gemfile;
              gemset = ./gemset.nix;
            };
          }; 
        in
        wrapped;

      mkFuncs = pkgs: bins:
        {
          mkRubyScript =
            # take script and dispatch it with the local bundle binary
            script: pkgs.writeShellScriptBin script "${bins.bundle} exec ${script} $@";
        };

      mkScripts = funcs:
        rec {
          rake = funcs.mkRubyScript "rake";
          rubyDevScripts = [ rake ];
        };

      mkEnvs = pkgs: configurations:
        {
          gems = pkgs.bundlerEnv configurations.bundlerConfig;
        };

      mkBins = envs: pkgs:
        {
          ruby = pkgs.ruby_3_1;
          bundle = "${envs.gems}/bin/bundle";
        };

      mkConfigurations = name: pkgs: envs: scripts: bins: bundlerConfig:
        {

          bundlerConfig = {
            inherit name;
            ruby = bins.ruby;
          } // bundlerConfig;

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
        inherit mkConfigurations;
        inherit mkScripts;
        inherit mkFuncs;
        inherit mkEnvs;
        inherit mkBins;
      };
    };
}
