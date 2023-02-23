{
  description = "produce ruby flakes";
  inputs.flake-utils.url = github:numtide/flake-utils;

  outputs = { flake-utils, ... }:
    let
      # include flake-utils context to make systems
      mkGemSystems = name: nixpkgs: lockfile: gemfile: gemset: strategy:
        flake-utils.lib.eachDefaultSystem
          (
            system: mkGemSystem system name nixpkgs lockfile gemfile gemset strategy
          );

      # understanding that flake-utils.lib.eachDefaultSystem creates a system
      # thsi creates a gem system for a gem.
      mkGemSystem = system: name: nixpkgs: lockfile: gemfile: gemset: strategy:
        let
          wrapped = rec {
            inherit name system;
            gems = pkgs.bundlerEnv configurations.bundlerConfig;
            pkgs = import nixpkgs { inherit system; };
            funcs = mkFuncs pkgs bins;
            scripts = mkScripts funcs;
            envs = mkEnvs pkgs configurations;
            bins = mkBins envs pkgs;
            configurations = mkConfigurations name pkgs envs scripts bins strategy
              {
                inherit
                  lockfile
                  gemfile
                  gemset;
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
          ruby = funcs.mkRubyScript "ruby";
          rubyDevScripts = [ rake ruby ];
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

          # we are using bundle exec to start in the bundled environment
          cat > $bin <<EOF
          #!/bin/sh -e
          exec ${gems}/bin/bundle exec ${ruby}/bin/ruby $out/share/${name}/${name} "\$@"
          EOF
          chmod +x $bin
        '';

      mkGemInstallPhase = strategy: name: ruby: gems:
        if strategy == "bin" then mkGemBinInstallPhase name ruby gems else mkGemLibInstallPhase name;

      mkConfigurations = name: pkgs: envs: scripts: bins: bundlerConfig: strategy:
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
            installPhase = mkGemInstallPhase strategy name ruby gems;
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
