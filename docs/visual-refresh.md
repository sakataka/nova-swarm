# Nova Swarm ビジュアル制作仕様

2026-09-09 / 内蔵 `image_gen` を使用。モデル番号を指定・取得できないため、モデルの版は未確認。

## 世界観と役割

母星の軌道ゲートを奪還する共鳴技術の迎撃機と、炉心を共有する自律艦隊の戦い。形状と素材は同じ硬質なアニメ宇宙戦調に揃え、陣営は明度と発光色で区別する。

| 対象 | 見た目の意味 |
| --- | --- |
| 自機 | 白いセラミック、コバルトのパネル、シアンの操縦席。細い矢じりと短い翼で、操作する機体を明確にする |
| 共鳴制御ポッド | 自機と同じ素材の小型無人機。Overdrive中だけ左右へ展開し、結晶化する共鳴場を制御する。独立した武器ではない |
| bug | 小さな甲虫型。単純な量産偵察ドローン |
| diver | 長い針型。縦方向の急降下を示す細い船体 |
| zig | ジグザグの翼。左右へ動く機動艦 |
| armor | 厚い矩形装甲と側面砲。耐久力がある重装艦 |
| saucer | 円盤と放射状の兵装。側方から回り込む艦 |
| commander | 冠状センサーと大きな翼。編隊を率いる指揮艦 |
| mid_lancer | 三連砲を持つ槍型駆逐艦 |
| mid_orbit | 開いた環状構造と放射状エミッター |
| mid_anchor | 幅広い装甲とミサイル区画を持つ要塞艦 |
| NOVA SOVEREIGN | 中ボスより巨大な中枢艦。銅の冠と3基の破壊可能な炉心 |

敵の共通色は黒い装甲・銅の縁・赤橙の炉心。敵弾も同じ暖色にし、自弾はシアン、強化弾は白金色とする。チップは既存のPOWER / SPREAD / RESONANCEの色と対応を保つ。

## 制作プロンプト仕様

以下は各生成に与えた最終的な制作条件の整理。発進・帰還は生成した自機を参照し、ボスは炉心位置の修正と背景の再指定を行った。原画は内蔵ツールの出力先に保持し、ゲームに必要な画像はすべてリポジトリへ保存した。

共通指示: “NOVA SWARM, sophisticated clean cel-shaded anime hard-surface orbital shooter. Strong readable silhouettes, restrained detail and bloom. No text, labels or grid lines. Sprite bodies are orthographic top-down, fully contained, with extraction padding. Player: white ceramic / cobalt / cyan / restrained gold. Enemy: charcoal / copper / red-orange.”

| 保存先 (`public/assets/refresh/`) | 生成条件 |
| --- | --- |
| player.png | One heroic rescue interceptor, nose UP, long arrowhead fuselage, short swept wings, cyan cockpit, twin engine nozzles, no detached FX, solid magenta extraction background |
| fleet.png | Exactly 3×3 distinct enemy ships, nose DOWN. Row-major: beetle scout, needle diver, lightning-chevron skirmisher, rectangular armored tank, circular saucer, crowned manta commander, triple-barrel lancer, open-ring orbit cruiser, broad anchor fortress. Strong silhouette differences |
| boss.png | One immense crowned command fortress, nose DOWN, charcoal and copper, exactly three orange reactor modules. Move central reactor down onto lower fuselage; keep side reactors. Final correction replaces checkerboard with solid magenta |
| pod.png | One compact autonomous resonance control pod, white/cobalt diamond-shaped device, cyan lens, articulated fins, gold trim, twin small thrusters, nose UP; manufactured craft, not an abstract mote |
| backgrounds.png | Exactly 2 columns × 3 rows, six dark backgrounds with empty combat centers: blue planet/gate, violet front, twin comets, copper asteroid belt, three fortresses, enemy crown/eclipse |
| title.png | Reference hero ship in orbital launch bay with two matching pods, restored identity, blue planet and gate beyond, upper central 40% quiet for title, bottom quiet for controls, 4:3 |
| ending.png | Reference hero and two pods returning over blue planet at dawn, restored cyan gate, receding enemy wreckage, peaceful gold/cobalt panoramic 3:1 |
| projectiles.png | 2×2: upward cyan needle, white-gold double lance, orange round enemy pellet, red-orange enemy teardrop. Bright bounded cores and readable shapes |
| beam_player.png / beam_enemy.png | Parallel sustained energy shafts with quiet constant-width middle, friendly cyan/gold and enemy vermilion/white, alpha preserved |
| explosions.png | 2×2 sequential reactor explosion: ignition, fireball, expanding ring, fading embers. Same origin and shared processing scale |
| icons.png | 3×3 cockpit icons: power lance, spread arrows, resonance rings, life ship, shield hexagon, bomb charge, overdrive emitter, chain links, boss crown. No baked-in text |
| panel.png | Empty wide dark navy glass with very thin cobalt/cyan edges, white ceramic corners and tiny gold rivets. No internal markings or text |
| shield.png | 2×2 same thin segmented cyan shield, tiny mechanical projector tips, pulsing perimeter, large empty center, stable scale |
| props.png / rock.png / mote.png | 2×2 compact props: dark copper-veined asteroid, cyan/gold collectible crystal, active orange reactor, same reactor broken and unlit |

## 組み込み

- `generate2dsprite` のプロセッサでマゼンタ除去、切り抜き、中央配置、縮小とグリッド化を実施。生成時に付いたalphaは維持する。原画の行位置が均等でない敵・アイコンは、実際の余白で切り分けてから固定セルへ再配置した。
- `asset-qc.json` に原画ID、抽出範囲、スケール、セル情報を記録。原画の微弱な発光・孤立ピクセルによる境界フラグと、納品セルの透明余白は区別して確認する。
- 自機は92×92の固定描画枠。強化中も拡大や黄色への全面着色をせず、中心を表示する。シールドは118〜126の枠で半透明にする。
- 制御ポッドは左右56px付近へ展開して小さく浮遊する。回転する大きなアイコンを廃止し、粒子は小さな結晶に限定する。
- ボス本体は380×396、原点はボス中心から(-190,-157)。原画の左右・中央炉心が既存の(-96,18)、(96,18)、(0,104)の部位判定と重なる。破壊後は同じ位置を暗い損傷モジュールに置き換える。
- フォントは同梱Oxaniumの500/700。スコア・残機も文字として描画し、旧ドット数字と画像内文字を混在させない。
- HP、攻撃パターン、衝突判定、成長、得点処理は変更しない。

## 確認対象

通常編隊、3体の中ボスとOverdrive、最終ボスと部位破壊、タイトル、ポーズ、ゲームオーバー、6面分の結果表をGodotの実描画で確認。Web版はプロジェクトの標準Godot 4.7と既存の4.7テンプレートで書き出す。

検証結果: スモーク、ゲームプレイ、最終ボス戦テストをGodot 4.7で通過。AI通し（seed 20260501、720秒上限）は281.28秒でVICTORY、スコア518563、残機3。ブラウザの1280×720、420×912、390×844で描画を確認し、タイトルのモード選択と開始を操作した。ブラウザコンソールに警告・エラーなし。タッチイベント経路は既存ゲームプレイテストで確認したが、iPhone実機での操作は未確認。縦表示は既存の4:3固定画面のため上下に余白が残る。
