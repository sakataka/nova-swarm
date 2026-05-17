# Nova Swarm

Godot 4.6 + GDScript で作るレトロアーケード調の2Dシューティングゲームです。Space Invaders / Galaxian 系の編隊移動、急降下、ボム、5ステージ構成、ボス戦をベースにしています。

## 起動

Godotエディタでこのフォルダを開き、実行します。

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

通常の開発・デバッグはGodotエディタまたはネイティブ実行で行います。Webエクスポート版はブラウザ配布前の確認用です。

## 操作

| 操作 | キー |
| --- | --- |
| 移動 | `A` / `D` または `←` / `→` |
| ショット | `Space` |
| ボム | `Shift` または `B` |
| Resonance Overdrive | `E` |
| AIプレイ切り替え | `T` |
| ポーズ | `P` |
| ミュート | `M` |
| モード選択 | タイトル画面で `A` / `D` または `←` / `→` |
| 開始 / リスタート | `Enter` |

## 構成

```text
project.godot
scenes/main.tscn
scripts/game.gd
scripts/game_config.gd
scripts/player.gd
scripts/enemy_swarm.gd
scripts/boss_controller.gd
scripts/projectile_manager.gd
scripts/hud.gd
scripts/audio_manager.gd
scripts/smoke_test.gd
scripts/gameplay_test.gd
scripts/ai_boss_stage5_test.gd
public/assets/spritesheet.png
public/assets/backgrounds.png
public/assets/ui_atlas.png
public/assets/rock_obstacle.png
public/assets/projectile_atlas.png
public/assets/final_boss.png
public/assets/boss_weakpoints.png
export_presets.cfg
```

`scripts/game.gd` は `GameController` として各サブシステムを束ねます。ステージ・敵・HUD用数字、アップグレード候補などの調整値は `scripts/game_config.gd` に集約しています。スプライトシートは実行時に黒背景を透明化して使います。

Godot プロジェクトを Codex / MCP / 自動テストと組み合わせて継続開発する方針は [`docs/godot-ai-development-workflow.md`](docs/godot-ai-development-workflow.md) にまとめています。Nova Swarm の責務分割を、次の Godot プロジェクトや伸ばすワーム系ゲームへ移すための制作メモです。

主な分割:

- `player.gd`: 自機のライフ、ボム、無敵、連続撃破チェイン、アップグレード修飾
- `enemy_swarm.gd`: 通常ステージの編隊、急降下、射撃
- `boss_controller.gd`: ボスのフェーズ、攻撃、ビーム予兆、部位破壊
- `projectile_manager.gd`: 自弾・敵弾、分岐ショットの生成と更新
- `hud.gd`: HUD描画
- `audio_manager.gd`: 効果音、Resonate対応BGM切り替え、Overdrive用BGMレイヤー、クロスフェード、ミュート、headless時の音声無効化

## 主なゲームシステム

- 5ステージ構成で、後半ステージには専用ギミックがあります。`ROCK BELT` では破壊可能な岩障害物、`PLASMA NEST` では敵弾を跳ね返すプラズマ壁が出ます。
- ステージ間の3択アップグレードは、連射だけでなく、ワイドショット、かすりチェイン、ボム返還、シールド反撃、アイテムドロップ強化などのビルド分岐を作ります。
- Resonance Overdrive中は近くの敵弾をスコア結晶に変換し、攻めながら危険を得点へ変えられます。近距離撃破もOverdrive維持に寄与します。
- ボスは複数の破壊可能部位を持ち、部位を壊すと攻撃テンポやビーム行動に影響します。
- リザルトにはランクに加えて次回改善ヒントを表示します。スコア、チェイン、被弾、ボム使用、クリア時間を見て改善先を出します。
- AI Pilotは自動プレイに加えて、AI Rivalスコアを表示し、練習・観戦時の比較材料にしています。

## アセット

