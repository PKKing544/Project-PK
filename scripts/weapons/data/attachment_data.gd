extends Resource
class_name AttachmentData

@export var attachment_name: String = "Attachment"

@export_group("Stat Multipliers")
@export var damage_multiplier: float = 1.0
@export var fire_rate_multiplier: float = 1.0
@export var charge_time_multiplier: float = 1.0
@export var ink_cost_multiplier: float = 1.0
@export var projectile_speed_multiplier: float = 1.0
@export var range_multiplier: float = 1.0

@export_group("Stat Additions")
@export var spread_add_deg: float = 0.0
@export var recoil_add_deg: float = 0.0
@export var pellet_count_add: int = 0
@export var burst_count_add: int = 0

@export_group("Added Effects")
@export var projectile_gravity_add: float = 0.0
@export var override_to_healing: bool = false
@export var extra_hit_effects: Array[EffectData] = []

# Takes a base fire mode, safely copies it, and mathematically applies the attachment
func apply_to(mode: FireModeData) -> FireModeData:
	if mode == null:
		return null
		
	var compiled = mode.duplicate()
	compiled.damage *= damage_multiplier
	compiled.fire_rate_sec *= fire_rate_multiplier
	compiled.min_charge_time_sec *= charge_time_multiplier
	compiled.max_charge_time_sec *= charge_time_multiplier
	compiled.ink_cost *= ink_cost_multiplier
	compiled.projectile_speed_m_s *= projectile_speed_multiplier
	compiled.range_m *= range_multiplier
	
	compiled.spread_deg += spread_add_deg
	compiled.recoil_deg += recoil_add_deg
	compiled.pellet_count += pellet_count_add
	compiled.burst_count += burst_count_add
	compiled.projectile_gravity += projectile_gravity_add
	if override_to_healing:
		compiled.heals_target = true
	
	var new_effects: Array[EffectData] = []
	new_effects.append_array(compiled.hit_effects)
	new_effects.append_array(extra_hit_effects)
	compiled.hit_effects = new_effects
	
	return compiled
