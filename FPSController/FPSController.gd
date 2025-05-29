extends CharacterBody3D

@export var look_sensitivity : float = 0.0005
@export var jump_velocity := 6.0
@export var auto_bhop := true

const HEADBOB_MOVE_AMOUNT = 0.06
const HEADBOB_FREQUENCY = 2.4
var headbob_time := 0.0

## ground movement settings
@export var walk_speed := 7.0
@export var sprint_speed := 12
@export var ground_accel := 14.0
@export var ground_decel := 10.0
@export var ground_friction := 6.0

## air movement settings
@export var air_cap := 0.85
@export var air_accel := 800.0
@export var air_move_speed := 500.0


var wish_dir := Vector3.ZERO
var cam_aligned_wish_dir := Vector3.ZERO

const CROUCH_TRANSLATE = 0.7
const CROUCH_JUMP_ADD = CROUCH_TRANSLATE * 0.9
var is_crouched := false

var noclip_speed_mult := 3.0
var noclip := false

func get_move_speed() -> float:
	if is_crouched:
		return walk_speed * 0.8
	return sprint_speed if Input.is_action_pressed("sprint") else walk_speed

#func _ready():
#	for child in %WorldModel.find_children("*", "VisualInstance3D"):
#		child.set_layer_mask_value(1, false)
#		child.set_layer_mask_value(2, true)

## using _unhandled_input instead of _input to allow for ui to be clickable without the camera stealing focus
func _unhandled_input(event):
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		event.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * look_sensitivity)
			%Camera3D.rotate_x(-event.relative.y * look_sensitivity)
			%Camera3D.rotation.x = clamp(%Camera3D.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _headbob_effect(delta):
	headbob_time += delta * self.velocity.length()
	%Camera3D.transform.origin = Vector3(
		cos(headbob_time * HEADBOB_FREQUENCY * 0.5) * HEADBOB_MOVE_AMOUNT,
		sin(headbob_time * HEADBOB_FREQUENCY) * HEADBOB_MOVE_AMOUNT,
		0
	)

@onready var animation_tree : AnimationTree = $"WorldModel/container/AnimationTree"
@onready var state_machine_playback : AnimationNodeStateMachinePlayback = $"WorldModel/container/AnimationTree".get("parameters/playback")
func update_animations():
	if noclip or (not is_on_floor()):
		## update later to include crouch jump animation
		if is_crouched:
			state_machine_playback.travel("jump")
		else:
			state_machine_playback.travel("jump")
		return

	var rel_vel = self.global_basis.inverse() * ((self.velocity * Vector3(1, 0, 1)) / get_move_speed())
	var rel_vel_xz = Vector2(rel_vel.x, -rel_vel.z)

	if is_crouched:
		state_machine_playback.travel("CrouchBlendSpace2D")
		animation_tree.set("parameters/CrouchBlendSpace2D/blend_position", rel_vel_xz)
	elif Input.is_action_pressed("sprint"):
		state_machine_playback.travel("RunBlendSpace2D")
		animation_tree.set("parameters/RunBlendSpace2D/blend_position", rel_vel_xz)
	else:
		state_machine_playback.travel("WalkBlendSpace2D")
		animation_tree.set("parameters/WalkBlendSpace2D/blend_position", rel_vel_xz)

func _process(delta):
	update_animations()

@onready var _original_capsule_height = $CollisionShape3D.shape.height

func _handle_crouch(delta) -> void:
	var was_crouched_last_frame = is_crouched
	if Input.is_action_pressed("crouch"):
		is_crouched = true
	elif is_crouched and not self.test_move(self.transform, Vector3(0, CROUCH_TRANSLATE, 0)):
		is_crouched = false

	var translate_y_if_possible := 0.0
	var result = KinematicCollision3D.new()
	if was_crouched_last_frame != is_crouched and not is_on_floor():
		translate_y_if_possible = CROUCH_JUMP_ADD if is_crouched else -CROUCH_JUMP_ADD
	if translate_y_if_possible != 0.0:
		self.position.y += translate_y_if_possible
		%Head.position.y -= result.get_travel().y
		%Head.position.y = clampf(%Head.position.y, -CROUCH_TRANSLATE, 0)

	%Head.position.y = move_toward(%Head.position.y, -CROUCH_TRANSLATE if is_crouched else 0, 7.0 * delta)
	$CollisionShape3D.shape.height = _original_capsule_height - CROUCH_TRANSLATE if is_crouched else _original_capsule_height
	$CollisionShape3D.position.y = $CollisionShape3D.shape.height / 2

func _handle_noclip(delta) -> bool:
	if Input.is_action_just_pressed("_noclip") and OS.has_feature("debug"):
		noclip = !noclip

	$CollisionShape3D.disabled = noclip

	if not noclip:
		return false

	var speed = get_move_speed() * noclip_speed_mult
	if Input.is_action_pressed("sprint"):
		speed *= 3.0

	self.velocity = cam_aligned_wish_dir * speed
	global_position += self.velocity * delta

	return true

func _handle_air_physics(delta) -> void:
	self.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	## source style air control
	var cur_speed_in_wish_dir = self.velocity.dot(wish_dir)
	## wish speed (if wish_dir > 0 length) capped to air_cap
	var capped_speed = min((air_move_speed * wish_dir).length(), air_cap)
	# the source sauce
	var add_speed_till_cap = capped_speed - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = air_accel * air_move_speed * delta
		accel_speed = min(accel_speed, add_speed_till_cap)
		self.velocity += accel_speed * wish_dir


func _handle_ground_physics(delta) -> void:
	## similar to air movement, acceleration and friction on ground
	var cur_speed_in_wish_dir = self.velocity.dot(wish_dir)
	var add_speed_till_cap = get_move_speed() - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = ground_accel * delta * get_move_speed()
		accel_speed = min(accel_speed, add_speed_till_cap)
		self.velocity += accel_speed * wish_dir

	## friction
	var control = max(self.velocity.length(), ground_decel)
	var drop = control * ground_friction * delta
	var new_speed = max(self.velocity.length() - drop, 0.0)
	if self.velocity.length() > 0:
		new_speed /= self.velocity.length()
	self.velocity *= new_speed

	_headbob_effect(delta)

func _physics_process(delta):
	var input_dir = Input.get_vector("left", "right", "up", "down").normalized()
	## Depnding on which way you have your character facing, you may have to negate the input directions
	## self.global_tranform.basis ensures that movement is relative to the character's orientation, rather than the world's
	wish_dir = self.global_transform.basis * Vector3(input_dir.x, 0., input_dir.y)
	cam_aligned_wish_dir = %Camera3D.global_transform.basis * Vector3(input_dir.x, 0., input_dir.y)

	_handle_crouch(delta)

	if not _handle_noclip(delta):
		if is_on_floor():
			if Input.is_action_just_pressed("jump") or (auto_bhop and Input.is_action_pressed("jump")):
				self.velocity.y = jump_velocity
			_handle_ground_physics(delta)
		else:
			_handle_air_physics(delta)

		move_and_slide()


func _on_door_body_entered(body: Node3D) -> void:
	pass # Replace with function body.
