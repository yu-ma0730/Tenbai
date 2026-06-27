// FX Scalping Signal Tool

const PAIRS = ['USDJPY', 'EURUSD', 'EURJPY', 'XAUUSD'];
const PAIR_LABELS = {
  USDJPY: 'USD/JPY',
  EURUSD: 'EUR/USD',
  EURJPY: 'EUR/JPY',
  XAUUSD: 'GOLD',
};

// 各通貨ペアのpip単位 (SL計算用)
const PIP_SIZE = {
  USDJPY: 0.01,
  EURUSD: 0.0001,
  EURJPY: 0.01,
  XAUUSD: 0.1,
};

// 小数点桁数
const DECIMALS = {
  USDJPY: 3,
  EURUSD: 5,
  EURJPY: 3,
  XAUUSD: 2,
};

// SL幅 (pips)
const SL_PIPS = {
  USDJPY: 8,
  EURUSD: 8,
  EURJPY: 10,
  XAUUSD: 20,
};

let currentTF = 5;
let activePairs = new Set(PAIRS);
let autoRefreshEnabled = true;
let refreshTimer = null;
let countdownTimer = null;
let countdown = 30;

// ---- 価格シミュレーション ----
// 現実的なベース価格を維持
const basePrices = {
  USDJPY: 157.50,
  EURUSD: 1.0820,
  EURJPY: 170.40,
  XAUUSD: 3285.0,
};

function getPrice(pair) {
  const b = basePrices[pair];
  const pip = PIP_SIZE[pair];
  // ±0.3% 以内でランダムウォーク
  const drift = (Math.random() - 0.5) * b * 0.003;
  basePrices[pair] = b + drift;
  return basePrices[pair];
}

// ---- テクニカル計算 ----
function generateOHLC(pair, bars = 50) {
  const candles = [];
  let price = basePrices[pair];
  const pip = PIP_SIZE[pair];
  const volatility = pip * 5;
  for (let i = 0; i < bars; i++) {
    const open = price;
    const move = (Math.random() - 0.49) * volatility * 8;
    const close = open + move;
    const high = Math.max(open, close) + Math.random() * volatility * 2;
    const low  = Math.min(open, close) - Math.random() * volatility * 2;
    candles.push({ open, high, low, close });
    price = close;
  }
  return candles;
}

function calcEMA(closes, period) {
  const k = 2 / (period + 1);
  let ema = closes[0];
  for (let i = 1; i < closes.length; i++) {
    ema = closes[i] * k + ema * (1 - k);
  }
  return ema;
}

function calcRSI(closes, period = 14) {
  if (closes.length < period + 1) return 50;
  let gains = 0, losses = 0;
  for (let i = 1; i <= period; i++) {
    const diff = closes[i] - closes[i - 1];
    if (diff > 0) gains += diff; else losses -= diff;
  }
  let avgGain = gains / period;
  let avgLoss = losses / period;
  for (let i = period + 1; i < closes.length; i++) {
    const diff = closes[i] - closes[i - 1];
    const g = diff > 0 ? diff : 0;
    const l = diff < 0 ? -diff : 0;
    avgGain = (avgGain * (period - 1) + g) / period;
    avgLoss = (avgLoss * (period - 1) + l) / period;
  }
  if (avgLoss === 0) return 100;
  const rs = avgGain / avgLoss;
  return 100 - (100 / (1 + rs));
}

function generateSignal(pair) {
  const candles = generateOHLC(pair, 60);
  const closes = candles.map(c => c.close);
  const currentPrice = closes[closes.length - 1];
  const prevCloses = closes.slice(0, -1);

  const ema9  = calcEMA(closes, 9);
  const ema21 = calcEMA(closes, 21);
  const ema9prev  = calcEMA(prevCloses, 9);
  const ema21prev = calcEMA(prevCloses, 21);

  const rsi = calcRSI(closes, 14);

  const sl = SL_PIPS[pair] * PIP_SIZE[pair];
  const tp1 = sl * 1.5;
  const tp2 = sl * 2.0;

  // EMAクロス判定
  const bullCross = ema9prev <= ema21prev && ema9 > ema21;
  const bearCross = ema9prev >= ema21prev && ema9 < ema21;

  // RSI確認
  const rsiBull = rsi < 65 && rsi > 35;
  const rsiBear = rsi < 65 && rsi > 35;

  // シグナル判定（EMAクロス + RSI確認 + ランダム要素でスキャルピングらしく）
  let signal = 'NEUTRAL';
  const rand = Math.random();

  if ((bullCross && rsi > 40 && rsi < 65) || (ema9 > ema21 && rsi > 45 && rsi < 60 && rand < 0.35)) {
    signal = 'BUY';
  } else if ((bearCross && rsi > 35 && rsi < 60) || (ema9 < ema21 && rsi > 40 && rsi < 55 && rand < 0.35)) {
    signal = 'SELL';
  }

  const entry = currentPrice;
  const priceChange = closes[closes.length - 1] - closes[closes.length - 6];
  const pctChange = (priceChange / closes[closes.length - 6]) * 100;

  return {
    pair,
    signal,
    entry,
    sl: signal === 'BUY' ? entry - sl : entry + sl,
    tp1: signal === 'BUY' ? entry + tp1 : entry - tp1,
    tp2: signal === 'BUY' ? entry + tp2 : entry - tp2,
    ema9: ema9,
    ema21: ema21,
    rsi: Math.round(rsi * 10) / 10,
    priceChange,
    pctChange,
  };
}

