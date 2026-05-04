# Equipment System

This system allows for dynamic swapping of equipment using the debug menu. 

## How it works

The game contains 5 main equipment categories:
- **Hands**: The base weapon logic (e.g., Burst Hand).
- **Attachments**: Modifiers applied to the Hand (e.g., increased fire rate, extra pellets).
- **Abilities**: Right-click actions with cooldowns.
- **Dashes**: Modifies dash speed and duration.
- **Heavy Attacks**: Custom melee properties.

The **Debug Equipment Menu** (press `C` in-game) allows you to mix and match any combination of these.

## Adding new items

Whenever you want to add a new weapon, ability, or dash to the game:
1. Create a new `.tres` Resource file in the editor.
2. Select the appropriate class (e.g., `DashData`).
3. Save it into the corresponding folder under `res://scripts/weapons/data/instances/`:
   - `/hands/`
   - `/attachments/`
   - `/abilities/`
   - `/dashes/`
   - `/heavy_attacks/`

**That's it!** The next time you press `C` in-game, your new item will automatically appear in the dropdown menu. You don't need to write any UI code to add new options.
