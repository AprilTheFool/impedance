extends CharacterBody3D

@export var look_sensitivity : float = 0.002
@export var jump_velocity := 6.0
@export var auto_bhop := false

@export var headbob_move_amount = 0.1
const HEADBOB_FREQUENCY = 1
var headbob_time := 0.0

@export var walk_speed := 7.0
@export var sprint_speed := 15
@export var ground_accel := 14.0
@export var ground_decel := 10.0
@export var ground_friction := 6.0

var current_sprint_speed := 15.0
@export var sprint_speed_cap := 25.0
@export var sprint_build_up := 1.0

var default_fov := 98.0
var sprint_fov := 110.0
var fov_speed := 4.0
var target_fov := 75.0

var current_line_density := 0.0
var target_line_density := 0.0
var line_transition_speed := 3.0

@export var air_cap := 0.85
@export var air_accel := 800.0
@export var air_move_speed := 500.0

var wish_dir := Vector3.ZERO

func get_move_speed(delta) -> float:
	var input_dir = Input.get_vector("left", "right", "up", "down")

	if Input.is_action_pressed("sprint"):
		if input_dir.length() > 0:
			# Accelerate toward sprint cap
			if current_sprint_speed < sprint_speed:
				current_sprint_speed = sprint_speed
			else:
				current_sprint_speed = min(current_sprint_speed + sprint_build_up * delta, sprint_speed_cap)
		else:
			# Decelerate toward base sprint speed if not moving
			if current_sprint_speed > sprint_speed:
				current_sprint_speed = max(current_sprint_speed - sprint_build_up * delta, sprint_speed)
	else:
		current_sprint_speed = walk_speed

	return current_sprint_speed

func _ready():
	## hide world model in fpv
	for child in %WorldModel.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(2, true)

func _unhandled_input(event):
	## capture mouse when window is clicked and release when esc is pressed
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	## handle mouse movement
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * look_sensitivity)
			%Camera3D.rotate_x(-event.relative.y * look_sensitivity)
			%Camera3D.rotation.x = clamp(%Camera3D.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _headbob_effect(delta):
	headbob_time += delta * self.velocity.length()
	%Camera3D.transform.origin = Vector3(
		cos(headbob_time * HEADBOB_FREQUENCY * 0.5) * headbob_move_amount,
		sin(headbob_time * HEADBOB_FREQUENCY) * headbob_move_amount,
		0
	)

func _process(delta):
	pass

func _handle_air_physics(delta) -> void:
	## set gravity based on project setting (default 12)
	self.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	
	## fancy css style air movement
	var cur_speed_in_wish_dir = self.velocity.dot(wish_dir)
	var capped_speed = min((air_move_speed * wish_dir).length(), air_cap)
	var add_speed_till_cap = capped_speed - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed =  air_accel * air_move_speed * delta
		accel_speed = min(accel_speed, add_speed_till_cap)
		self.velocity += accel_speed * wish_dir

func _handle_ground_physics(delta) -> void:
	var cur_speed_in_wish_dir = self.velocity.dot(wish_dir)
	var move_speed = get_move_speed(delta)
	var add_speed_till_cap = move_speed - cur_speed_in_wish_dir

	if add_speed_till_cap > 0:
		var accel_speed = ground_accel * delta * move_speed
		accel_speed = min(accel_speed, add_speed_till_cap)
		self.velocity += accel_speed * wish_dir

	# Modify friction based on input
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var applied_friction = ground_friction

	if Input.is_action_pressed("sprint") and input_dir.length() == 0:
		# Reduce friction to allow slow deceleration while sprinting and not pressing movement
		applied_friction *= 0.1  # lower friction = longer slide

	var control = max(self.velocity.length(), ground_decel)
	var drop = control * applied_friction * delta
	var new_speed = max(self.velocity.length() - drop, 0.0)

	if self.velocity.length() > 0:
		new_speed /= self.velocity.length()

	self.velocity *= new_speed

	_headbob_effect(delta)

func _physics_process(delta):
	## handle fov and speedlines at high speeds
	if velocity.length() > 18:
		target_fov = sprint_fov
		target_line_density = 0.6
	elif velocity.length() > 12:
		target_fov = default_fov
		target_line_density = 0.4
	elif velocity.length() > 8:
		target_fov = default_fov
		target_line_density = 0.1
	else:
		target_fov = default_fov
		target_line_density = 0.0

	## smooth fov transition
	var current_fov: float = %Camera3D.fov
	%Camera3D.fov = lerp(current_fov, target_fov, delta * fov_speed)

	## smooth speed lines transition
	current_line_density = lerp(current_line_density, target_line_density, delta * line_transition_speed)
	$SpeedLines.material.set_shader_parameter("line_density", current_line_density)

	var input_dir = Input.get_vector("left", "right", "up", "down").normalized()
	wish_dir = self.global_transform.basis * Vector3(input_dir.x, 0., input_dir.y)

	if is_on_floor():
		if Input.is_action_just_pressed("jump") or (auto_bhop and Input.is_action_pressed("jump")):
			self.velocity.y = jump_velocity
		_handle_ground_physics(delta)
	else:
		_handle_air_physics(delta)
		
	move_and_slide()
