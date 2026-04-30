import "./styles.css";

const W = 960;
const H = 720;
const HUD = 76;
const PLAY_H = H - HUD;
const PLAYER_Y = H - 58;

type Vec = { x: number; y: number };
type Bullet = Vec & { vx: number; vy: number; enemy: boolean; r: number; power: number; color: string };
type EnemyKind = "bug" | "diver" | "zig" | "armor" | "saucer";
type State = "title" | "playing" | "paused" | "stageClear" | "gameOver" | "victory";

type Enemy = {
  id: number;
  kind: EnemyKind;
  x: number;
  y: number;
  baseX: number;
  baseY: number;
  hp: number;
  maxHp: number;
  t: number;
  dive: number;
  shoot: number;
  score: number;
  size: number;
};

type Boss = {
  x: number;
  y: number;
  hp: number;
  maxHp: number;
  t: number;
  phase: number;
  shoot: number;
  beam: number;
};

type Stage = {
  name: string;
  bg: number;
  rows: number;
  cols: number;
  kinds: EnemyKind[];
  speed: number;
  fire: number;
  dive: number;
  boss?: true;
};

type Sprite = { x: number; y: number; w: number; h: number };

const sprites: Record<string, Sprite> = {
  player: { x: 30, y: 342, w: 128, h: 120 },
  bug: { x: 45, y: 72, w: 76, h: 74 },
  diver: { x: 274, y: 72, w: 134, h: 150 },
  zig: { x: 526, y: 79, w: 68, h: 170 },
  armor: { x: 735, y: 83, w: 105, h: 156 },
  saucer: { x: 942, y: 84, w: 109, h: 64 },
  bomb: { x: 630, y: 356, w: 74, h: 96 },
  boss: { x: 584, y: 708, w: 600, h: 458 },
  boom1: { x: 38, y: 548, w: 86, h: 82 },
  boom2: { x: 186, y: 538, w: 130, h: 110 },
  boom3: { x: 403, y: 529, w: 150, h: 120 }
};

const bgPanels: Sprite[] = [
  { x: 14, y: 12, w: 599, h: 431 },
  { x: 642, y: 12, w: 599, h: 431 },
  { x: 14, y: 462, w: 599, h: 403 },
  { x: 642, y: 462, w: 599, h: 403 },
  { x: 14, y: 881, w: 1227, h: 359 }
];

const stages: Stage[] = [
  { name: "STAR DRIFT", bg: 0, rows: 3, cols: 8, kinds: ["bug", "bug", "diver"], speed: 24, fire: 1.2, dive: 0.45 },
  { name: "VENOM NEBULA", bg: 1, rows: 4, cols: 8, kinds: ["bug", "zig", "diver"], speed: 32, fire: 1.8, dive: 0.8 },
  { name: "ROCK BELT", bg: 2, rows: 4, cols: 9, kinds: ["armor", "bug", "zig"], speed: 36, fire: 2.2, dive: 1.0 },
  { name: "PLASMA NEST", bg: 3, rows: 5, cols: 9, kinds: ["saucer", "zig", "armor", "diver"], speed: 42, fire: 2.7, dive: 1.35 },
  { name: "CITADEL CORE", bg: 4, rows: 0, cols: 0, kinds: [], speed: 0, fire: 0, dive: 0, boss: true }
];

const enemyStats: Record<EnemyKind, { hp: number; score: number; size: number; color: string }> = {
  bug: { hp: 1, score: 120, size: 34, color: "#78ff69" },
  diver: { hp: 2, score: 240, size: 44, color: "#b76cff" },
  zig: { hp: 1, score: 180, size: 36, color: "#39eaff" },
  armor: { hp: 4, score: 420, size: 46, color: "#8dff5d" },
  saucer: { hp: 3, score: 360, size: 44, color: "#ff57f0" }
};

const digitMap: Record<string, string[]> = {
  "0": ["111", "101", "101", "101", "111"],
  "1": ["010", "110", "010", "010", "111"],
  "2": ["111", "001", "111", "100", "111"],
  "3": ["111", "001", "111", "001", "111"],
  "4": ["101", "101", "111", "001", "001"],
  "5": ["111", "100", "111", "001", "111"],
  "6": ["111", "100", "111", "101", "111"],
  "7": ["111", "001", "010", "010", "010"],
  "8": ["111", "101", "111", "101", "111"],
  "9": ["111", "101", "111", "001", "111"],
  " ": ["000", "000", "000", "000", "000"]
};

