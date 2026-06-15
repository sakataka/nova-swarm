# Nova Swarm 修正指示書（音量バグ・ゲームプレイバグ・UI 改善）

この文書は、Nova Swarm（Godot 4.6 / GDScript 製シューティングゲーム）に対する修正作業の指示書である。
事前調査で原因特定済みの問題と、その修正方法を記載する。**この文書だけで作業が完結するように書いてあるため、外部の会話コンテキストは不要。**

---

## 0. 前提

### プロジェクト概要

- Godot 4.6（GL Compatibility）。メインシーンは `scenes/main.tscn`（`scripts/game.gd` = `GameController` をアタッチした Node2D 1 個だけのシーン）。
- 描画はすべて `_draw()` の即時描画（`draw_rect` / `draw_string` / `draw_texture_rect_region` など）。**Control ノードは使っていない。この方式を維持すること。**
- ゲームロジックは RefCounted のサブシステム（`player.gd`, `enemy_swarm.gd`, `projectile_manager.gd`, `boss_controller.gd`, `ai_pilot.gd`, `hud.gd`）に分割され、`game.gd` が束ねる。調整値は `scripts/game_config.gd` に集約。
- 音声は `scripts/audio_manager.gd`。BGM は WAV ループ（`public/assets/audio/music/*.wav`）を 2 個の `AudioStreamPlayer` でクロスフェード再生（Resonate アドオンは `USE_RESONATE_MUSIC = false` で現在不使用。Resonate 側のコードパスは壊さないこと）。SFX は実行時生成の波形を 10 個のプレイヤーで再生。

### 実行・検証コマンド

```bash
# 構文チェック（全スクリプト変更後に必ず実行）
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --check-only --script res://scripts/game.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --check-only --script res://scripts/audio_manager.gd

# スモークテスト・ゲームプレイテスト（headless）
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://scripts/smoke_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://scripts/gameplay_test.gd

# 実機確認（音の確認は headless では不可能。必ずこれで行う）
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

注意: headless 実行時は `audio_manager.gd` の `_enabled` が false になり音声処理が無効化される。**音量関連の修正はテストコードでは検証できないので、実機起動して耳で確認すること。**

### コーディング規約・制約

- インデントはタブ。既存コードのスタイル（`snake_case`、型付き変数 `:=`、push_warning など）に合わせる。
- **formatter / format check / import sort の新規導入・設定追加・実行は禁止。**
- 機能の追加・変更をしたら同じ変更内で `README.md` を更新し、作業完了後にコミット・プッシュする（リポジトリの `AGENTS.md` 準拠）。
- **世界観の維持が最重要要件。** 本作はネオンアーケード STG。UI の配色は既存トークンに揃えること:
  - シアン `#49dfff` / `#72eaff` / `#7df7ff`（通常・情報）
  - マゼンタ `#ff7af0` / `#ff5ff0`（アクセント・操作ガイド）
  - イエロー `#fff06a` / `#ffef8b`（選択中・強調・スコア）
  - パネル地 `Color(0.02, 0.06, 0.12, α)`、枠線は `draw_rect(..., false, 1.0〜2.0)` の細枠
  - 数字はピクセルフォント風の自前描画（`hud.gd` の `_draw_digits` + `game_config.gd` の `DIGIT_MAP`）
- **新規画像アセットは作らない。** 既存の `public/assets/ui_atlas.png`（`game.gd` の `ui_regions` に領域定義あり: logo / life / bomb / shield / banner / ending）等を流用する。

### 作業順序

Part A（音量バグ）→ Part B（ゲームプレイバグ）→ Part C（UI 改善）の順で行う。各 Part 完了ごとに構文チェック + 2 つの headless テストを通すこと。

---

## Part A: 音量バグ修正（最優先）

報告されている症状: **「プレイ中、たまに音が急に大きくなる」**。調査の結果、以下 A1〜A6 の複合要因と特定した。すべて `scripts/audio_manager.gd`（一部 `scripts/game.gd`）の修正。

### A1. ダック解除時に BGM 音量が瞬時に +8dB ジャンプする

