# Nova Swarm

Godot 4.7 + GDScript で作る高コントラストなアニメ宇宙戦調の2Dシューティングゲームです。編隊戦、急降下、戦闘中のチップ成長、複数中ボス、部位破壊型の最終ボスを、約5分の6ステージにまとめています。

## 起動

Godotエディタでこのフォルダを開き、実行します。

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

通常の開発・デバッグはGodotエディタまたはネイティブ実行で行います。Webエクスポート版はブラウザ配布前の確認用です。

## 操作

| 操作 | キー |
| --- | --- |
| 移動 | `W` / `A` / `S` / `D` または `↑` / `←` / `↓` / `→` |
| ショット | `Space` |
| ボム | `Shift` または `B` |
| Resonance Overdrive | `E` |
| ポーズ | `P` |
| ミュート | `M` |
| モード選択 | タイトル画面でクリック、または `A` / `D`・`←` / `→` |
| 開始 / リスタート | タイトル画面の `DEPLOY` をクリック、または `Enter` |
| タッチ操作 | タッチ端末では左下スティック、右下 `SHOT` / `BOMB` / `OVER`、右上 `PAUSE` |

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
scripts/ai_boss_stage6_test.gd
public/assets/spritesheet.png
public/assets/backgrounds.png
public/assets/ui_atlas.png
public/assets/ui_chrome.png
public/assets/rock_obstacle.png
public/assets/projectile_atlas.png
public/assets/overdrive_mote.png
public/assets/score_crystal_atlas.png
public/assets/final_boss.png
public/assets/boss_weakpoints.png
public/assets/fonts/Oxanium-wght.ttf
public/assets/renewal/player_ship.png
public/assets/renewal/enemy_fleet.png
public/assets/renewal/final_boss.png
public/assets/renewal/background_atlas.png
public/assets/pro_ui/title_launch_bay.png
public/assets/pro_ui/controls/
public/assets/pro_ui/icons/
public/assets/pro_ui/shield/
public/assets/pro_ui/hud/
export_presets.cfg
```

`scripts/game.gd` は `GameController` として各サブシステムを束ねます。ステージ、ウェーブ、中ボス、成長チップ、敵、HUD用数字などの調整値は `scripts/game_config.gd` に集約しています。

Godot プロジェクトを Codex / MCP / 自動テストと組み合わせて継続開発する方針は [`docs/godot-ai-development-workflow.md`](docs/godot-ai-development-workflow.md) にまとめています。Nova Swarm の責務分割を、次の Godot プロジェクトや伸ばすワーム系ゲームへ移すための制作メモです。

主な分割:

- `player.gd`: 自機のライフ、ボム、無敵、連続撃破チェイン、3系統のチップ成長
- `enemy_swarm.gd`: 通常ウェーブの編隊、急降下、中ボスの行動と同時攻撃制御
- `boss_controller.gd`: ボスのフェーズ、攻撃、ビーム予兆、部位破壊
- `projectile_manager.gd`: 自弾・敵弾、分岐ショットの生成と更新
- `hud.gd`: 固定HUD、ウェーブ進捗、3系統の成長状態、ボスHP/Overdriveゲージ
- `audio_manager.gd`: 多層インパクトSFX、連打抑制、ピッチ揺らぎ、Overdrive用BGMレイヤー、クロスフェード、ミュート、Masterリミッター、headless時の音声無効化

## 主なゲームシステム

- 6ステージ構成です。3面最終ウェーブは中ボス2体、5面は中ボス3体が登場します。5面では3体が常時一斉攻撃せず、最大2体が攻撃し1体が休むローテーションになります。6面は最終ボス `NOVA SOVEREIGN` 戦です。
- 面と面の間に選択画面は挟みません。敵が落とす色付きチップを戦闘中に集め、`POW`（火力・連射）、`SPR`（拡散）、`RES`（Resonance・Overdrive）を各4段階まで成長させます。3個でレベルアップし、被弾時に失うのは未完成の進捗だけです。
- 通常面は `5 / 6 / 4 / 5 / 4` ウェーブへ圧縮し、約0.55秒で次の編隊へ接続します。面クリアも短いバナーだけで次へ進みます。面クリア時はシールド全回復、中ボス撃破時もシールド回復のチェックポイントになり、低残機時には面クリアで1機修復されます。
- 4面では破壊可能な岩障害物、5面では敵弾を跳ね返すプラズマ壁が出ます。
- Resonance Overdrive中は近くの敵弾をスコア結晶に変換し、攻めながら危険を得点へ変えられます。自機を囲む白・コバルト・金のエネルギー片はOverdrive発動中を示す視覚効果で、独立した攻撃判定は持ちません。変換された発光結晶は自機へ吸引され、回収時に得点へ加算されます。近距離撃破もOverdrive維持に寄与します。
- ボスは複数の破壊可能部位を持ち、部位を壊すと攻撃テンポやビーム行動に影響します。
- リザルトにはランクに加えて次回改善ヒントを表示します。スコア、チェイン、被弾、ボム使用、クリア時間を見て改善先を出します。
- AI Pilotはタイトル画面の `AI DEMO` から開始できます。プレイ中の操作モード切り替えはなく、通常プレイのテンポを妨げません。

## アセット

- `public/assets/spritesheet.png`: 自機、敵、弾、爆発、ボスなどの4x4固定グリッドスプライト
- `public/assets/backgrounds.png`: 旧ビジュアル互換用の宇宙背景アトラス
- `public/assets/ui_atlas.png`: タイトルロゴ、アイテムアイコン、ステージバナー、エンディング絵のUIアトラス
- `public/assets/ui_chrome.png`: 赤い中枢侵食テーマのパネル表面、警告コア、タッチボタン用ピクセルUIアトラス
- `public/assets/rock_obstacle.png`: `ROCK BELT` の岩障害物用スプライト。赤い鉱脈背景に馴染む生成画像を透明化して使用
- `public/assets/projectile_atlas.png`: 自弾、Overdrive弾、敵弾、ボス弾用の生成スプライトアトラス
- `public/assets/overdrive_mote.png`: Overdrive Aura / Burst用の生成エネルギー片。未テクスチャの四角粒子を置き換えます
- `public/assets/score_crystal_atlas.png`: 敵弾変換後のスコア結晶用4フレームアトラス
- `public/assets/final_boss.png`: 旧ビジュアル互換用のボススプライト
- `public/assets/boss_weakpoints.png`: ボス部位の生存/破壊済み表示用スプライトアトラス
- `public/assets/renewal/player_ship.png`: 白・コバルト・シアンを基調にした新しい自機スプライト
- `public/assets/renewal/enemy_fleet.png`: 通常敵6種と中ボス3種を収録した3x3スプライトアトラス
- `public/assets/renewal/final_boss.png`: 白・コバルト・金の最終ボス `NOVA SOVEREIGN`
- `public/assets/renewal/background_atlas.png`: 戦闘の視認性を優先した6面分の3x2宇宙背景アトラス
- `public/assets/pro_ui/`: 発進ベイのタイトル背景、実画像の操作パネル、9種のステータス／アイテム、4フレームの機械式シールド、操縦席風HUD
- `public/assets/fonts/Oxanium-wght.ttf`: タイトル、HUD、ステージ表示、ポーズ、リザルトに使うOxanium可変フォント。`public/assets/fonts/OFL.txt` のSIL Open Font License 1.1で同梱しています
- `public/assets/audio/music/*.wav`: タイトル、通常戦、後半戦、ボス、勝利、ゲームオーバー用のオリジナルBGM。通常戦150 BPM、後半162 BPM、ボス174 BPMを基準に、発進感のあるシンセ、ベース、アルペジオ、ドラムを重ねています。
- `scripts/tools/generate_music.py`: 6曲のループを決定的に再生成する標準ライブラリのみの音源生成スクリプト

## ゲーム品質改善

- Input Map 経由の操作に変更し、キーボードとゲームパッド入力を扱いやすくしています。
- Godot 4.7環境に更新し、iPhoneやWebのタッチ端末では画面上に仮想スティックとショット/ボム/Overdrive/ポーズボタンを出します。Web版は `?touch=1` でデスクトップ検証用に強制表示できます。
- 自機は左右だけでなく上下にも移動でき、敵弾や急降下の避け方を2D空間で選べるようにしています。AI Pilotも2D移動候補から安全位置を選びます。
- スコアチェイン、ノーミスステージボーナス、成績に応じた軽い難易度補正を追加しています。
- 敵弾のかすり、連続撃破、ボスヒットで溜まるResonanceゲージと、満タン時に発動できるOverdriveを追加しています。
- Overdrive中に敵弾をスコア結晶へ変換し、攻撃的な回避に得点上の価値を持たせています。
- Overdrive中はResonateのBGM stemを有効化し、通常戦、後半戦、ボス戦それぞれで専用レイヤーが重なってテンションが上がります。
- BGMは単一の再生経路で確実にループし、通常時・Overdrive時・ポーズ時の音量差を明確にしています。duck解除や曲切り替えは短いフェードで処理し、SFXの短時間連打とMasterバスのピークも抑えています。
- ステージ専用ギミック、戦闘中チップ成長、複数中ボス、ボス部位破壊、リザルト改善ヒントを追加しています。
- HUDは画面揺れから分離し、スコア、ステージ／ウェーブ、ライフ、ボム、シールド、3系統の成長、Overdrive、ボスHPを上端に固定しています。
- HUDは小さな補助ラベルを削り、アイコン・数値・レベル・進捗を画像フレーム内へ収めています。動的テキストはOxaniumへ統一し、割当幅に応じて縮小または省略します。
- UI/UXは発進ベイを基準に、白い装甲、コバルトのガラス、シアンの発光、控えめな金へ統一しています。タイトル、HUD、チップ、シールド、ステージバナー、ポーズ／結果パネルまで同じ実画像のメカ素材を使用します。
- タッチUIはiPhone Air相当の縦長表示でも押しやすいよう、仮想スティック、`SHOT`、`BOMB`、`OVER`、`PAUSE`の表示とヒットボックスを大きめに調整しています。
- 自機、敵艦隊、中ボス、6面ボス、6面分の背景を新しい生成スプライトへ差し替えています。
- ショット、着弾、爆発、チップ取得、レベルアップ、中ボス撃破、面クリアは、複数の短い波形を重ねた専用SFXにし、同音の過密な連打も抑制しています。
- 爆発、被弾、ボム、ステージ開始、ボス攻撃に画面揺れ、フラッシュ、ヒットストップ、予兆を追加しています。
- 急降下中の敵とボスビームにはDanger Lineを表示し、危険レーンを事前に読みやすくしています。
- `armor` は3HPになり、敵ごとの役割差が出るようにしています。
- 中ボスは攻撃パターンと同時攻撃ローテーションを維持したまま、基礎HPと後半の難易度倍率を抑え、長期戦になりすぎないようにしています。
- ボスの当たり判定は矩形ではなく複数の円形ゾーンで扱い、見た目から外れた弾が消えにくいようにしています。
- AI Pilotは候補地点までの移動経路を1.6秒先まで評価し、横移動弾、ボスビーム、急降下敵を予測して回避します。安全な成長チップの回収と、通常ウェーブでの最後のボム温存も行います。
- 720秒の決定的な複数シードAI通しを基準に調整し、全6面クリアは約5分です。同一seedは同一結果になり、`--seed` で別パターンを検証できます。
- 同一フレーム内で破壊済みの敵や岩障害物へ再ヒットして、スコアや撃破処理が重複しないようにしています。

## 検証

スモークテスト:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --display-driver headless --rendering-driver dummy --audio-driver Dummy --path . --script res://scripts/smoke_test.gd --log-file /private/tmp/nova-swarm-smoke.log
```

ゲームプレイテスト:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --display-driver headless --rendering-driver dummy --audio-driver Dummy --path . --script res://scripts/gameplay_test.gd --log-file /private/tmp/nova-swarm-gameplay.log
```

AIボス戦テスト:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --display-driver headless --rendering-driver dummy --audio-driver Dummy --path . --script res://scripts/ai_boss_stage6_test.gd --log-file /private/tmp/nova-swarm-ai-boss.log
```

AIシミュレーション:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --display-driver headless --rendering-driver dummy --audio-driver Dummy --path . --script res://scripts/ai_simulation_test.gd --log-file /private/tmp/nova-swarm-ai-sim.log -- --seconds=720 --seed=20260501 --min-stage=6
```

`AI_SIM_RESULT` にステージ、スコア、残ライフ、被弾回数がJSONで出ます。AIの調整はこのコマンドを画面なしで回して確認できます。
最終ボス戦だけ確認したい場合は `--start-stage=6` を付けます。

Godot MCPで確認する場合:

```text
get_project_info
run_project
get_debug_output
stop_project
```

## Webエクスポート

ローカルでWeb版を書き出すには、Godot 4.7 のExport Templatesが必要です。

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

タッチUIをデスクトップブラウザで強制表示する場合:

```text
http://127.0.0.1:4177/?touch=1
```

## GitHub Pages

`main` ブランチにpushすると、GitHub ActionsでGodot 4.7のWebエクスポートを実行し、`dist`相当の成果物をGitHub Pagesにデプロイします。

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
