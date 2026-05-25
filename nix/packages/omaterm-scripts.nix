{
  lib,
  stdenvNoCC,
  src,
}:

stdenvNoCC.mkDerivation {
  pname = "omaterm-scripts";
  version = "0-unstable";

  inherit src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    cp -R bin/. "$out/bin/"
    chmod +x "$out/bin"/*
    patchShebangs "$out/bin"

    runHook postInstall
  '';

  meta = {
    description = "Omaterm helper scripts";
    homepage = "https://github.com/omacom-io/omaterm";
    platforms = lib.platforms.linux;
    mainProgram = "omaterm-setup";
  };
}
