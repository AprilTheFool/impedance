extends CharacterBody3D

@export_group("Camera")

# mouse sens
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25

var _camera_input_direction := Vector2.ZERO

@onready var _camera_pivot: Node3D = %CameraPivot

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
