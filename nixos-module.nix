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
        type = types.str;
        description = "Customer ID (CID) for your Crowdstrike Falcon Sensor.";
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
                    ln -sf ${customFalconUnwrapped}/opt/CrowdStrike/* /opt/CrowdStrike/
                    /run/current-system/sw/bin/falconctl -s --trace=debug
                    # Replace <cid> with your CID
                    /run/current-system/sw/bin/falconctl -s --cid="${cfg.cid}" -f
                    /run/current-system/sw/bin/falconctl -g --cid
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