class Synth {
  private ctx?: AudioContext;
  private master?: GainNode;
  private timer = 0;
  muted = false;

  async start() {
    if (!this.ctx) {
      this.ctx = new AudioContext();
      this.master = this.ctx.createGain();
      this.master.gain.value = 0.18;
      this.master.connect(this.ctx.destination);
      this.loop();
    }
    if (this.ctx.state === "suspended") await this.ctx.resume();
  }

  toggle() {
    this.muted = !this.muted;
    if (this.master) this.master.gain.value = this.muted ? 0 : 0.18;
  }

  sfx(name: "shot" | "hit" | "boom" | "bomb" | "hurt" | "boss" | "clear") {
    if (!this.ctx || !this.master || this.muted) return;
    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    const table = {
      shot: [760, 0.055, "square"],
      hit: [180, 0.09, "sawtooth"],
      boom: [70, 0.28, "sawtooth"],
      bomb: [90, 0.7, "triangle"],
      hurt: [110, 0.22, "square"],
      boss: [55, 0.9, "sawtooth"],
      clear: [520, 0.45, "triangle"]
    } as const;
    const [freq, len, type] = table[name];
    osc.type = type;
    osc.frequency.setValueAtTime(freq, now);
    osc.frequency.exponentialRampToValueAtTime(Math.max(30, freq * 0.35), now + len);
    gain.gain.setValueAtTime(name === "bomb" || name === "boss" ? 0.35 : 0.22, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + len);
    osc.connect(gain);
    gain.connect(this.master);
    osc.start(now);
    osc.stop(now + len);
  }

  private loop() {
    if (!this.ctx || !this.master) return;
    const notes = [110, 146.83, 164.81, 220, 196, 164.81, 146.83, 130.81];
    const tick = () => {
      if (!this.ctx || !this.master) return;
      if (!this.muted) {
        const now = this.ctx.currentTime;
        const note = notes[this.timer % notes.length];
        const bass = this.ctx.createOscillator();
        const lead = this.ctx.createOscillator();
        const g = this.ctx.createGain();
        bass.type = "square";
        lead.type = this.timer % 4 === 0 ? "triangle" : "square";
        bass.frequency.value = note;
        lead.frequency.value = note * (this.timer % 8 === 7 ? 3 : 2);
        g.gain.setValueAtTime(0.055, now);
        g.gain.exponentialRampToValueAtTime(0.001, now + 0.18);
        bass.connect(g);
        lead.connect(g);
        g.connect(this.master);
        bass.start(now);
        lead.start(now + 0.02);
        bass.stop(now + 0.18);
        lead.stop(now + 0.12);
      }
      this.timer += 1;
      window.setTimeout(tick, 190);
    };
    tick();
  }
}

class Game {
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private spriteImg = new Image();
  private spriteSource?: CanvasImageSource;
  private bgImg = new Image();
  private keys = new Set<string>();
  private synth = new Synth();
  private state: State = "title";
  private stage = 0;
  private score = 0;
  private lives = 3;
  private bombs = 3;
  private playerX = W / 2;
  private invuln = 0;
  private shotCd = 0;
  private bombCd = 0;
  private enemies: Enemy[] = [];
  private bullets: Bullet[] = [];
  private explosions: Array<Vec & { t: number; big: boolean }> = [];
  private boss?: Boss;
  private stageTimer = 0;
  private swarmDir = 1;
  private nextId = 1;
  private last = performance.now();

  constructor(canvas: HTMLCanvasElement) {
    this.canvas = canvas;
    const ctx = canvas.getContext("2d");
    if (!ctx) throw new Error("Canvas 2D context is unavailable");
    this.ctx = ctx;
    this.ctx.imageSmoothingEnabled = false;
    this.spriteImg.onload = () => {
      this.spriteSource = makeBlackTransparent(this.spriteImg);
    };
    this.spriteImg.src = "/assets/spritesheet.png";
    this.bgImg.src = "/assets/backgrounds.png";
    this.bind();
    if (new URLSearchParams(location.search).has("autostart")) this.reset();
    requestAnimationFrame(this.frame);
  }