- **場所**: `scripts/audio_manager.gd` の `_apply_music_volume()`（284 行付近）
- **原因**: ポーズ解除時・アップグレード確定時に `set_music_ducked(false)` が呼ばれると、`_apply_music_volume()` がアクティブな BGM プレイヤーの `volume_db` を -38（duck）から -30（通常）へ**補間なしで即時代入**する。これが「急に音が大きくなる」の主因。
- **修正**: 即時代入をやめ、短い Tween（0.25 秒程度）で目標音量へ遷移させる。
  - メンバ変数 `var _volume_tween: Tween` を追加。
  - `_apply_music_volume()` 内のアクティブプレイヤーへの代入を、既存 Tween を kill してから `create_tween().tween_property(active_player, "volume_db", volume, 0.25)` に置き換える。
  - オーバードライブレイヤー（`_overdrive_music_player`）への代入（`MUSIC_DUCK_DB` / `OVERDRIVE_FALLBACK_VOLUME_DB` の切替）も同様に Tween 化する（こちらは既存の `_overdrive_fade_tween` の枠組みを流用してもよい）。
  - **Tween の競合に注意**: `_play_fallback_music()`（新しい曲のフェード開始時）と `_stop_music_players()` の冒頭で `_volume_tween` が走っていれば kill すること。Tween がクロスフェード処理（A2/A3 参照）と同じプレイヤーの volume_db を奪い合うと新たなバグになる。

### A2. クロスフェードが dB 空間の線形補間で、フェード終盤に音が急に立ち上がる

- **場所**: `scripts/audio_manager.gd` の `_update_fallback_fade()`（270 行付近）
- **原因**: `active.volume_db = lerpf(-80.0, _target_music_volume(), t)` のように **dB 値を線形補間**している。dB は対数スケールなので、-80→-30 の線形補間はフェード時間（1.25 秒）の前半 7 割がほぼ無音で、最後の 0.3 秒に急激に音が立ち上がる。曲切替（ステージ開始・ボス・ゲームオーバー等）のたびに「音が急に湧いて大きくなる」体感になる。
- **修正**: 補間をリニア振幅空間で行う。

```gdscript
func _update_fallback_fade(dt: float) -> void:
	if _music_players.is_empty() or _fade_elapsed >= _fade_time:
		return
	_fade_elapsed = minf(_fade_time, _fade_elapsed + dt)
	var t := _fade_elapsed / _fade_time
	var active := _music_players[_active_music_player]
	var previous := _music_players[1 - _active_music_player]
	var target_linear := db_to_linear(_target_music_volume())
	active.volume_db = linear_to_db(maxf(0.00001, target_linear * t))
	if previous.playing:
		var previous_linear := db_to_linear(_previous_volume_db)
		previous.volume_db = linear_to_db(maxf(0.00001, previous_linear * (1.0 - t)))
		if t >= 1.0:
			previous.stop()
```

- `maxf(0.00001, ...)` は `linear_to_db(0)` が -inf になるのを防ぐガード。必須。

### A3. クロスフェード中に `_apply_music_volume()` が音量をスナップして 1 フレームの音量スパイクが出る

- **場所**: `scripts/audio_manager.gd` の `_apply_music_volume()` と `_update_fallback_fade()` の競合
- **原因**: ステージ開始から 1.25 秒（フェード中）以内にポーズ（duck）やオーバードライブ切替が起きると、`_apply_music_volume()` がフェード途中（例: 実効 -60dB）のプレイヤーをいきなり目標音量（-30dB 等）へスナップし、次フレームでフェード処理が補間値へ引き戻す。1 フレームだけ音量が跳ねる＝ポップノイズ。
- **修正**: `_apply_music_volume()` では、**フェード進行中（`_fade_elapsed < _fade_time`）はアクティブプレイヤーの volume_db に触らない**。フェード処理は毎フレーム `_target_music_volume()` を参照しているため、duck / overdrive の目標変更はフェード側が自然に追従する。

```gdscript
# _apply_music_volume() 内、アクティブプレイヤーへの反映部分:
if not _music_players.is_empty() and _fade_elapsed >= _fade_time:
	# （ここで A1 の Tween 処理）
```

### A4. graze SFX の同時多重再生で音圧が跳ね上がる

- **場所**: `scripts/audio_manager.gd` の `play_sfx()`（139 行付近）。発生源は `scripts/game.gd:619`（オーバードライブ中の弾変換、毎フレーム発火し得る）と `scripts/game.gd:730`（かすり判定、同一フレームに複数発火し得る）。
- **原因**: 同じ -12dB の graze 音が 1〜数フレーム内に最大 10 ボイス重なると、合算音圧が瞬間的に約 +20dB 跳ねる。「たまに音が大きくなる」のもう一つの主因。
- **修正**: `play_sfx()` に SFX 名ごとのクールダウン（70ms 程度）を入れる。発生側（game.gd）は変更しない。