// ---- UI描画 ----
function fmt(pair, val) {
  return val.toFixed(DECIMALS[pair]);
}

function renderSignalCard(data) {
  const { pair, signal, entry, sl, tp1, tp2, ema9, ema21, rsi, pctChange } = data;
  const label = PAIR_LABELS[pair];
  const dec = DECIMALS[pair];
  const isBuy = signal === 'BUY';
  const isSell = signal === 'SELL';
  const isNeutral = !isBuy && !isSell;

  const cardClass = isBuy ? 'buy-card' : isSell ? 'sell-card' : 'neutral-card';
  const badgeClass = isBuy ? 'buy-badge' : isSell ? 'sell-badge' : 'neutral-badge';
  const badgeText = isBuy ? '▲ BUY' : isSell ? '▼ SELL' : '◆ 様子見';

  const changeSign = pctChange >= 0 ? '+' : '';
  const changeClass = pctChange >= 0 ? 'pos' : 'neg';

  // RRビジュアルバー計算
  // 全体幅をSL+TP2の合計距離で正規化
  const totalRange = Math.abs(tp2 - sl);
  const entryPct = Math.abs(entry - sl) / totalRange * 100;
  const tp1Pct   = Math.abs(tp1 - sl) / totalRange * 100;
  const tp2Pct   = 100;

  // バーの色はbuy=青系, sell=赤系
  const barColorEntry = isBuy ? '#3b82f6' : '#ef4444';

  // SLバー幅: エントリーからSLまでの割合
  const slWidth = entryPct;
  // TP1バー: エントリーからTP1まで
  const tp1Width = tp1Pct - entryPct;
  // TP2バー: TP1からTP2まで
  const tp2Width = tp2Pct - tp1Pct;

  const rsiClass = isBuy ? 'rsi-chip-bull' : isSell ? 'rsi-chip-bear' : 'rsi-chip-neutral';
  const emaLabel = ema9 > ema21 ? 'EMA9 > EMA21 ↑' : ema9 < ema21 ? 'EMA9 < EMA21 ↓' : 'EMA クロス中';

  let rrSection = '';
  if (!isNeutral) {
    rrSection = `
      <div class="rr-area">
        <div class="price-table">
          <div class="price-row entry-row">
            <span class="price-row-label">ENTRY</span>
            <span class="price-row-val">${fmt(pair, entry)}</span>
          </div>
          <div class="price-row sl-row">
            <span class="price-row-label">SL (損切)</span>
            <span class="price-row-val">${fmt(pair, sl)}</span>
          </div>
          <div class="price-row tp1-row">
            <span class="price-row-label">TP1 RR 1:1.5</span>
            <span class="price-row-val">${fmt(pair, tp1)}</span>
          </div>
          <div class="price-row tp2-row">
            <span class="price-row-label">TP2 RR 1:2.0</span>
            <span class="price-row-val">${fmt(pair, tp2)}</span>
          </div>
        </div>

        <div class="rr-visual">
          <!-- ビジュアルバー -->
          <div style="position:relative; height:24px; margin: 4px 0;">
            <!-- 背景トラック -->
            <div style="position:absolute;top:9px;left:0;right:0;height:6px;background:#1e3a5f;border-radius:3px;"></div>

            ${isBuy ? `
            <!-- SL (左側、赤) -->
            <div style="position:absolute;top:9px;left:0;width:${slWidth}%;height:6px;background:linear-gradient(90deg,#ef4444,#fb923c);border-radius:3px 0 0 3px;"></div>
            <!-- TP1 (中央、水色) -->
            <div style="position:absolute;top:9px;left:${slWidth}%;width:${tp1Width}%;height:6px;background:linear-gradient(90deg,#3b82f6,#34d399);"></div>
            <!-- TP2 (右側、緑) -->
            <div style="position:absolute;top:9px;left:${slWidth + tp1Width}%;width:${tp2Width}%;height:6px;background:linear-gradient(90deg,#34d399,#4ade80);border-radius:0 3px 3px 0;"></div>
            <!-- エントリーマーカー -->
            <div style="position:absolute;top:3px;left:${slWidth}%;transform:translateX(-50%);width:3px;height:18px;background:#e0e6f0;border-radius:2px;"></div>
            <!-- TP1マーカー -->
            <div style="position:absolute;top:3px;left:${slWidth + tp1Width}%;transform:translateX(-50%);width:2px;height:18px;background:#34d399;border-radius:2px;opacity:0.8;"></div>
            ` : `
            <!-- SL (右側、青) -->
            <div style="position:absolute;top:9px;right:0;width:${slWidth}%;height:6px;background:linear-gradient(90deg,#60a5fa,#3b82f6);border-radius:0 3px 3px 0;"></div>
            <!-- TP1 (中央、赤) -->
            <div style="position:absolute;top:9px;right:${slWidth}%;width:${tp1Width}%;height:6px;background:linear-gradient(90deg,#34d399,#ef4444);"></div>
            <!-- TP2 (左側、緑) -->
            <div style="position:absolute;top:9px;right:${slWidth + tp1Width}%;width:${tp2Width}%;height:6px;background:linear-gradient(90deg,#4ade80,#34d399);border-radius:3px 0 0 3px;"></div>
            <!-- エントリーマーカー -->
            <div style="position:absolute;top:3px;right:${slWidth}%;transform:translateX(50%);width:3px;height:18px;background:#e0e6f0;border-radius:2px;"></div>
            <!-- TP1マーカー -->
            <div style="position:absolute;top:3px;right:${slWidth + tp1Width}%;transform:translateX(50%);width:2px;height:18px;background:#34d399;border-radius:2px;opacity:0.8;"></div>
            `}
          </div>
          <!-- ラベル行 -->
          <div style="position:relative;height:14px;font-size:9px;">
            ${isBuy ? `
            <span style="position:absolute;left:0;color:#f87171;transform:translateX(0);">← SL</span>
            <span style="position:absolute;left:${slWidth}%;color:#90b0d8;transform:translateX(-50%);">Entry</span>
            <span style="position:absolute;left:${slWidth + tp1Width}%;color:#34d399;transform:translateX(-50%);">TP1</span>
            <span style="position:absolute;right:0;color:#4ade80;">TP2 →</span>
            ` : `
            <span style="position:absolute;left:0;color:#4ade80;">← TP2</span>
            <span style="position:absolute;right:${slWidth + tp1Width}%;color:#34d399;transform:translateX(50%);">TP1</span>
            <span style="position:absolute;right:${slWidth}%;color:#90b0d8;transform:translateX(50%);">Entry</span>
            <span style="position:absolute;right:0;color:#60a5fa;">SL →</span>
            `}
          </div>
        </div>

        <div class="rr-badge-row">
          <span class="rr-badge rr-badge-15">RR 1:1.5</span>
          <span class="rr-badge rr-badge-20">RR 1:2.0</span>
        </div>
      </div>
    `;
  } else {
    rrSection = `
      <div class="rr-area" style="color:#4a6fa5;font-size:13px;text-align:center;padding:20px;">
        明確なシグナルなし — 次のエントリーポイントを待機中
      </div>
    `;
  }

  return `
    <div class="signal-card ${cardClass}">
      <div class="card-header">
        <span class="pair-name">${label}</span>
        <span class="signal-badge ${badgeClass}">${badgeText}</span>
      </div>
      <div class="price-area">
        <span class="current-price">${fmt(pair, entry)}</span>
        <span class="price-change ${changeClass}">${changeSign}${pctChange.toFixed(3)}%</span>
      </div>
      ${rrSection}
      <div class="indicators-row">
        <span class="indicator-chip ema-chip">${emaLabel}</span>
        <span class="indicator-chip ${rsiClass}">RSI ${data.rsi}</span>
        <span class="indicator-chip tf-chip">${currentTF}分足</span>
      </div>
    </div>
  `;
}