  private bind() {
    window.addEventListener("keydown", async (ev) => {
      if (["ArrowLeft", "ArrowRight", "Space", "ShiftLeft", "ShiftRight"].includes(ev.code)) ev.preventDefault();
      await this.synth.start();
      if (ev.code === "Enter" && (this.state === "title" || this.state === "gameOver" || this.state === "victory")) this.reset();
      if (ev.code === "KeyP" && this.state === "playing") this.state = "paused";
      else if (ev.code === "KeyP" && this.state === "paused") this.state = "playing";
      if (ev.code === "KeyM") this.synth.toggle();
      this.keys.add(ev.code);
    });
    window.addEventListener("keyup", (ev) => this.keys.delete(ev.code));
  }

  private reset() {
    this.stage = 0;
    this.score = 0;
    this.lives = 3;
    this.bombs = 3;
    this.playerX = W / 2;
    this.state = "playing";
    this.loadStage(0);
    this.synth.sfx("clear");
  }

  private loadStage(index: number) {
    this.stage = index;
    this.stageTimer = 0;
    this.bullets = [];
    this.explosions = [];
    this.enemies = [];
    this.boss = undefined;
    this.playerX = W / 2;
    this.invuln = 1.4;
    const st = stages[index];
    if (st.boss) {
      this.boss = { x: W / 2, y: HUD + 142, hp: 520, maxHp: 520, t: 0, phase: 0, shoot: 0.5, beam: 0 };
      this.synth.sfx("boss");
      return;
    }
    const startX = 148;
    const startY = HUD + 68;
    const gapX = 84;
    const gapY = 58;
    for (let r = 0; r < st.rows; r += 1) {
      for (let c = 0; c < st.cols; c += 1) {
        const kind = st.kinds[(r + c) % st.kinds.length];
        const stats = enemyStats[kind];
        this.enemies.push({
          id: this.nextId++,
          kind,
          x: startX + c * gapX,
          y: startY + r * gapY,
          baseX: startX + c * gapX,
          baseY: startY + r * gapY,
          hp: stats.hp,
          maxHp: stats.hp,
          t: Math.random() * 10,
          dive: 0,
          shoot: 0.8 + Math.random() * 2.2,
          score: stats.score,
          size: stats.size
        });
      }
    }
  }

  private frame = (now: number) => {
    const dt = Math.min(0.033, (now - this.last) / 1000);
    this.last = now;
    if (this.state === "playing") this.update(dt);
    this.draw();
    requestAnimationFrame(this.frame);
  };

  private update(dt: number) {
    this.stageTimer += dt;
    this.invuln = Math.max(0, this.invuln - dt);
    this.shotCd = Math.max(0, this.shotCd - dt);
    this.bombCd = Math.max(0, this.bombCd - dt);

    const move = (this.keys.has("ArrowRight") || this.keys.has("KeyD") ? 1 : 0) - (this.keys.has("ArrowLeft") || this.keys.has("KeyA") ? 1 : 0);
    this.playerX = clamp(this.playerX + move * 430 * dt, 42, W - 42);
    if (this.keys.has("Space") && this.shotCd <= 0) this.firePlayer();
    if ((this.keys.has("ShiftLeft") || this.keys.has("ShiftRight") || this.keys.has("KeyB")) && this.bombCd <= 0) this.useBomb();

    this.updateEnemies(dt);
    this.updateBoss(dt);
    this.updateBullets(dt);
    this.updateExplosions(dt);
    this.checkCollisions();
    this.checkStageEnd();
  }

  private firePlayer() {
    this.shotCd = 0.14;
    this.bullets.push({ x: this.playerX - 12, y: PLAYER_Y - 44, vx: 0, vy: -660, enemy: false, r: 4, power: 1, color: "#49dfff" });
    this.bullets.push({ x: this.playerX + 12, y: PLAYER_Y - 44, vx: 0, vy: -660, enemy: false, r: 4, power: 1, color: "#49dfff" });
    this.synth.sfx("shot");
  }

