{
  description = "produce ruby flakes";
  inputs.flake-utils.url = github:numtide/flake-utils;

  outputs = { flake-utils, ... }:
    let
      # include flake-utils context to make systems
      mkGemSystems = name: nixpkgs: lockfile: gemfile: gemset: strategy: src:
        flake-utils.lib.eachDefaultSystem
          (system: mkGemSystem system name nixpkgs lockfile gemfile gemset strategy src);

      # understanding that flake-utils.lib.eachDefaultSystem creates a system
      # this creates a gem system for a gem.
      mkGemSystem = system: name: nixpkgs: lockfile: gemfile: gemset: strategy: src:
        let
          wrapped = rec {
            inherit name system;
            gems = pkgs.bundlerEnv configurations.bundlerConfig;
            pkgs = import nixpkgs { inherit system; };
            funcs = mkFuncs pkgs bins;
            scripts = mkScripts funcs name pkgs bins;
            envs = mkEnvs pkgs configurations;
            bins = mkBins envs pkgs;
            configurations = mkConfigurations name pkgs envs scripts bins
              {
                inherit
                  lockfile
                  gemfile
                  gemset;
              }
              strategy
              src;

          };

          thisSystem = rec {
            packages = flake-utils.lib.flattenTree {
              default = wrapped.pkgs.stdenv.mkDerivation
                wrapped.configurations.derivationConfig;
            };
            defaultPackage = packages.default;
            devShell =
              let
                derivationConfig = wrapped.configurations.derivationConfig // {
                  shellHook = "zsh";
                  buildInputs = wrapped.configurations.derivationConfig.buildInputs ++
                    [ wrapped.pkgs.zsh ];
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
            script:
            pkgs.writeShellScriptBin
              script "${bins.bundle} exec ${script} $@";
        };

      mkScripts = funcs: name: pkgs: bins:
        rec {
          rake = funcs.mkRubyScript "rake";
          ruby = funcs.mkRubyScript "ruby";
          binScript = pkgs.writeShellScriptBin name "${bins.bundle} exec bin/${name} $@";
          rubyDevScripts = [ rake ruby binScript ];
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

      mkGemLibInstallPhase = name:
        ''
          mkdir -p $out/{bin,share/${name}}
          cp -r * $out/share/${name}
        '';

      mkGemBinInstallPhase = name: ruby: gems:
        ''
          mkdir -p $out/{bin,share/${name}}
          cp -r * $out/share/${name}
          bin=$out/bin/${name}
          binlib=$out/share/${name}/bin/${name}
          bundle=${gems}/bin/bundle
          ruby=${ruby}/bin/ruby

          # we are using bundle exec to start in the bundled environment
          cat > $bin <<EOF
          #!/bin/sh -e
          exec $bundle exec $ruby $binlib "\$@"
          EOF
          chmod +x $bin
        '';

      mkGemInstallPhase = strategy: name: ruby: gems:
        if strategy == "bin" then mkGemBinInstallPhase name ruby gems else mkGemLibInstallPhase name;

      mkConfigurations = name: pkgs: envs: scripts: bins: bundlerConfig: strategy: src:
        {

          bundlerConfig = {
            inherit name;
            ruby = bins.ruby;
          } // bundlerConfig;

          derivationConfig = {
            inherit name src;
            buildInputs = [
              bins.ruby
              envs.gems
              pkgs.makeWrapper
              pkgs.git
            ] ++ scripts.rubyDevScripts;
            installPhase = mkGemInstallPhase strategy name bins.ruby envs.gems;
          };
        };
    in
    {
      # use lib keyword on outputs to expose nix functions
      lib = {
        inherit mkConfigurations;
        inherit mkGemSystems;
        inherit mkGemSystem;
        inherit mkScripts;
        inherit mkFuncs;
        inherit mkEnvs;
        inherit mkBins;
      };
    };
}