function updateSummary(signals) {
  const buys     = signals.filter(s => s.signal === 'BUY').length;
  const sells    = signals.filter(s => s.signal === 'SELL').length;
  const neutrals = signals.filter(s => s.signal === 'NEUTRAL').length;
  document.getElementById('buy-count').textContent  = buys;
  document.getElementById('sell-count').textContent = sells;
  document.getElementById('neutral-count').textContent = neutrals;
  const now = new Date();
  document.getElementById('last-update-time').textContent =
    now.getHours().toString().padStart(2, '0') + ':' +
    now.getMinutes().toString().padStart(2, '0') + ':' +
    now.getSeconds().toString().padStart(2, '0');
}

function updatePairButtonColors(signals) {
  signals.forEach(s => {
    const btn = document.querySelector(`.pair-btn[data-pair="${s.pair}"]`);
    if (!btn) return;
    btn.classList.remove('buy-active', 'sell-active');
    if (s.signal === 'BUY')  btn.classList.add('buy-active');
    if (s.signal === 'SELL') btn.classList.add('sell-active');
  });
}

function fetchSignals() {
  const grid = document.getElementById('signals-grid');

  // ローディング表示
  const loadingHtml = Array.from(activePairs).map(() => `
    <div class="loading-card">
      <div class="loading-spinner"></div>
      <span>シグナル分析中...</span>
    </div>
  `).join('');
  grid.innerHTML = loadingHtml;

  // APIコール
  fetch('/api/fx/signals', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ pairs: Array.from(activePairs), tf: currentTF }),
  })
    .then(r => r.json())
    .then(data => {
      if (!data.success) throw new Error('API error');
      const signals = data.signals;
      grid.innerHTML = signals.map(renderSignalCard).join('');
      updateSummary(signals);
      updatePairButtonColors(signals);
      updateConnectionBadge(data.mt5_connected);
    })
    .catch(() => {
      grid.innerHTML = '<div class="loading-card" style="color:#f87171;">データ取得エラー。再度お試しください。</div>';
    });
}

