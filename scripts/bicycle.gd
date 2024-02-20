extends RigidBody3D

@export var bikers = []
@export var max_velocity = 1500
@export var friction = 0.8
@export var handling = 1000
@export var biker_offset = 2.5
@export var speedFactor = 0.025
var current_velocity = 0.0
var current_force = 0
var current_acc = 0
var current_lean = 0
var current_dir = 0
var biker_res = preload("res://gameobjects/biker.tscn")
var forward_vector = Vector3.ZERO
@export var group_factor = 0.8

# We display this on HUD, it's linear_velocity.length()
var speed = 0


# Called when the node enters the scene tree for the first time.
func _ready():
	reset()

func _physics_process(delta):
	apply_force(current_force * forward_vector)
	var turn = Vector3.ZERO
	turn.y = 10/(linear_velocity.length()+0.01)
	set_inertia(turn)
	var angular_force = Vector3.ZERO
	angular_force.y = current_lean
	apply_torque(angular_force)
	
	
var should_reset = false
func _integrate_forces(state):
	if should_reset:
		state.transform = get_node("../StartPosition").transform

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if !multiplayer.is_server():
		return
	
	if GlobalCrap.players.size() != bikers.size():
		resync_bikers.rpc()
		
	if get_node("../StartTimer").time_left > 0:
		# Tell others about new position so people but don't actually update it below
		update_bicycle.rpc(position, rotation, current_velocity)
		return
		
	forward_vector = get_global_transform().basis.z
	if Input.is_action_just_pressed("crash"):
		crash()
	current_lean = 0
	current_force = 0
	for biker in bikers:
		current_force += (biker.current_force/pow(bikers.size(),group_factor))
		current_lean += biker.current_lean/bikers.size()
	#if(current_force < 0):
		#current_force = 0
	#else:
		#current_force -= (current_force * (current_velocity/max_velocity))
	#if(current_acc < -100):
		#current_acc = -100
	#else:
		#current_acc -= 10
	#current_acc += current_force * delta
	#current_velocity += current_acc * delta
	#if(current_velocity < 0):
		#current_velocity = 0
	#position += current_velocity * forward_vector * delta * speedFactor
	#rotation.y += deg_to_rad(current_lean * delta * (current_velocity/handling))
	##current_velocity -= ((current_velocity * friction) + 10 + abs(current_lean)) * delta
	
	speed = linear_velocity.length()
	update_bicycle.rpc(position, rotation, linear_velocity.length())
	
@rpc("call_local")
func resync_bikers():
	for biker in bikers:
		# If you try queue_free instead of free, a newly created biker may have
		# a conflicting node name which throws a bunch of RPC errors
		biker.free()
	bikers = []
	var playerCount = GlobalCrap.players.size()
	add_bikers(playerCount)

@rpc
func update_bicycle(new_position, new_rotation, new_speed):
	position = new_position
	rotation = new_rotation
	speed = new_speed

func reset():
	position = get_node("../StartPosition").position
	rotation = get_node("../StartPosition").rotation
	should_reset = true
	current_velocity   = 0
	current_lean = 0
	current_force = 0
	speed = 0
	resync_bikers.rpc()

func add_bikers(amt):
	for i in amt:
		var biker_instance = biker_res.instantiate()
		if i == 0:
			biker_instance.is_front = true
		if i == amt-1:
			biker_instance.is_rear = true
		biker_instance.peer_id = GlobalCrap.players[i]
		var name = "Biker" + str(GlobalCrap.players[i])
		biker_instance.name = name
		
		add_child(biker_instance)
		
		# Don't set freeze true, it makes collisions (e.g. with end area) not work
		biker_instance.freeze = true
		
		var biker_pos = Vector3.ZERO
		biker_pos.z = -biker_offset * i
		biker_instance.position = biker_pos
		bikers.append(biker_instance)

func crash():
	var total_force = 0
	for biker in bikers:
		total_force += biker.current_force
	total_force = total_force/bikers.size()
	
	for biker in bikers:
		biker.top_level = true
		biker.freeze = false
		var randvect = Vector3.ZERO
		randvect.x = randf_range(-0.1,0.1)
		randvect.z = randf_range(-0.3,-0.6)
		randvect = randvect * (total_force) * 0.1
		randvect.y = randf_range(0.1,1)
		print(randvect)
		biker.apply_impulse(randvect)
		#biker.set_inertia(randvect)
		biker.apply_torque_impulse(randvect)
		
