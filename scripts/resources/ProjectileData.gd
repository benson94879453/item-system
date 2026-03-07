extends Resource
class_name ProjectileData

# ============================================================
# 子彈數據資源（ProjectileData）
#
# 遵循「靈魂（Resource）與肉體（Node）分離」原則。
# 企劃可在編輯器中建立 .tres 檔設定不同子彈種類，
# 再將其指派給 TowerData.projectile_data。
# ============================================================

@export var id: String = "basic_bullet"           # 子彈唯一識別碼
@export var display_name: String = "普通子彈"      # 顯示名稱（供未來 UI 使用）
@export var texture: Texture2D                     # 子彈外觀貼圖（可為空，代表白色預設圓點）

@export_group("飛行數值")
@export var speed: float = 400.0                   # 飛行速度（像素/秒）
@export var pierce_count: int = 0                  # 穿透次數（0=普通子彈、N=至多穿透 N 個）

@export_group("擴展備用（未實作）")
@export var homing_strength: float = 0.0           # 追蹤強度（0=直線飛行，>0=加強鎖定）
@export var lifetime: float = 5.0                  # 最長存活秒數（超時自動銷毀）
