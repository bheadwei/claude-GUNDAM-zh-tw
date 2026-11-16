// 專案圖解「現況」分頁的測試腳本：run-tests.sh 把它塞進範本複本的 </body> 前，用 headless chrome --dump-dom 跑。
// live.js 的載入被攔下來改成 data: 網址，內容在載入當下依 Date.now() 現算（經過時間、卡住要對得上頁面的時鐘）；
// LV 為 null 時改載一個不存在的檔，模擬還沒有 live.js。結果以 JSON 寫進 <pre id="result">。
// 用 http 開時改測伺服器結束提示，依網址的 ?<模式>：
//   （沒有）真的 POST .shutdown 關掉伺服器，等下一輪輪詢；
//   ?mock   .serve-id 的回應由 FX 假造：連不上 → 提示、tick 停住（部件卡的經過分鐘數也停）→ 不切分頁、改回 200 → 提示消失、恢復輪詢
//           → 404 → 網址已失效 → 改回 200 → 提示消失、恢復輪詢；
//   ?never  從沒連上過、第一次就拿到 404 → 不顯示提示、照常輪詢；
//   ?hide   分頁隱藏 15 分鐘（虛擬時間）→ 只剩 .serve-id 心跳；回到可見 → 立刻各載入一次 data.js、live.js，心跳停；
//   ?real=<port>  真伺服器：關掉後出現提示，再對 127.0.0.1:<port>（測試開的慢速伺服器）發請求，請求懸著時虛擬時間不前進，外部趁這段把伺服器重起；之後提示自己消失。
(function(){
var R = {}, LV = null, ap = document.head.appendChild.bind(document.head), T = 0, MODE = location.search.slice(1), NL = 0, ND = 0, NF = 0, FX = null, VS = 'visible';
Object.defineProperty(document, 'visibilityState', {get: function () { return VS; }});
document.head.appendChild = function (n) {
  if (n.tagName === 'SCRIPT' && /^data\.js/.test(n.getAttribute('src') || '')) ND++;
  if (n.tagName === 'SCRIPT' && /^live\.js/.test(n.getAttribute('src') || '')) {
    NL++;
    if (location.protocol !== 'http:' || MODE)
      n.src = LV ? (T = Math.floor(Date.now() / 1000), 'data:text/javascript,' + encodeURIComponent('window.OVERVIEW_LIVE = ' + JSON.stringify(LV()) + ';')) : 'no-such-live.js';
  }
  return ap(n);
};
var of = window.fetch;
window.fetch = function (u) { if (/\.serve-id/.test(u)) NF++; return FX && /\.serve-id/.test(u) ? FX() : of.apply(this, arguments); };
function res(code) { return function () { return Promise.resolve(new Response('', {status: code})); }; }
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

function at(ms, f) { setTimeout(f, ms); }
function seeVis() { document.dispatchEvent(new Event('visibilitychange')); }
if (MODE === 'never') {
  FX = res(404);
  at(3000, function () { R.n0 = {gone: snap().gone, nl: NL}; });
  at(9000, function () { R.n1 = {gone: snap().gone, nl: NL}; done(); });
  return;
}
if (MODE === 'hide') {
  LV = function () { return {lanes: [], needs: [], clashes: [], doneToday: {agents: 0, tasks: 0}, feed: [], at: 'H' + T}; };
  FX = res(200);
  function cnt() { return {sid: NF, data: ND, live: NL}; }
  var c0;
  at(3000, function () { VS = 'hidden'; seeVis(); c0 = cnt(); });
  at(913000, function () { var c = cnt(); R.h1 = {sid: c.sid - c0.sid, data: c.data - c0.data, live: c.live - c0.live}; c0 = c; VS = 'visible'; seeVis(); });
  at(913400, function () { var c = cnt(); R.h2 = {sid: c.sid - c0.sid, data: c.data - c0.data, live: c.live - c0.live}; c0 = c; });
  at(1230000, function () { R.h3 = {sid: NF - c0.sid}; done(); });
  return;
}
if (MODE === 'mock') {
  LV = function () { return {lanes: [Object.assign(ln('m1', 'g1', 50, 590, null), {parts: ['p2a']})], needs: [], clashes: [], doneToday: {agents: 0, tasks: 0}, feed: [], at: 'M' + T}; };
  at(3000, function () { R.m0 = {need: kpis()['k-need'].t, lanes: qa('.lane').length}; LV = null; FX = function () { return Promise.reject(new TypeError('down')); }; });
  at(8000, function () { R.m1 = {gone: snap().gone, clock: lane('m1').querySelector('.lclock').textContent, part: q('.pc[data-part] .who').textContent}; });
  at(21000, function () {
    R.m2 = {need: kpis()['k-need'].t, clock: lane('m1').querySelector('.lclock').textContent, nl: NL, part: q('.pc[data-part] .who').textContent};
    FX = res(200); LV = function () { return {lanes: [ln('m1', 'g1', 30, 5, null)], needs: [], clashes: [], doneToday: {agents: 0, tasks: 0}, feed: [], at: 'R' + T}; };
  });
  at(32000, function () { R.m3 = {gone: snap().gone, nl: NL}; });
  at(36000, function () { R.m3b = {nl: NL}; LV = null; FX = res(404); });
  at(40000, function () { R.m4 = {gone: snap().gone, nl: NL}; });
  at(41000, function () { FX = res(200); LV = function () { return {lanes: [], needs: [], clashes: [], doneToday: {agents: 0, tasks: 0}, feed: [], at: 'S' + T}; }; });
  at(54000, function () { R.m5 = {gone: snap().gone, nl: NL}; });
  at(58000, function () { R.m6 = {nl: NL}; done(); });
  return;
}
if (/^real=/.test(MODE)) {
  at(1500, function () { R.alive = snap(); fetch('.shutdown', {method: 'POST'}); });
  at(8000, function () { R.dead = snap(); of('http://127.0.0.1:' + MODE.slice(5) + '/', {mode: 'no-cors'}).then(function () { R.held = true; }, function () { R.held = false; }); });
  at(30000, function () { R.back = snap(); done(); });
  return;
}
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
  LV = function () {
    return {lanes: [ln('l1', 'g1', 300, 660, {done: 1, total: 3}), ln('l2', 'g1', 60, 5, null), ln('l3', 'g1', 30, 5, null), ln('l4', null, 30, 5, null)],
      needs: [{id: 'n1', kind: 'approve', who: 'implementer', where: 'main', text: 'npm install', since: T - 120}, {id: 'n2', kind: 'reply', who: '主 session', where: 'main', text: '要哪一個？', since: T - 60}],
      clashes: [], doneToday: {agents: 7, tasks: 1}, feed: [], at: 'A'};
  };
}, 800);
setTimeout(function () {
  if (ON) {
    var bad = [];
    qa('*').forEach(function (e) {
      if (getComputedStyle(e).animationName !== 'none' || getComputedStyle(e, '::after').animationName !== 'none') bad.push(e.tagName + '.' + e.className);
    });
    R.reduceBad = bad.length;
    R.reduceSeen = {lanes: qa('.lane').length, ind: qa('.pbar.ind i').length};
    return done();
  }
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
var fin = false;
function done() { if (fin) return; fin = true; var p = document.createElement('pre'); p.id = 'result'; p.textContent = JSON.stringify(R); document.body.appendChild(p); }
})();
