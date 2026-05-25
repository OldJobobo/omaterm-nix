{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "lazyvim-starter";
  version = "2026-05-25";

  src = fetchFromGitHub {
    owner = "LazyVim";
    repo = "starter";
    rev = "803bc181d7c0d6d5eeba9274d9be49b287294d99";
    hash = "sha256-QrpnlDD4r1X4C8PqBhQ+S3ar5C+qDrU1Jm/lPqyMIFM=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/lazyvim-starter"
    cp -R . "$out/share/lazyvim-starter/"

    runHook postInstall
  '';

  meta = {
    description = "Pinned LazyVim starter configuration";
    homepage = "https://github.com/LazyVim/starter";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
}
