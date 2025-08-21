extends CharacterBody3D

class_name PlayerCharacter 

@export_group("Movement variables")
var moveSpeed : float
var moveAccel : float
var moveDeccel : float
var desiredMoveSpeed : float 
@export var desiredMoveSpeedCurve : Curve
@export var maxSpeed : float
@export var inAirMoveSpeedCurve : Curve
var inputDirection : Vector2 
var moveDirection : Vector3 
@export var hitGroundCooldown : float #amount of time the character keep his accumulated speed before losing it (while being on ground)
var hitGroundCooldownRef : float 
@export var bunnyHopDmsIncre : float #bunny hopping desired move speed incrementer
@export var autoBunnyHop : bool = false
var lastFramePosition : Vector3 
var lastFrameVelocity : Vector3
var wasOnFloor : bool
var walkOrRun : String = "WalkState" #keep in memory if play char was walking or running before being in the air
#for crouch visible changes
@export var baseHitboxHeight : float
@export var baseModelHeight : float
@export var heightChangeSpeed : float

@export_group("Crouch variables")
@export var crouchSpeed : float
@export var crouchAccel : float
@export var crouchDeccel : float
@export var continiousCrouch : bool = false #if true, doesn't need to keep crouch button on to crouch
@export var crouchHitboxHeight : float
@export var crouchModelHeight : float

@export_group("Walk variables")
@export var walkSpeed : float
@export var walkAccel : float
@export var walkDeccel : float

@export_group("Run variables")
@export var runSpeed : float
@export var runAccel : float 
@export var runDeccel : float 
@export var continiousRun : bool = false #if true, doesn't need to keep run button on to run

@export_group("Jump variables")
@export var jumpHeight : float
@export var jumpTimeToPeak : float
@export var jumpTimeToFall : float
@onready var jumpVelocity : float = (2.0 * jumpHeight) / jumpTimeToPeak
@export var jumpCooldown : float
var jumpCooldownRef : float 
@export var nbJumpsInAirAllowed : int 
var nbJumpsInAirAllowedRef : int 
var jumpBuffOn : bool = false
var bufferedJump : bool = false
@export var coyoteJumpCooldown : float
var coyoteJumpCooldownRef : float
var coyoteJumpOn : bool = false

@export_group("Gravity variables")
@onready var jumpGravity : float = (-2.0 * jumpHeight) / (jumpTimeToPeak * jumpTimeToPeak)
@onready var fallGravity : float = (-2.0 * jumpHeight) / (jumpTimeToFall * jumpTimeToFall)

@export_group("Keybind variables")
@export var moveForwardAction : String = ""
@export var moveBackwardAction : String = ""
@export var moveLeftAction : String = ""
@export var moveRightAction : String = ""
@export var runAction : String = ""
@export var crouchAction : String = ""
@export var jumpAction : String = ""

# NEW BEAM VARIABLES
@export_category("Beam Effect")
@export var gunMarker : Marker3D  # Assign your gun marker here!
@export var beamColor : Color = Color(1.0, 0.5, 0.0, 0.6)  # Semi-transparent orange
@export var beamWidth : float = 0.1
@export var beamGlowIntensity : float = 2.0
@export var enableBeamParticles : bool = true
@export var deformSpeed : float = 3.0
@export var deformStrength : float = 0.1
var beam_time : float = 0.0  # Custom timer for beam animation

#references variables
@onready var camHolder : Node3D = $CameraHolder
@onready var model : MeshInstance3D = $Model
@onready var hitbox : CollisionShape3D = $Hitbox
@onready var stateMachine : Node = $StateMachine
@onready var hud : CanvasLayer = $HUD
@onready var ceilingCheck : RayCast3D = $Raycasts/CeilingCheck
@onready var floorCheck : RayCast3D = $Raycasts/FloorCheck
@onready var camera = $CameraHolder/Camera
@onready var timer: Timer = $Timer

# NEW BEAM REFERENCES
var beamMesh : MeshInstance3D
var beamMaterial : ShaderMaterial
var beamParticles : GPUParticles3D
var beamShader : Shader

@export_category("Scoring System")
@export var scoreZone : Area3D  # Assign your scoring area
@export var boxSpawnPoint : Marker3D  # Where boxes respawn
@export var scoreSound : AudioStreamPlayer3D  # Optional sound effect
@export var currentScore : int = 0
var scoredObjects : Array[RigidBody3D] = []  # Track what we've scored

