'use strict';

// ---------- 状態管理 ----------
const state = {
  activePair: 'USDJPY',
  activeTf: '15m',
  data: {},        // pair -> analyze result
  overviewData: {}, // pair -> summary
  charts: {},
  loading: false,
};

const PAIRS = {
  USDJPY: 'ドル円',
  EURUSD: 'ユーロドル',
  EURJPY: 'ユーロ円',
  XAUUSD: 'ゴールド',
};

// ---------- メイン ----------
document.addEventListener('DOMContentLoaded', () => {
  initPairTabs();
  loadMt5Status();
  loadOverview();
  loadPair(state.activePair);
  // 15秒ごとにMT5状態確認、60秒ごとにシグナル更新
  setInterval(loadMt5Status, 15000);
  setInterval(() => {
    loadOverview();
    loadPair(state.activePair);
  }, 60000);
});

async function loadMt5Status() {
  try {
    const res = await fetch('/api/mt5/status');
    const json = await res.json();
    if (!json.success) return;
    const connected = Object.values(json.status).some(s => s.connected);
    const dot = document.getElementById('mt5-dot');
    const label = document.getElementById('mt5-label');
    const guide = document.getElementById('mt5-guide');
    if (connected) {
      const pairs = Object.entries(json.status).filter(([, s]) => s.connected).map(([p]) => p);
      dot.style.background = '#3fb950';
      dot.style.animation = 'pulse 2s infinite';
      label.style.color = '#3fb950';
      label.textContent = `MT5 接続中 (${pairs.join(', ')})`;
      if (guide) guide.style.display = 'none';
    } else {
      dot.style.background = '#8b949e';
      dot.style.animation = 'none';
      label.style.color = '#8b949e';
      label.textContent = 'MT5 未接続 (デモデータ)';
      if (guide) guide.style.display = 'block';
    }
  } catch (e) { /* ignore */ }
}

function initPairTabs() {
  const container = document.getElementById('pair-tabs');
  container.innerHTML = '';
  for (const [pair, name] of Object.entries(PAIRS)) {
    const btn = document.createElement('button');
    btn.className = 'pair-tab' + (pair === state.activePair ? ' active' : '');
    btn.dataset.pair = pair;
    btn.innerHTML = `<span>${name}</span><br><small style="font-size:10px;opacity:.7">${pair}</small>`;
    btn.addEventListener('click', () => switchPair(pair));
    container.appendChild(btn);
  }
}

function switchPair(pair) {
  state.activePair = pair;
  document.querySelectorAll('.pair-tab').forEach(b => {
    b.classList.toggle('active', b.dataset.pair === pair);
  });
  if (state.data[pair]) {
    renderDetail(state.data[pair]);
  } else {
    loadPair(pair);
  }
}

// ---------- API ----------
async function loadOverview() {
  try {
    const res = await fetch('/api/fx/scan_all');
    const json = await res.json();
    if (!json.success) return;
    state.overviewData = json.pairs;
    renderOverview(json.pairs);
    updateTabBadges(json.pairs);
  } catch (e) { console.error('overview error', e); }
}

async function loadPair(pair) {
  if (state.loading) return;
  state.loading = true;
  showLoading(true);

  try {
    const res = await fetch(`/api/fx/scan?pair=${pair}`);
    const json = await res.json();
    if (!json.success) { showLoading(false); state.loading = false; return; }
    state.data[pair] = json;
    if (state.activePair === pair) renderDetail(json);
  } catch (e) {
    console.error('loadPair error', e);
  }

  showLoading(false);
  state.loading = false;
}

// ---------- レンダリング ----------
function renderDetail(data) {
  renderTrendBar(data);
  renderChart(data);
  renderSignals(data);
}

