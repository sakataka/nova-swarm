# Godot AI Development Workflow

このメモは、Nova Swarm の Godot 4.6 + GDScript 開発でうまく回った進め方を、次の Godot プロジェクトにも移せるように整理したものです。いわゆる「Vibe Godoting」的な発想は、AI にゲームを丸ごと任せるためではなく、Godot の制作工程を分解して、Codex / MCP / テンプレート / アセット生成 / 自動テストを適切な粒度で組み合わせるために使います。

## 基本方針

- 最初にプロジェクト基盤を決める。シーン、入力、音、UI、データ、テスト、export の置き場所を早めに固定する。
- Codex には 1 回の依頼で 1 つの責務を任せる。全体をふわっと作り直すより、移動、衝突、HUD、音、テストなどを狭く改善する。
- Godot では実行確認を必ず分けて考える。GDScript 編集、headless test、native 実行、MCP / Editor でのログ確認は別の品質ゲートとして扱う。
- 生成アセットは初期案として使う。採用判断は、ゲーム画面での視認性、当たり判定との一致、速度が上がったときの読みやすさで行う。
- 仕様が変わったら README や docs も同じ単位で更新する。次の Codex 作業の入力品質を落とさない。

## Nova Swarm での責務分割

Nova Swarm では、現在の主な責務を次のように分けています。

| 領域 | 主なファイル | 役割 |
| --- | --- | --- |
| ゲーム本体 | `scripts/game.gd` | `GameController` としてステージ、プレイヤー、敵、弾、HUD、音を束ねる |
| 調整値 | `scripts/game_config.gd` | ステージ、敵、アップグレード、HUD 数字などの調整値 |
| プレイヤー | `scripts/player.gd` | ライフ、ボム、無敵、チェイン、アップグレード修飾 |
| 敵編隊 | `scripts/enemy_swarm.gd` | 通常ステージの編隊移動、急降下、射撃 |
| ボス | `scripts/boss_controller.gd` | ボスフェーズ、攻撃、ビーム予兆、部位破壊 |
| 弾 | `scripts/projectile_manager.gd` | 自弾、敵弾、分岐ショット、Overdrive 弾 |
| HUD | `scripts/hud.gd` | HUD、リザルト、AI Rival 表示 |
| 音 | `scripts/audio_manager.gd` | 効果音、BGM、Resonate、Overdrive stem、headless 時の音声無効化 |
| テスト | `scripts/*_test.gd` | smoke、gameplay、AI simulation、ボス戦検証 |
| export | `export_presets.cfg` | Web / 配布向けの書き出し設定 |

新しい Godot ゲームでも、最初にこの表に相当する「責務の住所」を決めてから実装すると、AI への依頼範囲が安定します。

## 伸ばすワームへ移す場合

伸ばすワームでは、最初に次のような構成を決めると扱いやすくなります。

| 領域 | 置き場所の例 | 固定したい判断 |
| --- | --- | --- |
| メインループ | `scripts/game.gd` | 状態遷移、リトライ、ポーズ、seed/debug mode |
| ワーム本体 | `scripts/worm.gd` | 頭、体節、伸長、曲がり、自己衝突 |
| ステージ | `scripts/stage.gd` | 壁、障害物、スポーン、安全地帯 |
| ルール | `scripts/game_rules.gd` | スコア、アイテム効果、難易度上昇、ゲームオーバー条件 |
| 入力 | `project.godot` / `scripts/input_controller.gd` | キーボード、ゲームパッド、入力バッファ |
| カメラ / 演出 | `scripts/camera_fx.gd` | 追従、画面揺れ、ズーム、速度演出 |
| HUD | `scripts/hud.gd` | スコア、長さ、アイテム、リザルト、リトライ |
| 音 | `scripts/audio_manager.gd` | BGM、伸長、取得、衝突、危険予兆 |
| テスト | `scripts/*_test.gd` | 固定 seed、衝突、伸長、アイテム取得、ゲームオーバー |
| export | `export_presets.cfg` | Web / macOS などの配布先 |

Codex への依頼は、たとえば「ワームの伸長ロジックだけ直す」「自己衝突の headless test を追加する」「リザルト画面の情報整理だけ行う」のように、表の 1 領域へ閉じるのが安全です。

## 推奨パイプライン

1. テンプレート基盤を作る
   - main scene、入力、画面サイズ、autoload、音、export、テスト置き場を決める。
   - ここで責務の住所を README に書く。

2. 最小ループを作る
   - ワームなら、動く、伸びる、ぶつかる、リトライできる、までを先に作る。
   - Nova Swarm なら、移動、射撃、敵、被弾、リスタートが最小ループに相当する。

3. headless / debug で確認する
   - 見た目の前に、ロジックが壊れていないことを固定 seed やスクリプトで確認する。
   - Nova Swarm では `smoke_test.gd`、`gameplay_test.gd`、`ai_simulation_test.gd`、`ai_boss_stage5_test.gd` を使う。

4. native 実行 / MCP で体感を見る
   - 操作感、速度、視認性、音、演出は headless test だけでは判断しない。
   - Godot MCP を使う場合は、対象シーン、ノード、プロパティを狭く指定して確認する。

5. アセット生成を補助的に使う
   - ワーム本体、セグメント、アイテム、障害物、背景、UI アイコン、エフェクトの候補作成に使う。
   - 採用前に、頭の位置、体の長さ、危険物、進行方向、背景との分離、速度上昇時の視認性を確認する。

6. README / docs を更新する
   - ルール、入力、スコア、ゲームオーバー、難易度、テスト、export、主要ファイルを更新する。
   - Codex に次の作業を頼む前に、現在の仕様が読める状態にする。

## Codex に任せやすい作業単位

- 移動速度や加速度の調整
- 曲がり方や入力バッファの改善
- 伸長タイミングやアイテム効果の調整
- 自己衝突、壁衝突、障害物衝突の修正
- ステージギミックを 1 種類だけ追加
- HUD の表示項目や優先度の整理
- リザルト画面とリトライ導線の改善
- fixed seed / debug mode / headless test の追加
- 生成アセットを Godot へ取り込むための import / atlas 整理
- README の現在仕様への同期

## MCP / Editor 連携の使い方

MCP や Editor 操作は強力ですが、シーンやリソースを直接変えるため、作業範囲を小さくします。

- 最初は node 構成、autoload、project settings、debug output の確認に使う。
- 変更する場合は「このシーンのこのノード」「このプロパティ」「このリソース」まで絞る。
- Codex が変更した後は、GDScript diff だけでなく `.tscn` / `.tres` / `.import` の差分も確認する。
- 体感確認は native 実行を優先し、Web export は配布前の確認として扱う。

## 回帰ポイント

伸ばすワームで最初に固定したい回帰ポイントは次の通りです。

- 固定 seed で一定時間エラーなく走る。
- アイテム取得で長さとスコアが増える。
- 壁や障害物に当たるとゲームオーバーになる。
- 自分の体に当たったときの扱いが仕様通りになる。
- リトライ後にスコア、長さ、ステージ、音、入力状態が初期化される。
- 速度が上がっても頭、体、危険物、アイテムが読み分けられる。
- README の操作方法、テスト方法、export 方法が実装と一致している。

Nova Swarm で得た教訓は、AI を「ゲームを作る魔法のボタン」として使うより、「Godot プロジェクトを継続的に改善する共同開発者」として使う方が安定する、という点です。工程を分け、責務を狭くし、実行確認と docs 更新まで同じ流れに含めることで、Godot でも Codex の作業品質を保ちやすくなります。