@export_category("Holding Objects")
@export var ThrowForce = 1.0
@export var FollowSpeed = 4.0
@export var FollowDistance = 3.0
@export var MaxDistanceFromCamera = 7.0
@export var dropBelowPlayer = false
@export var GroundRay : RayCast3D

@onready var interactRay = $CameraHolder/Camera/InteractRay
var heldObject : RigidBody3D

func _ready():
	setup_beam_effect()
	setup_scoring_system()
	#set move variables, and value references
	moveSpeed = walkSpeed
	moveAccel = walkAccel
	moveDeccel = walkDeccel
	
	hitGroundCooldownRef = hitGroundCooldown
	jumpCooldownRef = jumpCooldown
	nbJumpsInAirAllowedRef = nbJumpsInAirAllowed
	coyoteJumpCooldownRef = coyoteJumpCooldown

func setup_scoring_system():
	# Connect to score zone if assigned
	if scoreZone:
		# Make sure the Area3D is set up correctly
		scoreZone.monitoring = true
		scoreZone.monitorable = true
		
		# Connect the body_entered signal to our scoring function
		if not scoreZone.body_entered.is_connected(_on_score_zone_entered):
			scoreZone.body_entered.connect(_on_score_zone_entered)
		print("Scoring system initialized! Current score: ", currentScore)
		print("Score zone monitoring: ", scoreZone.monitoring)
	else:
		print("Warning: Score Zone not assigned! Please assign an Area3D in the inspector.")

func _on_score_zone_entered(body: Node3D):
	print("Something entered score zone: ", body.name, " (Type: ", body.get_class(), ")")
	
	# Check if the body is a RigidBody3D
	if body is RigidBody3D:
		print("Detected RigidBody3D: ", body.name)
		score_object(body as RigidBody3D)
	else:
		print("Object is not a RigidBody3D, ignoring.")

func score_object(body: RigidBody3D):
	print("Attempting to score object: ", body.name)
	
	# Prevent scoring the same object multiple times quickly
	if body in scoredObjects:
		print("Object already scored recently, ignoring.")
		return
	
	# Add to scored objects temporarily
	scoredObjects.append(body)
	
	# Remove from scored objects after a short delay to prevent double-scoring
	get_tree().create_timer(0.5).timeout.connect(func(): scoredObjects.erase(body))
	
	# Increase score
	currentScore += 1
	print("SCORE! Current score: ", currentScore)
	
	# Play sound effect if assigned
	if scoreSound:
		scoreSound.play()
	
	# If this was the held object, drop it from gravity gun
	if body == heldObject:
		print("Dropping held object from gravity gun")
		drop_held_object()
	
	# Respawn the object at spawn point
	if boxSpawnPoint:
		respawn_object(body)
	else:
		print("Warning: Box Spawn Point not assigned! Object will not respawn.")

func respawn_object(body: RigidBody3D):
	print("Respawning object: ", body.name)
	
	# Stop the object's movement
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	
	# Move to spawn point
	body.global_position = boxSpawnPoint.global_position
	body.global_rotation = boxSpawnPoint.global_rotation
	
	print("Object moved to spawn position: ", boxSpawnPoint.global_position)
	
	# Optional: Add a little upward velocity so it doesn't spawn inside the ground
	body.linear_velocity = Vector3(0, 2, 0)
	
	print("Object respawned successfully!")

func setup_beam_effect():
	# Check if gun marker is assigned
	if not gunMarker:
		print("Warning: Gun Marker not assigned! Please assign a Marker3D in the inspector.")
		return
	
	# Create beam mesh (cylinder)
	beamMesh = MeshInstance3D.new()
	var cylinderMesh = CylinderMesh.new()
	cylinderMesh.height = 1.0  # Will be scaled dynamically
	cylinderMesh.top_radius = beamWidth
	cylinderMesh.bottom_radius = beamWidth
	cylinderMesh.radial_segments = 16  # More segments for better deformation
	cylinderMesh.rings = 10  # More rings for smoother deformation
	beamMesh.mesh = cylinderMesh
	
	# Create custom shader for deformation effect
	create_beam_shader()
	
	# Create shader material
	beamMaterial = ShaderMaterial.new()
	beamMaterial.shader = beamShader
	beamMaterial.set_shader_parameter("beam_color", beamColor)
	beamMaterial.set_shader_parameter("emission_intensity", beamGlowIntensity)
	beamMaterial.set_shader_parameter("time", 0.0)
	beamMaterial.set_shader_parameter("deform_speed", deformSpeed)
	beamMaterial.set_shader_parameter("deform_strength", deformStrength)
	beamMesh.material_override = beamMaterial
	
	# Add to scene but hide initially
	add_child(beamMesh)
	beamMesh.visible = false
	
	# Create particle effect for extra glow
	if enableBeamParticles:
		beamParticles = GPUParticles3D.new()
		setup_beam_particles()
		add_child(beamParticles)
		beamParticles.visible = false

