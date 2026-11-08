# Joe Farmer (Godot 4.3+)

Open this folder in Godot 4.3 or newer and press F5. All art is placeholder until the PixelLab sprites are ready.

## Controls
| Key | Action |
|---|---|
| WASD / arrows | Move |
| 1-6 or Q | Pick tool: Hoe, Watering Can, Seeds, Scythe, Axe, Pickaxe |
| Space / J / left click | Use tool on the tile in front of you |
| Tab | Next seed (only in-season seeds) |
| R | Next animal type (for the livestock dealer and butcher) |
| E / K / right click | Interact: bed (front door), collect from animals, harvest, use market stalls |
| B | Buy the plot you're standing on |
| Mouse wheel or + / - | Zoom between 6x (default) and 4x |
| F5 / F9 | Save / load |

Walk down the path off the bottom of the farm to reach the town square, and walk off the top of the square to come back.
At your stand, E drops all your sellable goods in. A full stack of 99 sells over about 2 to 3 nights, and the farm is paid 90% of each day's sales when the new day starts.
At the butcher, E sells your selected animal wholesale and Space processes it into meat for a fee.

## How it fits together
- `autoload/` holds global systems: `clock.gd` (5 AM to midnight, the midnight freeze, the 7 AM late wake, 4 seasons of 28 days), `economy.gd` (gold/silver/copper stored as copper), `db.gd` (crop and animal data plus prices), `inventory.gd` (one bag per player), `save_game.gd`, `net.gd` (co-op) and `controls.gd` (key bindings).
- `data/crops.json` and `data/animals.json` hold all balance numbers. Prices are in copper (100c = 1s, 100s = 1g). Goods sell for 1.5x out of season.
- `scripts/farm.gd` holds the farm: plots, debris, soil, crops and animals. `scripts/market.gd` is the town square. `scripts/main.gd` connects players to both.
- **Co-op:** the host is authoritative. Every change goes through `request_action()` and runs on the host, then gets broadcast. Start with `-- --host` or `-- --join=<ip>` (2 to 4 players). The networking is built in but **not tested yet**.

## Testing
`godot --headless --path . -- --smoke-test` runs 24 checks of the core loop (clear, till, plant, water, grow, harvest, stocking the stand and overnight sales, buy seeds, buy plots, animals, breeding, butcher, off-season prices, the midnight rule, seasons and save/load).

## Not built yet
House interior and relocation, barns/coops as buildings, the blacksmith and carpenter shops, tool upgrades, processing machines, real UI, sound, and the art swap.

## Windows builds
Every push to `main` (so every merged PR) runs `.github/workflows/build-windows.yml` on GitHub Actions. It downloads Godot 4.3 and the Windows export template, runs the smoke test (a failing test stops the build), and exports `JoeFarmer.exe` with the "Windows Desktop" preset in `export_presets.cfg`. The game data is embedded, so the .exe is a single file.

Get the build from the repo's **Releases** page ("Latest build", always the newest), or from the run's artifacts in the **Actions** tab (kept 90 days). You can also start a build by hand with **Actions > Build Windows .exe > Run workflow**. To move to a newer Godot, change `GODOT_VERSION` at the top of the workflow.

To export locally instead: Project > Export > Windows Desktop > Export Project (install the export templates first if Godot asks).
