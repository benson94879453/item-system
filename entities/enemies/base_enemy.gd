extends Area2D
class_name BaseEnemy

## 子節點參照
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hitbox_area: Area2D = $HitboxArea
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

@export var data: EnemyData 

var _actual_speed: float = 0.0

var _current_health: float
var _is_attacking: bool = false
var _target_building: Node2D = null
var _current_attack_cd: float = 0.0


func _ready() -> void:
	add_to_group("Enemy")
	# HitboxArea 偵測碰觸到建築物（Tower / Base，layer = bit 3）
	hitbox_area.body_entered.connect(_on_hitbox_body_entered)
	hitbox_area.body_exited.connect(_on_hitbox_body_exited)

func setup(new_data: EnemyData) -> void:
	data = new_data
	
	# 設定根節點的碰撞形狀（供 Tower RangeArea 和 Projectile 偵測）
	var circle = CircleShape2D.new()
	circle.radius = data.collision_radius
	collision_shape.shape = circle
	
	# 設定 HitboxArea 的碰撞形狀（供偵測建築物，範圍稍微大一點以確保提早觸發攻擊並停止移動）
	var hitbox_circle = CircleShape2D.new()
	hitbox_circle.radius = data.collision_radius + 4.0
	$HitboxArea/CollisionShape2D.shape = hitbox_circle
	
	_current_health = data.max_health
	if data.texture:
		sprite.texture = data.texture
	
	_actual_speed = data.speed
	
	# 設定 NavigationAgent2D 參數
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 16.0
	nav_agent.avoidance_enabled = true
	nav_agent.radius = data.collision_radius
	
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	
	# Z-index 排序：高威脅等級的怪物顯示在最上層，並加上基數確保蓋過所有建築物 (預設 Z-index 0)
	z_index = 10 + data.threat_level

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
	
func set_target(target_pos: Vector2) -> void:
	if not is_inside_tree(): 
		await ready 
	
	nav_agent.target_position = target_pos

func _physics_process(delta: float) -> void:
	if not data:
		return
		
	if _is_attacking:
		if nav_agent.avoidance_enabled:
			nav_agent.set_velocity(Vector2.ZERO)
		
		if is_instance_valid(_target_building):
			_process_attack(delta)
			return
		else:
			_is_attacking = false
			_target_building = null
			# 塔被打爆了，重新計算路徑 (假設主堡還在)
			var base = get_tree().get_first_node_in_group("Base")
			if base:
				set_target(base.global_position)
			
	if nav_agent.is_navigation_finished():
		_on_reach_base()
		return
		
	var next_path_position: Vector2 = nav_agent.get_next_path_position()
	var new_velocity: Vector2 = global_position.direction_to(next_path_position) * _actual_speed
	
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(new_velocity)
	else:
		_on_velocity_computed(new_velocity)

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	global_position += safe_velocity * get_physics_process_delta_time()

func _process_attack(delta: float) -> void:
	_current_attack_cd -= delta
	if _current_attack_cd <= 0.0:
		if _target_building and _target_building.has_method("take_damage"):
			_target_building.take_damage(data.attack_power)
		_current_attack_cd = data.attack_speed

## HitboxArea 偵測到碰觸建築物（取代原本 get_slide_collision 的邏輯）
func _on_hitbox_body_entered(body: Node2D) -> void:
	if _is_attacking:
		return
	if body and body.is_in_group("Attackable"):
		_is_attacking = true
		_target_building = body
		_current_attack_cd = 0.0

## 當離開建築物範圍時，若目標剛好是離開的那個，則重置攻擊狀態
func _on_hitbox_body_exited(body: Node2D) -> void:
	if body == _target_building:
		_is_attacking = false
		_target_building = null

func _on_reach_base() -> void:
	var base = get_tree().get_first_node_in_group("Base")
	if base and base.is_in_group("Attackable"):
		_is_attacking = true
		_target_building = base
		_current_attack_cd = 0.0
