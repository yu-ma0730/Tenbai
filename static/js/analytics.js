/*
 * 汎用アクセス解析タグ
 * 使い方（計測したいページに1行追加するだけ）:
 * <script defer
 *   src="https://<このプロジェクトのドメイン>/static/js/analytics.js"
 *   data-site="example.com"
 *   data-endpoint="https://<このプロジェクトのドメイン>/api/collect"></script>
 */
(function () {
  var script = document.currentScript;
  if (!script) return;

  var endpoint = script.getAttribute("data-endpoint");
  var site = script.getAttribute("data-site") || location.hostname;
  if (!endpoint) return;

  function send() {
    var payload = JSON.stringify({
      site: site,
      path: location.pathname + location.search,
      referrer: document.referrer || "",
      title: document.title,
      screen: screen.width + "x" + screen.height,
      lang: navigator.language || "",
    });

    if (navigator.sendBeacon) {
      navigator.sendBeacon(endpoint, new Blob([payload], { type: "application/json" }));
    } else {
      fetch(endpoint, {
        method: "POST",
        mode: "no-cors",
        headers: { "Content-Type": "text/plain" },
        body: payload,
        keepalive: true,
      }).catch(function () {});
    }
  }

  send();

  var pushState = history.pushState;
  history.pushState = function () {
    pushState.apply(history, arguments);
    send();
  };
  window.addEventListener("popstate", send);
})();
