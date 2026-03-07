extends Area2D
class_name Projectile

# ============================================================
# 子彈實體腳本（Projectile）
# 職責：
#   1. 接收由塔傳入的目標、傷害、速度等參數
#   2. 每幀追蹤目標飛行
#   3. 命中敵人後造成傷害並視穿透次數決定是否銷毀
#   4. 目標消失 / 飛出畫面時自動清除，防止記憶體洩漏
# ============================================================

# --- 子節點引用 ---
@onready var sprite: Sprite2D = %Sprite2D
@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var screen_notifier: VisibleOnScreenNotifier2D = %VisibleOnScreenNotifier2D

# --- 飛行參數 ---
var target: Node2D        # 追蹤目標
var damage: float         # 攜帶的傷害值
var speed: float = 400.0  # 飛行速度（像素/秒）

# --- 穿透機制 ---
# pierce_count = 0 → 命中即銷毀（普通子彈）
# pierce_count = N → 最多再穿透 N 個敵人
var pierce_count: int = 0
var hit_targets: Array[Node2D] = []  # 已命中清單，防止對同一敵人重複傷害


func _ready() -> void:
	# 【訊號自連線】不依賴編輯器拖拉，場景更乾淨
	body_entered.connect(_on_body_entered)
	screen_notifier.screen_exited.connect(_on_screen_exited)


# ===== 公開 API：由「塔」在發射時呼叫 =====
# new_speed：可選，讓不同塔發射不同速度的子彈
# new_pierce：可選，穿透型子彈傳入 > 0 的數值
func setup(new_target: Node2D, new_damage: float, new_speed: float = 400.0, new_pierce: int = 0) -> void:
	target = new_target
	damage = new_damage
	speed = new_speed
	pierce_count = new_pierce


func _physics_process(delta: float) -> void:
	# 防呆：目標已死亡（節點被 queue_free），子彈自毀
	if not is_instance_valid(target):
		queue_free()
		return

	# 追蹤邏輯：朝目標方向勻速飛行
	var direction: Vector2 = global_position.direction_to(target.global_position)
	global_position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	# 穿透防呆：同一目標不重複傷害
	if body in hit_targets:
		return

	# 僅對有「受傷功能」的節點造成傷害
	if body.has_method("take_damage"):
		body.take_damage(damage)
		hit_targets.append(body)

		if pierce_count <= 0:
			# 普通子彈：命中即銷毀
			queue_free()
		else:
			# 穿透子彈：扣除一次穿透次數後繼續飛行
			pierce_count -= 1


func _on_screen_exited() -> void:
	# 防洩漏：子彈飛出畫面時自動銷毀
	queue_free()
