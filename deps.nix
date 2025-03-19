{
  pkgs,
  lib,
  beamPackages,
  overrides ? (x: y: { }),
}:

let
  buildMix = lib.makeOverridable beamPackages.buildMix;
  buildRebar3 = lib.makeOverridable beamPackages.buildRebar3;

  workarounds = {
    portCompiler = _unusedArgs: old: {
      buildPlugins = [ pkgs.beamPackages.pc ];
    };

    rustlerPrecompiled =
      {
        toolchain ? null,
        ...
      }:
      old:
      let
        extendedPkgs = pkgs.extend fenixOverlay;
        fenixOverlay = import "${
          fetchTarball {
            url = "https://github.com/nix-community/fenix/archive/056c9393c821a4df356df6ce7f14c722dc8717ec.tar.gz";
            sha256 = "sha256:1cdfh6nj81gjmn689snigidyq7w98gd8hkl5rvhly6xj7vyppmnd";
          }
        }/overlay.nix";
        nativeDir = "${old.src}/native/${with builtins; head (attrNames (readDir "${old.src}/native"))}";
        fenix =
          if toolchain == null then
            extendedPkgs.fenix.stable
          else
            extendedPkgs.fenix.fromToolchainName toolchain;
        native =
          (extendedPkgs.makeRustPlatform {
            inherit (fenix) cargo rustc;
          }).buildRustPackage
            {
              pname = "${old.packageName}-native";
              version = old.version;
              src = nativeDir;
              cargoLock = {
                lockFile = "${nativeDir}/Cargo.lock";
              };
              nativeBuildInputs = [
                extendedPkgs.cmake
              ] ++ extendedPkgs.lib.lists.optional extendedPkgs.stdenv.isDarwin extendedPkgs.darwin.IOKit;
              doCheck = false;
            };

      in
      {
        nativeBuildInputs = [ extendedPkgs.cargo ];

        env.RUSTLER_PRECOMPILED_FORCE_BUILD_ALL = "true";
        env.RUSTLER_PRECOMPILED_GLOBAL_CACHE_PATH = "unused-but-required";

        preConfigure = ''
          mkdir -p priv/native
          for lib in ${native}/lib/*
          do
            ln -s "$lib" "priv/native/$(basename "$lib")"
          done
        '';

        buildPhase = ''
          suggestion() {
            echo "***********************************************"
            echo "                 deps_nix                      "
            echo
            echo " Rust dependency build failed.                 "
            echo
            echo " If you saw network errors, you might need     "
            echo " to disable compilation on the appropriate     "
            echo " RustlerPrecompiled module in your             "
            echo " application config.                           "
            echo
            echo " We think you need this:                       "
            echo
            echo -n " "
            grep -Rl 'use RustlerPrecompiled' lib \
              | xargs grep 'defmodule' \
              | sed 's/defmodule \(.*\) do/config :${old.packageName}, \1, skip_compilation?: true/'
            echo "***********************************************"
            exit 1
          }
          trap suggestion ERR
          ${old.buildPhase}
        '';
      };
  };

  defaultOverrides = (
    final: prev:

    let
      apps = {
        crc32cer = [
          {
            name = "portCompiler";
          }
        ];
        explorer = [
          {
            name = "rustlerPrecompiled";
            toolchain = {
              name = "nightly-2024-11-01";
              sha256 = "sha256-wq7bZ1/IlmmLkSa3GUJgK17dTWcKyf5A+ndS9yRwB88=";
            };
          }
        ];
        snappyer = [
          {
            name = "portCompiler";
          }
        ];
      };

      applyOverrides =
        appName: drv:
        let
          allOverridesForApp = builtins.foldl' (
            acc: workaround: acc // (workarounds.${workaround.name} workaround) drv
          ) { } apps.${appName};

        in
        if builtins.hasAttr appName apps then drv.override allOverridesForApp else drv;

    in
    builtins.mapAttrs applyOverrides prev
  );

  self = packages // (defaultOverrides self packages) // (overrides self packages);

  packages =
    with beamPackages;
    with self;
    {

      absinthe =
        let
          version = "1.7.8";
          drv = buildMix {
            inherit version;
            name = "absinthe";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "absinthe";
              sha256 = "c4085df201892a498384f997649aedb37a4ce8a726c170d5b5617ed3bf45d40b";
            };

            beamDeps = [
              dataloader
              decimal
              nimble_parsec
              telemetry
            ];
          };
        in
        drv;

      absinthe_phoenix =
        let
          version = "2.0.3";
          drv = buildMix {
            inherit version;
            name = "absinthe_phoenix";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "absinthe_phoenix";
              sha256 = "caffaea03c17ea7419fe07e4bc04c2399c47f0d8736900623dbf4749a826fd2c";
            };

            beamDeps = [
              absinthe
              absinthe_plug
              decimal
              phoenix
              phoenix_html
              phoenix_pubsub
            ];
          };
        in
        drv;

      absinthe_plug =
        let
          version = "90a8188e94e2650f13259fb16462075a87f98e18";
          drv = buildMix {
            inherit version;
            name = "absinthe_plug";
            appConfigPath = ./config;

            src = pkgs.fetchFromGitHub {
              owner = "blockscout";
              repo = "absinthe_plug";
              rev = "90a8188e94e2650f13259fb16462075a87f98e18";
              hash = "sha256-Wh1piOkq0m3jh5cYLhuR3oZNDbQE917/X0IXavwbikw=";
            };

            beamDeps = [
              absinthe
              plug
            ];
          };
        in
        drv;

      absinthe_relay =
        let
          version = "1.5.2";
          drv = buildMix {
            inherit version;
            name = "absinthe_relay";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "absinthe_relay";
              sha256 = "0587ee913afa31512e1457a5064ee88427f8fe7bcfbeeecd41c71d9cff0b62b6";
            };

            beamDeps = [
              absinthe
              ecto
            ];
          };
        in
        drv;

      accept =
        let
          version = "0.3.5";
          drv = buildRebar3 {
            inherit version;
            name = "accept";

            src = fetchHex {
              inherit version;
              pkg = "accept";
              sha256 = "11b18c220bcc2eab63b5470c038ef10eb6783bcb1fcdb11aa4137defa5ac1bb8";
            };
          };
        in
        drv;

      bamboo =
        let
          version = "2.3.1";
          drv = buildMix {
            inherit version;
            name = "bamboo";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "bamboo";
              sha256 = "895b2993ed195b2b0fa79c0d5a1d36aa529e817b6df257e4a10745459048d505";
            };

            beamDeps = [
              hackney
              jason
              mime
              plug
            ];
          };
        in
        drv;

      bcrypt_elixir =
        let
          version = "3.2.0";
          drv = buildMix {
            inherit version;
            name = "bcrypt_elixir";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "bcrypt_elixir";
              sha256 = "563e92a6c77d667b19c5f4ba17ab6d440a085696bdf4c68b9b0f5b30bc5422b8";
            };

            beamDeps = [
              comeonin
              elixir_make
            ];
          };
        in
        drv;

      blake2 =
        let
          version = "1.0.4";
          drv = buildMix {
            inherit version;
            name = "blake2";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "blake2";
              sha256 = "e9f4120d163ba14d86304195e50745fa18483e6ad2be94c864ae449bbdd6a189";
            };
          };
        in
        drv;

      briefly =
        let
          version = "4836ba322ffb504a102a15cc6e35d928ef97120e";
          drv = buildMix {
            inherit version;
            name = "briefly";
            appConfigPath = ./config;

            src = pkgs.fetchFromGitHub {
              owner = "CargoSense";
              repo = "briefly";
              rev = "4836ba322ffb504a102a15cc6e35d928ef97120e";
              hash = "sha256-eNfyzS8X1r6SOjV5YDVNGq65J9ezR3QB7WbRD7RaQ/s=";
            };
          };
        in
        drv;

      cachex =
        let
          version = "4.0.3";
          drv = buildMix {
            inherit version;
            name = "cachex";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "cachex";
              sha256 = "d5d632da7f162f8a190f1c39b712c0ebc9cf0007c4e2029d44eddc8041b52d55";
            };

            beamDeps = [
              eternal
              ex_hash_ring
              jumper
              sleeplocks
              unsafe
            ];
          };
        in
        drv;

      castore =
        let
          version = "1.0.11";
          drv = buildMix {
            inherit version;
            name = "castore";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "castore";
              sha256 = "e03990b4db988df56262852f20de0f659871c35154691427a5047f4967a16a62";
            };
          };
        in
        drv;

      cbor =
        let
          version = "1.0.1";
          drv = buildMix {
            inherit version;
            name = "cbor";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "cbor";
              sha256 = "5431acbe7a7908f17f6a9cd43311002836a34a8ab01876918d8cfb709cd8b6a2";
            };
          };
        in
        drv;

      cc_precompiler =
        let
          version = "0.1.10";
          drv = buildMix {
            inherit version;
            name = "cc_precompiler";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "cc_precompiler";
              sha256 = "f6e046254e53cd6b41c6bacd70ae728011aa82b2742a80d6e2214855c6e06b22";
            };

            beamDeps = [
              elixir_make
            ];
          };
        in
        drv;

      certifi =
        let
          version = "2.12.0";
          drv = buildRebar3 {
            inherit version;
            name = "certifi";

            src = fetchHex {
              inherit version;
              pkg = "certifi";
              sha256 = "ee68d85df22e554040cdb4be100f33873ac6051387baf6a8f6ce82272340ff1c";
            };
          };
        in
        drv;

      cldr_utils =
        let
          version = "2.28.2";
          drv = buildMix {
            inherit version;
            name = "cldr_utils";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "cldr_utils";
              sha256 = "c506eb1a170ba7cdca59b304ba02a56795ed119856662f6b1a420af80ec42551";
            };

            beamDeps = [
              castore
              certifi
              decimal
            ];
          };
        in
        drv;

      cloak =
        let
          version = "1.1.4";
          drv = buildMix {
            inherit version;
            name = "cloak";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "cloak";
              sha256 = "92b20527b9aba3d939fab0dd32ce592ff86361547cfdc87d74edce6f980eb3d7";
            };

            beamDeps = [
              jason
            ];
          };
        in
        drv;

      cloak_ecto =
        let
          version = "1.3.0";
          drv = buildMix {
            inherit version;
            name = "cloak_ecto";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "cloak_ecto";
              sha256 = "314beb0c123b8a800418ca1d51065b27ba3b15f085977e65c0f7b2adab2de1cc";
            };

            beamDeps = [
              cloak
              ecto
            ];
          };
        in
        drv;

      combine =
        let
          version = "0.10.0";
          drv = buildMix {
            inherit version;
            name = "combine";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "combine";
              sha256 = "1b1dbc1790073076580d0d1d64e42eae2366583e7aecd455d1215b0d16f2451b";
            };
          };
        in
        drv;

      comeonin =
        let
          version = "5.5.1";
          drv = buildMix {
            inherit version;
            name = "comeonin";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "comeonin";
              sha256 = "65aac8f19938145377cee73973f192c5645873dcf550a8a6b18187d17c13ccdb";
            };
          };
        in
        drv;

      complex =
        let
          version = "0.6.0";
          drv = buildMix {
            inherit version;
            name = "complex";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "complex";
              sha256 = "0a5fa95580dcaf30fcd60fe1aaf24327c0fe401e98c24d892e172e79498269f9";
            };
          };
        in
        drv;

      con_cache =
        let
          version = "1.1.1";
          drv = buildMix {
            inherit version;
            name = "con_cache";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "con_cache";
              sha256 = "1def4d1bec296564c75b5bbc60a19f2b5649d81bfa345a2febcc6ae380e8ae15";
            };

            beamDeps = [
              telemetry
            ];
          };
        in
        drv;

      cors_plug =
        let
          version = "3.0.3";
          drv = buildMix {
            inherit version;
            name = "cors_plug";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "cors_plug";
              sha256 = "3f2d759e8c272ed3835fab2ef11b46bddab8c1ab9528167bd463b6452edf830d";
            };

            beamDeps = [
              plug
            ];
          };
        in
        drv;

      cowboy =
        let
          version = "2.13.0";
          drv = buildRebar3 {
            inherit version;
            name = "cowboy";

            src = fetchHex {
              inherit version;
              pkg = "cowboy";
              sha256 = "e724d3a70995025d654c1992c7b11dbfea95205c047d86ff9bf1cda92ddc5614";
            };

            beamDeps = [
              cowlib
              ranch
            ];
          };
        in
        drv;

      cowboy_telemetry =
        let
          version = "0.4.0";
          drv = buildRebar3 {
            inherit version;
            name = "cowboy_telemetry";

            src = fetchHex {
              inherit version;
              pkg = "cowboy_telemetry";
              sha256 = "7d98bac1ee4565d31b62d59f8823dfd8356a169e7fcbb83831b8a5397404c9de";
            };

            beamDeps = [
              cowboy
              telemetry
            ];
          };
        in
        drv;

      cowlib =
        let
          version = "2.14.0";
          drv = buildRebar3 {
            inherit version;
            name = "cowlib";

            src = fetchHex {
              inherit version;
              pkg = "cowlib";
              sha256 = "0af652d1550c8411c3b58eed7a035a7fb088c0b86aff6bc504b0bc3b7f791aa2";
            };
          };
        in
        drv;

      dataloader =
        let
          version = "2.0.2";
          drv = buildMix {
            inherit version;
            name = "dataloader";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "dataloader";
              sha256 = "4c6cabc0b55e96e7de74d14bf37f4a5786f0ab69aa06764a1f39dda40079b098";
            };

            beamDeps = [
              ecto
              telemetry
            ];
          };
        in
        drv;

      db_connection =
        let
          version = "2.7.0";
          drv = buildMix {
            inherit version;
            name = "db_connection";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "db_connection";
              sha256 = "dcf08f31b2701f857dfc787fbad78223d61a32204f217f15e881dd93e4bdd3ff";
            };

            beamDeps = [
              telemetry
            ];
          };
        in
        drv;

      decimal =
        let
          version = "2.3.0";
          drv = buildMix {
            inherit version;
            name = "decimal";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "decimal";
              sha256 = "a4d66355cb29cb47c3cf30e71329e58361cfcb37c34235ef3bf1d7bf3773aeac";
            };
          };
        in
        drv;

      decorator =
        let
          version = "1.4.0";
          drv = buildMix {
            inherit version;
            name = "decorator";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "decorator";
              sha256 = "0a07cedd9083da875c7418dea95b78361197cf2bf3211d743f6f7ce39656597f";
            };
          };
        in
        drv;

      digital_token =
        let
          version = "1.0.0";
          drv = buildMix {
            inherit version;
            name = "digital_token";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "digital_token";
              sha256 = "8ed6f5a8c2fa7b07147b9963db506a1b4c7475d9afca6492136535b064c9e9e6";
            };

            beamDeps = [
              cldr_utils
              jason
            ];
          };
        in
        drv;

      ecto =
        let
          version = "3.12.5";
          drv = buildMix {
            inherit version;
            name = "ecto";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ecto";
              sha256 = "6eb18e80bef8bb57e17f5a7f068a1719fbda384d40fc37acb8eb8aeca493b6ea";
            };

            beamDeps = [
              decimal
              jason
              telemetry
            ];
          };
        in
        drv;

      ecto_sql =
        let
          version = "3.12.1";
          drv = buildMix {
            inherit version;
            name = "ecto_sql";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ecto_sql";
              sha256 = "aff5b958a899762c5f09028c847569f7dfb9cc9d63bdb8133bff8a5546de6bf5";
            };

            beamDeps = [
              db_connection
              ecto
              postgrex
              telemetry
            ];
          };
        in
        drv;

      elixir_make =
        let
          version = "0.9.0";
          drv = buildMix {
            inherit version;
            name = "elixir_make";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "elixir_make";
              sha256 = "db23d4fd8b757462ad02f8aa73431a426fe6671c80b200d9710caf3d1dd0ffdb";
            };
          };
        in
        drv;

      eternal =
        let
          version = "1.2.2";
          drv = buildMix {
            inherit version;
            name = "eternal";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "eternal";
              sha256 = "2c9fe32b9c3726703ba5e1d43a1d255a4f3f2d8f8f9bc19f094c7cb1a7a9e782";
            };
          };
        in
        drv;

      evision =
        let
          version = "0.2.11";
          drv = buildMix {
            inherit version;
            name = "evision";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "evision";
              sha256 = "b3497d07bcf2c7dae2f9916b22600b18486d4b8b388fe001c074647c67087f55";
            };

            beamDeps = [
              castore
              elixir_make
              nx
            ];
          };
        in
        drv;

      ex_abi =
        let
          version = "0.8.2";
          drv = buildMix {
            inherit version;
            name = "ex_abi";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_abi";
              sha256 = "db785ad43c24d4d7015d3070611eb3e2bd88fa96b614cab10cb42401c94e1e74";
            };

            beamDeps = [
              ex_keccak
              jason
            ];
          };
        in
        drv;

      ex_aws =
        let
          version = "2.5.8";
          drv = buildMix {
            inherit version;
            name = "ex_aws";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_aws";
              sha256 = "8f79777b7932168956c8cc3a6db41f5783aa816eb50de356aed3165a71e5f8c3";
            };

            beamDeps = [
              hackney
              jason
              mime
              sweet_xml
              telemetry
            ];
          };
        in
        drv;

      ex_aws_s3 =
        let
          version = "2.5.6";
          drv = buildMix {
            inherit version;
            name = "ex_aws_s3";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_aws_s3";
              sha256 = "9874e12847e469ca2f13a5689be04e546c16f63caf6380870b7f25bf7cb98875";
            };

            beamDeps = [
              ex_aws
              sweet_xml
            ];
          };
        in
        drv;

      ex_brotli =
        let
          version = "0.5.0";
          drv = buildMix {
            inherit version;
            name = "ex_brotli";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_brotli";
              sha256 = "8447d98d51f8f312629fd38619d4f564507dcf3a03d175c3f8f4ddf98e46dd92";
            };

            beamDeps = [
              phoenix
              rustler_precompiled
            ];
          };
        in
        drv.override (workarounds.rustlerPrecompiled { } drv);

      ex_cldr =
        let
          version = "2.40.2";
          drv = buildMix {
            inherit version;
            name = "ex_cldr";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_cldr";
              sha256 = "cd9039ca9a7c61b99c053a16bd2201ebd7d1c87b49499a4c6d761ec14bca4442";
            };

            beamDeps = [
              cldr_utils
              decimal
              gettext
              jason
              nimble_parsec
            ];
          };
        in
        drv;

      ex_cldr_currencies =
        let
          version = "2.16.4";
          drv = buildMix {
            inherit version;
            name = "ex_cldr_currencies";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_cldr_currencies";
              sha256 = "46a67d1387f14e836b1a24d831fa5f0904663b4f386420736f40a7d534e3cb9e";
            };

            beamDeps = [
              ex_cldr
              jason
            ];
          };
        in
        drv;

      ex_cldr_lists =
        let
          version = "2.11.1";
          drv = buildMix {
            inherit version;
            name = "ex_cldr_lists";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_cldr_lists";
              sha256 = "00161c04510ccb3f18b19a6b8562e50c21f1e9c15b8ff4c934bea5aad0b4ade2";
            };

            beamDeps = [
              ex_cldr_numbers
              jason
            ];
          };
        in
        drv;

      ex_cldr_numbers =
        let
          version = "2.33.6";
          drv = buildMix {
            inherit version;
            name = "ex_cldr_numbers";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_cldr_numbers";
              sha256 = "de1259b535c837ae66801171045878176bdb07243688376fecda71e4b4bb2ba2";
            };

            beamDeps = [
              decimal
              digital_token
              ex_cldr
              ex_cldr_currencies
              jason
            ];
          };
        in
        drv;

      ex_cldr_units =
        let
          version = "3.17.2";
          drv = buildMix {
            inherit version;
            name = "ex_cldr_units";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_cldr_units";
              sha256 = "457d76c6e3b548bd7aba3c7b5d157213be2842d1162c2283abf81d9e2f1e1fc7";
            };

            beamDeps = [
              cldr_utils
              decimal
              ex_cldr_lists
              ex_cldr_numbers
              jason
            ];
          };
        in
        drv;

      ex_hash_ring =
        let
          version = "6.0.4";
          drv = buildMix {
            inherit version;
            name = "ex_hash_ring";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_hash_ring";
              sha256 = "89adabf31f7d3dfaa36802ce598ce918e9b5b33bae8909ac1a4d052e1e567d18";
            };
          };
        in
        drv;

      ex_json_schema =
        let
          version = "0.10.2";
          drv = buildMix {
            inherit version;
            name = "ex_json_schema";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_json_schema";
              sha256 = "37f43be60f8407659d4d0155a7e45e7f406dab1f827051d3d35858a709baf6a6";
            };

            beamDeps = [
              decimal
            ];
          };
        in
        drv;

      ex_keccak =
        let
          version = "0.7.6";
          drv = buildMix {
            inherit version;
            name = "ex_keccak";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_keccak";
              sha256 = "9d1568424eb7b995e480d1b7f0c1e914226ee625496600abb922bba6f5cdc5e4";
            };

            beamDeps = [
              rustler_precompiled
            ];
          };
        in
        drv.override (workarounds.rustlerPrecompiled { } drv);

      ex_rlp =
        let
          version = "0.6.0";
          drv = buildMix {
            inherit version;
            name = "ex_rlp";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_rlp";
              sha256 = "7135db93b861d9e76821039b60b00a6a22d2c4e751bf8c444bffe7a042f1abaf";
            };
          };
        in
        drv;

      ex_secp256k1 =
        let
          version = "0.7.4";
          drv = buildMix {
            inherit version;
            name = "ex_secp256k1";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_secp256k1";
              sha256 = "465fd788c83c24d2df47f302e8fb1011054c81a905345e377c957b159a783bfc";
            };

            beamDeps = [
              rustler_precompiled
            ];
          };
        in
        drv.override (workarounds.rustlerPrecompiled { } drv);

      ex_utils =
        let
          version = "0.1.7";
          drv = buildMix {
            inherit version;
            name = "ex_utils";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_utils";
              sha256 = "66d4fe75285948f2d1e69c2a5ddd651c398c813574f8d36a9eef11dc20356ef6";
            };
          };
        in
        drv;

      expo =
        let
          version = "1.1.0";
          drv = buildMix {
            inherit version;
            name = "expo";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "expo";
              sha256 = "fbadf93f4700fb44c331362177bdca9eeb8097e8b0ef525c9cc501cb9917c960";
            };
          };
        in
        drv;

      file_info =
        let
          version = "0.0.4";
          drv = buildMix {
            inherit version;
            name = "file_info";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "file_info";
              sha256 = "50e7ad01c2c8b9339010675fe4dc4a113b8d6ca7eddce24d1d74fd0e762781a5";
            };

            beamDeps = [
              mimetype_parser
            ];
          };
        in
        drv;

      floki =
        let
          version = "0.37.0";
          drv = buildMix {
            inherit version;
            name = "floki";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "floki";
              sha256 = "516a0c15a69f78c47dc8e0b9b3724b29608aa6619379f91b1ffa47109b5d0dd3";
            };
          };
        in
        drv;

      flow =
        let
          version = "1.2.4";
          drv = buildMix {
            inherit version;
            name = "flow";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "flow";
              sha256 = "874adde96368e71870f3510b91e35bc31652291858c86c0e75359cbdd35eb211";
            };

            beamDeps = [
              gen_stage
            ];
          };
        in
        drv;

      gen_stage =
        let
          version = "1.2.1";
          drv = buildMix {
            inherit version;
            name = "gen_stage";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "gen_stage";
              sha256 = "83e8be657fa05b992ffa6ac1e3af6d57aa50aace8f691fcf696ff02f8335b001";
            };
          };
        in
        drv;

      gettext =
        let
          version = "0.26.2";
          drv = buildMix {
            inherit version;
            name = "gettext";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "gettext";
              sha256 = "aa978504bcf76511efdc22d580ba08e2279caab1066b76bb9aa81c4a1e0a32a5";
            };

            beamDeps = [
              expo
            ];
          };
        in
        drv;

      hackney =
        let
          version = "1.20.1";
          drv = buildRebar3 {
            inherit version;
            name = "hackney";

            src = fetchHex {
              inherit version;
              pkg = "hackney";
              sha256 = "fe9094e5f1a2a2c0a7d10918fee36bfec0ec2a979994cff8cfe8058cd9af38e3";
            };

            beamDeps = [
              certifi
              idna
              metrics
              mimerl
              parse_trans
              ssl_verify_fun
              unicode_util_compat
            ];
          };
        in
        drv;

      hammer =
        let
          version = "6.2.1";
          drv = buildMix {
            inherit version;
            name = "hammer";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "hammer";
              sha256 = "b9476d0c13883d2dc0cc72e786bac6ac28911fba7cc2e04b70ce6a6d9c4b2bdc";
            };

            beamDeps = [
              poolboy
            ];
          };
        in
        drv;

      hammer_backend_redis =
        let
          version = "6.2.0";
          drv = buildMix {
            inherit version;
            name = "hammer_backend_redis";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "hammer_backend_redis";
              sha256 = "9965d55705d7ca7412bb0685f5cd44fc47d103bf388abc50438e71974c36c9fa";
            };

            beamDeps = [
              hammer
              redix
            ];
          };
        in
        drv;

      httpoison =
        let
          version = "2.2.1";
          drv = buildMix {
            inherit version;
            name = "httpoison";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "httpoison";
              sha256 = "51364e6d2f429d80e14fe4b5f8e39719cacd03eb3f9a9286e61e216feac2d2df";
            };

            beamDeps = [
              hackney
            ];
          };
        in
        drv;

      idna =
        let
          version = "6.1.1";
          drv = buildRebar3 {
            inherit version;
            name = "idna";

            src = fetchHex {
              inherit version;
              pkg = "idna";
              sha256 = "92376eb7894412ed19ac475e4a86f7b413c1b9fbb5bd16dccd57934157944cea";
            };

            beamDeps = [
              unicode_util_compat
            ];
          };
        in
        drv;

      image =
        let
          version = "0.56.0";
          drv = buildMix {
            inherit version;
            name = "image";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "image";
              sha256 = "f32bb924c4fd6404108533f7a4de9a3d4c5471038c65e961c1671286eb14ef73";
            };

            beamDeps = [
              evision
              jason
              nx
              phoenix_html
              plug
              sweet_xml
              vix
            ];
          };
        in
        drv;

      jason =
        let
          version = "1.4.4";
          drv = buildMix {
            inherit version;
            name = "jason";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "jason";
              sha256 = "c5eb0cab91f094599f94d55bc63409236a8ec69a21a67814529e8d5f6cc90b3b";
            };

            beamDeps = [
              decimal
            ];
          };
        in
        drv;

      joken =
        let
          version = "2.6.2";
          drv = buildMix {
            inherit version;
            name = "joken";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "joken";
              sha256 = "5134b5b0a6e37494e46dbf9e4dad53808e5e787904b7c73972651b51cce3d72b";
            };

            beamDeps = [
              jose
            ];
          };
        in
        drv;

      jose =
        let
          version = "1.11.10";
          drv = buildMix {
            inherit version;
            name = "jose";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "jose";
              sha256 = "0d6cd36ff8ba174db29148fc112b5842186b68a90ce9fc2b3ec3afe76593e614";
            };
          };
        in
        drv;

      jumper =
        let
          version = "1.0.2";
          drv = buildMix {
            inherit version;
            name = "jumper";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "jumper";
              sha256 = "9b7782409021e01ab3c08270e26f36eb62976a38c1aa64b2eaf6348422f165e1";
            };
          };
        in
        drv;

      logger_file_backend =
        let
          version = "0.0.14";
          drv = buildMix {
            inherit version;
            name = "logger_file_backend";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "logger_file_backend";
              sha256 = "071354a18196468f3904ef09413af20971d55164267427f6257b52cfba03f9e6";
            };
          };
        in
        drv;

      logger_json =
        let
          version = "5.1.4";
          drv = buildMix {
            inherit version;
            name = "logger_json";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "logger_json";
              sha256 = "3f20eea58e406a33d3eb7814c7dff5accb503bab2ee8601e84da02976fa3934c";
            };

            beamDeps = [
              ecto
              jason
              phoenix
              plug
              telemetry
            ];
          };
        in
        drv;

      math =
        let
          version = "0.7.0";
          drv = buildMix {
            inherit version;
            name = "math";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "math";
              sha256 = "7987af97a0c6b58ad9db43eb5252a49fc1dfe1f6d98f17da9282e297f594ebc2";
            };
          };
        in
        drv;

      memento =
        let
          version = "0.3.2";
          drv = buildMix {
            inherit version;
            name = "memento";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "memento";
              sha256 = "25cf691a98a0cb70262f4a7543c04bab24648cb2041d937eb64154a8d6f8012b";
            };
          };
        in
        drv;

      metrics =
        let
          version = "1.0.1";
          drv = buildRebar3 {
            inherit version;
            name = "metrics";

            src = fetchHex {
              inherit version;
              pkg = "metrics";
              sha256 = "69b09adddc4f74a40716ae54d140f93beb0fb8978d8636eaded0c31b6f099f16";
            };
          };
        in
        drv;

      mime =
        let
          version = "2.0.6";
          drv = buildMix {
            inherit version;
            name = "mime";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "mime";
              sha256 = "c9945363a6b26d747389aac3643f8e0e09d30499a138ad64fe8fd1d13d9b153e";
            };
          };
        in
        drv;

      mimerl =
        let
          version = "1.3.0";
          drv = buildRebar3 {
            inherit version;
            name = "mimerl";

            src = fetchHex {
              inherit version;
              pkg = "mimerl";
              sha256 = "a1e15a50d1887217de95f0b9b0793e32853f7c258a5cd227650889b38839fe9d";
            };
          };
        in
        drv;

      mimetype_parser =
        let
          version = "0.1.3";
          drv = buildMix {
            inherit version;
            name = "mimetype_parser";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "mimetype_parser";
              sha256 = "7d8f80c567807ce78cd93c938e7f4b0a20b1aaaaab914bf286f68457d9f7a852";
            };
          };
        in
        drv;

      mox =
        let
          version = "1.1.0";
          drv = buildMix {
            inherit version;
            name = "mox";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "mox";
              sha256 = "d44474c50be02d5b72131070281a5d3895c0e7a95c780e90bc0cfe712f633a13";
            };
          };
        in
        drv;

      msgpax =
        let
          version = "2.4.0";
          drv = buildMix {
            inherit version;
            name = "msgpax";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "msgpax";
              sha256 = "ca933891b0e7075701a17507c61642bf6e0407bb244040d5d0a58597a06369d2";
            };

            beamDeps = [
              plug
            ];
          };
        in
        drv;

      nimble_csv =
        let
          version = "1.2.0";
          drv = buildMix {
            inherit version;
            name = "nimble_csv";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "nimble_csv";
              sha256 = "d0628117fcc2148178b034044c55359b26966c6eaa8e2ce15777be3bbc91b12a";
            };
          };
        in
        drv;

      nimble_options =
        let
          version = "1.1.1";
          drv = buildMix {
            inherit version;
            name = "nimble_options";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "nimble_options";
              sha256 = "821b2470ca9442c4b6984882fe9bb0389371b8ddec4d45a9504f00a66f650b44";
            };
          };
        in
        drv;

      nimble_parsec =
        let
          version = "1.4.2";
          drv = buildMix {
            inherit version;
            name = "nimble_parsec";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "nimble_parsec";
              sha256 = "4b21398942dda052b403bbe1da991ccd03a053668d147d53fb8c4e0efe09c973";
            };
          };
        in
        drv;

      number =
        let
          version = "1.0.5";
          drv = buildMix {
            inherit version;
            name = "number";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "number";
              sha256 = "c0733a0a90773a66582b9e92a3f01290987f395c972cb7d685f51dd927cd5169";
            };

            beamDeps = [
              decimal
            ];
          };
        in
        drv;

      nx =
        let
          version = "0.9.2";
          drv = buildMix {
            inherit version;
            name = "nx";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "nx";
              sha256 = "914d74741617d8103de8ab1f8c880353e555263e1c397b8a1109f79a3716557f";
            };

            beamDeps = [
              complex
              telemetry
            ];
          };
        in
        drv;

      oauth2 =
        let
          version = "2.1.0";
          drv = buildMix {
            inherit version;
            name = "oauth2";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "oauth2";
              sha256 = "8ac07f85b3307dd1acfeb0ec852f64161b22f57d0ce0c15e616a1dfc8ebe2b41";
            };

            beamDeps = [
              tesla
            ];
          };
        in
        drv;

      optimal =
        let
          version = "0.3.6";
          drv = buildMix {
            inherit version;
            name = "optimal";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "optimal";
              sha256 = "1a06ea6a653120226b35b283a1cd10039550f2c566edcdec22b29316d73640fd";
            };
          };
        in
        drv;

      parse_trans =
        let
          version = "3.4.1";
          drv = buildRebar3 {
            inherit version;
            name = "parse_trans";

            src = fetchHex {
              inherit version;
              pkg = "parse_trans";
              sha256 = "620a406ce75dada827b82e453c19cf06776be266f5a67cff34e1ef2cbb60e49a";
            };
          };
        in
        drv;

      phoenix =
        let
          version = "1.5.14";
          drv = buildMix {
            inherit version;
            name = "phoenix";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix";
              sha256 = "207f1aa5520320cbb7940d7ff2dde2342162cf513875848f88249ea0ba02fef7";
            };

            beamDeps = [
              jason
              phoenix_html
              phoenix_pubsub
              plug
              plug_cowboy
              plug_crypto
              telemetry
            ];
          };
        in
        drv;

      phoenix_ecto =
        let
          version = "4.6.3";
          drv = buildMix {
            inherit version;
            name = "phoenix_ecto";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_ecto";
              sha256 = "909502956916a657a197f94cc1206d9a65247538de8a5e186f7537c895d95764";
            };

            beamDeps = [
              ecto
              phoenix_html
              plug
              postgrex
            ];
          };
        in
        drv;

      phoenix_html =
        let
          version = "3.3.4";
          drv = buildMix {
            inherit version;
            name = "phoenix_html";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_html";
              sha256 = "0249d3abec3714aff3415e7ee3d9786cb325be3151e6c4b3021502c585bf53fb";
            };

            beamDeps = [
              plug
            ];
          };
        in
        drv;

      phoenix_live_view =
        let
          version = "0.17.7";
          drv = buildMix {
            inherit version;
            name = "phoenix_live_view";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_live_view";
              sha256 = "25eaf41028eb351b90d4f69671874643a09944098fefd0d01d442f40a6091b6f";
            };

            beamDeps = [
              jason
              phoenix
              phoenix_html
              telemetry
            ];
          };
        in
        drv;

      phoenix_pubsub =
        let
          version = "2.1.3";
          drv = buildMix {
            inherit version;
            name = "phoenix_pubsub";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_pubsub";
              sha256 = "bba06bc1dcfd8cb086759f0edc94a8ba2bc8896d5331a1e2c2902bf8e36ee502";
            };
          };
        in
        drv;

      plug =
        let
          version = "1.16.1";
          drv = buildMix {
            inherit version;
            name = "plug";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "plug";
              sha256 = "a13ff6b9006b03d7e33874945b2755253841b238c34071ed85b0e86057f8cddc";
            };

            beamDeps = [
              mime
              plug_crypto
              telemetry
            ];
          };
        in
        drv;

      plug_cowboy =
        let
          version = "2.7.2";
          drv = buildMix {
            inherit version;
            name = "plug_cowboy";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "plug_cowboy";
              sha256 = "245d8a11ee2306094840c000e8816f0cbed69a23fc0ac2bcf8d7835ae019bb2f";
            };

            beamDeps = [
              cowboy
              cowboy_telemetry
              plug
            ];
          };
        in
        drv;

      plug_crypto =
        let
          version = "1.2.5";
          drv = buildMix {
            inherit version;
            name = "plug_crypto";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "plug_crypto";
              sha256 = "26549a1d6345e2172eb1c233866756ae44a9609bd33ee6f99147ab3fd87fd842";
            };
          };
        in
        drv;

      poison =
        let
          version = "4.0.1";
          drv = buildMix {
            inherit version;
            name = "poison";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "poison";
              sha256 = "ba8836feea4b394bb718a161fc59a288fe0109b5006d6bdf97b6badfcf6f0f25";
            };
          };
        in
        drv;

      poolboy =
        let
          version = "1.5.2";
          drv = buildRebar3 {
            inherit version;
            name = "poolboy";

            src = fetchHex {
              inherit version;
              pkg = "poolboy";
              sha256 = "dad79704ce5440f3d5a3681c8590b9dc25d1a561e8f5a9c995281012860901e3";
            };
          };
        in
        drv;

      postgrex =
        let
          version = "0.20.0";
          drv = buildMix {
            inherit version;
            name = "postgrex";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "postgrex";
              sha256 = "d36ef8b36f323d29505314f704e21a1a038e2dc387c6409ee0cd24144e187c0f";
            };

            beamDeps = [
              db_connection
              decimal
              jason
            ];
          };
        in
        drv;

      prometheus =
        let
          version = "4.11.0";
          drv = buildMix {
            inherit version;
            name = "prometheus";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "prometheus";
              sha256 = "719862351aabf4df7079b05dc085d2bbcbe3ac0ac3009e956671b1d5ab88247d";
            };

            beamDeps = [
              quantile_estimator
            ];
          };
        in
        drv;

      prometheus_ecto =
        let
          version = "1.4.3";
          drv = buildMix {
            inherit version;
            name = "prometheus_ecto";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "prometheus_ecto";
              sha256 = "8d66289f77f913b37eda81fd287340c17e61a447549deb28efc254532b2bed82";
            };

            beamDeps = [
              ecto
              prometheus_ex
            ];
          };
        in
        drv;

      prometheus_ex =
        let
          version = "31f7fbe4b71b79ba27efc2a5085746c4011ceb8f";
          drv = buildMix {
            inherit version;
            name = "prometheus_ex";
            appConfigPath = ./config;

            src = pkgs.fetchFromGitHub {
              owner = "lanodan";
              repo = "prometheus.ex";
              rev = "31f7fbe4b71b79ba27efc2a5085746c4011ceb8f";
              hash = "sha256-2PZP+YnwnHt69HtIAQvjMBqBbfdbkRSoMzb1AL2Zsyc=";
            };

            beamDeps = [
              prometheus
            ];
          };
        in
        drv;

      prometheus_phoenix =
        let
          version = "1.3.0";
          drv = buildMix {
            inherit version;
            name = "prometheus_phoenix";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "prometheus_phoenix";
              sha256 = "c4d1404ac4e9d3d963da601db2a7d8ea31194f0017057fabf0cfb9bf5a6c8c75";
            };

            beamDeps = [
              phoenix
              prometheus_ex
            ];
          };
        in
        drv;

      prometheus_plugs =
        let
          version = "1.1.5";
          drv = buildMix {
            inherit version;
            name = "prometheus_plugs";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "prometheus_plugs";
              sha256 = "0273a6483ccb936d79ca19b0ab629aef0dba958697c94782bb728b920dfc6a79";
            };

            beamDeps = [
              accept
              plug
              prometheus_ex
              prometheus_process_collector
            ];
          };
        in
        drv;

      prometheus_process_collector =
        let
          version = "3dc94dcff422d7b9cbd7ddf6bf2a896446705f3f";
          drv = buildMix {
            inherit version;
            name = "prometheus_process_collector";
            appConfigPath = ./config;

            src = pkgs.fetchFromGitHub {
              owner = "Phybbit";
              repo = "prometheus_process_collector";
              rev = "3dc94dcff422d7b9cbd7ddf6bf2a896446705f3f";
              hash = "sha256-cmZiq0kROUiDQsd3EBIN7tcfB73E61/h/aNILh/NjXs=";
            };

            beamDeps = [
              prometheus
            ];
          };
        in
        drv;

      qrcode =
        let
          version = "0.1.5";
          drv = buildMix {
            inherit version;
            name = "qrcode";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "qrcode";
              sha256 = "a266b7fb7be0d3b713912055dde3575927eca920e5d604ded45cd534f6b7a447";
            };
          };
        in
        drv;

      quantile_estimator =
        let
          version = "0.2.1";
          drv = buildRebar3 {
            inherit version;
            name = "quantile_estimator";

            src = fetchHex {
              inherit version;
              pkg = "quantile_estimator";
              sha256 = "282a8a323ca2a845c9e6f787d166348f776c1d4a41ede63046d72d422e3da946";
            };
          };
        in
        drv;

      que =
        let
          version = "0.10.1";
          drv = buildMix {
            inherit version;
            name = "que";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "que";
              sha256 = "a737b365253e75dbd24b2d51acc1d851049e87baae08cd0c94e2bc5cd65088d5";
            };

            beamDeps = [
              ex_utils
              memento
            ];
          };
        in
        drv;

      ranch =
        let
          version = "1.8.1";
          drv = buildRebar3 {
            inherit version;
            name = "ranch";

            src = fetchHex {
              inherit version;
              pkg = "ranch";
              sha256 = "aed58910f4e21deea992a67bf51632b6d60114895eb03bb392bb733064594dd0";
            };
          };
        in
        drv;

      recon =
        let
          version = "2.5.6";
          drv = buildMix {
            inherit version;
            name = "recon";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "recon";
              sha256 = "96c6799792d735cc0f0fd0f86267e9d351e63339cbe03df9d162010cefc26bb0";
            };
          };
        in
        drv;

      redix =
        let
          version = "1.5.2";
          drv = buildMix {
            inherit version;
            name = "redix";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "redix";
              sha256 = "78538d184231a5d6912f20567d76a49d1be7d3fca0e1aaaa20f4df8e1142dcb8";
            };

            beamDeps = [
              castore
              nimble_options
              telemetry
            ];
          };
        in
        drv;

      remote_ip =
        let
          version = "1.2.0";
          drv = buildMix {
            inherit version;
            name = "remote_ip";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "remote_ip";
              sha256 = "2ff91de19c48149ce19ed230a81d377186e4412552a597d6a5137373e5877cb7";
            };

            beamDeps = [
              combine
              plug
            ];
          };
        in
        drv;

      rustler_precompiled =
        let
          version = "0.8.2";
          drv = buildMix {
            inherit version;
            name = "rustler_precompiled";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "rustler_precompiled";
              sha256 = "63d1bd5f8e23096d1ff851839923162096364bac8656a4a3c00d1fff8e83ee0a";
            };

            beamDeps = [
              castore
            ];
          };
        in
        drv;

      siwe =
        let
          version = "51c9c08240eb7eea3c35693011f8d260cd9bb3be";
          drv = buildMix {
            inherit version;
            name = "siwe";
            appConfigPath = ./config;

            src = pkgs.fetchFromGitHub {
              owner = "royal-markets";
              repo = "siwe-ex";
              rev = "51c9c08240eb7eea3c35693011f8d260cd9bb3be";
              hash = "sha256-ltxJSmHAfz2oJBGYt/kPa6pOHu40TxsFZ0KtstD+5U0=";
            };

            beamDeps = [
              rustler_precompiled
            ];
          };
        in
        drv.override (workarounds.rustlerPrecompiled { } drv);

      sleeplocks =
        let
          version = "1.1.3";
          drv = buildRebar3 {
            inherit version;
            name = "sleeplocks";

            src = fetchHex {
              inherit version;
              pkg = "sleeplocks";
              sha256 = "d3b3958552e6eb16f463921e70ae7c767519ef8f5be46d7696cc1ed649421321";
            };
          };
        in
        drv;

      spandex =
        let
          version = "3.2.0";
          drv = buildMix {
            inherit version;
            name = "spandex";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "spandex";
              sha256 = "d0a7d5aef4c5af9cf5467f2003e8a5d8d2bdae3823a6cc95d776b9a2251d4d03";
            };

            beamDeps = [
              decorator
              optimal
              plug
            ];
          };
        in
        drv;

      spandex_datadog =
        let
          version = "1.4.0";
          drv = buildMix {
            inherit version;
            name = "spandex_datadog";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "spandex_datadog";
              sha256 = "360f8e1b4db238c1749c4872b1697b096429927fa42b8858d0bb782067380123";
            };

            beamDeps = [
              msgpax
              spandex
              telemetry
            ];
          };
        in
        drv;

      spandex_ecto =
        let
          version = "0.7.0";
          drv = buildMix {
            inherit version;
            name = "spandex_ecto";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "spandex_ecto";
              sha256 = "c64784be79d95538013b7c60828830411c5c7aff1f4e8d66dfe564b3c83b500e";
            };

            beamDeps = [
              spandex
            ];
          };
        in
        drv;

      spandex_phoenix =
        let
          version = "1.1.0";
          drv = buildMix {
            inherit version;
            name = "spandex_phoenix";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "spandex_phoenix";
              sha256 = "265fe05c1736485fbb75d66ef7576682ebf6428c391dd54d22217f612fd4ddad";
            };

            beamDeps = [
              phoenix
              plug
              spandex
              telemetry
            ];
          };
        in
        drv;

      ssl_verify_fun =
        let
          version = "1.1.7";
          drv = buildMix {
            inherit version;
            name = "ssl_verify_fun";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ssl_verify_fun";
              sha256 = "fe4c190e8f37401d30167c8c405eda19469f34577987c76dde613e838bbc67f8";
            };
          };
        in
        drv;

      sweet_xml =
        let
          version = "0.7.5";
          drv = buildMix {
            inherit version;
            name = "sweet_xml";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "sweet_xml";
              sha256 = "193b28a9b12891cae351d81a0cead165ffe67df1b73fe5866d10629f4faefb12";
            };
          };
        in
        drv;

      telemetry =
        let
          version = "1.3.0";
          drv = buildRebar3 {
            inherit version;
            name = "telemetry";

            src = fetchHex {
              inherit version;
              pkg = "telemetry";
              sha256 = "7015fc8919dbe63764f4b4b87a95b7c0996bd539e0d499be6ec9d7f3875b79e6";
            };
          };
        in
        drv;

      tesla =
        let
          version = "1.13.0";
          drv = buildMix {
            inherit version;
            name = "tesla";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "tesla";
              sha256 = "7b8fc8f6b0640fa0d090af7889d12eb396460e044b6f8688a8e55e30406a2200";
            };

            beamDeps = [
              castore
              hackney
              jason
              mime
              mox
              msgpax
              poison
              telemetry
            ];
          };
        in
        drv;

      timex =
        let
          version = "3.7.11";
          drv = buildMix {
            inherit version;
            name = "timex";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "timex";
              sha256 = "8b9024f7efbabaf9bd7aa04f65cf8dcd7c9818ca5737677c7b76acbc6a94d1aa";
            };

            beamDeps = [
              combine
              gettext
              tzdata
            ];
          };
        in
        drv;

      typed_ecto_schema =
        let
          version = "0.4.1";
          drv = buildMix {
            inherit version;
            name = "typed_ecto_schema";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "typed_ecto_schema";
              sha256 = "85c6962f79d35bf543dd5659c6adc340fd2480cacc6f25d2cc2933ea6e8fcb3b";
            };

            beamDeps = [
              ecto
            ];
          };
        in
        drv;

      tzdata =
        let
          version = "1.1.1";
          drv = buildMix {
            inherit version;
            name = "tzdata";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "tzdata";
              sha256 = "a69cec8352eafcd2e198dea28a34113b60fdc6cb57eb5ad65c10292a6ba89787";
            };

            beamDeps = [
              hackney
            ];
          };
        in
        drv;

      ueberauth =
        let
          version = "0.10.8";
          drv = buildMix {
            inherit version;
            name = "ueberauth";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ueberauth";
              sha256 = "f2d3172e52821375bccb8460e5fa5cb91cfd60b19b636b6e57e9759b6f8c10c1";
            };

            beamDeps = [
              plug
            ];
          };
        in
        drv;

      ueberauth_auth0 =
        let
          version = "2.1.0";
          drv = buildMix {
            inherit version;
            name = "ueberauth_auth0";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ueberauth_auth0";
              sha256 = "8d3b30fa27c95c9e82c30c4afb016251405706d2e9627e603c3c9787fd1314fc";
            };

            beamDeps = [
              oauth2
              ueberauth
            ];
          };
        in
        drv;

      unicode_util_compat =
        let
          version = "0.7.0";
          drv = buildRebar3 {
            inherit version;
            name = "unicode_util_compat";

            src = fetchHex {
              inherit version;
              pkg = "unicode_util_compat";
              sha256 = "25eee6d67df61960cf6a794239566599b09e17e668d3700247bc498638152521";
            };
          };
        in
        drv;

      unsafe =
        let
          version = "1.0.2";
          drv = buildMix {
            inherit version;
            name = "unsafe";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "unsafe";
              sha256 = "b485231683c3ab01a9cd44cb4a79f152c6f3bb87358439c6f68791b85c2df675";
            };
          };
        in
        drv;

      varint =
        let
          version = "1.5.1";
          drv = buildMix {
            inherit version;
            name = "varint";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "varint";
              sha256 = "24f3deb61e91cb988056de79d06f01161dd01be5e0acae61d8d936a552f1be73";
            };
          };
        in
        drv;

      vix =
        let
          version = "0.33.0";
          drv = buildMix {
            inherit version;
            name = "vix";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "vix";
              sha256 = "9acde72b27bdfeadeb51f790f7a6cc0d06cf555718c05cf57e43c5cf93d8471b";
            };

            beamDeps = [
              castore
              cc_precompiler
              elixir_make
            ];
          };
        in
        drv;

      websockex =
        let
          version = "0.4.3";
          drv = buildMix {
            inherit version;
            name = "websockex";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "websockex";
              sha256 = "95f2e7072b85a3a4cc385602d42115b73ce0b74a9121d0d6dbbf557645ac53e4";
            };
          };
        in
        drv;

    };
in
self