```gdscript
const SFX_MIN_INTERVAL_MS := 70
var _sfx_last_played_ms: Dictionary = {}

func play_sfx(sfx_name: String) -> void:
	if muted or not _enabled or not sfx_streams.has(sfx_name):
		return
	var now := Time.get_ticks_msec()
	if now - int(_sfx_last_played_ms.get(sfx_name, -SFX_MIN_INTERVAL_MS)) < SFX_MIN_INTERVAL_MS:
		return
	_sfx_last_played_ms[sfx_name] = now
	_play_stream(sfx_streams[sfx_name], -8.0 if sfx_name in ["bomb", "boss"] else -12.0)
```

### A5. アップグレード画面中にオーバードライブの BGM 状態が残る

- **場所**: `scripts/game.gd` の `_begin_upgrade()`（401 行付近）
- **原因**: オーバードライブ発動中にステージをクリアすると、UPGRADE ステートでは `_update_overdrive_feedback()` が呼ばれない（`_update_game()` 内のみ）ため、`set_music_overdriven(true)` のまま残る。アップグレード画面の間オーバードライブ用シンセレイヤーが鳴り続け、確定時には duck 解除と合わさって通常より 3dB 大きい音量（`MUSIC_OVERDRIVE_DB = -27`）で一瞬復帰する。また `overdrive_aura` パーティクルもオーバーレイの裏で放出され続ける。
- **修正**: `_begin_upgrade()` に以下を追加。

```gdscript
audio_manager.set_music_overdriven(false)
if overdrive_aura:
	overdrive_aura.emitting = false
```

### A6.（保険）Master バスにリミッターを追加してクリップ歪みを防ぐ

- **場所**: `scripts/audio_manager.gd` の `_ready()` から呼ぶ新規関数
- **目的**: SFX が重なった瞬間のデジタルクリップ（歪み・音割れ）を構造的に防ぐ。A4 と併用する安全網。
- **修正**: `_enabled` のときだけ、Master バスに `AudioEffectHardLimiter`（Godot 4.3+ の推奨クラス。旧 `AudioEffectLimiter` は非推奨なので使わない）を重複チェック付きで追加。

```gdscript
func _setup_master_limiter() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	for i in range(AudioServer.get_bus_effect_count(master_bus)):
		if AudioServer.get_bus_effect(master_bus, i) is AudioEffectHardLimiter:
			return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(master_bus, limiter)
```

### Part A の受け入れ確認（実機・耳で確認）

1. ゲーム開始 → P でポーズ → P で解除。**解除時に BGM がフワッと（約 0.25 秒で）戻り、急に大きくならない。**
2. ステージクリア → アップグレード画面 → 選択確定。**確定時に音量ジャンプがない。オーバードライブ中にクリアした場合も、アップグレード画面でシンセレイヤーが鳴り続けない。**
3. ステージ開始直後（1 秒以内）にポーズ／オーバードライブ発動。**「ブツッ」というポップノイズが出ない。**
4. 曲の切り替わり（ステージ開始・ボス突入・ゲームオーバー）で、**新しい曲が「急に湧く」のではなく滑らかに入ってくる。**
5. オーバードライブ中に敵弾の密集地帯へ突っ込む（graze 連発）。**音圧が瞬間的に跳ね上がらず、音割れしない。**
6. M キーのミュート → 解除が従来どおり動く（リグレッション確認）。

---

## Part B: ゲームプレイバグ修正

### B1. ダイブ中の敵が編隊の方向転換判定に混ざり、編隊が画面端でビクつく

- **場所**: `scripts/enemy_swarm.gd` の `update()` 冒頭のエッジ判定（77〜85 行付近）
- **原因**: エッジ判定（`enemy.x < 54.0 or enemy.x > width - 54.0`）が**全敵**を対象にしている。ダイブ中の敵は `sin` 横揺れで編隊と無関係に画面端へ出入りするため、端に滞在している間 `swarm_dir` が毎フレーム反転し、編隊全体がその場で振動する。
- **修正**: エッジ判定の対象を「ダイブ中でない・commander でない敵」に限定する。

```gdscript
for enemy in enemies:
	if enemy.dive <= 0.0 and enemy.kind != "commander" and (enemy.x < 54.0 or enemy.x > width - 54.0):
		edge = true
	if enemy.kind == "commander" and enemy.hp > 0:
		commander_alive = true
```

