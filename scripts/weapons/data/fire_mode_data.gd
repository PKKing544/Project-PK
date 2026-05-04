extends Resource
class_name FireModeData

enum FireType { HITSCAN, PROJECTILE }
enum TriggerType { AUTOMATIC, SEMI_AUTO, BURST, CHARGE }

@export var mode_name: String = "Primary"
@export var fire_type: FireType = FireType.HITSCAN
@export var trigger_type: TriggerType = TriggerType.AUTOMATIC

@export_group("Stats")
@export var damage: float = 10.0
@export var kickback_force: float = 0.0 # Force pushed backwards when fired
@export var fire_rate_sec: float = 0.1 # Time between shots
@export var ink_cost: float = 1.0 # Replaces ammo
@export var spread_deg: float = 0.0
@export var recoil_deg: float = 0.0
@export var range_m: float = 100.0 # Max distance for hitscan

@export_group("Advanced Firing")
@export var pellet_count: int = 1 # Shotgun style
@export var burst_count: int = 1 # Sequential burst
@export var burst_delay_sec: float = 0.05
@export var min_charge_time_sec: float = 0.5 # Minimum hold time required to fire charged
@export var max_charge_time_sec: float = 1.5 # Maximum hold time for 100% scale

@export_group("Projectile Specific")
@export var projectile_speed_m_s: float = 30.0
@export var projectile_gravity: float = 0.0 # How fast it falls
@export var projectile_scene: PackedScene
@export var heals_target: bool = false # If true, damage applies as healing

@export_group("Reactive Kickback")
@export var reactive_kickback_force: float = 0.0 # Force when firing very close to a wall/floor
@export var reactive_kickback_range: float = 4.0 # How close you need to be
@export var reactive_kickback_threshold: int = 5 # Number of consecutive shots before kicking in

@export_group("Spread Bloom")
@export var spread_tighten_speed: float = 5.0
@export var spread_kick_per_shot: float = 0.2
@export var min_spread_deg: float = 0.0
@export var max_spread_deg: float = 10.0

@export_group("Effects")
@export var hit_effects: Array[EffectData] = []
