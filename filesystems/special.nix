{
  config,
  l,
  parentCfg,
  cfg,
  ...
}:

let
  specialFilesystemOpts =
    { ... }:
    {
      options = {
        enable = l.mkEnableOption "the filesystem mount";

        device = l.mkOption {
          default = null;
          example = "/dev/sda";
          type = l.types.nullOr l.types.str;
          description = "Location of the device.";
        };

        options = l.mkOption {
          default = { };
          example = {
            "noexec" = false;
            "hidepid" = 4;
          };
          description = ''
            Options used to mount the file system.
            If the value is false, the option is disabled.
            If the value is an integer or a string, it is passed as "name=value".
          '';
          type = l.types.attrsOf (
            l.types.oneOf [
              l.types.bool
              l.types.int
              l.types.str
            ]
          );
        };
      };

      config = {
        options = {
          "noexec" = l.mkDefault true;
        };
      };
    };
in
{
  options = {
    special = l.mkOption {
      description = ''
        Special Filesystem hardening.

        Sets the option "noexec" by default.
      '';
      default = { };
      type = l.types.attrsOf (l.types.submodule specialFilesystemOpts);
    };
  };

  config = {
    # Convert specialFilesystemOpts to boot.specialFileSystems option on nixpkgs
    boot.specialFileSystems = l.mkIf parentCfg.enable (
      l.mapAttrs (
        name: opts:
        (l.mkIf opts.enable {
          device = l.mkIf (opts.device != null) (l.mkDefault opts.device);
          options = l.attrNames (
            l.filterAttrs (_: bool: bool) (
              l.mapAttrs' (name: value: {
                name = (if ((l.typeOf value) == "bool") then name else (name + "=" + (toString value)));
                value = (if ((l.typeOf value) == "bool") then value else true);
              }) opts.options
            )
          );
        })
      ) cfg
    );

    # Harden special filesystems while maintaining NixOS defaults as outlined
    # here:
    # https://github.com/NixOS/nixpkgs/blob/e2dd4e18cc1c7314e24154331bae07df76eb582f/nixos/modules/tasks/filesystems.nix
    nix-mineral.filesystems.special = {
      "/dev/shm".enable = l.mkDefault true;

      "/run".enable = l.mkDefault true;

      "/dev".enable = l.mkDefault true;

      # Hide processes from other users except root, may cause breakage.
      # change options."hidepid" to false if you want to disable.
      "/proc" = {
        enable = l.mkDefault true;
        device = l.mkDefault "proc";
        options = {
          "hidepid" = 2;
          "gid" = config.users.groups.proc.gid;
        };
      };
    };

    # Add "proc" group to whitelist /proc access and allow systemd-logind to view
    # /proc in order to unbreak it, as well as to user@ for similar reasons.
    # See https://github.com/systemd/systemd/issues/12955, and https://github.com/Kicksecure/security-misc/issues/208
    users.groups.proc.gid = l.mkIf parentCfg.enable (l.mkDefault config.ids.gids.proc);
    systemd.services.systemd-logind.serviceConfig.SupplementaryGroups = l.mkIf parentCfg.enable [
      "proc"
    ];
    systemd.services."user@".serviceConfig.SupplementaryGroups = l.mkIf parentCfg.enable [ "proc" ];
  };
}