- 既存の `if edge and commander_alive: break` の早期 break はそのままでよい。
- **確認**: ステージ 2 以降（dive 率が高い）で編隊が画面端に到達したとき、滑らかに折り返すこと。ダイブ機が端で暴れても編隊が振動しないこと。

### B2.（任意・挙動変更なしのみ可）敵の射撃間隔式の演算子優先順位が紛らわしい

- **場所**: `scripts/enemy_swarm.gd:112` の `enemy.shoot = 1.2 + randf() * 3.4 / maxf(0.55, chance)`
- **問題**: `(1.2 + randf() * 3.4) / chance` の意図だった可能性があるが、現状の式では基礎値 1.2 秒が難易度の影響を受けない。**ただし現挙動でゲームバランスは成立しているため、挙動を変えてはならない。**
- **修正**: 現在の評価順を明示する括弧を付けるだけにする: `enemy.shoot = 1.2 + (randf() * 3.4 / maxf(0.55, chance))`。バランス変更（割る位置の変更）はこの作業では行わない。

---

## Part C: UI 改善（世界観維持・既存画像流用）

共通ルール: 配色・パネル様式は「0. 前提」の世界観トークンに従う。フォントは既存どおり `ThemeDB.fallback_font`（`game.gd` の `font`）。テキストは既存 UI に合わせ**すべて英語大文字**。新規画像は作らず `ui_atlas.png` の `ui_regions`（`game.gd:69` 付近に定義）を流用する。レイアウト座標は下記を目安とし、実機スクリーンショットで重なりがないことを確認して微調整してよい。

### C1. HUD のリソース表示をアイコン化（LIFE / BOMB / SHLD）

- **現状**: `scripts/hud.gd` の `draw_hud()` が "LIFE 3 / BOMB 3 / SHLD 0" を英字ラベル＋ピクセル数字で表示。直感的でなく、世界観的にも文字が多い。
- **変更**: 各ラベルの代わりに `ui_atlas.png` の既存アイコン（`ui_regions["life"]`, `["bomb"]`, `["shield"]`、元は 248×248 の領域。アイテムドロップ描画 `game.gd:1243` で流用実績あり）を約 22×22px で描画し、右にピクセル数字で個数を表示する。例: `[♥アイコン] 3`。
  - `draw_hud()` は `CanvasItem` を受け取るので `canvas.draw_texture_rect_region(ui_texture, ...)` で描ける。`ui_texture` と `ui_regions` は `game.gd` が持っているため、`draw_hud()` の引数に追加するか、セットアップ時に `hud` へ渡す（既存の責務分割を崩さない方法を選ぶ）。
  - x 座標は現行ラベル位置（LIFE: 512 / BOMB: 642 / SHLD: 790）を基準に、アイコン + 数字で収まるよう調整。HUD の高さは 76px、既存要素（SCORE・STAGE・CHAIN・ボス HP バー (315,56,330,8)・レゾナンスバー y=64）と重ねないこと。
  - `ui_texture` が null の場合（読み込み失敗時）は現行のテキストラベル表示にフォールバックする。

### C2. ミュートインジケーター

- **現状**: M キーでミュートしても画面に何も表示されず、状態が分からない（実質バグ）。
- **変更**: ミュート中、HUD 右上に "MUTE" を小さく表示する。
  - `audio_manager.muted` を `draw_hud()` へ渡す（または `game.gd` 側で HUD の上に直接描く。既存の `_draw_control_mode_badge()`（game.gd:1360）と同じ「黒地 + 細枠 + 13px テキスト」の様式を流用するとよい）。
  - 位置は右上 (x ≈ 900, y ≈ 14〜34) 目安。CHAIN 表示（790〜920 付近, y 41〜61）と重ねない。
  - 色はマゼンタ `#ff7af0`、点滅は不要（常時表示で十分）。

### C3. ボス HP バーの強化

- **現状**: `hud.gd:23-26` でボス戦中に無名の赤バー（315, 56, 330×8）が出るだけ。何のゲージか分かりにくい。
- **変更**:
  - バーの左に小さく "CITADEL CORE"（ステージ名 = ボス名。`game_config.gd` の `STAGES[4].name` を使い、ハードコードしない）を 10〜12px で表示。スペースが足りなければ "BOSS" でも可。
  - バーに 1px のシアン細枠を追加（`canvas.draw_rect(rect, Color(0.33, 0.91, 1.0, 0.4), false, 1.0)`）。
  - HP 残量 35% 未満（ボスの phase 2 と同じ閾値）でバー色を `#ff386f` → `#fff06a`（イエロー）寄りに変えるなど、残量で色が変わる演出を追加してよい。

