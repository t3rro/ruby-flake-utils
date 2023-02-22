{
  description = "produce ruby flakes";
  inputs.flake-utils.url = github:numtide/flake-utils;

  outputs = { flake-utils, ... }:
    let
      # include flake-utils context to make systems
      # mkGemSystems = attrs: flake-utils.lib.eachDefaultSystem(system: mkGemSystem );


      # understanding that flake-utils.lib.eachDefaultSystem creates a system
      # thsi creates a gem system for a gem.
      mkGemSystem = system: name: nixpkgs: lockfile: gemfile: gemset:
        let
          wrapped = rec {
            inherit name system;
            gems = pkgs.bundlerEnv configurations.bundlerConfig;
            pkgs = import nixpkgs { inherit system; };
            funcs = mkFuncs pkgs bins;
            scripts = mkScripts funcs;
            envs = mkEnvs pkgs configurations;
            bins = mkBins envs pkgs;
            configurations = mkConfigurations name pkgs envs scripts bins {
              inherit lockfile gemfile gemset;
            };
          };

          thisSystem = rec {
            packages = flake-utils.lib.flattenTree { default = wrapped.pkgs.stdenv.mkDerivation wrapped.configurations.derivationConfig; };
            defaultPackage = packages.default;
            devShell =
              let
                derivationConfig = wrapped.configurations.derivationConfig // {
                  shellHook = "zsh";
                  buildInputs = wrapped.configurations.derivationConfig.buildInputs ++ [ wrapped.pkgs.zsh ];
                };
              in
              wrapped.pkgs.stdenv.mkDerivation derivationConfig;
          };
        in
        thisSystem;

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
        inherit mkGemSystem;
        inherit mkScripts;
        inherit mkFuncs;
        inherit mkEnvs;
        inherit mkBins;
      };
    };
}
