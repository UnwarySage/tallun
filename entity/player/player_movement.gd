extends Node
# Adapted from the docs, and will need tweaking.
# sprint/fatigue, signals to drive viewbobbing
# https://docs.godotengine.org/en/stable/tutorials/3d/fps_tutorial/part_one.html


export var _subject : NodePath
var subject : KinematicBody

# These two look like constants, but are variables so they can be adjusted in settings
# TODO, setup configuration singleton
export var MOUSE_SENSITIVITY = 0.05
export var INVERT_MOUSE = -1

# These will become variables for faster tweaking
const GRAVITY :=  -38.8
const MAX_SPEED := 15.0
const ACCELERATION := 4.5
const DEACCELERATION := 10.0
const MAX_SLOPE_ANGLE = 30


# actual velocity, as of last frame
var velocity := Vector3.ZERO
# velocity being calculated this frame, as a normal vector
var desired_velocity := Vector3.ZERO

# not the actual camera, so we can implement camera shake separately
var camera_position : Spatial
# the parent of all things that should move "up and down" with the players view
var rotation_helper : Spatial

func _ready():
	subject = get_node(_subject)
	camera_position = get_parent().find_node("CameraRoot")
	rotation_helper = get_parent().find_node("RotationHelper")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	process_input(delta)
	process_movement(delta)


func _input(event):
	# if we have the mouse captured, and this is mouse motion
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# rotate the rotation helper on the "up down axis"
		rotation_helper.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY * INVERT_MOUSE))
		# and rotate the playerbody on the "left right" axis
		subject.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))
		
		# Now amend camera motion if neccesary
		var camera_rotation = rotation_helper.rotation_degrees
		camera_rotation.x = clamp(camera_rotation.x,-70,70)
		rotation_helper.rotation_degrees = camera_rotation

func process_input(delta)->void:
	desired_velocity = Vector3.ZERO
	
	# Get the look transform, so this is relative to it
	var cam_xform = camera_position.get_global_transform()
	# get the 2d input, relative to the plane the player stands on
	var input_movement_vector = Vector2()
	
	# standard input cancelling
	if Input.is_action_pressed("player_move_forward"):
		input_movement_vector.y += 1
	if Input.is_action_pressed("player_move_backward"):
		input_movement_vector.y -= 1
	if Input.is_action_pressed("player_strafe_left"):
		input_movement_vector.x -= 1
	if Input.is_action_pressed("player_strafe_right"):
		input_movement_vector.x += 1
		
	# Normalize the result
	input_movement_vector = input_movement_vector.normalized()
	
	# modify our desired velocity by adding the camera transform with inputs adjusting it
	desired_velocity += -cam_xform.basis.z * input_movement_vector.y
	desired_velocity += cam_xform.basis.x * input_movement_vector.x
	
	# capture/free the cursor
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	 

func process_movement(delta)->void:
	# Do not include gravity in player movement calculations
	desired_velocity.y = 0
	desired_velocity = desired_velocity.normalized()
	
	# do apply it to actual velocity
	velocity.y += delta * GRAVITY
	
	# get the horizontal components of last frame's velocity
	var horizontal_velocity = velocity
	horizontal_velocity.y = 0
	
	# make a copy of desired_velocity and scale it to be on the MAX_SPEED sphere
	var target = desired_velocity
	target *= MAX_SPEED
	
	# (de)acceleration to be applied this frame
	var accel = 0
	
	# decide which one it is based on whether our desired and actual velocities are alligned
	if desired_velocity.dot(horizontal_velocity) > 0:
		accel = ACCELERATION
	else:
		accel = DEACCELERATION
	
	# move our horizontal velocity by our desired velocity, respecting delta and accel
	horizontal_velocity = horizontal_velocity.linear_interpolate(target,accel * delta)
	# copy our horizontal velocity into actual velocity
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	# now actually carry out the movement, and record our new actual velocity, post collisions,etc.
	velocity = subject.move_and_slide(velocity,Vector3(0,1,0),0.05,4,deg2rad(MAX_SLOPE_ANGLE))
	
	
	
 
