{
  falcon-sensor-unwrapped,
  buildFHSEnv,
  symlinkJoin,
  ...
}: let
  falconFHSWrapper = mainProgram: buildFHSEnv {
    name = mainProgram;
    targetPkgs = pkgs: with pkgs; [libnl openssl zlib];
    runScript = "${falcon-sensor-unwrapped}/opt/CrowdStrike/${mainProgram}";
  };

  falconctl = falconFHSWrapper "falconctl";

  falcond = falconFHSWrapper "falcond";

  falcon-kernel-check = falconFHSWrapper "falcon-kernel-check";

  in
  symlinkJoin {
    pname = "falcon-sensor";
    version = falcon-sensor-unwrapped.version;
    paths = [
      falconctl
      falcond
      falcon-kernel-check
    ];
  }
