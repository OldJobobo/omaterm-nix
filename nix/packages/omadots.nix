{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "omadots";
  version = "2026-05-25";

  src = fetchFromGitHub {
    owner = "omacom-io";
    repo = "omadots";
    rev = "11fd9c3a1705dbce841f26e455462db228d085e5";
    hash = "sha256-dV1AwyWBEK9sKoMsGOkY/nL0Kg5gFvrlu43tzueuPkc=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/omadots"
    cp -R config "$out/share/omadots/"

    runHook postInstall
  '';

  meta = {
    description = "Pinned Omadots shared terminal configuration";
    homepage = "https://github.com/omacom-io/omadots";
    platforms = lib.platforms.all;
  };
}
