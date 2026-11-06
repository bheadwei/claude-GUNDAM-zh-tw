// 專案圖解畫面的檢查腳本：整份檔案內容就是一個函式，原樣當 Playwright MCP browser_evaluate 的 function 參數。
// 回傳六項，全部為 0 或 false 才算過（ADR-2026-11-05-003「確認方式」、plan 階段 3）。
// 量的是專案地圖（畫布、頁首、提示與落差抽屜、右側欄），不含任務圖分頁。
// 量測時暫時打開全部縮放分層（lod1、lod2），讓只在放大時才顯示的文字也被量到，量完還原。
() => {
  const root = document.documentElement, world = document.getElementById('world');
  const saved = root.className;
  root.classList.add('lod1', 'lod2');
  try {
    const hit = (a, b) => a.left < b.right - 0.5 && b.left < a.right - 0.5 && a.top < b.bottom - 0.5 && b.top < a.bottom - 0.5;
    const pairs = rs => rs.reduce((n, a, i) => n + rs.slice(i + 1).filter(b => hit(a, b)).length, 0);
    const rects = sel => [...world.querySelectorAll(sel)].map(r => r.getBoundingClientRect());
    const overlaps = pairs(rects('.mod > rect.box')) + pairs(rects('rect.grp'));

    const vb = (document.getElementById('mini').getAttribute('viewBox') || '').split(/\s+/).map(Number);
    const toWorld = world.getScreenCTM().inverse();
    let outOfBounds = 0;
    if (vb.length === 4) {
      world.querySelectorAll('rect, path, text, circle, line').forEach(e => {
        const ctm = e.getScreenCTM();
        if (!ctm) return;
        const b = e.getBBox();
        if (!b.width && !b.height) return;
        const m = toWorld.multiply(ctm);
        const pts = [[b.x, b.y], [b.x + b.width, b.y], [b.x, b.y + b.height], [b.x + b.width, b.y + b.height]]
          .map(([x, y]) => new DOMPoint(x, y).matrixTransform(m));
        if (pts.some(p => p.x < vb[0] - 0.5 || p.y < vb[1] - 0.5 || p.x > vb[0] + vb[2] + 0.5 || p.y > vb[1] + vb[3] + 0.5)) outOfBounds++;
      });
    } else outOfBounds = -1;

    const scopes = [world, document.querySelector('.bar'), document.getElementById('ntc'),
      document.getElementById('drift'), document.getElementById('panel')].filter(Boolean);
    const texts = [];
    scopes.forEach(s => {
      const w = document.createTreeWalker(s, NodeFilter.SHOW_TEXT, {
        acceptNode: n => n.parentNode.closest('script, style, title') ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT
      });
      for (let n = w.nextNode(); n; n = w.nextNode()) { const t = n.nodeValue.trim(); if (t) texts.push(t); }
    });
    const brCount = texts.reduce((n, t) => n + (t.match(/<br|&lt;br/gi) || []).length, 0);
    const EMPTY = /沒有|尚未|找不到|（無）|^—$/;
    const seen = {};
    texts.filter(t => EMPTY.test(t)).forEach(t => { seen[t] = (seen[t] || 0) + 1; });
    const dupEmpty = Object.keys(seen).filter(t => seen[t] > 1).length;

    let overflowText = 0;
    world.querySelectorAll('.mod').forEach(g => {
      const w = Number(g.querySelector('rect.box').getAttribute('width'));
      g.querySelectorAll('text:not(.badge-t)').forEach(t => {
        const b = t.getBBox();
        if (b.width && (b.x < 4 || b.x + b.width > w - 4)) overflowText++;
      });
    });
    world.querySelectorAll('g.gg').forEach(g => {
      const r = g.querySelector('rect.grp').getBBox(), b = g.querySelector('text').getBBox();
      if (b.width && b.x + b.width > r.x + r.width - 4) overflowText++;
    });

    const hScroll = root.scrollWidth > root.clientWidth || document.body.scrollWidth > document.body.clientWidth;
    return {overlaps, outOfBounds, brCount, dupEmpty, overflowText, hScroll};
  } finally {
    root.className = saved;
  }
}
