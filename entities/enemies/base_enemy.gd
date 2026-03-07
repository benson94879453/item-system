extends CharacterBody2D
class_name BaseEnemy

@onready var sprite: Sprite2D = %Sprite2D
@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var nav_agent: NavigationAgent2D = %NavigationAgent2D

@export var data: EnemyData 

var _current_health: float
var _is_attacking: bool = false
var _target_building: Node2D = null
var _current_attack_cd: float = 0.0

func _ready() -> void:
	add_to_group("Enemy")

func setup(new_data: EnemyData) -> void:
	data = new_data
	
	var circle = CircleShape2D.new()
	circle.radius = data.collision_radius
	collision_shape.shape = circle
	
	_current_health = data.max_health
	if data.texture:
		sprite.texture = data.texture
	
	nav_agent.avoidance_enabled = true
	nav_agent.radius = data.collision_radius
	if not nav_agent.velocity_computed.is_connected(_on_velocity_computed):
		nav_agent.velocity_computed.connect(_on_velocity_computed)

func take_damage(amount: float) -> void:
	_current_health -= amount
	if _current_health <= 0:
		die()

func die() -> void:
	_drop_reward()
	queue_free()

func _drop_reward() -> void:
	if data and data.reward_item:
		GameManager.give_reward(data.reward_item, data.reward_amount)
	
func _physics_process(delta: float) -> void:
	if not data:
		return
		
	if _is_attacking:
		if is_instance_valid(_target_building):
			_process_attack(delta)
			return
		else:
			_is_attacking = false
			_target_building = null
			
	if nav_agent.is_navigation_finished():
		_on_reach_base()
		return

	var next_path_position: Vector2 = nav_agent.get_next_path_position()
	var direction: Vector2 = global_position.direction_to(next_path_position)
	nav_agent.velocity = direction * data.speed

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	if _is_attacking:
		return
	velocity = safe_velocity
	move_and_slide()
	_check_tower_collision()

func _process_attack(delta: float) -> void:
	_current_attack_cd -= delta
	if _current_attack_cd <= 0.0:
		if _target_building.has_method("take_damage"):
			_target_building.take_damage(data.attack_power)
		_current_attack_cd = data.attack_speed

func _check_tower_collision() -> void:
	if _is_attacking:
		return
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider and collider.is_in_group("Attackable"):
			_is_attacking = true
			_target_building = collider
			_current_attack_cd = 0.0
			break

func set_target(target_pos: Vector2) -> void:
	if not is_inside_tree(): 
		await ready 
	nav_agent.target_position = target_pos

func _on_reach_base() -> void:
	var base = get_tree().get_first_node_in_group("Base")
	if base and base.is_in_group("Attackable"):
		_is_attacking = true
		_target_building = base
		_current_attack_cd = 0.0