// ---- カウントダウン ----
function startCountdown() {
  clearInterval(countdownTimer);
  countdown = 30;
  document.getElementById('next-update').textContent = `${countdown}秒後更新`;
  countdownTimer = setInterval(() => {
    countdown--;
    if (countdown <= 0) {
      countdown = 30;
      if (autoRefreshEnabled) fetchSignals();
    }
    document.getElementById('next-update').textContent = `${countdown}秒後更新`;
  }, 1000);
}

// ---- イベント ----
document.querySelectorAll('.tf-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.tf-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    currentTF = parseInt(btn.dataset.tf);
    fetchSignals();
    startCountdown();
  });
});

document.querySelectorAll('.pair-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    const pair = btn.dataset.pair;
    if (activePairs.has(pair)) {
      if (activePairs.size > 1) {
        activePairs.delete(pair);
        btn.classList.remove('active', 'buy-active', 'sell-active');
      }
    } else {
      activePairs.add(pair);
      btn.classList.add('active');
    }
    fetchSignals();
  });
});

document.getElementById('refresh-btn').addEventListener('click', () => {
  const btn = document.getElementById('refresh-btn');
  btn.classList.add('spinning');
  fetchSignals();
  startCountdown();
  setTimeout(() => btn.classList.remove('spinning'), 700);
});

document.getElementById('auto-refresh-toggle').addEventListener('change', e => {
  autoRefreshEnabled = e.target.checked;
  document.getElementById('next-update').textContent = autoRefreshEnabled ? `${countdown}秒後更新` : '自動更新OFF';
  if (autoRefreshEnabled) startCountdown();
  else clearInterval(countdownTimer);
});

function updateConnectionBadge(connected) {
  let badge = document.getElementById('mt5-badge');
  if (!badge) return;
  if (connected) {
    badge.textContent = '● MT5 接続中';
    badge.style.color = '#4ade80';
    badge.style.borderColor = 'rgba(74,222,128,0.4)';
    badge.style.background = 'rgba(74,222,128,0.1)';
  } else {
    badge.textContent = '○ シミュレーション';
    badge.style.color = '#fbbf24';
    badge.style.borderColor = 'rgba(251,191,36,0.4)';
    badge.style.background = 'rgba(251,191,36,0.08)';
  }
}

// 初期ロード
fetchSignals();
startCountdown();
