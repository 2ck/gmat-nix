{
    description = ( "GMAT: General Mission Analysis Tool" );

    inputs = {
        gmat = { url = "file+https://downloads.sourceforge.net/project/gmat/GMAT/GMAT-R2022a/gmat-src_and_data-R2022a.zip"; flake = false; };
        # gmat dependencies
        xerces = { url = "file+https://archive.apache.org/dist/xerces/c/3/sources/xerces-c-3.2.2.tar.gz"; flake = false; };
        wxwidgets = { url = "file+https://github.com/wxWidgets/wxWidgets/releases/download/v3.0.4/wxWidgets-3.0.4.tar.bz2"; flake = false; };
        cspice = { url = "file+https://naif.jpl.nasa.gov/pub/naif/misc/toolkit_N0067/C/PC_Linux_GCC_64bit/packages/cspice.tar.Z"; flake = false; };
        swig = { url = "file+https://download.sourceforge.net/swig/swig-4.0.2.tar.gz"; flake = false; };
        pcre = { url = "file+https://sourceforge.net/projects/pcre/files/pcre/8.45/pcre-8.45.tar.gz/download"; flake = false; };
        java = { url = "file+https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.5+10/OpenJDK11U-jdk_x64_linux_hotspot_11.0.5_10.tar.gz"; flake = false; };
    };

    outputs = { self, nixpkgs, gmat, xerces, wxwidgets, cspice, swig, pcre, java }:
    let
        system = "x86_64-linux";
        pkgs = nixpkgs.legacyPackages.${system};
        dependencies = [
            pkgs.git
        ];
        gmat-configure = pkgs.stdenv.mkDerivation {
            name = "gmat-configure";
            nativeBuildInputs = [
                pkgs.unzip pkgs.gzip pkgs.gnutar
                pkgs.gnumake pkgs.cmake
                # configure script
                pkgs.python3
                # wxWidgets
                pkgs.pkg-config
                pkgs.gtk2 pkgs.gtk3 pkgs.libGL pkgs.libGLU
                # cspice
                pkgs.tcsh
            ];
            phases = [ "unpackPhase" "patchPhase" "configurePhase" "buildPhase"];
            # unpack gmat and symlink everything that would have been curl-ed in the configure script
            unpackPhase = ''
                mkdir -p $out
                unzip ${gmat} -d $out
                ln -s ${xerces} $out/GMAT-R2022a/depends/xerces.tar.gz
                mkdir -p $out/GMAT-R2022a/depends/wxWidgets
                ln -s ${wxwidgets} $out/GMAT-R2022a/depends/wxWidgets/wxWidgets.tar.bz2
                mkdir -p $out/GMAT-R2022a/depends/cspice/linux
                ln -s ${cspice} $out/GMAT-R2022a/depends/cspice/linux/cspice.tar.Z
                mkdir -p $out/GMAT-R2022a/depends/swig/swig
                ln -s ${swig} $out/GMAT-R2022a/depends/swig/swig.tar.gz
                ln -s ${pcre} $out/GMAT-R2022a/depends/swig/swig/pcre-8.45.tar.gz
                mkdir -p $out/GMAT-R2022a/depends/java/linux
                ln -s ${java} $out/GMAT-R2022a/depends/java/linux/jdk.tar.gz
            '';
            # dependencies are already fetched (and sandbox means no internet during build)
            # so comment out all curl calls in the configure script
            # NOTE: No idea how the '-shared' flag for wxWidgets gets lost, but there are two possible bandaid fixes here
            # NOTE: gzip may complain about symlinks, so --force
            patchPhase = ''
                substituteInPlace $out/GMAT-R2022a/depends/configure.py --replace "os.system('curl" "#os.system('curl"
                #substituteInPlace $out/GMAT-R2022a/depends/configure.py --replace "makeFlag = os.system('make -j' + nCores + ' > \"' + logs_path + '/wxWidgets_build.log\" 2>&1')" "makeFlag = os.system('NIX_CFLAGS_COMPILE=\"$NIX_CFLAGS_COMPILE -shared\" make -j' + nCores + ' > \"' + logs_path + '/wxWidgets_build.log\" 2>&1')"
                substituteInPlace $out/GMAT-R2022a/depends/configure.py --replace "--enable-unicode --with-opengl" "CXXFLAGS=\"-shared $CXXFLAGS\" --enable-unicode --with-opengl"
                substituteInPlace $out/GMAT-R2022a/depends/configure.py --replace "if not os.path.exists(cspice_path):" "if not os.path.exists(cspice_path + '/cspice64'):"
                substituteInPlace $out/GMAT-R2022a/depends/configure.py --replace "os.system('gzip -d" "os.system('gzip --force -d"
                substituteInPlace $out/GMAT-R2022a/depends/configure.py --replace "./mkprodct.csh" "tcsh mkprodct.csh"
                substituteInPlace $out/GMAT-R2022a/depends/configure.py --replace "if not os.path.exists(swig_dir):" "if not os.path.exists(swig_dir + '/linux-install'):"
            '';
            configurePhase = ''
                cd $out/GMAT-R2022a/depends/ && python3 configure.py
            '';
            buildPhase = ''
                mkdir $out/GMAT-R2022a/build/linux-cmake
                cd $out/GMAT-R2022a/build/linux-cmake
                cmake -DPLUGIN_PYTHONINTERFACE=OFF -DPLUGIN_EXTERNALFORCEMODEL=OFF -DPLUGIN_MATLABINTERFACE=OFF ../..
                make -j$(nproc)
            '';
            outputs = [ "out" ];
        };
    in
    {
        devShells.${system}.default = pkgs.mkShell {
            buildInputs = [gmat-configure dependencies];
            shellHook = ''
                ln -sfT ${gmat-configure} ./gmat
                cd gmat/GMAT-R2022a/application/bin
                exec $SHELL
            '';
        };
    };
}