  private useBomb() {
    if (this.bombs <= 0) return;
    this.bombCd = 0.55;
    this.bombs -= 1;
    this.synth.sfx("bomb");
    this.bullets = this.bullets.filter((b) => !b.enemy);
    for (const e of this.enemies) {
      e.hp = 0;
      this.explosions.push({ x: e.x, y: e.y, t: 0, big: false });
      this.score += Math.floor(e.score * 0.55);
    }
    this.enemies = this.enemies.filter((e) => e.hp > 0);
    if (this.boss) {
      this.boss.hp = Math.max(0, this.boss.hp - 80);
      for (let i = 0; i < 8; i += 1) this.explosions.push({ x: this.boss.x - 190 + i * 55, y: this.boss.y + Math.sin(i) * 42, t: 0, big: true });
    }
  }

  private updateEnemies(dt: number) {
    const st = stages[this.stage];
    if (!this.enemies.length) return;
    const edge = this.enemies.some((e) => e.x < 54 || e.x > W - 54);
    if (edge) this.swarmDir *= -1;
    for (const e of this.enemies) {
      e.t += dt;
      if (e.dive <= 0 && Math.random() < st.dive * dt * 0.035) e.dive = 1;
      if (e.dive > 0) {
        e.y += (120 + this.stage * 24) * dt;
        e.x += Math.sin(e.t * (e.kind === "zig" ? 8 : 4)) * 160 * dt;
        if (e.y > H + 40) {
          e.y = HUD + 50;
          e.x = e.baseX;
          e.dive = 0;
        }
      } else {
        e.x += this.swarmDir * st.speed * dt;
        e.y = e.baseY + Math.sin(this.stageTimer * 1.6 + e.id) * 9;
      }
      e.shoot -= dt;
      if (e.shoot <= 0) {
        const chance = st.fire * (e.kind === "saucer" ? 1.7 : 1);
        e.shoot = 0.7 + Math.random() * 2.1 / chance;
        if (Math.random() < 0.42 + this.stage * 0.05 || e.dive > 0) this.fireEnemy(e);
      }
    }
  }

  private fireEnemy(e: Enemy) {
    if (e.kind === "saucer") {
      for (let i = -1; i <= 1; i += 1) this.bullets.push({ x: e.x, y: e.y + 22, vx: i * 82, vy: 210 + Math.abs(i) * 35, enemy: true, r: 5, power: 1, color: "#ff63f7" });
      return;
    }
    const aim = clamp((this.playerX - e.x) * 0.22, -90, 90);
    this.bullets.push({ x: e.x, y: e.y + 22, vx: aim, vy: e.kind === "armor" ? 260 : 230, enemy: true, r: e.kind === "armor" ? 6 : 5, power: 1, color: enemyStats[e.kind].color });
  }

  private updateBoss(dt: number) {
    const b = this.boss;
    if (!b) return;
    b.t += dt;
    b.phase = b.hp < b.maxHp * 0.35 ? 2 : b.hp < b.maxHp * 0.68 ? 1 : 0;
    b.x = W / 2 + Math.sin(b.t * (0.7 + b.phase * 0.22)) * (90 + b.phase * 38);
    b.y = HUD + 126 + Math.sin(b.t * 1.3) * 18;
    b.shoot -= dt;
    if (b.shoot <= 0) {
      b.shoot = [0.8, 0.55, 0.38][b.phase];
      const spread = b.phase === 0 ? 4 : b.phase === 1 ? 6 : 8;
      for (let i = 0; i < spread; i += 1) {
        const dx = i - (spread - 1) / 2;
        this.bullets.push({ x: b.x + dx * 36, y: b.y + 128, vx: dx * 54, vy: 230 + Math.abs(dx) * 18, enemy: true, r: 6, power: 1, color: i % 2 ? "#ff49df" : "#ff7a2b" });
      }
    }
    b.beam -= dt;
    if (b.phase >= 1 && b.beam <= 0) {
      b.beam = b.phase === 1 ? 2.8 : 1.9;
      this.bullets.push({ x: b.x, y: b.y + 148, vx: 0, vy: 360, enemy: true, r: 14, power: 1, color: "#ff3c37" });
      this.synth.sfx("boss");
    }
  }

