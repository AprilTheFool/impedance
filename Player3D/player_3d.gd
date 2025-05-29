extends CharacterBody3D

# camera vars
@export_group("Camera")

# mouse sens
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25

# movement vars
@export_group("Movement")
@export var move_speed := 8.0
@export var acceleration := 20.0
@export var rotation_speed := 12.0
@export var jump_impulse := 12.0

var _camera_input_direction := Vector2.ZERO
var _last_movement_direction := Vector3.BACK
var _gravity := -30.0

@onready var _camera_pivot: Node3D = %CameraPivot
@onready var _camera: Camera3D = %Camera3D
@onready var _skin: SophiaSkin = %SophiaSkin

# capture mouse on lmb
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# release mouse cursor on esc
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	var is_camera_motion := (
		# check if mouse is captured by game window
		event is InputEventMouseMotion and
		Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	)
	if is_camera_motion:
		_camera_input_direction = event.screen_relative * mouse_sensitivity


func _physics_process(delta: float) -> void:
	# pivot camera on x axis using CameraPivot node
	_camera_pivot.rotation.x += _camera_input_direction.y * delta
	# clamp camera rotation on x axis to prevent flipping view angle past 180deg
	_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, -PI / 6.0, PI / 3.0)
	#pivot camera on y axis using CameraPivot node
	_camera_pivot.rotation.y -= _camera_input_direction.x * delta
	
	#reset camera pivot speed each frame to stop movement when not moving the mouse
	_camera_input_direction = Vector2.ZERO
	
	# get movement input key (set in project > settings > input map)
	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# moon rune math, essentially setting a direction basis to calculate movement directions relative to the camera,
	# similar to switching gizmo to 'local' in blender
	var forward := _camera.global_basis.z
	var right := _camera.global_basis.x
	var move_direction := forward * raw_input.y + right * raw_input.x
	move_direction.y = 0.0
	move_direction = move_direction.normalized()
	
	var y_velocity := velocity.y
	velocity.y = 0.0
	# calculate base horizontal velocity using move speed & acceleration * move direction
	velocity = velocity.move_toward(move_direction * move_speed, acceleration * delta)
	# calculate and apply vertical velocity
	velocity.y = y_velocity + _gravity * delta
	
	var is_starting_jump := Input.is_action_pressed("jump") and is_on_floor()
	if is_starting_jump:
		velocity.y += jump_impulse
	
	move_and_slide()
	
	# store last movement direction to prevent animations resetting when key released
	if move_direction.length() > 0.2:
		_last_movement_direction = move_direction
	var target_angle := Vector3.BACK.signed_angle_to(_last_movement_direction, Vector3.UP)
	_skin.global_rotation.y = lerp_angle(_skin.rotation.y, target_angle, rotation_speed * delta)
	
	# switch between run and idle animations based on velocity
	var ground_speed := velocity.length()
	if ground_speed > 0.0:
		_skin.move()
	else:
		_skin.idle()
	
	
	
	
	
