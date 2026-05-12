{
  lib,
  stdenv,
  fetchFromGitHub,
  rdma-core,
  openssl,
  zlib,
  xz,
  expat,
  bashNonInteractive,
  boost,
  curl,
  pkg-config,
  libxml2,
  pciutils,
  busybox,
  python3,
  automake,
  autoconf,
  libtool,
  # use these to shrink the package's footprint if necessary (e.g. for hardened appliances)
  enableADBGenericTools ? true,
  enableBoost ? true,
  # contains binary-only libraries
  enableDPA ? true,
  enableFwMgr ? true,
  enableOpenssl ? true,
  enablePython ? true,
  enableRDMA ? true,
  enableZlib ? true,
}:

assert enableDPA -> enableOpenssl;
assert enableFwMgr -> enableOpenssl;
assert enableFwMgr -> enableZlib;

stdenv.mkDerivation (finalAttrs: {
  pname = "mstflint";
  version = "4.35.0-1";

  src = fetchFromGitHub {
    owner = "Mellanox";
    repo = finalAttrs.pname;
    rev = "v${finalAttrs.version}";
    hash = "sha256-sz/pIV7eV/lZe6Wckao+frf8HUcWnAVBAV2+gC5KJ3U=";
  };

  nativeBuildInputs = [
    autoconf
    automake
    libtool
    pkg-config
  ]
  ++ lib.optionals enableFwMgr [
    libxml2
  ];

  buildInputs =
    lib.optionals enableADBGenericTools [
      expat
      xz
    ]
    ++ lib.optionals enableBoost [
      boost
    ]
    ++ lib.optionals enableFwMgr [
      curl
      libxml2
      xz
    ]
    ++ lib.optionals enableOpenssl [
      openssl
    ]
    ++ lib.optionals enablePython [
      bashNonInteractive
      busybox
      pciutils
      python3
    ]
    ++ lib.optionals enableRDMA [
      rdma-core
    ]
    ++ lib.optionals enableZlib [
      zlib
    ];

  preConfigure = lib.optionalString enableBoost ''
      export CPPFLAGS="$CPPFLAGS -DUSE_BOOST -DUSE_BOOST_ALGORITHM -DUSE_BOOST_REGEX"
    ''
    + lib.optionalString enableADBGenericTools ''
      export CPPFLAGS="$CPPFLAGS -I$(pwd)/tools_layouts"
    ''
    + lib.optionalString enableFwMgr ''
      export CPPFLAGS="$CPPFLAGS -isystem ${libxml2.dev}/include/libxml2"
    ''
    + ''
      echo ${finalAttrs.src.rev} > tools_git_sha
      export INSTALL_BASEDIR=$out
      ./autogen.sh
    '';

  # Cannot use wrapProgram since the python script's logic depends on the
  # filename and will get messed up if the executable is named ".xyz-wrapped".
  # That is why the python executable and runtime dependencies are injected
  # this way.
  #
  # Remove host_cpu replacement again (see https://github.com/Mellanox/mstflint/pull/865),
  # needs to hit master or a release. master_devel may be rebased.
  #
  # Remove patch for regex check, after https://github.com/Mellanox/mstflint/pull/871
  # got merged.
  prePatch = [
    ''
      patchShebangs --build eval_git_sha.sh
      substituteInPlace configure.ac \
          --replace-fail "build_cpu" "host_cpu"
      substituteInPlace common/compatibility.h \
          --replace-fail "#define ROOT_PATH \"/\"" "#define ROOT_PATH \"$out/\""
      substituteInPlace configure.ac \
          --replace-fail 'Whether to use GNU C regex])' 'Whether to use GNU C regex])],[AC_MSG_RESULT([yes])'
    ''
    (lib.optionals enablePython ''
      substituteInPlace common/python_wrapper.sh \
        --replace-fail \
        'exec $PYTHON_EXEC $SCRIPT_PATH "$@"' \
        'export PATH=$PATH:${
          lib.makeBinPath [
            (placeholder "out")
            pciutils
            busybox
          ]
        }; exec ${python3}/bin/python3 $SCRIPT_PATH "$@"'
    '')
  ];

  configureFlags = [
    "--datarootdir=${placeholder "out"}/share"
  ]
  ++ lib.optionals enableADBGenericTools [
    "--enable-adb-generic-tools"
  ]
  ++ lib.optionals enableDPA [
    "--enable-dpa"
  ]
  ++ lib.optionals enableFwMgr [
    "--enable-fw-mgr"
    "--enable-xml2"
  ]
  ++ lib.optionals enableOpenssl [
    "--enable-cs"
  ]
  ++ lib.optionals (!enableOpenssl) [
    "--disable-cs"
    "--disable-openssl"
  ]
  ++ lib.optionals enableRDMA [
    "--enable-inband"
    "--enable-rdmem"
  ]
  ++ lib.optionals (!enableRDMA) [
    "--disable-inband"
    "--disable-rdmem"
  ]
  ++ lib.optionals (!enableZlib) [
    "--disable-dc"
  ];

  enableParallelBuilding = true;

  hardeningDisable = [ "format" ];

  dontDisableStatic = true; # the build fails without this. should probably be reported upstream

  strictDeps = true;

  meta = {
    description = "Open source version of Mellanox Firmware Tools (MFT)";
    homepage = "https://github.com/Mellanox/mstflint";
    license = with lib.licenses; [
      gpl2Only
      bsd2
    ];
    maintainers = with lib.maintainers; [ thillux ];
    platforms = lib.platforms.linux;
  };
})