  private updateBullets(dt: number) {
    for (const b of this.bullets) {
      b.x += b.vx * dt;
      b.y += b.vy * dt;
    }
    this.bullets = this.bullets.filter((b) => b.y > HUD - 40 && b.y < H + 50 && b.x > -50 && b.x < W + 50);
  }

  private updateExplosions(dt: number) {
    for (const ex of this.explosions) ex.t += dt;
    this.explosions = this.explosions.filter((ex) => ex.t < 0.5);
  }

  private checkCollisions() {
    for (const bullet of this.bullets) {
      if (bullet.enemy) continue;
      for (const e of this.enemies) {
        if (dist(bullet, e) < e.size * 0.62 + bullet.r) {
          bullet.y = -999;
          e.hp -= bullet.power;
          if (e.hp <= 0) {
            this.score += e.score;
            this.explosions.push({ x: e.x, y: e.y, t: 0, big: e.kind === "armor" || e.kind === "saucer" });
            this.synth.sfx("boom");
          } else {
            this.synth.sfx("hit");
          }
        }
      }
      if (this.boss && bullet.y < this.boss.y + 185 && bullet.y > this.boss.y - 165 && Math.abs(bullet.x - this.boss.x) < 245) {
        bullet.y = -999;
        this.boss.hp -= bullet.power;
        this.score += 8;
        this.explosions.push({ x: bullet.x, y: bullet.y + 20, t: 0, big: false });
        this.synth.sfx("hit");
      }
    }
    this.enemies = this.enemies.filter((e) => e.hp > 0);
    this.bullets = this.bullets.filter((b) => b.y > -900);

    if (this.invuln <= 0) {
      const hitBullet = this.bullets.find((b) => b.enemy && dist(b, { x: this.playerX, y: PLAYER_Y }) < 27 + b.r);
      const hitEnemy = this.enemies.find((e) => dist(e, { x: this.playerX, y: PLAYER_Y }) < e.size + 22);
      if (hitBullet || hitEnemy) this.hurt();
    }
  }

  private hurt() {
    this.lives -= 1;
    this.invuln = 1.8;
    this.bullets = this.bullets.filter((b) => !b.enemy);
    this.explosions.push({ x: this.playerX, y: PLAYER_Y, t: 0, big: true });
    this.synth.sfx("hurt");
    if (this.lives <= 0) this.state = "gameOver";
  }

  private checkStageEnd() {
    if (this.boss && this.boss.hp <= 0) {
      this.score += 8000;
      this.explosions.push({ x: this.boss.x, y: this.boss.y, t: 0, big: true });
      this.boss = undefined;
      this.state = "victory";
      this.synth.sfx("clear");
      return;
    }
    if (!stages[this.stage].boss && this.enemies.length === 0) {
      this.score += 1000 + this.stage * 500;
      this.bombs = Math.min(5, this.bombs + 1);
      this.synth.sfx("clear");
      this.loadStage(this.stage + 1);
    }
  }

  private draw() {
    this.ctx.clearRect(0, 0, W, H);
    this.drawBackground();
    this.drawHud();
    this.drawPlayfield();
    if (this.state !== "playing") this.drawOverlay();
  }

  private drawBackground() {
    const st = stages[this.stage];
    const p = bgPanels[st.bg];
    if (this.bgImg.complete) {
      this.ctx.globalAlpha = 0.92;
      this.ctx.drawImage(this.bgImg, p.x, p.y, p.w, p.h, 0, HUD, W, PLAY_H);
      this.ctx.globalAlpha = 1;
    } else {
      const g = this.ctx.createLinearGradient(0, HUD, 0, H);
      g.addColorStop(0, "#081323");
      g.addColorStop(1, "#02030a");
      this.ctx.fillStyle = g;
      this.ctx.fillRect(0, HUD, W, PLAY_H);
    }
    this.ctx.fillStyle = "rgba(0,0,0,0.34)";
    this.ctx.fillRect(0, HUD, W, PLAY_H);
    for (let i = 0; i < 65; i += 1) {
      const x = (i * 149 + this.stageTimer * (12 + i % 4)) % W;
      const y = HUD + ((i * 61 + this.stageTimer * (35 + i % 5)) % PLAY_H);
      this.ctx.fillStyle = i % 7 === 0 ? "#bdfbff" : "rgba(255,255,255,0.55)";
      this.ctx.fillRect(x, y, i % 7 === 0 ? 2 : 1, i % 7 === 0 ? 2 : 1);
    }
  }

