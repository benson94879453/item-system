extends CharacterBody2D 
class_name BaseTower

# ============================================================
# 塔的基礎實體腳本（BaseTower）
#
# 職責：
#   1. 透過 setup(TowerData) 接收數值資料
#   2. 定時尋找範圍內的敵人並發射子彈
#   3. 承受傷害 / 死亡
# ============================================================

@onready var range_area: Area2D = %RangeArea
@onready var attack_timer: Timer = %AttackTimer

var data: TowerData       # 這座塔的靈魂資料
var current_target: Node2D = null
var current_health: float


func _ready() -> void:
	# 讓防禦塔貼上 "Attackable" 標籤，使敵人可以識別並攻擊它
	add_to_group("Attackable")


func setup(new_data: TowerData) -> void:
	data = new_data

	# 初始化生命值
	current_health = data.health

	# 根據攻擊速度設定計時器間隔（attack_speed = 每秒攻擊次數）
	if data.attack_speed > 0:
		attack_timer.wait_time = 1.0 / data.attack_speed

	# 動態設定偵測範圍（1 格 = 64 像素）
	var shape = CircleShape2D.new()
	shape.radius = data.attack_range * 64.0
	$RangeArea/CollisionShape2D.shape = shape

	attack_timer.start()


# ===== 受擊 / 死亡邏輯 =====
func take_damage(amount: float) -> void:
	current_health -= amount
	# TODO: 未來可加上受損閃爍特效或冒煙粒子
	if current_health <= 0:
		die()


func die() -> void:
	# TODO: 未來可播放倒塌粒子特效與音效
	queue_free()


# ===== 攻擊循環 =====
# 由 AttackTimer 的 timeout 訊號觸發
func _on_attack_timer_timeout() -> void:
	find_target()
	if current_target:
		shoot()


func find_target() -> void:
	var enemies = range_area.get_overlapping_bodies()
	if enemies.is_empty():
		current_target = null
		return

	# MVP 尋敵策略：優先打到陣列第一個
	# TODO: 未來可擴展為「打血量最少」、「打最接近終點」等策略
	current_target = enemies[0]


func shoot() -> void:
	# 防呆：確保此塔已設定子彈場景
	if data.projectile_scene == null:
		return

	# 1. 實例化子彈
	var proj = data.projectile_scene.instantiate()

	# 2. 先加入場景樹（必須在設定位置前），讓 _ready() 執行
	get_parent().add_child(proj)

	# 3. 設定子彈初始位置在塔的中心
	proj.global_position = self.global_position

	# 4. 讀取 ProjectileData 的數值（優先使用資料資源，否則套預設值）
	var proj_speed: float = 400.0
	var proj_pierce: int = 0

	if data.projectile_data != null:
		proj_speed = data.projectile_data.speed
		proj_pierce = data.projectile_data.pierce_count

		# 若 ProjectileData 有指定貼圖，套用到子彈的 Sprite2D
		if data.projectile_data.texture != null and proj.has_node("Sprite2D"):
			proj.get_node("Sprite2D").texture = data.projectile_data.texture

	# 5. 把目標、傷害、速度、穿透次數交接給子彈
	proj.setup(current_target, data.damage, proj_speed, proj_pierce)
