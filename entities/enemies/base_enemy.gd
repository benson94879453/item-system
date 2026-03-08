extends Area2D
class_name BaseEnemy

## 子節點參照
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var hitbox_area: Area2D = $HitboxArea

@export var data: EnemyData 

@export_group("Jitter Settings")
@export var max_path_offset: float = 12.0      # 怪物偏離導航中線的最大距離
@export var speed_jitter_range: float = 0.10   # 速度擾動百分比 (±10%)

var _current_health: float
var _is_attacking: bool = false
var _target_building: Node2D = null
var _current_attack_cd: float = 0.0

var _actual_speed: float = 0.0
var _path_offset_scalar: float = 0.0

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
	
	# 設定 HitboxArea 的碰撞形狀（供偵測建築物）
	var hitbox_circle = CircleShape2D.new()
	hitbox_circle.radius = data.collision_radius
	$HitboxArea/CollisionShape2D.shape = hitbox_circle
	
	_current_health = data.max_health
	if data.texture:
		sprite.texture = data.texture
	
	# 關閉 NavigationAgent2D 的 avoidance（不需要避讓其他敵人）
	nav_agent.avoidance_enabled = false
	nav_agent.radius = data.collision_radius
	
	# Jitter: 速度擾動與路徑錯位
	var speed_multiplier = 1.0 + randf_range(-speed_jitter_range, speed_jitter_range)
	_actual_speed = data.speed * speed_multiplier
	_path_offset_scalar = randf_range(-max_path_offset, max_path_offset)
	
	# Z-index 排序：高威脅等級的怪物顯示在最上層
	z_index = data.threat_level

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
	
	# 計算正交向量 (垂直於前進方向) 以模擬偏左或偏右
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
	var offset_target: Vector2 = next_path_position + (perpendicular * _path_offset_scalar)
	
	# 朝著帶有偏移的目標前進
	var move_direction: Vector2 = global_position.direction_to(offset_target)
	global_position += move_direction * _actual_speed * delta

func _process_attack(delta: float) -> void:
	_current_attack_cd -= delta
	if _current_attack_cd <= 0.0:
		if _target_building.has_method("take_damage"):
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
