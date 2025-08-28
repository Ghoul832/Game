extends CharacterBody2D

@export var speed = 300
@export var gravity = 30
@export var jump_force = 300

# Wall slide settings
@export var wall_slide_speed = 80
@export var require_input_to_slide = true

@onready var ap = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var cshape = $CollisionShape2D
@onready var crouch_raycast_1 = $CrouchRayCast_1
@onready var crouch_raycast_2 = $CrouchRayCast_2
@onready var wall_raycast_left = $WallRayCast_Left
@onready var wall_raycast_right = $WallRayCast_Right
@onready var coyote_timer = $CoyoteTimer
@onready var jump_buffer_timer = $JumpBufferTimer
@onready var jump_height_timer = $JumpHeightTimer

var is_crouching = false
var stuck_under_object = false
var can_cayote_jump = false
var jump_buffered = false

var is_wall_sliding = false
var wall_dir = 0  # -1 left, 1 right

var standing_cshape = preload("res://resoucres/player_standing.tres")
var crouching_cshape = preload("res://resoucres/player_crouching.tres")


func _physics_process(delta):
	# gravity (don't apply while wall-sliding)
	if !is_on_floor() and (can_cayote_jump == false) and !is_wall_sliding:
		velocity.y += gravity
		if velocity.y > 1000:
			velocity.y = 1000

	# jump (start variable jump height timer)
	if Input.is_action_just_pressed("jump"):
		jump_height_timer.start()
		jump()

	# horizontal movement
	var horizontal_direction = Input.get_axis("move_left", "move_right")
	velocity.x = speed * horizontal_direction
	if horizontal_direction != 0:
		switch_direction(horizontal_direction)

	# crouch logic (unchanged)
	if Input.is_action_just_pressed("crouch"):
		crouch()
	elif Input.is_action_just_released("crouch"):
		if above_head_is_empty():
			stand()
		else:
			if not stuck_under_object:
				stuck_under_object = true
				print("player stuck")

	if stuck_under_object and above_head_is_empty():
		if not Input.is_action_just_pressed("crouch"):
			stand()
			stuck_under_object = false
			print("player was stuck")

	# floor transitions
	var was_on_floor = is_on_floor()
	move_and_slide()

	if was_on_floor and not is_on_floor() and velocity.y >= 0:
		can_cayote_jump = true
		coyote_timer.start()

	if not was_on_floor and is_on_floor():
		if jump_buffered:
			jump_buffered = false
			print("buffered jump")
			jump()

	# wall slide detection (after move_and_slide so collisions are accurate)
	update_wall_slide_state()
	update_animations(horizontal_direction)


# --- wall slide / detection ---
func update_wall_slide_state():
	# check raycasts (safe even if you forgot to add them; fallback to is_on_wall())
	var touching_left = false
	var touching_right = false
	if has_node("WallRayCast_Left"):
		touching_left = wall_raycast_left.is_colliding()
	if has_node("WallRayCast_Right"):
		touching_right = wall_raycast_right.is_colliding()

	var touching_wall = touching_left or touching_right or is_on_wall()
	var pushing_left = Input.is_action_pressed("move_left")
	var pushing_right = Input.is_action_pressed("move_right")

	var can_slide = not is_on_floor() and velocity.y >= 0 and touching_wall
	if require_input_to_slide:
		can_slide = can_slide and (pushing_left or pushing_right)

	if can_slide:
		# prefer direct raycast result; fallback to input or sprite facing
		if touching_left and not touching_right:
			wall_dir = -1
		elif touching_right and not touching_left:
			wall_dir = 1
		else:
			# fallback: prefer input direction
			if pushing_left and not pushing_right:
				wall_dir = -1
			elif pushing_right and not pushing_left:
				wall_dir = 1
			else:
				# last fallback: use velocity.x or sprite facing
				if velocity.x < 0:
					wall_dir = -1
				elif velocity.x > 0:
					wall_dir = 1
				else:
					if sprite.flip_h:
						wall_dir = -1
					else:
						wall_dir = 1

		is_wall_sliding = true

		# face the wall (mirrors sprite)
		switch_direction(wall_dir)

		# ensure a steady slow descent (fixes "stuck in mid-air" case)
		velocity.y = wall_slide_speed

		# optional: stop horizontal movement into the wall
		if sign(velocity.x) == wall_dir:
			velocity.x = 0
	else:
		is_wall_sliding = false
		wall_dir = 0


# --- jump (reuses normal jump anim) ---
func jump():
	if is_on_floor() or can_cayote_jump:
		velocity.y = -jump_force
		if can_cayote_jump:
			can_cayote_jump = false
			print("coyote jump")
	elif is_wall_sliding:
		# normal jump animation, push away from the wall
		var away = -wall_dir
		if wall_dir == 0:
			away = 1
		velocity.y = -jump_force
		velocity.x = speed * away
		is_wall_sliding = false
		wall_dir = 0
	else:
		if not jump_buffered:
			jump_buffered = true
			jump_buffer_timer.start()


# --- timers / helpers ---
func _on_coyote_timer_timeout():
	can_cayote_jump = false

func _on_jump_buffer_timer_timeout():
	jump_buffered = false

func _on_jump_height_timer_timeout():
	if not Input.is_action_pressed("jump"):
		if velocity.y < -100:
			velocity.y = -100
			print("short jump")

func above_head_is_empty() -> bool:
	return not crouch_raycast_1.is_colliding() and not crouch_raycast_2.is_colliding()

func update_animations(horizontal_direction):
	# wall slide priority
	if is_wall_sliding:
		ap.play("wall_slide1")
		return

	if is_on_floor():
		if horizontal_direction == 0:
			if is_crouching:
				ap.play("crouch")
			else:
				ap.play("idle")
		else:
			if is_crouching:
				ap.play("crouch_walk")
			else:
				ap.play("run")
	else:
		if velocity.y < 0:
			ap.play("jump")
		elif velocity.y > 0:
			ap.play("fall")

func switch_direction(dir):
	# dir: -1 left, 1 right
	sprite.flip_h = (dir == -1)
	sprite.position.x = dir * 4

func crouch():
	if is_crouching:
		return
	is_crouching = true
	cshape.shape = crouching_cshape
	cshape.position.y = -12

func stand():
	if not is_crouching:
		return
	is_crouching = false
	cshape.shape = standing_cshape
	cshape.position.y = -16
