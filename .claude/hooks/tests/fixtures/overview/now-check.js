// 專案圖解「現況」分頁的測試腳本：run-tests.sh 把它塞進範本複本的 </body> 前，用 headless chrome --dump-dom 跑。
// live.js 的載入被攔下來改成 data: 網址，內容在載入當下依 Date.now() 現算（經過時間、卡住要對得上頁面的時鐘）；
// LV 為 null 時改載一個不存在的檔，模擬還沒有 live.js。結果以 JSON 寫進 <pre id="result">。
// 用 http 開時改測伺服器結束提示：先記一次，再 POST .shutdown 關掉伺服器、等下一輪輪詢後再記一次。
(function(){
var R = {}, LV = null, ap = document.head.appendChild.bind(document.head), T = 0;
document.head.appendChild = function (n) {
  if (n.tagName === 'SCRIPT' && location.protocol !== 'http:' && /^live\.js/.test(n.getAttribute('src') || ''))
    n.src = LV ? (T = Math.floor(Date.now() / 1000), 'data:text/javascript,' + encodeURIComponent('window.OVERVIEW_LIVE = ' + JSON.stringify(LV()) + ';')) : 'no-such-live.js';
  return ap(n);
};
function $(i) { return document.getElementById(i); }
function q(s) { return document.querySelector(s); }
function qa(s) { return [].slice.call(document.querySelectorAll(s)); }
function vis(e) { return !!e && getComputedStyle(e).display !== 'none' && !e.closest('[hidden]'); }
function kpis() { var o = {}; qa('.kpi').forEach(function (k) { o[k.id] = {t: k.querySelector('.kn').textContent, zero: k.classList.contains('zero')}; }); return o; }
function lane(id) { return q('.lane[data-id="' + id + '"]'); }
function snap() {
  return {kpis: kpis(), needs: qa('#needs li').map(function (l) { return l.textContent; }), groups: qa('#groups > .tgrp').map(function (g) { return g.querySelector('.tgh b').textContent + '|' + g.querySelectorAll('.lane').length; }),
    nnone: vis($('nnone')) ? $('nnone').textContent : null, gone: vis($('gone')) ? $('gone').textContent : null};
}
function ln(id, g, since, last, files) { return {id: id, who: 'implementer', desc: '任務 ' + id, where: 'main', readonly: false, group: g, since: T - since, lastAt: T - last, doing: '編輯 ' + id + '.ts', files: files}; }
var added = {};
// l1 插進畫面當下記時鐘，之後第一次變成不同的值再記一次（每秒跳一格 → 5:00 之後是 5:01）
function watchClock(n) {
  var c = n.querySelector('.lclock'), o = new MutationObserver(function () { if (c.textContent !== R.clock0) { R.clock1 = c.textContent; o.disconnect(); } });
  R.clock0 = c.textContent;
  o.observe(c, {childList: true, characterData: true, subtree: true});
}
new MutationObserver(function (ms) { ms.forEach(function (m) { [].forEach.call(m.addedNodes, function (n) {
  if (!n.querySelectorAll) return;
  (n.classList.contains('lane') ? [n] : [].slice.call(n.querySelectorAll('.lane'))).forEach(function (l) {
    added[l.dataset.id] = l.classList.contains('enter');
    if (l.dataset.id === 'l1' && R.clock0 == null) watchClock(l);
  });
}); }); }).observe(document.body, {childList: true, subtree: true});

if (location.protocol === 'http:') {
  setTimeout(function () { R.alive = snap(); fetch('.shutdown', {method: 'POST'}); }, 1500);
  setTimeout(function () { R.dead = snap(); R.deadNv = !!q('#nv .kpis'); R.deadTitle = $('title').textContent; done(); }, 6000);
  return;
}
var ON = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
setTimeout(function () {
  R.hashless = {v: document.documentElement.classList.contains('v-now'), tabs: qa('.tabs button').map(function (b) { return b.textContent.replace(/（.*/, ''); }),
    legend: vis(q('.legend')), chipbar: vis(q('.chipbar')), still: $('still').textContent};
  R.none = snap();
  if (ON) {
    var bad = [];
    qa('*').forEach(function (e) {
      if (getComputedStyle(e).animationName !== 'none' || getComputedStyle(e, '::after').animationName !== 'none') bad.push(e.tagName + '.' + e.className);
    });
    R.reduceBad = bad.length;
    return done();
  }
  LV = function () {
    return {lanes: [ln('l1', 'g1', 300, 660, {done: 1, total: 3}), ln('l2', 'g1', 60, 5, null), ln('l3', 'g1', 30, 5, null), ln('l4', null, 30, 5, null)],
      needs: [{id: 'n1', kind: 'approve', who: 'implementer', where: 'main', text: 'npm install', since: T - 120}, {id: 'n2', kind: 'reply', who: '主 session', where: 'main', text: '要哪一個？', since: T - 60}],
      clashes: [], doneToday: {agents: 7, tasks: 1}, feed: [], at: 'A'};
  };
}, 800);
setTimeout(function () {
  R.A = snap();
  R.A.stuck = lane('l1').classList.contains('stuck');
  R.A.firstEnter = added.l1;
  R.A.bar = lane('l1').querySelector('.pbar i').style.width;
  R.A.ind = lane('l2').querySelector('.pbar').classList.contains('ind');
  R.A.anim = getComputedStyle(lane('l2').querySelector('.pbar i')).animationName;
  R.ref = lane('l2');
}, 3600);
setTimeout(function () {
  var a = LV;
  LV = function () { var x = a(); return Object.assign(x, {lanes: x.lanes.concat([ln('l5', 'g2', 10, 5, null)]), doneToday: {agents: 0, tasks: 2}, at: 'B'}); };
}, 4600);
setTimeout(function () {
  R.B = snap();
  R.B.same = lane('l2') === R.ref; delete R.ref;
  R.B.enter = added.l5;
  var b = LV;
  LV = function () { return Object.assign(b(), {doneToday: {agents: 0, tasks: 0}, at: 'C'}); };
}, 7200);
setTimeout(function () {
  R.C = snap();
  q('.tabs button[data-v=map]').click();
  R.map = {legend: vis(q('.legend')), chipbar: vis(q('.chipbar')), still: vis($('still'))};
  q('.tabs button[data-v=now]').click();
  R.back = {legend: vis(q('.legend')), chipbar: vis(q('.chipbar'))};
  $('still').click();
  R.still = {text: $('still').textContent, ls: localStorage.getItem('overview-still'), play: getComputedStyle(lane('l2').querySelector('.pbar i')).animationPlayState};
  done();
}, 9800);
function done() { var p = document.createElement('pre'); p.id = 'result'; p.textContent = JSON.stringify(R); document.body.appendChild(p); }
})();
