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
public/assets/spritesheet.png
public/assets/backgrounds.png
public/assets/ui_atlas.png
export_presets.cfg
```

`scripts/game.gd` は `GameController` として各サブシステムを束ねます。ステージ・敵・HUD用数字などの調整値は `scripts/game_config.gd` に集約しています。スプライトシートは実行時に黒背景を透明化して使います。

主な分割:

- `player.gd`: 自機のライフ、ボム、無敵、連続撃破チェイン
- `enemy_swarm.gd`: 通常ステージの編隊、急降下、射撃
- `boss_controller.gd`: ボスのフェーズ、攻撃、ビーム予兆
- `projectile_manager.gd`: 自弾・敵弾の生成と更新
- `hud.gd`: HUD描画
- `audio_manager.gd`: 効果音、Resonate対応BGM切り替え、クロスフェード、ミュート、headless時の音声無効化

## アセット

- `public/assets/spritesheet.png`: 自機、敵、弾、爆発、ボスなどの4x4固定グリッドスプライト
- `public/assets/backgrounds.png`: 5ステージ分の宇宙背景アトラス
- `public/assets/ui_atlas.png`: タイトルロゴ、アイテムアイコン、ステージバナー、エンディング絵のUIアトラス
- `public/assets/audio/music/*.wav`: タイトル、通常戦、後半戦、ボス、勝利、ゲームオーバー用のネオンSTG系BGMループ

## ゲーム品質改善

- Input Map 経由の操作に変更し、キーボードとゲームパッド入力を扱いやすくしています。
- スコアチェイン、ノーミスステージボーナス、成績に応じた軽い難易度補正を追加しています。
- 敵弾のかすり、連続撃破、ボスヒットで溜まるResonanceゲージと、満タン時に発動できるOverdriveを追加しています。
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
