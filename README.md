# TES3 mods
My TES3 Morrowind mods and modding utility tools.

## Mods

### 🚧 Immersive Travel
> nexus link: 
Real-time travel with smooth movement.

### ✅ Lockpick Minigame
> nexus link: https://www.nexusmods.com/morrowind/mods/52813
Implements a gothic-like lockpicking minigame.

### ✅ Simple Levelup Skills Persist
> nexus link: https://www.nexusmods.com/morrowind/mods/52794
On levelup, simply carry over unused attributes. If you pick an attribute when leveling up, all skill levelups for that attributes are lost. 

### ✅ Pickpocket Minigame
> nexus link: https://www.nexusmods.com/morrowind/mods/52793
Replaces the vanilla pickpocket mechanic with a KCD-inspired minigame. 

### ✅ Immersive Maps
> nexus link: https://www.nexusmods.com/morrowind/mods/52683
A simple mod that disables the vanilla map menu and replaces it with textured maps when you read a map or a guide book. Also Integrates with various Map & Compass map packs.

### ✅ Immersive Bosmer Corpse Disposal
> nexus link: https://www.nexusmods.com/morrowind/mods/51123
This mod changes the "dispose corpse" button to "eat corpse" if you are playing as a Bosmer and adds some buffs for eating your felled enemies. Includes some logic for use as an Ashfall-addon.

### ✅ MWSE Compare Tooltips
> nexus link: https://www.nexusmods.com/morrowind/mods/51087
This mod adds compare tooltips for looked-at or equipped items against the equipped item of the same category. The mod has multiple MCM options to configure the comparison style. 

### ✅ MWSE Loading Splash Screens
> nexus link: https://www.nexusmods.com/morrowind/mods/51076
This mod uses MWSE to display splash screens during cell loading instead of freezing the frame as vanilla does.

## Tools

### 🚧 mwscript
> current version: 
> download: TBD
A small utility command line tool to dump tes3 plugins to human readable files, with some additional options.

```cmd
Usage: mwscript <COMMAND>

Commands:
  dump         Dump scripts from a plugin
  serialize    Serialize a plugin to a human-readable format
  deserialize  Deserialize a plugin from a human-readable format
  help         Print this message or the help of the given subcommand(s)

Options:
  -h, --help     Print help
  -V, --version  Print version
```

### 🚧 omw-util
> current version: v0.2
> download: TBD
A small utility command line tool to move plugins from your omw data directories to a working dir, and back.


```cmd
Usage: omw-util [OPTIONS] [COMMAND]

Commands:
  export   Copy plugins found in the openmw.cfg to specified directory
  cleanup  Cleans up a directory with a valid omw-util.manifest file
  import   Imports a morrowind.ini file contents to openmw.cfg. Currently only supports content names
  help     Print this message or the help of the given subcommand(s)

Options:
  -v, --verbose  Verbose output
  -h, --help     Print help
  -V, --version  Print version
```