### C4. 操作ガイドの表示（ポーズ画面・タイトル画面）

- **現状**: 操作方法（射撃・ボム・オーバードライブ等のキー）がゲーム内のどこにも表示されていない。ポーズ画面は "PAUSED / PRESS P TO RETURN" のみ。
- **変更**:
  - **ポーズ画面**（`game.gd` の `_draw_overlay()`、`state == GameState.PAUSED` のとき）: タイトル下に操作一覧パネルを追加。様式はアップグレードカード（`_draw_upgrade_overlay()`）と同じ「`Color(0.02, 0.06, 0.12, 0.84)` 地 + シアン細枠」。内容は以下（project.godot の入力マップに準拠）:
    ```
    MOVE        WASD / ARROWS
    SHOT        SPACE
    BOMB        B / SHIFT
    OVERDRIVE   E
    AI MODE     T
    PAUSE       P
    MUTE        M
    ```
  - **タイトル画面**: START ボタンの下（y ≈ Config.HUD + 520 以降の空き）に同内容を 1〜2 行の小さい文字（12〜13px、`Color(0.89, 0.98, 1.0, 0.6)`）で要約表示。例: `SPACE SHOT / B BOMB / E OVERDRIVE / T AI / P PAUSE / M MUTE`。既存の "STAGE GIMMICKS / BUILD CHOICES / OVERDRIVE CONVERT" 行と重ねないこと。

### C5. レゾナンスバーにラベルを付ける

- **現状**: `hud.gd` の `_draw_resonance_bar()` が HUD 下端に細いゲージを描くが、満タンになるまで（"OVERDRIVE READY" が出るまで）何のゲージか分からない。
- **変更**: バーの左端上（x = 22, y ≈ Config.HUD - 19）に "RESONANCE" を 10〜11px、`Color(0.89, 0.98, 1.0, 0.55)` で常時表示。右端の "OVERDRIVE READY / OVERDRIVE" 表示（x = W - 174）とは重ならない。

### C6. アップグレード画面の数字キー選択

- **現状**: アップグレード選択は左右キー + ENTER のみ。
- **変更**:
  - `game.gd` の `_unhandled_input()` の UPGRADE 分岐に、1/2/3 キーで直接選択 + 確定する処理を追加（`event is InputEventKey and event.pressed and not event.echo` で `event.keycode` が `KEY_1`〜`KEY_3` のとき、該当 index が `upgrade_options.size()` 未満なら `upgrade_selected` に設定して `_apply_selected_upgrade()`）。
  - 各カードの左上に番号 "1" "2" "3" をピクセル数字（`hud._draw_digits` 相当の様式）または 14px テキストで表示。
  - 案内行 "LEFT / RIGHT SELECT   ENTER CONFIRM" を "1-3 / LEFT / RIGHT SELECT   ENTER CONFIRM" に更新。

### Part C の受け入れ確認

1. 実機起動し、タイトル → プレイ → ポーズ → アップグレード → ボス戦 → ゲームオーバー/クリアの各画面でスクリーンショットを確認。要素の重なり・はみ出しがない。
2. `ui_atlas.png` 読み込み失敗時のフォールバック（テキスト表示）が生きている。
3. M キーで MUTE 表示が出て、再度 M で消える。
4. アップグレード画面で 1/2/3 キー選択が機能し、左右 + ENTER も従来どおり動く。
5. AI モード（T キー / タイトルで AI PILOT 選択）でも全 UI が正常表示される。

---

## 完了条件（全体）

1. 構文チェックと 2 つの headless テスト（smoke / gameplay）がすべてパスする。
2. Part A の受け入れ確認 1〜6 を実機で実施し、すべて満たす。
3. Part C の受け入れ確認 1〜5 を実機で実施し、すべて満たす。
4. `README.md` の該当箇所（操作説明・`audio_manager.gd` の説明・ゲーム品質改善の節など）を変更内容に合わせて更新する。
5. 変更をコミットし、プッシュする（コミットは Part 単位など意味のある粒度に分けてよい）。
