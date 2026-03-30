{falcon-sensor-overlay}: {
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.falcon-sensor;
  customFalconUnwrapped = pkgs.falcon-sensor-unwrapped.override {
    debFile = cfg.debFile;
    version = cfg.version;
  };
  customFalcon = pkgs.falcon-sensor.override {
    falcon-sensor-unwrapped = customFalconUnwrapped;
  };
in {
  options = {
    services.falcon-sensor = {
      enable = mkEnableOption (mdDoc "Crowdstrike Falcon Sensor");
      kernelPackages = mkOption {
        default = pkgs.linuxKernel.packages.linux_6_8;
        defaultText = literalExpression "pkgs.linuxKernel.packages.linux_6_8";
        type = types.nullOr types.raw;
        description = "falcon-sensor has a whitelist of supported kernels. This option sets the linux kernel.";
      };
      cid = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Customer ID (CID) for your Crowdstrike Falcon Sensor.";
      };
      cidFile = mkOption {
        type = types.nullOr (types.either types.path types.str);
        default = null;
        description = "Path to a file containing the CrowdStrike CID.";
      };
      debFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to the Crowdstrike .deb file";
      };
      version = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Crowdstrike version";
      };
      logLevel = mkOption {
        type = types.enum [ "none" "err" "warn" "info" "debug" ];
        default = "none";
        description = "falcon-sensor logging level";
      };
    };
  };

  config =
    mkIf cfg.enable
    (mkMerge [
      {
        nixpkgs.overlays = [
          falcon-sensor-overlay
        ];

        environment.systemPackages = [
          customFalcon
        ];

        assertions = [
          {
            assertion = (cfg.cid != null) || (cfg.cidFile != null);
            message = "You must provide either services.falcon-sensor.cid or services.falcon-sensor.cidFile.";
          }
          {
            assertion = (cfg.cid == null) || (cfg.cidFile == null);
            message = "You cannot set both services.falcon-sensor.cid and services.falcon-sensor.cidFile at the same time.";
          }
        ];

        systemd = {
          tmpfiles.settings = {
            "10-falcon-sensor" = {
              "/opt/CrowdStrike" = {
                d = {
                  group = "root";
                  user = "root";
                  mode = "0770";
                };
              };
            };
          };
          services.falcon-sensor = {
            enable = true;
            description = "Crowdstrike Falcon Sensor";
            unitConfig.DefaultDependencies = false;
            after = ["local-fs.target" "systemd-tmpfiles-setup.service"];
            conflicts = ["shutdown.target"];
            before = ["sysinit.target" "shutdown.target"];
            serviceConfig = {
              StandardOutput = "journal";
              ExecStartPre = [
                (pkgs.writeScript "falcon-init"
                  /*
                  bash
                  */
                  ''
                    #!${pkgs.bash}/bin/bash
                    set -euo

                    # read the secret path or pass the string
                    ${if cfg.cidFile != null then ''
                      CID_VALUE=$(cat "$CREDENTIALS_DIRECTORY/falcon_cid")
                    '' else ''
                      CID_VALUE="${cfg.cid}"
                    ''}

                    # looks like at least the ASPM and Falcon4IT directories are
                    # being deleted and recreated as real dirs.
                    # This tries to remedy that issue by looping all files and failing silently
                    for item in ${customFalconUnwrapped}/opt/CrowdStrike/*; do
                      target="/opt/CrowdStrike/$(basename "$item")"
                      ln -sfT "$item" "$target" 2>/dev/null || true
                    done

                    ${customFalcon}/opt/CrowdStrike/falconctl -s --trace=${cfg.logLevel}
                    ${customFalcon}/opt/CrowdStrike/falconctl -s -f --cid="$CID_VALUE"
                    ${customFalcon}/opt/CrowdStrike/falconctl -g --cid
                  '')
              ];
              ExecStart = "/run/current-system/sw/bin/falcond";
              User = "root";
              Type = "forking";
              PIDFile = "/var/run/falcond.pid";
              Restart = "on-failure";
              TimeoutStopSec = "60s";
              KillMode = "control-group";
              KillSignal = "SIGTERM";
            } // lib.optionalAttrs (cfg.cidFile != null) {
            LoadCredential = "falcon_cid:${cfg.cidFile}";
            };
            wantedBy = ["multi-user.target"];
          };
        };
      }
      (mkIf (cfg.kernelPackages != null) {
        boot.kernelPackages = mkForce cfg.kernelPackages;
      })
    ]);
}
