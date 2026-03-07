# Tower & Projectile 數據來源表

## 一、數據層級概覽

```
ItemData (.gd / .tres)
  └─ TowerData (.gd / .tres)   ← 繼承 ItemData，加入塔專屬欄位
       └─ ProjectileData (.gd / .tres)   ← 被 TowerData 以欄位持有
```

| 執行階段 | 呼叫者 | 被呼叫者 | 傳遞方式 |
|---------|--------|---------|---------|
| 放置塔時 | 負責放塔的腳本（待實作） | `BaseTower.setup(TowerData)` | 傳入 `TowerData` Resource |
| 攻擊計時到時 | `BaseTower._on_attack_timer_timeout()` | `BaseTower.shoot()` | 內部呼叫 |
| 發射子彈時 | `BaseTower.shoot()` | `Projectile.setup(...)` | 傳入 4 個基本型別參數 |

---

## 二、TowerData 欄位數據來源

> **檔案**：[TowerData.gd](file:///c:/Users/benso/OneDrive/文件/GitHub/MiniDefenseGame/scripts/resources/TowerData.gd)  
> **繼承**：`ItemData` → `Resource`  
> **資料實例**：[first_tower.tres](file:///c:/Users/benso/OneDrive/文件/GitHub/MiniDefenseGame/data/towers/first_tower.tres)

| 欄位 | 型別 | 來源 | 說明 |
|------|------|------|------|
| `id` | `int` | `ItemData`（繼承） | 道具唯一編號，在 `.tres` 中編輯器填寫 |
| `name` | `String` | `ItemData`（繼承） | 道具名稱，在 `.tres` 中填寫 |
| `texture` | `Texture2D` | `ItemData`（繼承） | 道具圖示，在 `.tres` 中拖入圖片 |
| `max_stack` | `int` | `ItemData`（繼承） | 最大堆疊數，預設 64 |
| `description` | `String` | `ItemData`（繼承） | 描述文字，預設空字串 |
| `tower_scene` | `PackedScene` | `TowerData`（自身），`.tres` 填入 | 塔的實體場景（`.tscn`） |
| `projectile_scene` | `PackedScene` | `TowerData`（自身），`.tres` 填入 | 子彈場景（`.tscn`） |
| `projectile_data` | `ProjectileData` | `TowerData`（自身），`.tres` 填入 | 子彈數值資源（`.tres`） |
| `build_cost` | `int` | `TowerData`（自身），預設 50 | 建造費用 |
| `damage` | `float` | `TowerData`（自身），預設 10.0 | 每發傷害，由 `BaseTower.shoot()` 讀取傳給 Projectile |
| `attack_range` | `float` | `TowerData`（自身），預設 3.0 | 偵測半徑（格），由 `BaseTower.setup()` 算成 px 後設給 `CollisionShape2D` |
| `attack_speed` | `float` | `TowerData`（自身），預設 1.0 | 每秒攻擊次數，由 `BaseTower.setup()` 換算為 `Timer.wait_time` |
| `health` | `float` | `TowerData`（自身），預設 500.0 | 塔的生命值，由 `BaseTower.setup()` 初始化 `current_health` |

---

## 三、ProjectileData 欄位數據來源

> **檔案**：[ProjectileData.gd](file:///c:/Users/benso/OneDrive/文件/GitHub/MiniDefenseGame/scripts/resources/ProjectileData.gd)  
> **繼承**：`Resource`  
> **持有者**：`TowerData.projectile_data`

| 欄位 | 型別 | 來源 | 說明 |
|------|------|------|------|
| `id` | `String` | `.tres` 中填寫，預設 `"basic_bullet"` | 子彈識別碼 |
| `display_name` | `String` | `.tres` 中填寫，預設 `"普通子彈"` | 顯示名稱（未來 UI 用） |
| `texture` | `Texture2D` | `.tres` 中填入圖片，可為空 | 子彈貼圖，`BaseTower.shoot()` 讀取後套到 `Sprite2D` |
| `speed` | `float` | `.tres` 中填寫，預設 400.0 | 飛行速度，由 `BaseTower.shoot()` 讀取後傳給 `Projectile.setup()` |
| `pierce_count` | `int` | `.tres` 中填寫，預設 0 | 穿透次數，由 `BaseTower.shoot()` 讀取後傳給 `Projectile.setup()` |
| `homing_strength` | `float` | `.tres` 中填寫，預設 0.0 | 追蹤強度（**未實作**） |
| `lifetime` | `float` | `.tres` 中填寫，預設 5.0 | 最長存活秒（**未實作**） |

---

## 四、Projectile 實體接收的數據

> **檔案**：[projectile.gd](file:///c:/Users/benso/OneDrive/文件/GitHub/MiniDefenseGame/entities/projectiles/projectile.gd)  
> **場景**：[projectile.tscn](file:///c:/Users/benso/OneDrive/文件/GitHub/MiniDefenseGame/entities/projectiles/projectile.tscn)  
> **進入點**：`setup(new_target, new_damage, new_speed, new_pierce)`

| 成員變數 | 型別 | 誰傳入 | 傳入來源欄位 | 預設值 |
|---------|------|--------|------------|--------|
| `target` | `Node2D` | `BaseTower.shoot()` | `BaseTower.current_target`（`find_target()` 找到的敵人） | 無 |
| `damage` | `float` | `BaseTower.shoot()` | `TowerData.damage` | 無 |
| `speed` | `float` | `BaseTower.shoot()` | `ProjectileData.speed`（若無 `projectile_data` 則為 400.0） | 400.0 |
| `pierce_count` | `int` | `BaseTower.shoot()` | `ProjectileData.pierce_count`（若無 `projectile_data` 則為 0） | 0 |
| `hit_targets` | `Array[Node2D]` | Projectile 自身初始化 | — | `[]` |

---

## 五、BaseTower 內部狀態數據來源

> **檔案**：[base_tower.gd](file:///c:/Users/benso/OneDrive/文件/GitHub/MiniDefenseGame/entities/towers/base_tower.gd)

| 成員變數 | 型別 | 誰賦值 | 來源 |
|---------|------|--------|------|
| `data` | `TowerData` | `setup(new_data)` 呼叫者 | 外部傳入的 `TowerData` Resource |
| `current_health` | `float` | `setup()` 內部 | `data.health` |
| `current_target` | `Node2D` | `find_target()` | `range_area.get_overlapping_bodies()[0]` |

---

## 六、數據流全貌圖

```
[.tres 檔案（編輯器填寫）]
  TowerData (first_tower.tres)
    ├─ ItemData 欄位: id, name, texture, description, max_stack
    ├─ tower_scene     → PackedScene (.tscn)
    ├─ projectile_scene → PackedScene (projectile.tscn)
    ├─ projectile_data  → ProjectileData (.tres)
    │     ├─ speed, pierce_count  ──→ BaseTower.shoot() 讀取 ──→ Projectile.setup()
    │     └─ texture              ──→ BaseTower.shoot() 讀取 ──→ Sprite2D.texture
    ├─ damage          ──→ BaseTower.shoot() 讀取 ──→ Projectile.setup()
    ├─ attack_range    ──→ BaseTower.setup() 換算 ──→ CollisionShape2D.shape.radius
    ├─ attack_speed    ──→ BaseTower.setup() 換算 ──→ AttackTimer.wait_time
    └─ health          ──→ BaseTower.setup() 初始化 BaseTower.current_health

[場景樹執行時]
  BaseTower.find_target()
    └─ RangeArea.get_overlapping_bodies()[0] ──→ current_target (Node2D)
  
  BaseTower.shoot()
    └─ Projectile.setup(current_target, data.damage, proj_speed, proj_pierce)
```
