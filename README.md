# Nova Swarm

Godot 4.7 + GDScript で作る高コントラストなアニメ宇宙戦調の2Dシューティングゲームです。編隊戦、急降下、戦闘中のチップ成長、複数中ボス、部位破壊型の最終ボスを、約5分の6ステージにまとめています。

敵艦隊は炉心を共有する「共鳴ネットワーク」でつながっており、撃破の順番で連鎖の広がりが変わります。戦闘はBGMのビートに同期し、AI DEMOではAIの思考をホログラム表示で観戦できます。

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
| Resonance Overdrive（HUD・タッチ表記は `DRIVE`） | `E`（ビートに合わせると PERFECT SYNC） |
| AI思考ホログラム表示の切替 | `V`（AI DEMO中） |
| ポーズ | `P` または `Esc`（ポーズメニューから再開・リスタート・タイトルへ戻る） |
| ミュート | `M` |
| モーション軽減 | タイトル・ポーズで `R`、または `MOTION FULL` / `MOTION LOW` をクリック・タップ |
| モード選択 | タイトル画面でクリック、または `A` / `D`・`←` / `→` |
| AIの性格選択 | AI DEMO選択中に `W` / `S`・`↑` / `↓`、または選択中の `AI DEMO` を再クリック |
| 開始 / リスタート | タイトル画面の `DEPLOY` をクリック、または `Enter`。ゲームオーバー・クリア画面では `RETRY` / `PLAY AGAIN` と `TITLE` をクリック・タップ、または矢印キーで選んで `Enter` |
| キーボードフォーカス | タイトルでは `Tab` / `Shift+Tab` でモード・出撃・音・モーションを選び、`Enter` で実行。ポーズ・結果では `Tab` または矢印キーでメニューを選択 |
| タッチ操作 | タッチ端末では左下スティック、右下 `SHOT` / `BOMB` / `DRIVE`、右上 `PAUSE`。縦長画面ではゲーム画面の下に操作パッドを出し、タイトル・ポーズ・結果画面のボタンもその領域に大きく並べる |

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
scripts/fx_layer.gd
scripts/ui_layer.gd
scripts/beat_clock.gd
scripts/resonance_network.gd
scripts/ai_pilot.gd
scripts/audio_manager.gd
scripts/smoke_test.gd
scripts/gameplay_test.gd
scripts/ai_boss_stage6_test.gd
public/assets/refresh/
public/assets/fonts/Oxanium-wght.ttf
export_presets.cfg
```

`scripts/game.gd` は `GameController` として各サブシステムを束ねます。ステージ、ウェーブ、中ボス、成長チップ、敵、HUD用数字などの調整値は `scripts/game_config.gd` に集約しています。

Godot プロジェクトを Codex / MCP / 自動テストと組み合わせて継続開発する方針は [`docs/godot-ai-development-workflow.md`](docs/godot-ai-development-workflow.md) にまとめています。Nova Swarm の責務分割を、次の Godot プロジェクトや伸ばすワーム系ゲームへ移すための制作メモです。

主な分割:

- `player.gd`: 自機のライフ、ボム、無敵、連続撃破チェイン、3系統のチップ成長
- `enemy_swarm.gd`: 通常ウェーブの編隊、急降下、中ボスの行動と同時攻撃制御
- `boss_controller.gd`: ボスのフェーズ、攻撃、ビーム予兆、部位破壊
- `projectile_manager.gd`: 自弾・敵弾、分岐ショットの生成と更新
- `hud.gd`: 固定HUD、面名とウェーブ区切り、3系統の成長状態、ボスHP/Overdrive（DRIVE）ゲージ
- `fx_layer.gd`: ワールドとUIの間に描く加算合成の発光レイヤー。火花、衝撃リング、破片、電撃、ポップアップを管理します。演出用の乱数はゲーム側の乱数と分けており、同一seedの結果に影響しません
- `ui_layer.gd`: HUD・オーバーレイ・タッチ操作を発光レイヤーより手前に描く層
- `beat_clock.gd`: 再生中BGMのBPMに合わせたビート時計。ゲーム時間で進め、実際に音が出ている場合は再生位置で位相を補正します
- `resonance_network.gd`: 敵編隊の共鳴リンク、サージの伝播、連鎖数、指揮艦撃破時のネットワーク崩壊
- `ai_pilot.gd`: AI Pilotの回避・攻撃判断、性格ごとの重み、観戦オーバーレイ用の思考データ
- `audio_manager.gd`: 多層インパクトSFX、連打抑制、ピッチ揺らぎ、Overdrive用BGMレイヤー、クロスフェード、ミュート、Masterリミッター、headless時の音声無効化

## 主なゲームシステム

### 共鳴ネットワーク

- 通常編隊の敵は上下左右の隣とリンクし、指揮艦はハブとして最上段の近い敵とつながります。中ボス同士もリンクします。
- 敵を撃破するとリンクを伝ってサージが走り、隣の敵に1ダメージを与えます。サージで撃破した敵からはさらに先へ伝わり、連鎖数に応じて得点倍率が上がります（`CHAIN xN`）。
- ビートに合わせた撃破はサージが1段遠くまで届き、Overdrive中はさらに2段伸びます。ビートとOverdriveが重なるとサージのダメージが2になります。
- 耐久の高い敵はサージを受けても残るため連鎖を止めます。どこから崩すかが攻略の判断になります。
- 急降下中の敵や、距離が離れすぎたリンクは一時的に途切れます。
- 急降下中に撃破した敵からはサージを送らず、編隊へ戻った敵は再び共鳴します。
- 指揮艦を倒すとネットワーク全体が崩壊し、つながっていた全ての敵に波状のサージが届き、短時間スタン（射撃不能）になります。
- 中ボスを倒すと、リンク先の中ボスに最大HPの20%のサージが入ります。最終ボスは左右の炉心を壊すと中央炉心が過負荷（OVERLOAD）になり、追加ダメージが入ります。

### ビート同期

- 敵とボスの弾は、発射タイマーで装填された後、次のビートで発射されます。装填中の敵は炉心が光り、閉じていくリングで発射タイミングを予告します。
- 小節の頭では数体が同時に装填し、リズムに合わせた一斉射撃になります。
- ビートに合わせてOverdriveを発動すると PERFECT SYNC となり、効果時間が1秒延びてボーナス得点が入ります。ビートに合わせたかすりはResonanceの獲得量が増えます。
- 編隊の脈動、画面左右のリズムレール、小節ごとのスイープ、HUDのビート表示（Overdriveゲージ下の4点）がBGMと同期します。

### AI観戦モード（AI DEMO）

- AIの思考をホログラム表示します。評価した移動候補（危険度で色分け）、選んだ移動先と経路、敵弾の予測線、狙っている敵のロックオン枠を表示し、左上にAIの性格・現在の判断（ATTACK / EVADE / CHAIN HUNT / SYNC WAIT など）・危険度を出します。`V` で表示を切り替えます。
- 6連鎖、ネットワーク崩壊、中ボス撃破、炉心破壊、ぎりぎりのかすりでは、スローモーションとカメラの寄り、上下の黒帯で見せ場を演出します。
- AIの性格は BALANCED / AGGRESSIVE / CAREFUL から選べます。AGGRESSIVEは連鎖狙いと前進を優先し、CAREFULは危険回避とアイテム回収を優先します。
- AI DEMOの最高スコアの推移を保存し、手動プレイ中は右上に同じ経過時間のAIとのスコア差（`VS AI`）を表示します。

### その他

- 6ステージ構成です。3面最終ウェーブは中ボス2体、5面は中ボス3体が登場します。5面では3体が常時一斉攻撃せず、最大2体が攻撃し1体が休むローテーションになります。6面は最終ボス `NOVA SOVEREIGN` 戦です。
- 面と面の間に選択画面は挟みません。敵が落とす色付きチップを戦闘中に集め、`POW`（火力・連射）、`SPR`（拡散）、`RES`（Resonance・Overdrive）を各4段階まで成長させます。3個でレベルアップし、被弾時に失うのは未完成の進捗だけです。
- 通常面は `5 / 6 / 4 / 5 / 4` ウェーブへ圧縮し、約0.55秒で次の編隊へ接続します。面クリアも短いバナーだけで次へ進みます。面クリア時はシールド全回復、中ボス撃破時もシールド回復のチェックポイントになり、低残機時には面クリアで1機修復されます。
- 4面では破壊可能な岩障害物、5面では敵弾を跳ね返すプラズマ壁が出ます。
- Resonance Overdrive中は近くの敵弾をスコア結晶に変換し、攻めながら危険を得点へ変えられます。Overdrive中は白・コバルトの共鳴制御ポッドが左右へ展開します。ポッドは敵弾を結晶化する共鳴場の制御装置という位置づけで、独立した射撃・攻撃判定は持ちません。変換された発光結晶は自機へ吸引され、回収時に得点へ加算されます。近距離撃破もOverdrive維持に寄与します。
- ボスは複数の破壊可能部位を持ち、部位を壊すと攻撃テンポやビーム行動に影響します。
- リザルトにはランクに加えて次回改善ヒントを表示します。スコア、チェイン、被弾、ボム使用、クリア時間を見て改善先を出します。
- 手動プレイの自己ベストを保存し（`user://best_score.json`）、タイトルとリザルトに表示します。更新時は `NEW BEST` を出します。AI DEMOのスコアは自己ベストに含めません。
- 致命的な被弾で終了したフレームは、その後のアイテム回収や面クリア報酬を加算せず、最終スコアと自己ベストを一致させます。
- AI Pilotはタイトル画面の `AI DEMO` から開始できます。プレイ中の操作モード切り替えはなく、通常プレイのテンポを妨げません。
- タッチ端末のAI DEMOにも `PAUSE` を表示し、観戦の途中でもメニューから再開・リスタート・タイトルへの移動ができます。
- タイトルとメニューはタッチを1回だけ処理し、Godotが補助的に生成するマウス入力ではAIの性格選択などを重複実行しません。
- リスタート、タイトルへの移動、バックグラウンド化でタッチ入力を解除し、古い移動・射撃・DRIVE入力を次のプレイへ持ち越しません。AI DEMOのポーズ画面は自動操縦・性格と観戦用の操作を案内します。

