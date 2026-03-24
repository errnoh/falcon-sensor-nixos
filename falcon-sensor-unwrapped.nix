{
  stdenv,
  lib,
  dpkg,
  autoPatchelfHook,
  zlib,
  openssl,
  libnl,
  debFile ? throw "You must provide the CrowdStrike .deb file path",
  version ? "unknown",
  ...
}:
stdenv.mkDerivation {
  pname = "falcon-sensor-unwrapped";
  arch = "x86_64-linux";
  src = debFile;
  inherit version;

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    zlib
  ];

  propagatedBuildInputs = [
    openssl
    libnl
  ];

  sourceRoot = ".";

  unpackCmd =
    /*
    bash
    */
    ''
      dpkg-deb -x "$src" .
    '';

  installPhase = ''
    cp -r ./ $out/
  '';

  meta = with lib; {
    mainProgram = "falconctl";
    description = "Crowdstrike Falcon Sensor";
    homepage = "https://www.crowdstrike.com/";
    license = licenses.unfree;
    platforms = platforms.linux;
  };
}
