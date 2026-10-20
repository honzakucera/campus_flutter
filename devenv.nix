{ pkgs, config, ... }:

{
  android = {
    enable = true;
    flutter.enable = true;
    platforms.version = [ "36" ];
  };

  scripts.campus-emulator.exec = ''
    exec ${pkgs.bash}/bin/bash "${config.devenv.root}/scripts/android-emulator.sh" "$@"
  '';
}