## アセット

2026-09-09に、内蔵画像生成機能でゲーム内の画像を全面刷新しました。素材は `public/assets/refresh/` にまとめています。使用ツールからモデル番号は取得できないため、特定の画像モデルの版は記録していません。

- `player.png` / `pod.png`: 白・コバルト・シアンの自機と共鳴制御ポッド。自機の表示サイズは強化中も一定で、中央の小さなマーカーが衝突判定の中心を示します。
- `fleet.png`: 通常敵6種と中ボス3種。黒い装甲・銅の縁・赤橙の炉心を共通にし、虫型、針型、ジグザグ翼、重装甲、円盤、指揮艦、三連砲、環状艦、要塞艦の輪郭で役割を区別します。
- `boss.png` / `props.png`: 最終ボスと破壊可能な炉心の生存・破壊後表示。炉心の位置は既存の部位判定に合わせています。
- `backgrounds.png`: 母星のゲートから敵の中枢まで進む6面の背景。2列×3行で、各面の中央は暗く保ちます。
- `title.png` / `ending.png`: 同じ自機と2基のポッドが出撃し、母星へ帰還する一続きのシーン。
- `projectiles.png` / `beam_player.png` / `beam_enemy.png` / `explosions.png`: シアンの自弾、白金の強化弾、赤橙の敵弾・ビーム、4段階の炉心爆発。
- `icons.png` / `panel.png` / `shield.png`: 操縦席と同じ素材のHUD・操作パネル・成長チップ・シールド。シールドの中央は空け、機体を隠しません。
- `rock.png` / `props.png` / `mote.png`: 銅鉱脈の岩、回収する共鳴結晶、小さな粒子。
- `public/assets/fonts/Oxanium-wght.ttf`: タイトル、HUD、スコア・残機などの数字、ポーズ、結果画面で共通使用。画像へ文字を焼き込まず、同梱のSIL Open Font License 1.1で利用します。

