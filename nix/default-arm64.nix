let
  pkgs = (import ./nixpkgs.nix {
    crossSystem = {
      config = "aarch64-unknown-linux-gnu";
    };
    config = {
      packageOverrides = pkg: {
        gpgme = (static pkg.gpgme);
        libassuan = (static pkg.libassuan);
        libgpgerror = (static pkg.libgpgerror);
        libseccomp = (static pkg.libseccomp);
        glib = (static pkg.glib).overrideAttrs (x: {
          outputs = [ "bin" "out" "dev" ];
          mesonFlags = [
            "-Ddefault_library=static"
            "-Ddevbindir=${placeholder ''dev''}/bin"
            "-Dgtk_doc=false"
            "-Dnls=disabled"
          ];
          postInstall = ''
            moveToOutput "share/glib-2.0" "$dev"
            substituteInPlace "$dev/bin/gdbus-codegen" --replace "$out" "$dev"
            sed -i "$dev/bin/glib-gettextize" -e "s|^gettext_dir=.*|gettext_dir=$dev/share/glib-2.0/gettext|"
            sed '1i#line 1 "${x.pname}-${x.version}/include/glib-2.0/gobject/gobjectnotifyqueue.c"' \
              -i "$dev"/include/glib-2.0/gobject/gobjectnotifyqueue.c
          '';
        });
      };
    };
  });

  static = pkg: pkg.overrideAttrs (x: {
    doCheck = false;
    configureFlags = (x.configureFlags or [ ]) ++ [
      "--without-shared"
      "--disable-shared"
    ];
    dontDisableStatic = true;
    enableSharedExecutables = false;
    enableStatic = true;
  });

  self = with pkgs; buildGoModule rec {
    name = "skopeo";
    src = ./..;
    vendorSha256 = null;
    doCheck = false;
    enableParallelBuilding = true;
    outputs = [ "out" ];
    nativeBuildInputs = [ bash gitMinimal go-md2man installShellFiles makeWrapper pkg-config which ];
    buildInputs = [ glibc glibc.static gpgme libassuan libgpgerror libseccomp ];
    prePatch = ''
      export CFLAGS='-static -pthread'
      export LDFLAGS='-s -w -static-libgcc -static'
      export EXTRA_LDFLAGS='-s -w -linkmode external -extldflags "-static -lm"'
      export BUILDTAGS='static netgo osusergo exclude_graphdriver_btrfs exclude_graphdriver_devicemapper'
    '';
    buildPhase = ''
      patchShebangs .
      make bin/skopeo
    '';
    installPhase = ''
      install -Dm755 bin/skopeo $out/bin/skopeo
    '';
  };
in
self
