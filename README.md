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
| ポーズ | `P` |
| ミュート | `M` |
| 開始 / リスタート | `Enter` |

## 構成

```text
project.godot
scenes/main.tscn
scripts/game.gd
scripts/smoke_test.gd
public/assets/spritesheet.png
public/assets/backgrounds.png
export_presets.cfg
```

`scripts/game.gd` がゲーム本体です。スプライトシートは実行時に黒背景を透明化して使います。

## アセット

- `public/assets/spritesheet.png`: 自機、敵、弾、爆発、ボスなどの4x4固定グリッドスプライト
- `public/assets/backgrounds.png`: 5ステージ分の宇宙背景アトラス

## 検証

スモークテスト:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://scripts/smoke_test.gd
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