function renderTrendBar(data) {
  const el = document.getElementById('trend-bar');
  const trendLabels = { UP: '上昇トレンド', DOWN: '下降トレンド', RANGE: 'レンジ相場' };
  const arrow = data.trend === 'UP' ? '↑' : data.trend === 'DOWN' ? '↓' : '→';
  const srcBadge = data.data_source === 'mt5'
    ? `<span style="padding:2px 8px;background:rgba(63,185,80,0.15);color:#3fb950;border:1px solid rgba(63,185,80,0.4);border-radius:4px;font-size:11px;font-weight:700">MT5 LIVE</span>`
    : `<span style="padding:2px 8px;background:rgba(139,148,158,0.15);color:#8b949e;border:1px solid var(--border);border-radius:4px;font-size:11px">DEMO</span>`;
  el.innerHTML = `
    <span class="trend-label">1H トレンド</span>
    <span class="trend-badge ${data.trend}">${arrow} ${trendLabels[data.trend]}</span>
    <div class="trend-strength-bar">
      <div class="trend-strength-fill ${data.trend}" style="width:${data.trend_strength}%"></div>
    </div>
    <span class="trend-strength-val">${data.trend_strength}%</span>
    ${srcBadge}
    <span class="updated-badge">
      <span class="pulse-dot"></span>
      ${data.updated_at}
    </span>
  `;
}

function renderSignals(data) {
  const container = document.getElementById('signals-container');
  if (!data.signals || data.signals.length === 0) {
    container.innerHTML = `
      <div class="no-signal">
        <div class="no-signal-icon">🔍</div>
        <div class="no-signal-text">現在、明確なシグナルは検出されていません</div>
      </div>`;
    return;
  }

  container.innerHTML = data.signals.map((sig, i) => {
    const ei = sig.entry_info;
    const dirIcon = sig.direction === 'BUY' ? '▲' : sig.direction === 'SELL' ? '▼' : '◆';
    const dirLabel = sig.direction === 'BUY' ? '買い' : sig.direction === 'SELL' ? '売り' : '中立';

    const entryHtml = ei ? `
      <div class="entry-grid">
        <div class="entry-item">
          <div class="entry-item-label">エントリー</div>
          <div class="entry-item-value entry">${ei.entry}</div>
        </div>
        <div class="entry-item">
          <div class="entry-item-label">ストップロス</div>
          <div class="entry-item-value sl">${ei.sl}</div>
        </div>
        <div class="entry-item">
          <div class="entry-item-label">TP1 (RR ${ei.rr1})</div>
          <div class="entry-item-value tp1">${ei.tp1}</div>
        </div>
        <div class="entry-item">
          <div class="entry-item-label">TP2 (RR ${ei.rr2})</div>
          <div class="entry-item-value tp2">${ei.tp2}</div>
        </div>
      </div>` : '';

    const trendMatchHtml = sig.trend_match === true
      ? `<div class="trend-match-indicator match">✓ 1時間足トレンドと一致 — エントリー優先度: 高</div>`
      : sig.trend_match === false
      ? `<div class="trend-match-indicator no-match">⚠ 1時間足トレンドに逆行 — 慎重に判断してください</div>`
      : `<div class="trend-match-indicator neutral">→ トレンドレス環境 — レンジ戦略</div>`;

    return `
      <div class="signal-card">
        <div class="signal-card-header">
          <div class="signal-dir-icon ${sig.direction}">${dirIcon}</div>
          <div class="signal-meta">
            <div class="signal-pattern-name">${sig.pattern}</div>
            <div class="signal-time">15M | ${sig.time}</div>
          </div>
          <span class="signal-strength-pill ${sig.direction}">${dirLabel} ${sig.strength}%</span>
        </div>
        <div class="signal-card-body">
          ${entryHtml}
          ${trendMatchHtml}
        </div>
      </div>`;
  }).join('');
}