世界観・各素材の制作指示と配置は [ビジュアル制作仕様](docs/visual-refresh.md) に記録しています。旧画像は履歴参照用として残していますが、ゲームの描画では読み込みません。

- `public/assets/audio/music/*.wav`: Music Creator（ACE-Step / MLX）で制作したBGM6曲とOverdrive用追加レイヤー3曲。アナログシンセ、アルペジオ、電子ドラムを軸に、アニメ宇宙戦の雰囲気へ統一しています。効果音は従来どおりです。
- `bgm-request.json`: 全9曲の用途・曲調・指定BPMを記録した制作依頼。
- `public/assets/audio/music/manifest.json`: セットID、生成条件、納品ファイル名、音声の技術検査、ループ区間。生成時の指定BPMをビート時計にも使用しますが、生成音声の拍位置・テンポの厳密な一致は保証されません。

| ファイル | 場面 | 指定BPM | 生成尺 |
| --- | --- | --- | --- |
| `title.wav` | 発進前の期待感を出すタイトル | 116 | 60秒 |
| `stage_drive.wav` | 序盤の通常戦 | 132 | 60秒 |
| `stage_pressure.wav` | 3〜5面の後半戦 | 162 | 60秒 |
| `boss_core.wav` | 6面の最終ボス | 140 | 60秒 |
| `victory_clear.wav` | 全面クリアの結果画面 | 132 | 30秒 |
| `game_over.wav` | ゲームオーバーの結果画面 | 72 | 30秒 |
| `overdrive_drive.wav` | 序盤戦のOverdrive追加レイヤー | 132 | 30秒 |
| `overdrive_pressure.wav` | 後半戦のOverdrive追加レイヤー | 162 | 30秒 |
| `overdrive_boss.wav` | ボス戦のOverdrive追加レイヤー | 140 | 30秒 |

