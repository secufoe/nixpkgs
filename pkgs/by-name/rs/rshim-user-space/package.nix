{
  autoconf,
  automake,
  bashNonInteractive,
  coreutils,
  fetchFromGitHub,
  fuse,
  gawk,
  gnugrep,
  gnused,
  lib,
  libusb1,
  makeBinaryWrapper,
  pciutils,
  pkg-config,
  procps,
  pv,
  stdenv,
  which,
  util-linux,
  withBfbInstall ? true,
  withBfbTool ? true,
  bfscripts,
  jq,
  cpio,
  gzip,
  bintools,
}:

stdenv.mkDerivation rec {
  pname = "rshim-user-space";
  version = "2.5.1";

  src = fetchFromGitHub {
    owner = "Mellanox";
    repo = "rshim-user-space";
    rev = "rshim-${version}";
    hash = "sha256-wHU9XmAMWiwyus2A5IseWHd+woplzI0LJXH6MEAwdGs=";
  };

  nativeBuildInputs = [
    autoconf
    automake
    pkg-config
  ]
  ++ lib.optionals withBfbInstall [ makeBinaryWrapper ];

  buildInputs = [
    pciutils
    libusb1
    fuse
  ];

  prePatch = lib.optionalString withBfbInstall ''
    patchShebangs scripts/bfb-install
  ''
  + lib.optionalString withBfbTool ''
    patchShebangs scripts/bfb-tool
  '';

  strictDeps = true;

  preConfigure = "./bootstrap.sh";

  installPhase = ''
    mkdir -p "$out"/bin
    cp -a src/rshim "$out"/bin/
  ''
  + lib.optionalString withBfbInstall ''
    cp -a scripts/bfb-install "$out"/bin/
    cp -a scripts/bfb-tool "$out"/bin/
  '';

  postFixup = lib.optionalString withBfbInstall ''
    wrapProgram $out/bin/bfb-install \
      --set PATH ${
        lib.makeBinPath [
          bashNonInteractive
          coreutils
          gawk
          gnugrep
          gnused
          pciutils
          procps
          pv
          util-linux
          which
        ]
      }
  ''
  + lib.optionalString withBfbInstall ''
    wrapProgram $out/bin/bfb-tool \
      --set PATH ${
        lib.makeBinPath [
          bfscripts
          bashNonInteractive
          coreutils
          gawk
          gnugrep
          gnused
          pciutils
          procps
          pv
          util-linux
          which
          jq
          cpio
          gzip
          bintools
        ]
      }
  '';

  meta = with lib; {
    description = "User-space rshim driver for the BlueField SoC";
    longDescription = ''
      The rshim driver provides a way to access the rshim resources on the
      BlueField target from external host machine. The current version
      implements device files for boot image push and virtual console access.
      It also creates virtual network interface to connect to the BlueField
      target and provides a way to access the internal rshim registers.
    '';
    homepage = "https://github.com/Mellanox/rshim-user-space";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
    maintainers = with maintainers; [
      thillux
    ];
  };
}