  private drawHud() {
    this.ctx.fillStyle = "rgba(3, 8, 16, 0.94)";
    this.ctx.fillRect(0, 0, W, HUD);
    this.ctx.strokeStyle = "rgba(84, 231, 255, 0.5)";
    this.ctx.lineWidth = 2;
    this.ctx.beginPath();
    this.ctx.moveTo(0, HUD - 1);
    this.ctx.lineTo(W, HUD - 1);
    this.ctx.stroke();
    this.drawLabel("SCORE", 26, 18);
    this.drawDigits(String(this.score).padStart(7, "0"), 132, 15, 5, "#7df7ff");
    this.drawLabel("STAGE", 382, 18);
    this.drawDigits(String(this.stage + 1), 486, 15, 5, "#fff06a");
    this.drawLabel("LIFE", 574, 18);
    this.drawDigits(String(this.lives), 664, 15, 5, "#81ff88");
    this.drawLabel("BOMB", 742, 18);
    this.drawDigits(String(this.bombs), 834, 15, 5, "#ff7af0");
    if (this.boss) {
      const w = 330;
      this.ctx.fillStyle = "rgba(255,255,255,0.14)";
      this.ctx.fillRect(315, 56, w, 8);
      this.ctx.fillStyle = "#ff386f";
      this.ctx.fillRect(315, 56, w * Math.max(0, this.boss.hp / this.boss.maxHp), 8);
    }
  }

  private drawPlayfield() {
    for (const e of this.enemies) this.drawEnemy(e);
    if (this.boss) this.drawBoss(this.boss);
    for (const b of this.bullets) this.drawBullet(b);
    this.drawPlayer();
    for (const ex of this.explosions) this.drawExplosion(ex);
  }

  private drawPlayer() {
    if (this.invuln > 0 && Math.floor(this.stageTimer * 16) % 2 === 0) this.ctx.globalAlpha = 0.52;
    this.drawSprite("player", this.playerX, PLAYER_Y, 92, 88);
    this.ctx.globalAlpha = 1;
  }

  private drawEnemy(e: Enemy) {
    this.drawSprite(e.kind, e.x, e.y, e.size * 1.7, e.size * 1.7);
    if (e.hp < e.maxHp) {
      this.ctx.fillStyle = "rgba(255,255,255,0.25)";
      this.ctx.fillRect(e.x - 20, e.y + e.size, 40, 4);
      this.ctx.fillStyle = enemyStats[e.kind].color;
      this.ctx.fillRect(e.x - 20, e.y + e.size, 40 * e.hp / e.maxHp, 4);
    }
  }

  private drawBoss(b: Boss) {
    this.drawSprite("boss", b.x, b.y + 26, 470, 360);
    this.ctx.strokeStyle = b.phase === 2 ? "#ff386f" : "#63f3ff";
    this.ctx.lineWidth = 2;
    this.ctx.strokeRect(b.x - 244, b.y - 154, 488, 308);
  }

  private drawBullet(b: Bullet) {
    this.ctx.fillStyle = b.color;
    this.ctx.shadowBlur = b.enemy ? 12 : 16;
    this.ctx.shadowColor = b.color;
    this.ctx.beginPath();
    this.ctx.ellipse(b.x, b.y, b.r, b.enemy ? b.r * 1.6 : b.r * 2.4, 0, 0, Math.PI * 2);
    this.ctx.fill();
    this.ctx.shadowBlur = 0;
  }

  private drawExplosion(ex: Vec & { t: number; big: boolean }) {
    const key = ex.t < 0.17 ? "boom1" : ex.t < 0.34 ? "boom2" : "boom3";
    const s = ex.big ? 104 : 68;
    this.ctx.globalAlpha = 1 - ex.t * 1.2;
    this.drawSprite(key, ex.x, ex.y, s, s);
    this.ctx.globalAlpha = 1;
  }