全曲をループ再生します。Music Creatorで先頭と末尾を0.25秒重ねて継ぎ目をならすため、納品尺は生成尺より0.25秒短くなります。音楽的なつながりの自然さは技術検査では判定されません。Overdriveレイヤーは打楽器中心で依頼し、開始時に本編BGMの再生位置をレイヤーの尺へ折り返して合わせます。別々に生成した音源のため、拍やフレーズの完全一致を保証するものではありません。

再取得は `music-create` スキルのCLIで行えます。セットIDはmanifestを参照してください。同じ依頼の送信は既存セットを返します。

```bash
bun run --cwd /Users/sakataka/Documents/music-creator music-create submit "$PWD/bgm-request.json"
bun run --cwd /Users/sakataka/Documents/music-creator music-create status <set-id> --wait
bun run --cwd /Users/sakataka/Documents/music-creator music-create fetch <set-id> --out "$PWD/public/assets/audio/music"
```

## ゲーム品質改善

- Input Map 経由の操作に変更し、キーボードとゲームパッド入力を扱いやすくしています。
- Godot 4.7環境に更新し、iPhoneやWebのタッチ端末では画面上に仮想スティックとショット/ボム/Overdrive/ポーズボタンを出します。Web版は `?touch=1` でデスクトップ検証用に強制表示できます。
- 自機は左右だけでなく上下にも移動でき、敵弾や急降下の避け方を2D空間で選べるようにしています。AI Pilotも2D移動候補から安全位置を選びます。
- スコアチェイン、ノーミスステージボーナス、成績に応じた軽い難易度補正を追加しています。
- 敵弾のかすり、連続撃破、ボスヒットで溜まるResonanceゲージと、満タン時に発動できるOverdriveを追加しています。Overdriveはプレイ時間の約2割だけ発動する切り札として、ゲージの獲得量と延長量を調整しています。
- Overdrive中に敵弾をスコア結晶へ変換し、攻撃的な回避に得点上の価値を持たせています。
- Overdrive中は通常戦、後半戦、ボス戦それぞれの生成済み追加レイヤーを重ねてテンションを上げます。通常の再生経路はAudioStreamPlayerで、Resonate経路でも同じ音源をstemとして利用できます。
- BGMは単一の再生経路で確実にループし、通常時・Overdrive時・ポーズ時の音量差を明確にしています。duck解除や曲切り替えは短いフェードで処理し、SFXの短時間連打とMasterバスのピークも抑えています。
- Web版はタブを閉じる、別アプリへ移る、画面を非表示にするなどの終了・バックグラウンド操作でBGMと効果音を停止し、ゲーム画面へ戻った場合だけ現在のBGMを再開します。
- Web版のタイトル曲は画面表示時に再生を要求します。ブラウザの自動再生制限で音声が保留されている間は `START SOUND` を表示し、一度のクリック・タッチ・キー入力で音声が開始します。出撃やモード選択の入力でも開始し、実際のAudioContextが再開してから現在のBGMを再要求します。`START SOUND` を押すためにOFF→ONへ切り替える必要はありません。自動再生が許可されている環境では初めから `SOUND ON` になります。
- ステージ専用ギミック、戦闘中チップ成長、複数中ボス、ボス部位破壊、リザルト改善ヒントを追加しています。
- HUDは画面揺れから分離し、スコア、ステージ／ウェーブ、ライフ、ボム、シールド、3系統の成長、Overdrive、ボスHPを上端に固定しています。
- HUDはスコア、ステージ番号と面名、ウェーブ数ぶんの区切りゲージ、`POW` / `SPR` / `RES` のラベル付き成長表示、`DRIVE` ゲージとビート表示、残機・ボム・シールドをまとめ、細い罫線で区分します。スコア・残機を含むすべての動的テキストはOxaniumへ統一し、割当幅に応じて縮小または省略します。
- UI/UXは発進ベイを基準に、白い装甲、コバルトのガラス、シアンの発光、控えめな金へ統一しています。機体、背景、チップ、シールドは実画像を使い、メニューとHUDの枠は解像度に合わせてシャープに描画します。
- タッチUIはiPhone Air相当の縦長表示でも押しやすいよう、仮想スティック、`SHOT`、`BOMB`、`DRIVE`、`PAUSE`の表示とヒットボックスを大きめに調整しています。`BOMB` は残数バッジ、`DRIVE` はゲージの溜まり具合をリングで示し、満タンで `READY` と光ります。
- Overdriveが使えるようになると、手動プレイではHUD下に `DRIVE READY` と押すキー（タッチでは `TAP DRIVE`）を点滅表示します。
- ステージ開始時は面番号と面名、1面ではキーボード操作の一覧を中央の空きレーンに出します。ウェーブ切り替えは小さな `WAVE n / m` 表示、面クリアはランクと回復内容（ボム・シールド・残機）を表示します。
- ポーズ画面は `RESUME` / `RESTART` / `TITLE` のメニューと、キーボードかタッチかに合わせた操作一覧を出します。ゲームオーバー・クリア画面は最終スコア、自己ベスト、到達ステージ、面ごとの成績表と、再挑戦・タイトルへ戻るボタンを出します。
- タイトルは各モードに `YOU FLY` / `WATCH THE AI` の説明を付け、AI DEMO選択中は性格を表示します。画面下に操作ヒントを出します。
- 自機、敵艦隊、中ボス、6面ボス、6面分の背景を新しい生成スプライトへ差し替えています。
- ショット、着弾、爆発、チップ取得、レベルアップ、中ボス撃破、面クリアは、複数の短い波形を重ねた専用SFXにし、同音の過密な連打も抑制しています。
- 爆発、被弾、ボム、ステージ開始、ボス攻撃に画面揺れ、フラッシュ、ヒットストップ、予兆を追加しています。
- 描画はワールド、加算合成の発光、UIの3層に分けています。弾・エンジン炎・炉心・アイテムの発光、被弾時の白フラッシュ、機体の傾き、急降下の残像、撃破時の破片・火花・衝撃リングを出します。
- 背景は自機の位置に合わせてゆっくりずれる視差表示にし、奥・中・手前の3層の星を流します。面の切り替えでは星が伸びるワープ演出になります。
- 通常敵のHPバーは廃止し、被弾時の色の変化と白フラッシュで耐久を伝えます。中ボスのHPバーは細くしています。
- 急降下中の敵とボスビームにはDanger Lineを表示し、危険レーンを事前に読みやすくしています。
- `armor` は3HPになり、敵ごとの役割差が出るようにしています。
- 中ボスは攻撃パターンと同時攻撃ローテーションを維持したまま、基礎HPと後半の難易度倍率を抑え、長期戦になりすぎないようにしています。
- ボスの当たり判定は矩形ではなく複数の円形ゾーンで扱い、見た目から外れた弾が消えにくいようにしています。
- AI Pilotは候補地点までの移動経路を1.6秒先まで評価し、横移動弾、ボスビーム、急降下敵を予測して回避します。安全な成長チップの回収と、通常ウェーブでの最後のボム温存も行います。
- 720秒の決定的な複数シードAI通しを基準に調整し、全6面クリアは約5〜6分です（BALANCED・seed 20260501で約310秒）。同一seedは同一結果になり、`--seed` で別パターンを検証できます。
- 同一フレーム内で破壊済みの敵や岩障害物へ再ヒットして、スコアや撃破処理が重複しないようにしています。
- ボスと岩への命中処理で、弾を消した後の座標を使っていたため部位破壊が発生しなかった不具合を修正しています。

