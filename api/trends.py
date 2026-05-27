from http.server import BaseHTTPRequestHandler
import json
import os

def fetch_google_trends():
    try:
        from pytrends.request import TrendReq
        pt = TrendReq(hl='ja-JP', tz=540, timeout=(10, 30))
        df = pt.trending_searches(pn='japan')
        items = []
        for rank, keyword in enumerate(df[0].tolist()[:10], 1):
            items.append({'rank': rank, 'keyword': keyword, 'volume': 0, 'change': '急上昇', 'category': 'Google急上昇'})
        return {'success': True, 'items': items}
    except Exception as e:
        return {'success': False, 'error': str(e)}

def fetch_rakuten_trends():
    try:
        import requests
        app_id = os.environ.get('RAKUTEN_APP_ID', '')
        if not app_id:
            return {'success': False, 'error': 'RAKUTEN_APP_ID not set'}
        url = 'https://app.rakuten.co.jp/services/api/IchibaItem/Ranking/20170628'
        params = {'format': 'json', 'applicationId': app_id, 'hits': 10, 'page': 1, 'genreId': 0}
        resp = requests.get(url, params=params, timeout=10)
        resp.raise_for_status()
        data = resp.json()
        items = []
        for rank, item in enumerate(data.get('Items', [])[:10], 1):
            info = item.get('Item', {})
            items.append({'rank': rank, 'keyword': info.get('itemName', '')[:30], 'volume': info.get('reviewCount', 0), 'change': f"¥{int(info.get('itemPrice', 0)):,}", 'category': info.get('genreName', '楽天')})
        return {'success': True, 'items': items}
    except Exception as e:
        return {'success': False, 'error': str(e)}

class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        source = 'google'
        if '?' in self.path:
            qs = self.path.split('?', 1)[1]
            for part in qs.split('&'):
                if part.startswith('source='):
                    source = part.split('=', 1)[1].lower()
        result = fetch_rakuten_trends() if source == 'rakuten' else fetch_google_trends()
        body = json.dumps(result, ensure_ascii=False).encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, format, *args):
        pass
