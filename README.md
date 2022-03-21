# BTNetIdle

## Author
* Sapphire

## Description
A mod for Unreal Tournament (UT99) servers that reconnects idle players as spectators.

**Important to note:** Players are reconnected via a mutate console command that invokes the Nexgen server controller mod's own reconnect function (`mutate NSC SPECTATE`). Nexgen is therefore required for this mod to work.

## Installation
1. Copy the file(s) inside the `Compiled` folder to your server's `UT/System/` directory
2. Optionally tweak the settings in `BTNetIdle.ini`
3. Open your server's `UnrealTournament.ini`
4. Under `[Engine.GameEngine]` add: `ServerActors=BTNetIdle_v000.BTNetIdle`
5. Restart your server

## Version
2022-03-21