## 検証

音楽の読み込み・9音源の末尾ループ・Overdrive再生位置・ミュート・バックグラウンド復帰（Dummy音声ドライバーでの機能検証。試聴は別途必要）:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --display-driver headless --rendering-driver dummy --audio-driver Dummy --path . --script res://scripts/audio_test.gd --log-file /private/tmp/nova-swarm-audio.log
```

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
localweb dev nova-swarm
```

port は LocalWeb が割り当てます。ブラウザで開きます。

```text
http://nova-swarm-dev.localhost/
```

タッチUIをデスクトップブラウザで強制表示する場合:

```text
http://nova-swarm-dev.localhost/?touch=1
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

### iPhone の表示

Web export は `web-shell.html` を使い、420×912px の安全領域と左端20pxの戻る操作を確保します。配色・ゲーム構図は維持します。起動時のモーション軽減設定で画面揺れ・拡大・フラッシュ・追加エフェクトを抑え、透明度軽減ではタッチ操作の背景を不透明にします。縦長のタッチ画面（高さが幅の約1.48倍以上）では、ゲーム画面を上に寄せたまま canvas を下へ広げ、その領域にスティックと `SHOT` / `BOMB` / `DRIVE` / `PAUSE` をまとめた操作パッドを出します。タイトル、ポーズ、ゲームオーバー、クリア時はこの領域にモード選択やメニューの大きなボタンを並べます。ゲーム内の構図は変えず、各ボタンは420×912pxで44px以上になります。

### 画面と体験の仕上げ（2026-10-03）

- 出撃画面は既存の発進ベイ画像を使い、Oxaniumの大きなタイトル、`Break the fleet. Ride the beat.` の説明、6ステージ・約5分の目安を配置します。デスクトップでは左の文字と中央の機体を分け、縦画面では画像・説明・モード・出撃の順に並べます。
- モード選択とメニューは細い縁と切り欠きへ整理し、シアンの面を主操作に使います。選択の縦線、マウスのホバー、キーボードのフォーカス枠で状態を区別します。タイトル背景の微小な視差とホバーの補間はモーション軽減時に停止します。
- タイトル・ポーズに `SOUND ON/OFF` と `MOTION FULL/LOW` を表示し、タッチでも変更できます。モーションはOSの初期設定を引き継ぎ、ゲーム内の選択は現在の起動中だけ保持します。
- ポーズはステージとスコア、操作一覧、再開・リスタート・タイトルを整理します。結果は桁区切りのスコアと成績を表示し、クリア時の帰還画像を4:3のまま背景に使います。
- 縦画面では、タイトルに連鎖・ビート同期の短い説明、プレイ中の操作パッドに大きなスコア・残機・シールド・ボム・DRIVE表示、ポーズに読みやすい操作一覧、結果に面ごとのスコアとランクを出します。AI観戦では現在の判断と説明、危険度を操作パッドの領域に表示します。
- Web起動待ちは発進ベイ画像と進捗表示に統一し、失敗時は理由と `RETRY FLIGHT` を表示します。Canvasにはキーボード操作の説明を付けます。ゲーム内の全情報をスクリーンリーダーへ提供する機能はありません。
- 現在の描画から参照されない旧画像群とテストスクリプトはWebエクスポートの対象外にします。旧素材はリポジトリの履歴参照用に保持します。

品質のセルフチェックでは、第一印象、独自のゲーム性の伝達、文字と余白の一貫性、選択と入力の反応、デスクトップと420×912pxの表示、モーション軽減、実行エラーを確認します。受賞の可否は外部審査によるため、このチェックの通過を受賞認定とは扱いません。
