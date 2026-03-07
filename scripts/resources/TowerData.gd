extends ItemData
class_name TowerData

# ============================================================
# 塔的數據資源（TowerData）
# 繼承自 ItemData，使現有背包系統可直接作為「建築選單」使用。
# ============================================================

@export var tower_scene: PackedScene           # 這座塔對應的實體場景
@export var projectile_scene: PackedScene      # 這座塔要發射的子彈場景
@export var projectile_data: ProjectileData    # 子彈的數值資料（速度、穿透等）

@export var build_cost: int = 50               # 建造費用
@export var damage: float = 10.0              # 每發子彈的基礎傷害值
@export var attack_range: float = 3.0         # 攻擊範圍（單位：格，1格=64px）
@export var attack_speed: float = 1.0         # 攻擊速度（每秒攻擊次數）
@export var health: float = 500.0             # 塔的生命值
