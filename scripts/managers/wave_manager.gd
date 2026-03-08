extends Node2D
class_name WaveManager

signal wave_started(wave_index: int)
signal wave_cleared(wave_index: int, reward: int)
signal all_waves_cleared

enum WaveState {
	WAITING,
	SPAWNING,
	COMBAT
}

@export var waves: Array[WaveData] = []
@export var enemy_scene: PackedScene
@export var target_node: Node2D 
@export var enemy_container: Node2D 
@export_group("Wave Generation")
@export var spawn_position: Vector2 = Vector2(50, 50)
@export var spawn_jitter_radius: float = 16.0  # 怪物出生點的隨機散佈半徑

var _current_wave_index: int = 0
var _current_state: WaveState = WaveState.WAITING

func _ready() -> void:
	if not target_node:
		push_warning("WaveManager: Target node (Base) not assigned!")

func _process(_delta: float) -> void:
	if _current_state == WaveState.COMBAT:
		_check_combat_end()

func start_next_wave() -> void:
	if _current_state != WaveState.WAITING:
		push_warning("WaveManager: Cannot start next wave (Status is not WAITING)")
		return
		
	if _current_wave_index >= waves.size():
		push_warning("WaveManager: All waves are already cleared.")
		return
		
	_current_state = WaveState.SPAWNING
	wave_started.emit(_current_wave_index)
	_spawn_wave_coroutine()

func _spawn_wave_coroutine() -> void:
	var current_wave: WaveData = waves[_current_wave_index]
	
	for spawn_data in current_wave.spawns:
		if spawn_data.delay_before_start > 0:
			await get_tree().create_timer(spawn_data.delay_before_start, false).timeout
			
		for i in range(spawn_data.spawn_count):
			_spawn_enemy(spawn_data.enemy_data)
			if spawn_data.spawn_interval > 0:
				await get_tree().create_timer(spawn_data.spawn_interval, false).timeout
	
	_current_state = WaveState.COMBAT

func _spawn_enemy(data: EnemyData) -> void:
	if not enemy_scene:
		return
		
	var enemy = enemy_scene.instantiate()
	
	# 產生隨機圓形偏移避免完全重疊
	var random_angle = randf() * TAU
	var random_radius = randf() * spawn_jitter_radius
	var offset = Vector2(cos(random_angle), sin(random_angle)) * random_radius
	
	enemy.global_position = spawn_position + offset
	enemy.add_to_group("Enemy")
	
	if enemy_container:
		enemy_container.add_child(enemy)
	else:
		get_tree().current_scene.add_child(enemy)
		
	if enemy.has_method("setup") and data:
		enemy.setup(data)
	else:
		push_warning("WaveManager: Enemy lacks setup() or enemy_data is null.")
	
	if target_node and enemy.has_method("set_target"):
		enemy.set_target(target_node.global_position)

func _check_combat_end() -> void:
	var has_alive_enemy: bool = false
	var enemies = get_tree().get_nodes_in_group("Enemy")
	
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			has_alive_enemy = true
			break
			
	if not has_alive_enemy:
		_end_wave()

func _end_wave() -> void:
	var reward = waves[_current_wave_index].wave_reward_money
	wave_cleared.emit(_current_wave_index, reward)
	GameManager.add_gold(reward)
	
	print("[WaveManager] Wave %d cleared! Reward: %d" % [_current_wave_index + 1, reward])
	
	_current_wave_index += 1
	_current_state = WaveState.WAITING
	
	if _current_wave_index >= waves.size():
		all_waves_cleared.emit()
		print("[WaveManager] All waves cleared! Victory!")