func create_beam_shader():
	beamShader = Shader.new()
	var shader_code = """
shader_type spatial;
render_mode blend_add, depth_draw_opaque, depth_test_disabled, diffuse_burley, specular_schlick_ggx, unshaded;

uniform vec4 beam_color : source_color = vec4(1.0, 0.5, 0.0, 0.6);
uniform float emission_intensity : hint_range(0.0, 10.0) = 2.0;
uniform float time : hint_range(0.0, 100.0) = 0.0;
uniform float deform_speed : hint_range(0.1, 10.0) = 3.0;
uniform float deform_strength : hint_range(0.0, 1.0) = 0.1;

varying vec3 world_vertex;
varying vec3 local_vertex;

void vertex() {
	local_vertex = VERTEX;
	
	// Normalize Y position: cylinder goes from -0.5 to +0.5
	// We want: -0.5 = gun end (no deformation), +0.5 = target end (max deformation)
	float distance_factor = (local_vertex.y + 0.5); // Now 0.0 at gun, 1.0 at target
	
	// IMPORTANT: Only deform vertices, the mesh position stays locked to gun marker
	// Create wavy deformation that ONLY affects the target end
	float wave1 = sin(time * deform_speed + local_vertex.y * 5.0) * deform_strength * distance_factor * distance_factor;
	float wave2 = cos(time * deform_speed * 1.3 + local_vertex.y * 3.0 + 1.57) * deform_strength * 0.7 * distance_factor * distance_factor;
	
	// Apply deformation to X and Z only - this moves vertices but not the mesh origin
	VERTEX.x += wave1;
	VERTEX.z += wave2;
	
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// No pulsing - constant intensity
	
	// Create subtle gradient - slightly brighter at gun end, consistent orange throughout
	float distance_factor = (local_vertex.y + 0.5);
	float gradient = 1.0 - distance_factor * 0.1; // Very subtle fade
	
	// Consistent orange color
	vec4 final_color = beam_color * emission_intensity * gradient;
	
	ALBEDO = final_color.rgb;
	EMISSION = final_color.rgb;
	ALPHA = beam_color.a; // Use the alpha from beam_color for consistent transparency
}
"""
	
	beamShader.code = shader_code

func setup_beam_particles():
	if not beamParticles:
		return
		
	# Create process material
	var processMaterial = ParticleProcessMaterial.new()
	processMaterial.direction = Vector3(0, 1, 0)  # Along cylinder height
	processMaterial.spread = 20.0
	processMaterial.initial_velocity_min = 0.2
	processMaterial.initial_velocity_max = 0.8
	processMaterial.gravity = Vector3(0, 0, 0)
	processMaterial.scale_min = 0.05
	processMaterial.scale_max = 0.15
	processMaterial.color = beamColor
	
	# Use the beam mesh as emission shape
	processMaterial.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	processMaterial.emission_box_extents = Vector3(beamWidth, 0.5, beamWidth)
	
	beamParticles.process_material = processMaterial
	beamParticles.amount = 100
	beamParticles.lifetime = 1.5
	beamParticles.visibility_aabb = AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20))
	
	# Create a simple quad mesh for particles with emissive material
	var particleMesh = QuadMesh.new()
	particleMesh.size = Vector2(0.05, 0.05)
	
	var particleMaterial = StandardMaterial3D.new()
	particleMaterial.albedo_color = beamColor
	particleMaterial.emission = beamColor
	particleMaterial.emission_energy = 2.0
	particleMaterial.flags_transparent = true
	particleMaterial.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particleMaterial.flags_unshaded = true
	
	beamParticles.draw_pass_1 = particleMesh
	beamParticles.material_override = particleMaterial