  private drawSprite(key: string, cx: number, cy: number, dw: number, dh: number) {
    const sp = sprites[key];
    const source = this.spriteSource ?? this.spriteImg;
    if (this.spriteImg.complete && sp) {
      this.ctx.drawImage(source, sp.x, sp.y, sp.w, sp.h, cx - dw / 2, cy - dh / 2, dw, dh);
      return;
    }
    this.ctx.fillStyle = "#7df7ff";
    this.ctx.fillRect(cx - dw / 2, cy - dh / 2, dw, dh);
  }

  private drawOverlay() {
    this.ctx.fillStyle = "rgba(0, 0, 0, 0.62)";
    this.ctx.fillRect(0, HUD, W, PLAY_H);
    const title = this.state === "title" ? "NOVA SWARM" : this.state === "paused" ? "PAUSED" : this.state === "victory" ? "MISSION CLEAR" : "GAME OVER";
    const sub = this.state === "paused" ? "PRESS P TO RETURN" : "PRESS ENTER TO START";
    this.ctx.textAlign = "center";
    this.ctx.textBaseline = "middle";
    this.ctx.font = "900 58px Arial Black, sans-serif";
    this.ctx.fillStyle = "#dffcff";
    this.ctx.shadowBlur = 18;
    this.ctx.shadowColor = "#37dcff";
    this.ctx.fillText(title, W / 2, HUD + 220);
    this.ctx.shadowBlur = 0;
    this.ctx.font = "700 22px Arial Black, sans-serif";
    this.ctx.fillStyle = "#ff7af0";
    this.ctx.fillText(sub, W / 2, HUD + 292);
    this.ctx.fillStyle = "rgba(226,251,255,0.82)";
    this.ctx.font = "700 17px Arial Black, sans-serif";
    this.ctx.fillText("5 STAGES / VARIANT ALIENS / BOMB / BOSS BATTLE", W / 2, HUD + 340);
    this.ctx.textAlign = "left";
  }

  private drawLabel(text: string, x: number, y: number) {
    this.ctx.font = "900 14px Arial Black, sans-serif";
    this.ctx.fillStyle = "rgba(226,251,255,0.76)";
    this.ctx.fillText(text, x, y + 18);
  }

  private drawDigits(text: string, x: number, y: number, scale: number, color: string) {
    this.ctx.shadowBlur = 10;
    this.ctx.shadowColor = color;
    for (const ch of text) {
      const rows = digitMap[ch] ?? digitMap[" "];
      for (let r = 0; r < rows.length; r += 1) {
        for (let c = 0; c < rows[r].length; c += 1) {
          if (rows[r][c] === "1") {
            this.ctx.fillStyle = color;
            this.ctx.fillRect(x + c * scale, y + r * scale, scale - 1, scale - 1);
          }
        }
      }
      x += scale * 4;
    }
    this.ctx.shadowBlur = 0;
  }
}

function clamp(v: number, min: number, max: number) {
  return Math.max(min, Math.min(max, v));
}

function dist(a: Vec, b: Vec) {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

function makeBlackTransparent(img: HTMLImageElement) {
  const atlas = document.createElement("canvas");
  atlas.width = img.naturalWidth;
  atlas.height = img.naturalHeight;
  const ctx = atlas.getContext("2d", { willReadFrequently: true });
  if (!ctx) return img;
  ctx.drawImage(img, 0, 0);
  const pixels = ctx.getImageData(0, 0, atlas.width, atlas.height);
  for (let i = 0; i < pixels.data.length; i += 4) {
    const r = pixels.data[i];
    const g = pixels.data[i + 1];
    const b = pixels.data[i + 2];
    if (r < 16 && g < 16 && b < 18) pixels.data[i + 3] = 0;
  }
  ctx.putImageData(pixels, 0, 0);
  return atlas;
}

const canvas = document.querySelector<HTMLCanvasElement>("#game");
if (!canvas) throw new Error("Game canvas was not found");
new Game(canvas);
