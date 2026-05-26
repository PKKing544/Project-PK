extends Node3D
class_name HandManager

@export var current_hand: HandData
@export var current_attachment: AttachmentData

@onready var shot_resolver: ShotResolver = $ShotResolver

signal ink_changed(current: float, max_ink: float)
signal hand_changed(hand: HandData)

var current_ink: float = 0.0

var fire_cooldown: float = 0.0
var charge_accumulated: float = 0.0
var is_trigger_pressed: bool = false
var was_trigger_pressed: bool = false
var consecutive_shots: int = 0
var time_since_last_shot: float = 0.0

func _ready():
	if current_hand:
		current_ink = current_hand.max_ink
		hand_changed.emit(current_hand)

func _process(delta: float):
	if not current_hand: return
	
	# Ink Regen (Passive)
	if current_ink < current_hand.max_ink:
		current_ink += current_hand.passive_ink_regen_per_sec * delta
		current_ink = min(current_ink, current_hand.max_ink)
		ink_changed.emit(current_ink, current_hand.max_ink)
		
	# Cooldown tracking
	if fire_cooldown > 0:
		fire_cooldown -= delta
		
	# Shot timing reset for propulsion
	time_since_last_shot += delta
	if time_since_last_shot > 0.2:
		consecutive_shots = 0
		
	# Handle Input logic
	# is_trigger_pressed is updated externally via set_trigger()
	
	if is_trigger_pressed:
		charge_accumulated += delta
		_process_mode(current_hand.primary_mode)
		if current_hand.secondary_mode:
			_process_mode(current_hand.secondary_mode)
	else:
		if was_trigger_pressed:
			_process_release(current_hand.primary_mode)
			if current_hand.secondary_mode:
				_process_release(current_hand.secondary_mode)
		charge_accumulated = 0.0
		
	was_trigger_pressed = is_trigger_pressed

func _process_mode(base_mode: FireModeData):
	if not base_mode: return
	var mode = base_mode
	if current_attachment:
		mode = current_attachment.apply_to(mode)
		
	match mode.trigger_type:
		FireModeData.TriggerType.AUTOMATIC:
			if fire_cooldown <= 0:
				try_fire(mode)
		FireModeData.TriggerType.SEMI_AUTO:
			if not was_trigger_pressed and fire_cooldown <= 0:
				try_fire(mode)
		FireModeData.TriggerType.BURST:
			if fire_cooldown <= 0 and not was_trigger_pressed:
				_fire_burst(mode)
		FireModeData.TriggerType.CHARGE:
			pass # Handled by global charge_accumulated

func _process_release(base_mode: FireModeData):
	if not base_mode: return
	var mode = base_mode
	if current_attachment:
		mode = current_attachment.apply_to(mode)
	if mode.trigger_type == FireModeData.TriggerType.CHARGE:
		_fire_charged(mode)

func set_trigger(pressed: bool):
	is_trigger_pressed = pressed

func try_fire(mode: FireModeData, charge_ratio: float = 1.0) -> bool:
	if current_ink >= mode.ink_cost:
		current_ink -= mode.ink_cost
		ink_changed.emit(current_ink, current_hand.max_ink)
		
		consecutive_shots += 1
		time_since_last_shot = 0.0
		
		shot_resolver.resolve_shot(mode, charge_ratio, consecutive_shots)
		fire_cooldown = mode.fire_rate_sec
		return true
	else:
		# Reset counter if we can't fire
		consecutive_shots = 0
		return false

func _fire_burst(mode: FireModeData):
	for i in range(mode.burst_count):
		if not try_fire(mode): break
		if mode.burst_delay_sec > 0:
			await get_tree().create_timer(mode.burst_delay_sec).timeout

func _fire_charged(mode: FireModeData):
	if charge_accumulated >= mode.min_charge_time_sec:
		var ratio = clamp(charge_accumulated / mode.max_charge_time_sec, 0.0, 1.0)
		try_fire(mode, ratio)
	charge_accumulated = 0.0

func equip_hand(hand: HandData, attachment: AttachmentData = null):
	current_hand = hand
	current_ink = hand.max_ink
	current_attachment = attachment
	hand_changed.emit(hand)
	ink_changed.emit(current_ink, hand.max_ink)

func equip_attachment(attachment: AttachmentData):
	current_attachment = attachment

func is_charging() -> bool:
	if not current_hand or not current_hand.primary_mode: return false
	return is_trigger_pressed and current_hand.primary_mode.trigger_type == FireModeData.TriggerType.CHARGE

func get_current_charge_ratio() -> float:
	if not is_charging(): return 0.0
	var max_charge = current_hand.primary_mode.max_charge_time_sec
	if max_charge <= 0.0: return 0.0
	return clamp(charge_accumulated / max_charge, 0.0, 1.0)
