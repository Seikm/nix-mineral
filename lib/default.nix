# This file is part of nix-mineral (https://github.com/nix-community/nix-mineral/).
# Copyright (c) 2025 cynicsketch
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

{ inputs, ... }:

let
  l = inputs.nixpkgs.lib // builtins;

  sources = l.fromTOML (l.readFile ./sources.toml);

  fetchGhFile =
    {
      user,
      repo,
      rev,
      file,
      sha256,
      ...
    }:
    l.fetchurl {
      url = "https://raw.githubusercontent.com/${user}/${repo}/${rev}/${file}";
      inherit sha256;
    };

  # constructor to create a boolean option easily with a description and default value
  mkBoolOption =
    desc: bool:
    l.mkOption {
      default = bool;
      example = !bool;
      description = desc;
      type = l.types.bool;
    };

  # constructor to create a deprecated option, forcing the default value to be null.
  # intended to be used with `mkDeprecatedOptionModule` to add a deprecation warning.
  # `value` can be any attrset that can be passed to `mkOption`, or a string with the description of the option.
  mkDeprecatedOption =
    value:
    let
      attrs =
        if l.typeOf value == "string" then
          {
            description = value;
            example = true;
            type = l.types.bool;
          }
        else
          value;
    in
    l.mkOption (
      attrs
      // {
        description = ''
          ::: {.warning}
          THIS OPTION IS NOW DEPRECATED. INFORMATION BELOW IS RETAINED FOR
          FUTURE REFERENCE, AND THIS OPTION IS SCHEDULED TO BE REMOVED PENDING THE
          NEXT RELEASE.
          :::

          ${if attrs ? description then attrs.description else ""}
        '';
        default = null;
        type = l.types.nullOr attrs.type;
      }
    );

  # returns a module that adds a deprecation warning if the specified option is set to a non-null value.
  # this is intended to be used the same way as `mkRemovedOptionModule` in nixpkgs,
  # but it does not create an option, it only adds a warning if the option is set to a non-null value.
  mkDeprecatedOptionModule =
    optionPath: message:
    { config, ... }:
    {
      config.warnings = l.optionals ((l.getAttrFromPath optionPath config) != null) [
        ''
          The option `${l.showOption optionPath}` is deprecated, and will be removed in a future release.
          Please remove this setting from your NixOS configuration.

          ${message}
        ''
      ];
    };

  # import wrapper to pass extra args to a module
  # used to pass the `l` variable to every module, and used in the importCategoryModule function to pass parentCfg and cfg.
  importModule =
    module: extraArgs: # `extraArgs` is a attrset that can contain any additional arguments to pass to the module
    (
      {
        lib,
        config,
        options,
        pkgs,
        ...
      }:
      (
        (
          if lib.typeOf module == "path" then
            import module
          else if lib.typeOf module == "string" then
            import module
          else
            module
        )
        (
          {
            inherit
              lib
              config
              options
              pkgs
              ;
            l = l // {
              # ugly, dont know another way to do this
              inherit
                sources
                fetchGhFile
                mkBoolOption
                mkDeprecatedOption
                mkDeprecatedOptionModule
                importModule
                mkCategoryModules
                mkFilesystemOptions
                ;
            };
          }
          // extraArgs
        )
      )
    );

  # Converts a declarative attrset of filesystem options into a valid list.
  # It filters out options set to `false` and formats non-booleans
  # (e.g., `hidepid = 2` -> `"hidepid=2"`). If the resulting list is
  # empty, it avoids errors by defining no options at all.
  mkFilesystemOptions =
    optionAttrs:
    let
      finalOptions = l.attrNames (
        l.filterAttrs (_: bool: bool) (
          l.mapAttrs' (name: value: {
            name = if l.isBool value then name else "${name}=${toString value}";
            value = if l.isBool value then value else true;
          }) optionAttrs
        )
      );
    in
    l.mkIf (finalOptions != [ ]) finalOptions;

  # recursively import a entire category of modules from a path, and return a list of modules to be imported with `imports`
  # `config` has to be the config attribute from nixpkgs
  # `path` is the path to the folder containing the modules, ex: ./category-name
  # `ignore` is a list of paths to ignore (can also be a folder), ex: [ ./category-name/module-name.nix ]
  # `args` are the default arguments to pass to the module, needs to be: { inherit options config pkgs lib; }
  # `extraParents` is a list of strings to add to the module option path, ex: [ "nix-mineral" ] will make the module options be available at config.nix-mineral.category-name.option-name
  # `condition` a default condition to apply to all modules
  mkCategoryModules =
    {
      config,
      path,
      ignore ? [ ],
      args,
      extraParents ? [ "nix-mineral" ],
      condition ? config.nix-mineral.enable,
    }:
    let
      # get all .nix files inside the path ignoring the files in the ignore list
      rawFilesetModules = l.map (l.fileset.fileFilter (file: file.hasExt "nix")) (
        l.fileset.toList (l.fileset.difference (l.fileset.unions [ path ]) (l.fileset.unions ignore))
      );
      # there is no default way to convert unions to strings or paths, so this is a workaround
      # `getModuleAttrPath` returns the attribute path of the module, ex: [ "extra-parent" "category-name" "module-name" ]
      # `getModuleFilePath` returns the module file path from nix store
      getModuleAttrPath =
        fileset:
        extraParents
        ++ (l.drop 3 fileset._internalBaseComponents)
        ++ [
          (l.removeSuffix ".nix" (l.elemAt (l.attrNames fileset._internalTree) 0))
        ];
      getModuleFilePath =
        fileset: (toString fileset._internalBase) + "/" + (l.elemAt (l.attrNames fileset._internalTree) 0);
    in
    l.map (
      fileset:
      (
        let
          moduleAttrPath = getModuleAttrPath fileset;
          moduleAttrPathParent = l.dropEnd 1 moduleAttrPath;
          importedModule =
            (importModule (getModuleFilePath fileset) {
              parentCfg = l.getAttrFromPath moduleAttrPathParent config;
              cfg = l.getAttrFromPath moduleAttrPath config;
            })
              args;
        in
        l.optionalAttrs (importedModule ? imports) {
          inherit (importedModule) imports;
        }
        // l.optionalAttrs (importedModule ? options) {
          options = l.setAttrByPath moduleAttrPathParent importedModule.options;
        }
        // l.optionalAttrs (importedModule ? config) {
          config = l.mkIf condition importedModule.config;
        }
      )
    ) rawFilesetModules;
in
{
  flake.lib = {
    inherit
      sources
      fetchGhFile
      mkBoolOption
      mkDeprecatedOption
      mkDeprecatedOptionModule
      importModule
      mkCategoryModules
      ;
  };
}
