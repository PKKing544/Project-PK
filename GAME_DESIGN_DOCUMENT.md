# Game Design Document
### A Living Reference for the Unnamed 3D Roguelike

> **Purpose:** This document is a complete, faithful record of all mechanics, systems, and design intentions discussed during development. It is written so that an AI — or a human developer — can use it alone to fully reconstruct the game from scratch. Exact quotes from the designer are preserved (with spelling corrected) and marked in *italics* throughout.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Engine & Architecture](#2-engine--architecture)
3. [World: The Chunk-Based Grid](#3-world-the-chunk-based-grid)
4. [Movement System](#4-movement-system)
5. [Combat: Weapon Architecture](#5-combat-weapon-architecture)
6. [Combat: Melee & Heavy Attacks](#6-combat-melee--heavy-attacks)
7. [Combat: Smash-Bros Physics (Knockback & Hitstun)](#7-combat-smash-bros-physics-knockback--hitstun)
8. [Equipment & Loadout System](#8-equipment--loadout-system)
9. [Pickup Orbs](#9-pickup-orbs)
10. [Enemies: Base Enemy](#10-enemies-base-enemy)
11. [Enemies: Elephant](#11-enemies-elephant)
12. [Enemies: Axolotl (Turret)](#12-enemies-axolotl-turret)
13. [Weapons: Healing Water Gun & Flowerbeds](#13-weapons-healing-water-gun--flowerbeds)
14. [Rendering: Chunk Billboard System](#14-rendering-chunk-billboard-system)
15. [Environment: The Prototype Grid Shader](#15-environment-the-prototype-grid-shader)
16. [File Structure Reference](#16-file-structure-reference)

---

## 1. Project Overview

This is a 3D action-roguelike built in **Godot 4**. The core loop is fast, expressive movement combined with a modular, mix-and-match weapon system. The tonal reference points are:

- **Movement feel:** *Titanfall 2* / *Ultrakill* — the player should always feel like they are the fastest, most dangerous thing in the room.
- **Combat feel:** *Super Smash Bros.* — knockback is weight-based and percentage-driven, not a simple HP bar depleting to zero. Killing blows send enemies flying dramatically.
- **World structure:** A procedurally-arranged 9×9 chunk grid of 100-meter rooms, inspired by grid-based roguelikes but rendered in full 3D.

The game is currently in a **prototype / movement-gym** phase. The primary test scene is `grid_test.tscn`.

---

## 2. Engine & Architecture

### Engine
- **Godot 4** (GDScript)
- Physics: `CharacterBody3D` for the player and most enemies
- Resources: Godot's `.tres` sub-resource system is used for all data (weapons, abilities, dash configs, etc.)

### Core Design Principle: Data-Driven Sub-Resources

Early in development, weapons were saved as many separate `.tres` files (one for each fire mode, effect, etc.), which made the project feel cluttered. The system was refactored so that **each weapon is exactly one `.tres` file** using Godot's inline sub-resource system.

> *"I completely understand your concern. Right now it feels like making a single gun means managing a sprawling web of 6 to 7 different files randomly scattered in your FileSystem. The underlying architecture is actually perfectly healthy and standard for professional Godot games! The friction and clutter you are feeling is stemming from how I generated the data for you, not from the scripts themselves."*

**Rule:** Hitscan weapons = **1 file** (`pistol.tres`). Projectile weapons = **2 files** (`burst.tres` + `burst_projectile.tscn`).

### Key Script Locations

| System | Path |
|---|---|
| Player | `scripts/player.gd` |
| Hand Manager | `scripts/weapons/logic/hand_manager.gd` |
| Shot Resolver | `scripts/weapons/logic/shot_resolver.gd` |
| Knockback Component | `scripts/components/knockback_component.gd` |
| Base Enemy | `scripts/enemies/base_enemy.gd` |
| World Manager | `scripts/world/world_manager.gd` |
| Chunk | `scripts/world/chunk.gd` |
| Terrain Settings | `scripts/world/terrain_settings.gd` |

---

## 3. World: The Chunk-Based Grid

### Overview

The world is a **9×9 grid of chunks**, each chunk being **100 meters × 100 meters**. The grid is always centered on the player. As the player moves, chunks are streamed in/out dynamically.

### Chunk Types (Structure Variety)

There are four chunk structure types, each with a matching 2D billboard asset for distant rendering:

| Type | Billboard Asset |
|---|---|
| Room | `art/billboards/room_chunk_billboard.png` |
| Tower | `art/billboards/tower_chunk_billboard.png` |
| Hall | `art/billboards/hall_chunk_billboard.png` |
| Courtyard | `art/billboards/courtyard_chunk_billboard.png` |

### Rendering Tiers (Radial Priority)

Chunks are sorted into **rendering tiers** based on distance from the player. This determines how much detail/physics each chunk receives:

| Tier | Color Code | Distance | Detail Level |
|---|---|---|---|
| Tier 1 | Pink (Immediate) | 0–1 chunks away | Full 3D + physics collisions |
| Tier 2 | Yellow (Inner) | 2–3 chunks away | Full 3D, physics enabled |
| Tier 3 | Purple (Outer) | 4+ chunks away | **2D Billboard only**, physics disabled |

Physics collisions are **only enabled in Tier 1 and Tier 2** to save CPU. When the player moves, the terrain ahead "solidifies" while distant terrain becomes purely visual.

### Terrain Generation

The terrain uses **FastNoiseLite** procedural noise to create hills and valleys that are seamless across chunk borders. All terrain conforms strictly to a **0.5m vertical grid** (quantization/snapping).

**Key terrain parameters (all exposed in Inspector on WorldManager):**

| Parameter | Default | Description |
|---|---|---|
| `height_scale` | — | Maximum hill height |
| `noise_frequency` | — | Controls density of hills/valleys |
| `terrain_seed` | — | Fixed seed for reproducibility |
| `quantization` | 0.5m | Vertex height snap increment |
| Terrain face resolution | **5m per face** | Chunky lowpoly aesthetic |

The 5m face resolution was specifically chosen for the game's high-speed movement style:

> *"Broad (5m per face): Chunky, stylized look — better for high-speed movement."*

Each face has its own unique normal (no shared vertices), creating the sharp, faceted lowpoly look.

### Height-Aware Spawning

`WorldManager` samples terrain height at each chunk center. Buildings automatically shift up or down to sit on top of whatever hill they land on.

### Movement Gym Layout

The original test environment was a structured **Movement Gym** divided into 8 zones:

```
                [Zone 6: Vertical Tower (30m tall)]
                           |
[Zone 4: Slopes] --- [Zone 1: SPAWN (40x40)] --- [Zone 2: Jump Heights]
                           |
                   [Zone 5: Wall Runs]  --- [Zone 3: Gap Jumps]
                           |
                   [Zone 7: Tight Corridors]
                           |
                   [Zone 8: Large Arena (80x80)]
```

| Zone | Purpose | Key Measurements |
|---|---|---|
| 1: Spawn | Flat open platform, control signs | 40×40 |
| 2: Jump Heights | Step platforms | 1m, 2m, 3m, 4m, 5m |
| 3: Gap Jumps | Horizontal gaps | 3m, 5m, 8m, 12m, 16m |
| 4: Slopes | Angle ramps | 15°, 30°, 45°, 60° |
| 5: Wall Runs | Parallel walls | 2m, 4m, 6m gap options |
| 6: Vertical Tower | Chained wall jumps | 30m tall |
| 7: Tight Corridors | Narrow spaces | 2m, 1.5m, 1m wide |
| 8: Large Arena | Combat + flow | 80×80 |

The gym geometry is generated **procedurally at runtime** by `gym_builder.gd` attached to a Node3D, keeping the scene file clean.

---

## 4. Movement System

### Philosophy

The movement system is modeled after games like *Titanfall 2* and *Ultrakill* — momentum should be preserved, chaining moves together should feel rewarding, and every mechanic should have an advanced/skillful interaction with other mechanics.

### Core Variables (player.gd exports)

| Variable | Value | Description |
|---|---|---|
| `speed` | 12.0 | Base horizontal speed |
| `jump_velocity` | (standard) | Base jump force |
| `max_air_jumps` | 1 | Number of air jumps (double jump default) |
| `dash_duration` | 0.1s | Duration of a dash burst (10 frames @ 60fps) |
| `dash_speed` | 60.0 | Horizontal speed during a dash |
| `ground_pound_speed` | -10.0 | Downward velocity on ground pound |
| `melee_up_boost` | 15.0 | Upward velocity added by heavy melee |
| `max_camera_roll` | (exported) | Max camera lean angle on strafing |
| `zoom_linger_timer` | 0.5s | How long aim-zoom persists after firing |

### Movement Mechanics

#### Jumping
- **Coyote Time:** A short window after walking off a ledge where a jump still triggers as a "ground jump." Prevents the frustrating "missed the jump by one frame" feeling.
- **Jump Buffering:** Pressing jump just before landing registers the input and fires the jump on the next frame the player is on the floor.
- **Double Jump:** After coyote time expires mid-air, one additional jump is available (`max_air_jumps = 1`). The double jump recharges on landing or on a wall jump.
  > *"If you want to build an upgrade item later that gives the player a 'Triple Jump,' you can just increment this number via code!"*
- **Wall Jump:** Jumping while touching a wall gives a velocity boost away from the wall. The coyote timer must be cleared on wall jump to prevent it consuming the double jump unexpectedly.

#### Dashing
- Dash grants `60.0` speed for `0.1` seconds.
- Air dash (`can_air_dash`) resets on landing or wall jump. This gives one air dash per airborne stretch.
- **B-Hopping:** If a dash ends while airborne and the player lands while holding `Ctrl` (Slide), the velocity stripper is bypassed. The player keeps full dash momentum into a ground slide — creating an extremely fast bhop chain.

#### Sliding
- Triggered by holding `Crouch/Sneak` while moving on the ground.
- The player slides on slopes automatically; on flat ground it requires `crouch_pressed`.
- A known design consideration: the slide exit logic was simplified to the check at the correct line; the dead `else: pass` branch was removed.

#### Wall Mechanics
- **Wall Latch:** Crouch while touching a wall to latch on (negates gravity).
- **Wall Slide:** Slow downward gravity while touching a wall without latching.
- **Wall Run:** Activated during a dash while in contact with a wall. Because `dash_duration = 0.1s`, the timing window is tight. A `was_recently_dashing` grace timer (0.3–0.5s) was discussed to widen the activation window.

#### Ground Pound
- Triggered by pressing `Crouch/Sneak` while airborne.
- Sets `velocity.y = ground_pound_speed` **once on button press** (not every frame). This allows gravity to accelerate the player past the initial value, making the pound feel weighty.

#### Heavy Melee Uppercut
- A fully charged heavy melee (`hold > 0.3s`) imparts `15.0` upward velocity on release.
- Combined with double jump + air dash, this allows the player to stay airborne indefinitely and scale tall vertical structures.

### Camera

- **Spring Arm:** Smooth third-person follow camera using a `SpringArm3D`.
- **Strafe Roll:** When pressing A or D, the camera rolls (`rotation.z`) into the turn direction — a "skate video" aesthetic.
- **Wall Run Lean:** Camera yanks away from the wall aggressively during wall runs to sell the G-forces.
- Both `max_camera_roll` and `melee_up_boost` are `@export` values adjustable in the Inspector without code changes.

### Aiming & Firing

The aim mode logic separates "is currently aiming" from "just fired":
```gdscript
aim_mode = Input.is_action_pressed("shoot") or zoom_linger_timer > 0
if Input.is_action_just_pressed("shoot") and not is_charging_melee:
    fire_weapon()
    zoom_linger_timer = 0.5
```
The `0.5s` zoom linger keeps the camera zoomed briefly after firing for visual clarity.

---

## 5. Combat: Weapon Architecture

### Overview

Weapons are composed of **data resources** (`HandData`, `FireModeData`, `EffectData`) rather than scene nodes. This keeps visual clutter minimal and makes weapons easily configurable in the Godot Inspector.

### HandData (`scripts/weapons/data/hand_data.gd`)

A `HandData` resource defines the base weapon "type" — what the hand *is*. It contains:

| Property | Type | Description |
|---|---|---|
| `max_ink` | float | Maximum ammo resource for this hand |
| `passive_ink_regen_per_sec` | float | Passive ink regeneration per second |
| `primary_mode` | FireModeData | The primary fire configuration |

### FireModeData

Defines how a single fire action behaves:

| Property | Description |
|---|---|
| `trigger_type` | `AUTOMATIC`, `SEMI_AUTO`, `BURST`, `CHARGE` |
| `fire_type` | `HITSCAN`, `PROJECTILE` |
| `damage` | Base damage per hit |
| `ink_cost` | Ink consumed per shot |
| `fire_rate_sec` | Seconds between shots (cooldown) |
| `spread_deg` | Random spread cone in degrees |
| `pellet_count` | Number of pellets per trigger pull |
| `range_m` | Max hitscan range in meters |
| `knockback_force` | Force applied to shooter (recoil kickback) |
| `reactive_kickback_force` | Wall-proximity push force |
| `reactive_kickback_threshold` | Consecutive shots before reactive kick activates |
| `reactive_kickback_range` | Distance raycast for detecting nearby surfaces |
| `burst_count` | Number of shots in a burst |
| `burst_delay_sec` | Delay between burst shots |
| `min_charge_time_sec` | Minimum hold time to fire a charged shot |
| `max_charge_time_sec` | Hold time for maximum charge ratio |
| `heals_target` | If true, `damage` value heals instead of hurts |
| `hit_effects` | Array of `EffectData` applied on hit |
| `projectile_scene` | Packed scene for projectile type |

### Trigger Types in Detail

**AUTOMATIC:** Fires every `fire_rate_sec` while trigger is held.

**SEMI_AUTO:** Fires once per trigger press. Requires release and re-press.

**BURST:** On trigger press, fires `burst_count` shots with `burst_delay_sec` between each. Uses `await get_tree().create_timer()` for the inter-burst delay.

**CHARGE:** Accumulates `charge_accumulated += delta` while trigger is held. On release, if `charge_accumulated >= min_charge_time_sec`, fires with `charge_ratio = clamp(charge_accumulated / max_charge_time_sec, 0.0, 1.0)`.

### HandManager (`scripts/weapons/logic/hand_manager.gd`)

The `HandManager` node (child of the player) orchestrates all firing:

- Tracks `current_ink`, `fire_cooldown`, `charge_accumulated`, `consecutive_shots`, `time_since_last_shot`
- `consecutive_shots` resets if `time_since_last_shot > 0.2s` — used for reactive kickback threshold
- `equip_hand(hand, attachment)` and `equip_attachment(attachment)` are the public API
- Emits `ink_changed(current, max)` and `hand_changed(hand)` signals for UI

### ShotResolver (`scripts/weapons/logic/shot_resolver.gd`)

Handles the actual physics of a shot:

**Aim Direction Calculation:**
1. Raycast from screen center via `Camera3D.project_ray_normal()`
2. If the ray hits something within 100m, that becomes the `final_target`
3. Direction = `(final_target - muzzle_point.global_position).normalized()`
4. Spread applied via `lerp(base_dir, random_vec, spread_rad)` — clamped to avoid inverting direction

**Hitscan Resolution:**
1. Raycast from muzzle along aim direction up to `mode.range_m`
2. On hit: call `preview_damage()` on the collider first
3. Apply all `hit_effects` (knockback, splash, etc.)
4. Then deal actual damage via `take_damage()` or `heal()`
5. Draw a temporary beam visual (0.05s lifetime, purple emissive cylinder, radius 0.03m)

**Beam Visual Properties:**
```
top_radius = 0.03, bottom_radius = 0.03
albedo_color = Color(0.2, 0.0, 0.4)
emission = Color(0.4, 0.0, 0.7)
emission_energy_multiplier = 3.0
lifetime = 0.05s
```

**Projectile Resolution:**
- Instantiates `mode.projectile_scene`
- Adds to `get_tree().root`
- Positions at `muzzle_point.global_position + aim_dir * 0.5` (0.5m forward offset prevents self-collision)
- Calls `proj.initialize(aim_dir, mode, shooter, charge_ratio)`

**Kickback (Recoil):**
- Normal kickback: `-aim_dir * kickback_force * max(1.0, 2.0 * charge_ratio)` — scales up to 2× at full charge
- Reactive kickback: Fires a short-range ray. If a surface is nearby and `consecutive_shots >= threshold`, pushes player back. Used for the shotgun-style "wall push" mechanic.

### AttachmentData

Attachments modify an existing `FireModeData`:
- `apply_to(mode: FireModeData) -> FireModeData` — returns a modified copy of the mode
- Stored in `scripts/weapons/data/instances/attachments/`
- Applied by `HandManager` every frame before determining trigger behavior

### EffectData

An abstract base resource. Subclasses implement:
```gdscript
func apply_effect(target, hit_point, hit_normal, aim_dir, charge_ratio, damage):
```

Known effect types:
- `KnockbackEffect` — applies knockback to a `KnockbackComponent` on the target
- `SplashDamageEffect` — area damage in a radius; plays a magenta expanding sphere visual (0.15s, matches exact splash radius)
- `SpawnFlowerbedEffectData` — spawns a flowerbed on floor surfaces (see Section 13)

---

## 6. Combat: Melee & Heavy Attacks

### Tap Melee (Light Attack)

- Bound to the melee button (middle mouse, short press)
- Player-controller-level fallback — always available regardless of equipment
- Short-range hit with a hitbox sweep
- Does not consume ink

### Heavy Attack System (`HeavyAttackData`)

The heavy attack is a fully **independent, equippable resource** decoupled from the player controller. This allows any `HeavyAttackData` to be mixed with any hand weapon.

> *"Keep the base Tap Melee tied to the player, but introduce a brand new, independent system for Heavy Attacks. This way you can mix and match any Hand with any Heavy Attack!"*

**`HeavyAttackData` resource properties (`scripts/weapons/data/heavy_attack_data.gd`):**

| Property | Default Value | Description |
|---|---|---|
| `attack_name` | "Lunge Punch" | Display name |
| `damage` | 100.0 | Damage dealt |
| `knockback_force` | 900.0 | Knockback applied to target |
| `hitstop_duration` | 0.05s | Freeze frames on hit (the "crunch" feel) |
| `lunge_boost` | 45.0 | Horizontal speed burst on swing |
| `pogo_bounce` | 25.0 | Upward velocity when hitting downward |
| `charge_threshold` | 0.3s | Minimum hold time to trigger heavy |
| `swing_duration` | 0.25s | Active hitbox frame window |

**Player Integration:**
```gdscript
@export_group("Equipment")
@export var equipped_heavy_attack: HeavyAttackData
```
- When `melee_charge_timer >= equipped_heavy_attack.charge_threshold` on release, the heavy executes
- If no `HeavyAttackData` is equipped, the heavy falls back to light tap variables
- All physics (lunge, pogo, hitstop) are read dynamically from the resource at runtime

**Pogo / Wall Bounce:**
- If the heavy hits an enemy below the player (downward attack), `pogo_bounce` is applied as upward velocity
- Pogo bounce magnitude scales with enemy `size_mult` (larger enemies = higher bounce)
- If an enemy has a **Bubble Shield** active (see Elephant section), pogo bounce is multiplied by **3×**

**Hitstun / Active Frames:**
- The player enters a brief locked animation state during `swing_duration`
- `is_swinging_melee` flag prevents double-firing

**Melee Charge Startup:**
The charge timer initializes to `0.0` on entry (not pre-seeded with delta):
```gdscript
elif melee_pressed and not is_swinging_melee:
    is_charging_melee = true
    melee_charge_timer = 0.0  # clean slate
```
This prevents ultra-light taps from accidentally registering as heavy attacks.

---

## 7. Combat: Smash-Bros Physics (Knockback & Hitstun)

### Philosophy

The damage model is inspired by *Super Smash Bros.* — enemies don't have a simple "HP bar goes to 0, then die" loop. Instead, accumulated damage **increases how far they fly on knockback**. Lethal hits send enemies flying dramatically off the screen rather than simply collapsing.

> *"Unlike generic game enemies that queue_free() the second they hit 0 HP, our BasicEnemy targets activate a localized [K.O.] State."*

### KnockbackComponent (`scripts/components/knockback_component.gd`)

A standalone Godot Node that can be added to **any** `CharacterBody3D` enemy. Properties:

| Property | Description |
|---|---|
| `weight` | Mass. Higher = resists knockback more. (Axolotl: 2500) |
| `knockback_resistance` | Multiplier that reduces incoming force |
| `size_mult` | Affects pogo bounce height when player pogos off this enemy |

**Air Balloon Gravity:**
While an enemy is in hitstun, gravity drops to **40%** of normal. This causes enemies to float farther distances — replicating the floaty Smash Bros. DI arc.

**Directional Restitution:**
- Hitstun momentum snaps to zero the instant stun ends — making physics feel immediately tactile
- Wall bounces are preserved during hitstun based on the enemy's density multiplier

### Preview Damage System

A critical architectural feature: before any shot actually deals damage, `preview_damage()` is called on the target. This solves the "chicken-and-egg" problem between damage and knockback calculation:

> *"Our ShotResolver and BaseProjectile solvers now whisper a preview_damage tick to targets a microsecond before hitting them. This means an enemy with massive health will securely tank a full 99-damage nuke with very little physical knockback, but the exact moment a 1 HP attack lands that promises to be fatal, they spoof their own percent mapping to 0.0 to instantly activate a 300% knockback velocity multiplier to fly off stage exactly like a Smash finisher!"*

**Call order:**
1. `collider.preview_damage(mode.damage)` — target internally adjusts its knockback-percent calculation
2. `effect.apply_effect(...)` — knockback is applied using the preview-adjusted percent
3. `collider.take_damage(mode.damage)` — actual HP is deducted

### K.O. State (Lingering Enemy Death)

When an enemy reaches 0 HP:
1. Enters **K.O. State** — does NOT immediately `queue_free()`
2. Becomes a muted physical ragdoll — knockback physics finish resolving
3. Player collision is disabled — the player can walk through the flying body
4. After **2.0 seconds**, the enemy safely deletes itself

### Combat HUD Debug Labels

During development, real-time combat metrics are displayed above every enemy:
- Raw Force vs. Acceleration breakdown
- Hitstun decay per shot

These are rendered via `Label3D` nodes on the enemy and update every frame.

---

## 8. Equipment & Loadout System

### Five Equipment Categories

The game has five independent equipment slots. Any combination is valid:

| Slot | Resource Type | Path |
|---|---|---|
| Hand | `HandData` | `instances/hands/` |
| Attachment | `AttachmentData` | `instances/attachments/` |
| Ability | (AbilityData) | `instances/abilities/` |
| Dash | `DashData` | `instances/dashes/` |
| Heavy Attack | `HeavyAttackData` | `instances/heavy_attacks/` |

### Debug Equipment Menu

- Press **`C`** in-game to open the Debug Equipment Menu
- Dropdown menus auto-populate by scanning the `instances/` directory
- **No UI code needs to be written to add a new item** — just drop a `.tres` file in the right folder

> *"The next time you press C in-game, your new item will automatically appear in the dropdown menu. You don't need to write any UI code to add new options."*

### Adding New Items

1. Create a new `.tres` Resource file in the Godot editor
2. Select the correct class (e.g., `DashData`)
3. Save into the appropriate subfolder under `res://scripts/weapons/data/instances/`
4. Done — it appears in the debug menu automatically

### Bloom Ability

`bloom_ability_data.gd` is one of the currently-defined ability types. Abilities are right-click actions with cooldowns. The exact Bloom mechanic values were in development at the time of the "Color Rendering Systems" session.

---

## 9. Pickup Orbs

### Overview

`PickupOrb` (`scripts/world/pickup_orb.gd`) is an `Area3D` that spawns from defeated enemies or placed in the world. It uses Minecraft-style magnet pickup behavior.

### Types

| Type | Color | Effect on Absorption |
|---|---|---|
| `BLACK_INK` | Dark gray `Color(0.1, 0.1, 0.1)` | Restores ink to `HandManager.current_ink` |
| `PINK_INK` | Pink `Color(1.0, 0.2, 0.8)` | Reduces ability cooldown + heals player |
| `KEY` | — | (Future use) |
| `ITEM` | — | (Future use) |

### Spawn Behavior

On `_ready()`, the orb launches with a randomized "pop" velocity:
```gdscript
velocity = Vector3(randf_range(-2, 2), randf_range(4, 7), randf_range(-2, 2))
```

### Physics

- Custom gravity: `velocity.y -= 20.0 * delta`
- Raycast downward each frame to detect floor
- On floor contact: bounces with `velocity.y = abs(velocity.y) * 0.5`
- Horizontal friction: `move_toward(v, 0, delta * 2.0)` on X and Z

### Magnet System

- Activates when player is within **12.0 meters** of the orb
- Magnet speed accelerates: `magnet_speed += delta * 40.0`
- Orb flies toward `player.global_position + Vector3(0, 1.0, 0)` (slightly above feet)
- Absorbed when within **0.8 meters** of target point

### Absorption Effects

**BLACK_INK:**
```gdscript
hm.current_ink = min(hm.current_ink + value, hm.current_hand.max_ink)
hm.emit_signal("ink_changed", hm.current_ink, hm.current_hand.max_ink)
```

**PINK_INK:**
```gdscript
player.ability_cooldown_timer = max(0, player.ability_cooldown_timer - value)
player.heal(value)
```

Default `value` for an orb is `20.0`.

---

## 10. Enemies: Base Enemy

### Architecture

`base_enemy.gd` (and its scene `basic_enemy.tscn`) provides the shared foundation for all enemies.

**Key variables:**
- `last_attack_time: float = 0.0` — timestamp of last attack, used by Elephant for "hasn't attacked in 5 seconds" heal targeting
- Enemies must be in the `"enemy"` group for the Elephant to locate them

**Death Behavior:**
All enemies follow the K.O. State pattern (Section 7) — physics finish resolving before the node is freed, with a 2.0s delay.

**Combat Labels:**
A `Label3D` above every enemy displays real-time knockback stats during development.

---