function renderOverview(pairs) {
  const tbody = document.getElementById('overview-tbody');
  if (!tbody) return;
  tbody.innerHTML = Object.entries(pairs).map(([pair, d]) => {
    const sig = d.top_signal;
    const trendArrow = d.trend === 'UP' ? '↑' : d.trend === 'DOWN' ? '↓' : '→';
    const trendColor = d.trend === 'UP' ? '#3fb950' : d.trend === 'DOWN' ? '#f85149' : '#8b949e';

    const sigHtml = sig
      ? `<span class="dir-chip ${sig.direction}">${sig.direction === 'BUY' ? '▲' : sig.direction === 'SELL' ? '▼' : '◆'} ${sig.pattern}</span>`
      : `<span class="dir-chip NONE">シグナルなし</span>`;

    const strengthHtml = sig
      ? `<div class="strength-bar-inline">
           <div class="strength-bar-bg">
             <div class="strength-bar-fill ${sig.direction}" style="width:${sig.strength}%"></div>
           </div>
           <span class="strength-val">${sig.strength}%</span>
         </div>`
      : `<span style="color:var(--text-muted)">—</span>`;

    return `
      <tr onclick="switchPair('${pair}')">
        <td>
          <div style="font-weight:700">${d.pair_name}</div>
          <div style="font-size:11px;color:var(--text-muted)">${pair}</div>
        </td>
        <td><span style="color:${trendColor};font-weight:700">${trendArrow} ${d.trend}</span></td>
        <td>${sigHtml}</td>
        <td>${strengthHtml}</td>
        <td style="font-size:11px;color:var(--text-muted)">${d.updated_at || '—'}</td>
      </tr>`;
  }).join('');
}

function updateTabBadges(pairs) {
  document.querySelectorAll('.pair-tab').forEach(btn => {
    const pair = btn.dataset.pair;
    btn.querySelectorAll('.signal-badge').forEach(b => b.remove());
    const d = pairs[pair];
    if (d && d.top_signal && d.top_signal.direction !== 'NEUTRAL') {
      const badge = document.createElement('span');
      badge.className = `signal-badge ${d.top_signal.direction.toLowerCase()}`;
      badge.textContent = d.top_signal.direction === 'BUY' ? '▲' : '▼';
      btn.appendChild(badge);
    }
  });
}