- `public/assets/spritesheet.png`: 自機、敵、弾、爆発、ボスなどの4x4固定グリッドスプライト
- `public/assets/backgrounds.png`: 5ステージ分の宇宙背景アトラス
- `public/assets/ui_atlas.png`: タイトルロゴ、アイテムアイコン、ステージバナー、エンディング絵のUIアトラス
- `public/assets/rock_obstacle.png`: `ROCK BELT` の岩障害物用スプライト。赤い鉱脈背景に馴染む生成画像を透明化して使用
- `public/assets/projectile_atlas.png`: 自弾、Overdrive弾、敵弾、ボス弾用の生成スプライトアトラス
- `public/assets/final_boss.png`: 5面ボス用の高解像度生成スプライト
- `public/assets/boss_weakpoints.png`: ボス部位の生存/破壊済み表示用スプライトアトラス
- `public/assets/audio/music/*.wav`: タイトル、通常戦、後半戦、ボス、勝利、ゲームオーバー用のネオンSTG系BGMループ。通常戦、後半戦、ボス戦にはResonateの追加stemとして鳴るOverdrive用シンセ/パーカッションレイヤーを実行時生成しています。

## ゲーム品質改善

- Input Map 経由の操作に変更し、キーボードとゲームパッド入力を扱いやすくしています。
- スコアチェイン、ノーミスステージボーナス、成績に応じた軽い難易度補正を追加しています。
- 敵弾のかすり、連続撃破、ボスヒットで溜まるResonanceゲージと、満タン時に発動できるOverdriveを追加しています。
- Overdrive中に敵弾をスコア結晶へ変換し、攻撃的な回避に得点上の価値を持たせています。
- Overdrive中はResonateのBGM stemを有効化し、通常戦、後半戦、ボス戦それぞれで専用レイヤーが重なってテンションが上がります。
- ステージ専用ギミック、ビルド分岐アップグレード、ボス部位破壊、リザルト改善ヒントを追加しています。
- 自弾・敵弾・5面ボス・ボス弱点表示を生成スプライトに差し替え、背景や岩障害物と同じ赤い鉱脈系の世界観に寄せています。
- AI Pilotの可視化としてAI Rivalスコアを追加しています。
- 爆発、被弾、ボム、ステージ開始、ボス攻撃に画面揺れ、フラッシュ、ヒットストップ、予兆を追加しています。
- `armor` は2HPになり、敵ごとの役割差が出るようにしています。
- ボスの当たり判定は矩形ではなく複数の円形ゾーンで扱い、見た目から外れた弾が消えにくいようにしています。
- ボスHPを調整し、終盤の硬さを少し抑えています。

## 検証

スモークテスト:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://scripts/smoke_test.gd
```

ゲームプレイテスト:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://scripts/gameplay_test.gd
```

AIボス戦テスト:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://scripts/ai_boss_stage5_test.gd
```

AIシミュレーション:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://scripts/ai_simulation_test.gd --seconds=75 --seed=20260501 --min-stage=2
```

`AI_SIM_RESULT` にステージ、スコア、残ライフ、被弾回数がJSONで出ます。AIの調整はこのコマンドを画面なしで回して確認できます。
ボス戦だけ確認したい場合は `--start-stage=5` を付けます。

Godot MCPで確認する場合:

```text
get_project_info
run_project
get_debug_output
stop_project
```

## Webエクスポート

ローカルでWeb版を書き出すには、Godot 4.6.2 のExport Templatesが必要です。

```bash
mkdir -p dist
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release Web dist/index.html
```

確認用HTTPサーバー:

```bash
cd dist
python3 -m http.server 4177 --bind 127.0.0.1
```

ブラウザで開きます。

```text
http://127.0.0.1:4177/
```

## GitHub Pages

`main` ブランチにpushすると、GitHub ActionsでGodot Webエクスポートを実行し、`dist`相当の成果物をGitHub Pagesにデプロイします。

公開URL:

```text
https://sakataka.github.io/nova-swarm/
```

## Godot MCP

このプロジェクトは `Coding-Solo/godot-mcp` で操作できます。Codexに登録する場合の例です。

```toml
[mcp_servers.godot]
command = "npx"
args = ["-y", "@coding-solo/godot-mcp"]

[mcp_servers.godot.env]
GODOT_PATH = "/Applications/Godot.app/Contents/MacOS/Godot"
DEBUG = "true"
```
