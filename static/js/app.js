// トレンド取得
document.getElementById("fetch-trends-btn").addEventListener("click", fetchTrends);

// 初期ロード
fetchTrends();

function getSelectedSources() {
  return Array.from(document.querySelectorAll(".source-btn input:checked")).map(cb => cb.value);
}

async function fetchTrends() {
  const sources = getSelectedSources();
  if (sources.length === 0) {
    showToast("ソースを1つ以上選択してください", "error");
    return;
  }

  const container = document.getElementById("trends-container");
  container.innerHTML = '<div class="loading"><span class="spinner"></span>トレンドを取得中...</div>';

  const res = await fetch("/api/trends", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ sources }),
  });
  const data = await res.json();

  document.getElementById("trends-updated").textContent = `最終更新: ${data.updated_at}`;
  container.innerHTML = "";

  const sourceColors = { X: "source-x", Google: "source-google", TikTok: "source-tiktok" };

  for (const [source, items] of Object.entries(data.trends)) {
    const block = document.createElement("div");
    block.className = "trend-source-block";
    block.innerHTML = `<div class="trend-source-title ${sourceColors[source]}">${source}</div>`;

    items.forEach(item => {
      const el = document.createElement("div");
      el.className = "trend-item";
      el.innerHTML = `
        <div class="trend-rank">${item.rank}</div>
        <div class="trend-info">
          <div class="trend-keyword">${item.keyword}</div>
          <div class="trend-meta">検索ボリューム: ${item.volume.toLocaleString()}</div>
        </div>
        <div class="trend-change">${item.change}</div>
        <div class="trend-category">${item.category}</div>
      `;
      el.addEventListener("click", () => {
        document.getElementById("keyword-input").value = item.keyword;
        document.getElementById("register-section").scrollIntoView({ behavior: "smooth" });
        document.getElementById("keyword-input").focus();
      });
      block.appendChild(el);
    });

    container.appendChild(block);
  }
}

// 商品登録・分析
document.getElementById("register-btn").addEventListener("click", async () => {
  const keyword = document.getElementById("keyword-input").value.trim();
  const url = document.getElementById("url-input").value.trim();

  if (!keyword && !url) {
    showToast("キーワードまたはURLを入力してください", "error");
    return;
  }

  const btn = document.getElementById("register-btn");
  btn.textContent = "分析中...";
  btn.disabled = true;

  const res = await fetch("/api/register", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ keyword, url }),
  });
  const data = await res.json();
  btn.textContent = "登録・分析";
  btn.disabled = false;

  if (!data.success) {
    showToast(data.error, "error");
    return;
  }

  showToast("商品を登録しました", "success");
  renderAnalysis(data.product);
  loadProducts();
});

function renderAnalysis(product) {
  const resultEl = document.getElementById("analysis-result");
  resultEl.classList.remove("hidden");
  resultEl.scrollIntoView({ behavior: "smooth" });

  document.getElementById("analysis-keyword").textContent = product.keyword || "商品";

  // 仕入れ先テーブル
  const tbody = document.getElementById("suppliers-tbody");
  tbody.innerHTML = "";
  product.suppliers.forEach(s => {
    const isChina = s.type.includes("中国");
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td class="supplier-name">${s.name}</td>
      <td><span class="type-badge ${isChina ? "type-china" : "type-domestic"}">${s.type}</span></td>
      <td class="price-cell">¥${s.price.toLocaleString()}</td>
      <td>${s.moq}個〜</td>
      <td>${s.lead_time}</td>
      <td><span class="stars">${"★".repeat(Math.round(s.rating))}${"☆".repeat(5 - Math.round(s.rating))}</span> ${s.rating}</td>
      <td><a href="${s.url}" target="_blank" class="link-btn">検索</a></td>
    `;
    tbody.appendChild(tr);
  });

  // 価格比較
  const pc = product.price_comparison;
  const grid = document.getElementById("comparison-grid");
  grid.innerHTML = `
    <div class="comparison-card amazon">
      <div class="comparison-platform">Amazon 出品</div>
      <div class="comparison-price"><span>¥</span>${pc.amazon.price.toLocaleString()}</div>
      <div class="comparison-details">
        <div><span class="label">仕入れ値: </span><span class="value">¥${pc.cost_price.toLocaleString()}</span></div>
        <div><span class="label">手数料: </span><span class="value">${pc.amazon.fee_rate}%</span></div>
        <div><span class="label">利益: </span><span class="value ${pc.amazon.profit >= 0 ? "profit-positive" : "profit-negative"}">¥${pc.amazon.profit.toLocaleString()}</span></div>
        <div><span class="label">利益率: </span><span class="value">${pc.amazon.margin}%</span></div>
        <div><span class="label">レビュー: </span><span class="value">${pc.amazon.review_count.toLocaleString()}件 (${pc.amazon.rating})</span></div>
      </div>
    </div>
    <div class="comparison-card ours">
      <div class="comparison-platform">弊社 販売</div>
      <div class="comparison-price"><span>¥</span>${pc.ours.price.toLocaleString()}</div>
      <div class="comparison-details">
        <div><span class="label">仕入れ値: </span><span class="value">¥${pc.cost_price.toLocaleString()}</span></div>
        <div><span class="label">手数料: </span><span class="value">${pc.ours.fee_rate}%</span></div>
        <div><span class="label">利益: </span><span class="value ${pc.ours.profit >= 0 ? "profit-positive" : "profit-negative"}">¥${pc.ours.profit.toLocaleString()}</span></div>
        <div><span class="label">利益率: </span><span class="value">${pc.ours.margin}%</span></div>
      </div>
      <div class="recommendation-badge">✓ ${pc.recommendation}</div>
    </div>
  `;
}

async function loadProducts() {
  const res = await fetch("/api/products");
  const data = await res.json();
  const list = document.getElementById("products-list");
  const count = document.getElementById("products-count");

  count.textContent = data.products.length;

  if (data.products.length === 0) {
    list.innerHTML = '<p class="empty-msg">登録済みの商品はありません</p>';
    return;
  }

  list.innerHTML = "";
  [...data.products].reverse().forEach(p => {
    const pc = p.price_comparison;
    const el = document.createElement("div");
    el.className = "product-item";
    el.innerHTML = `
      <div>
        <div class="product-keyword">${p.keyword || "（キーワードなし）"}</div>
        <div class="product-meta">登録: ${p.registered_at}${p.url ? " | URL: " + p.url.slice(0, 40) + "..." : ""}</div>
      </div>
      <div class="product-margin">利益率 ${pc.ours.margin}%</div>
    `;
    list.appendChild(el);
  });
}

function showToast(msg, type = "success") {
  const existing = document.querySelector(".toast");
  if (existing) existing.remove();

  const toast = document.createElement("div");
  toast.className = `toast ${type}`;
  toast.textContent = msg;
  document.body.appendChild(toast);
  setTimeout(() => toast.remove(), 3000);
}