// ---------- チャート描画（Canvas） ----------
function renderChart(data) {
  const canvas = document.getElementById('price-chart');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  const candles = state.activeTf === '1h' ? data.candles_1h : data.candles_15m;
  if (!candles || candles.length === 0) return;

  // DPI対応
  const dpr = window.devicePixelRatio || 1;
  const container = canvas.parentElement;
  const W = container.clientWidth;
  const H = container.clientHeight;
  canvas.width = W * dpr;
  canvas.height = H * dpr;
  canvas.style.width = W + 'px';
  canvas.style.height = H + 'px';
  ctx.scale(dpr, dpr);

  const PAD = { top: 16, right: 16, bottom: 40, left: 70 };
  const chartW = W - PAD.left - PAD.right;
  const chartH = H - PAD.top - PAD.bottom;

  // 価格範囲
  const highs = candles.map(c => c.high);
  const lows = candles.map(c => c.low);
  let maxP = Math.max(...highs);
  let minP = Math.min(...lows);
  const margin = (maxP - minP) * 0.08;
  maxP += margin;
  minP -= margin;
  const priceRange = maxP - minP;

  const toX = i => PAD.left + (i / (candles.length - 1)) * chartW;
  const toY = p => PAD.top + (1 - (p - minP) / priceRange) * chartH;

  // 背景
  ctx.fillStyle = '#0d1117';
  ctx.fillRect(0, 0, W, H);

  // グリッド
  ctx.strokeStyle = 'rgba(48,54,61,0.5)';
  ctx.lineWidth = 1;
  const gridLines = 5;
  for (let i = 0; i <= gridLines; i++) {
    const y = PAD.top + (i / gridLines) * chartH;
    ctx.beginPath();
    ctx.moveTo(PAD.left, y);
    ctx.lineTo(W - PAD.right, y);
    ctx.stroke();

    const price = maxP - (i / gridLines) * priceRange;
    ctx.fillStyle = '#8b949e';
    ctx.font = '10px monospace';
    ctx.textAlign = 'right';
    ctx.fillText(price.toFixed(3), PAD.left - 6, y + 4);
  }

  // EMAライン（1H表示時）
  if (state.activeTf === '1h' && data.ema20_1h && data.ema50_1h) {
    const ema20 = data.ema20_1h.slice(-candles.length);
    const ema50 = data.ema50_1h.slice(-candles.length);

    drawLine(ctx, ema20, toX, toY, '#58a6ff', 1.5);
    drawLine(ctx, ema50, toX, toY, '#f0883e', 1.5);

    // 凡例
    ctx.fillStyle = '#58a6ff';
    ctx.fillRect(PAD.left + 4, PAD.top + 4, 16, 3);
    ctx.fillStyle = '#e6edf3';
    ctx.font = '10px sans-serif';
    ctx.textAlign = 'left';
    ctx.fillText('EMA20', PAD.left + 24, PAD.top + 10);

    ctx.fillStyle = '#f0883e';
    ctx.fillRect(PAD.left + 80, PAD.top + 4, 16, 3);
    ctx.fillStyle = '#e6edf3';
    ctx.fillText('EMA50', PAD.left + 100, PAD.top + 10);
  }

  // ローソク足
  const candleW = Math.max(2, (chartW / candles.length) * 0.65);
  candles.forEach((c, i) => {
    const x = toX(i);
    const isBull = c.close >= c.open;
    const color = isBull ? '#3fb950' : '#f85149';

    // ヒゲ
    ctx.strokeStyle = color;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(x, toY(c.high));
    ctx.lineTo(x, toY(c.low));
    ctx.stroke();

    // 実体
    const bodyTop = toY(Math.max(c.open, c.close));
    const bodyBot = toY(Math.min(c.open, c.close));
    const bodyH = Math.max(1, bodyBot - bodyTop);

    ctx.fillStyle = color;
    ctx.fillRect(x - candleW / 2, bodyTop, candleW, bodyH);
  });

  // シグナルマーカー
  if (data.signals) {
    data.signals.forEach(sig => {
      const idx = sig.candle_index - (data.candles_15m.length - candles.length);
      if (idx < 0 || idx >= candles.length) return;
      const c = candles[idx];
      if (!c) return;
      const x = toX(idx);

      if (sig.direction === 'BUY') {
        const y = toY(c.low) + 14;
        ctx.fillStyle = '#3fb950';
        ctx.beginPath();
        ctx.moveTo(x, y - 10);
        ctx.lineTo(x - 6, y);
        ctx.lineTo(x + 6, y);
        ctx.closePath();
        ctx.fill();
      } else if (sig.direction === 'SELL') {
        const y = toY(c.high) - 14;
        ctx.fillStyle = '#f85149';
        ctx.beginPath();
        ctx.moveTo(x, y + 10);
        ctx.lineTo(x - 6, y);
        ctx.lineTo(x + 6, y);
        ctx.closePath();
        ctx.fill();
      }
    });
  }

  // X軸ラベル（5本ごと）
  ctx.fillStyle = '#8b949e';
  ctx.font = '10px monospace';
  ctx.textAlign = 'center';
  const step = Math.max(1, Math.floor(candles.length / 6));
  for (let i = 0; i < candles.length; i += step) {
    const x = toX(i);
    const label = candles[i].time ? candles[i].time.slice(11, 16) : '';
    ctx.fillText(label, x, H - PAD.bottom + 14);
  }
}

function drawLine(ctx, values, toX, toY, color, width) {
  ctx.strokeStyle = color;
  ctx.lineWidth = width;
  ctx.beginPath();
  values.forEach((v, i) => {
    if (i === 0) ctx.moveTo(toX(i), toY(v));
    else ctx.lineTo(toX(i), toY(v));
  });
  ctx.stroke();
}

// ---------- TF切替 ----------
document.addEventListener('click', e => {
  if (e.target.classList.contains('tf-btn')) {
    document.querySelectorAll('.tf-btn').forEach(b => b.classList.remove('active'));
    e.target.classList.add('active');
    state.activeTf = e.target.dataset.tf;
    const d = state.data[state.activePair];
    if (d) renderChart(d);
  }
});

// ---------- 手動スキャン ----------
document.getElementById('scan-btn')?.addEventListener('click', () => {
  state.data = {};
  loadOverview();
  loadPair(state.activePair);
});

// ---------- ローディング ----------
function showLoading(show) {
  const el = document.getElementById('chart-loading');
  if (el) el.style.display = show ? 'flex' : 'none';
}
