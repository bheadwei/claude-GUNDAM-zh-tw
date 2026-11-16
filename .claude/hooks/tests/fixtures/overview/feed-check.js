// 專案圖解「動態」可刪除、中斷與卡住顯示的測試腳本（計畫 adhoc-2026-11-16-overview-stable-url 階段 5）。
// run-tests.sh 塞進範本複本跑，file:// 開頁；live.js 被攔成 data: 網址。依網址的 ?<模式>：
//   del    30 則動態 → 12 則、刪第 1 則（焦點、補位、localStorage）、live.js 多一則新的
//   reload 同一個 profile 重開 → 被刪的仍不出現（data.js 的 project.name 不同時改測不受影響）
//   throw  localStorage.setItem 會 throw → 刪除當下仍從畫面消失、沒有未捕捉的錯誤
//   clear  按「全部清除」→ 動態區隱藏；live.js 之後多一則 → 只出現那 1 則
//   cut    agent_cut 的文字，以及「有未處理 need 的 lane 不算卡住」
// feed 的 t 用固定值（刪掉的 id 含 t，兩次開頁要對得上）。結果以 JSON 寫進 <pre id="result">。
(function(){
var R = {}, LV = null, T = 0, MODE = location.search.slice(1), ap = document.head.appendChild.bind(document.head), errs = 0, E = 1780000000;
window.addEventListener('error', function () { errs++; });
document.head.appendChild = function (n) {
  if (n.tagName === 'SCRIPT' && /^live\.js/.test(n.getAttribute('src') || ''))
    n.src = LV ? (T = Math.floor(Date.now() / 1000), 'data:text/javascript,' + encodeURIComponent('window.OVERVIEW_LIVE = ' + JSON.stringify(LV()) + ';')) : 'no-such-live.js';
  return ap(n);
};
function $(i) { return document.getElementById(i); }
function qa(s) { return [].slice.call(document.querySelectorAll(s)); }
function vis(e) { return !!e && getComputedStyle(e).display !== 'none' && !e.closest('[hidden]'); }
function at(ms, f) { setTimeout(f, ms); }
function rows() { return qa('#feed li:not(.leave)'); }
function ids() { return rows().map(function (l) { return l.dataset.id; }); }
function item(i) { return {t: E - i * 60, kind: 'agent_done', id: 'a' + i, who: 'implementer', where: 'main', text: '任務 ' + i}; }
function feed(n, extra) { var a = []; for (var i = 0; i < n; i++) a.push(item(i)); return (extra || []).concat(a); }
function ln(id, last) { return {id: id, who: 'implementer', desc: '任務 ' + id, where: 'main', readonly: false, group: 'g1', since: T - 900, lastAt: T - last, doing: '編輯 ' + id + '.ts', files: null}; }
function live(o) { return Object.assign({lanes: [], needs: [{id: 'n1', kind: 'approve', who: 'implementer', where: 'main', text: 'npm install', since: T - 120}], clashes: [], doneToday: {agents: 0, tasks: 0}, feed: feed(30), at: 'A'}, o); }
var A0 = '1780000000|agent_done|a0';
var fin = false;
function done() { if (fin) return; fin = true; R.errs = errs; var p = document.createElement('pre'); p.id = 'result'; p.textContent = JSON.stringify(R); document.body.appendChild(p); }

if (MODE === 'del') {
  LV = function () { return live(); };
  at(3000, function () {
    var b = qa('#feed li .fdel');
    R.A = {n: rows().length, btns: b.length, minW: Math.min.apply(null, b.map(function (x) { return x.getBoundingClientRect().width; })),
      minH: Math.min.apply(null, b.map(function (x) { return x.getBoundingClientRect().height; })), tab: b[0].tabIndex, tag: b[0].tagName,
      label: b[0].getAttribute('aria-label'), needs: qa('#needs li').length, needBtns: qa('#needs button').length, clear: !!$('fclear') && vis($('fclear')),
      clearW: $('fclear').getBoundingClientRect().width, clearH: $('fclear').getBoundingClientRect().height};
    var ids0 = ids(); R.ids0 = ids0; R.want13 = (E - 720) + '|agent_done|a12';
    b[0].focus(); b[0].click();
    R.D1 = {active: document.activeElement.closest('li') && document.activeElement.closest('li').dataset.id, want: ids0[1], isBtn: document.activeElement.className};
  });
  at(3600, function () {
    var s = ids(), key = 'overview-feed-hidden|現況|' + location.pathname;
    R.D2 = {n: s.length, first: s[0], last: s[11], ls: JSON.parse(localStorage.getItem(key) || 'null'), left: qa('#feed li').length};
    LV = function () { return live({feed: feed(30, [{t: E + 60, kind: 'agent_start', id: 'new', who: 'implementer', where: 'main', text: '新的'}]), at: 'B'}); };
  });
  at(6500, function () { var s = ids(); R.E = {n: s.length, first: s[0], hasA0: s.indexOf(A0) >= 0}; done(); });
} else if (MODE === 'reload') {
  LV = function () { return live(); };
  at(3000, function () { var s = ids(); R.R = {n: s.length, hasA0: s.indexOf(A0) >= 0, first: s[0]}; done(); });
} else if (MODE === 'throw') {
  LV = function () { return live(); };
  at(1000, function () { Storage.prototype.setItem = function () { throw new Error('quota'); }; });
  at(3000, function () { qa('#feed li .fdel')[0].click(); var s = ids(); R.T = {n: s.length, hasA0: s.indexOf(A0) >= 0, errs: errs}; done(); });
} else if (MODE === 'clear') {
  LV = function () { return live(); };
  at(3000, function () {
    $('fclear').click();
    R.C0 = {hidden: !vis($('feedbox')), n: rows().length, ae: document.activeElement.tagName};
    LV = function () { return live({feed: feed(30, [{t: E + 60, kind: 'agent_start', id: 'new', who: 'implementer', where: 'main', text: '新的'}]), at: 'B'}); };
  });
  at(6500, function () { R.C1 = {vis: vis($('feedbox')), n: rows().length, id: ids()[0]}; done(); });
} else if (MODE === 'cut') {
  LV = function () {
    return live({lanes: [ln('l1', 660), ln('l2', 660)], needs: [{id: 's1|l1|' + (T - 120), kind: 'approve', who: 'implementer', where: 'main', text: 'npm install', since: T - 120}],
      feed: [{t: E, kind: 'agent_cut', id: 'c1', who: 'implementer', where: 'main', text: '舊的', why: 'restart'},
             {t: E - 60, kind: 'agent_cut', id: 'c2', who: 'implementer', where: 'main', text: '舊的', why: 'silent'},
             {t: E - 60 - 1800, kind: 'agent_start', id: 'c2', who: 'implementer', where: 'main', text: '舊的'}]});
  };
  at(3000, function () {
    var fv = qa('#feed .fv.cut');
    R.K = {needs: qa('#needs li').map(function (l) { return l.textContent; }), l1: document.querySelector('.lane[data-id="l1"]').classList.contains('stuck'),
      l2: document.querySelector('.lane[data-id="l2"]').classList.contains('stuck'), fv: fv.map(function (e) { return e.textContent; }),
      fvTitle: fv[0] && fv[0].title, stuckTitle: (qa('#needs .nk').filter(function (e) { return e.textContent === '卡住'; })[0] || {}).title};
    done();
  });
} else done();
})();