func update_beam_effect(delta: float):
	if not heldObject or not beamMesh or not gunMarker:
		hide_beam()
		return
	
	# Show beam
	beamMesh.visible = true
	if beamParticles:
		beamParticles.visible = true
		beamParticles.emitting = true
	
	# Get positions
	var gunPos = gunMarker.global_position
	var objectPos = heldObject.global_position
	var distance = gunPos.distance_to(objectPos)
	var direction = (objectPos - gunPos).normalized()
	
	# CRITICAL FIX: Position the beam so its bottom (-0.5 Y) is EXACTLY at gun marker
	# Instead of centering the beam, we offset it so the gun end stays fixed
	var beam_center = gunPos + (direction * distance * 0.5)
	
	# Create the transform
	var up_vector = Vector3.UP
	if abs(direction.dot(Vector3.UP)) > 0.99:
		up_vector = Vector3.FORWARD
	
	var beam_transform = Transform3D()
	beam_transform.origin = beam_center
	beam_transform = beam_transform.looking_at(beam_center + direction, up_vector)
	beam_transform = beam_transform * Transform3D(Basis(Vector3.RIGHT, PI/2), Vector3.ZERO)
	
	# Apply transform and scale
	beamMesh.global_transform = beam_transform
	beamMesh.scale = Vector3(1, distance, 1)
	
	# The key insight: The mesh positioning makes the gun end stay at gunPos
	# because we're scaling from center, so -0.5 * distance puts gun end at right spot
	
	# Update particles to match
	if beamParticles:
		beamParticles.global_transform = beam_transform  
		beamParticles.scale = Vector3(1, distance, 1)
		var processMaterial = beamParticles.process_material as ParticleProcessMaterial
		if processMaterial:
			processMaterial.emission_box_extents = Vector3(beamWidth, distance * 0.5, beamWidth)
	
	# Only update time for deformation
	beam_time += delta
	if beamMaterial:
		beamMaterial.set_shader_parameter("time", beam_time)

func hide_beam():
	if beamMesh:
		beamMesh.visible = false
	if beamParticles:
		beamParticles.visible = false
		beamParticles.emitting = false

func set_held_object(body):
	if body is RigidBody3D and timer.is_stopped():
		heldObject = body
	else:
		pass #play sound effect or smth

func drop_held_object():
	heldObject = null
	hide_beam()

func throw_held_object():
	var obj = heldObject
	drop_held_object()
	obj.apply_central_impulse(-camera.global_transform.basis.z * ThrowForce * 10)

func handle_holding_objects():
	if Input.is_action_just_pressed("throw"):
		if heldObject != null: 
			throw_held_object()
			if timer.is_stopped(): timer.start()
	if Input.is_action_just_pressed("interact"):
		if heldObject != null: 
			drop_held_object()
			if timer.is_stopped(): timer.start()
	elif interactRay.is_colliding(): 
		set_held_object(interactRay.get_collider())
		
	if heldObject != null:
		var targetPos = camera.global_transform.origin + (camera.global_basis * Vector3(0, 0, -FollowDistance))
		var objectPos = heldObject.global_transform.origin
		heldObject.linear_velocity = (targetPos - objectPos) * FollowSpeed
		if heldObject.global_position.distance_to(camera.global_position) > MaxDistanceFromCamera:
			drop_held_object()
		if dropBelowPlayer && GroundRay.is_colliding():
			if GroundRay.get_collider() == heldObject: 
				drop_held_object()
	
func _process(delta: float):
	displayProperties()
	update_beam_effect(delta)  # NEW: Update beam every frame
	
func _physics_process(_delta : float):
	modifyPhysicsProperties()
	handle_holding_objects()
	
	move_and_slide()
	
func displayProperties():
	#display properties on the hud
	if hud != null:
		hud.displayCurrentState(stateMachine.currStateName)
		hud.displayDesiredMoveSpeed(desiredMoveSpeed)
		hud.displayVelocity(velocity.length())
		hud.displayNbJumpsInAirAllowed(nbJumpsInAirAllowed)
		# Display current score - only if HUD has the method
		if hud.has_method("displayScore"):
			hud.displayScore(currentScore)
		else:
			# Print score to console instead if HUD doesn't support it
			if currentScore > 0:
				print("Score: ", currentScore)
		
func modifyPhysicsProperties():
	lastFramePosition = position #get play char position every frame
	lastFrameVelocity = velocity #get play char velocity every frame
	wasOnFloor = !is_on_floor() #check if play char was on floor every frame
	
func gravityApply(delta : float):
	#if play char goes up, apply jump gravity
	#otherwise, apply fall gravity
	if velocity.y >= 0.0: velocity.y += jumpGravity * delta
	elif velocity.y < 0.0: velocity.y += fallGravity * delta
