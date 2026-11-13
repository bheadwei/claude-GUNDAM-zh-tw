// 專案圖解任務圖「部件卡誰在做／等你」與標題列目前任務標籤的測試腳本：run-tests.sh 把它塞進範本複本的 </body> 前，
// 以 #tasks 開頁、用 headless chrome --dump-dom 跑。live.js 的載入同 now-check.js 改成 data: 網址、依 Date.now() 現算。
// 結果以 JSON 寫進 <pre id="result">。
(function(){
var R = {}, LV = null, ap = document.head.appendChild.bind(document.head), T = 0;
document.head.appendChild = function (n) {
  if (n.tagName === 'SCRIPT' && /^live\.js/.test(n.getAttribute('src') || ''))
    n.src = LV ? (T = Math.floor(Date.now() / 1000), 'data:text/javascript,' + encodeURIComponent('window.OVERVIEW_LIVE = ' + JSON.stringify(LV()) + ';')) : 'no-such-live.js';
  return ap(n);
};
function $(i) { return document.getElementById(i); }
function q(s) { return document.querySelector(s); }
function card(id) { return q('.pc[data-part="plans/1.2-x.md|' + id + '"]'); }
function who(id) { var w = card(id).querySelector('.who'); return w.hidden ? null : w.textContent; }
function ln(id, g, parts) { return {id: id, who: 'implementer', desc: null, where: 'main', readonly: false, group: g, since: T - 720, lastAt: T - 5, doing: '編輯 a.ts', files: null, parts: parts}; }
function lanes() {
  var a = [ln('a1', 'g1', ['p9a'])];
  for (var i = 0; i < 6; i++) a.push(ln('x' + i, 'g1', []), ln('y' + i, 'g5', []), ln('z' + i, 'g3', []));
  return a;
}
var NEED = {id: 's1|a1|' + 0, kind: 'approve', who: 'implementer', where: 'main', text: 'Bash：跑 部署', since: 0};
var ref = {};
setTimeout(function () { LV = function () { return {lanes: lanes(), needs: [], clashes: [], doneToday: {agents: 0, tasks: 0}, feed: [], at: 'A'}; }; }, 800);
setTimeout(function () {
  R.A = {p9a: who('p9a'), p9b: who('p9b'), st: card('p9a').querySelector('.st').textContent};
  $('tv').scrollTop = 300;
  ref = {tc: q('.tcards'), card: card('p9a'), top: $('tv').scrollTop};
  LV = function () { return {lanes: lanes(), needs: [Object.assign({}, NEED, {id: 's1|a1|' + (T - 30), since: T - 30})], clashes: [], doneToday: {agents: 0, tasks: 0}, feed: [], at: 'B'}; };
}, 3000);
setTimeout(function () {
  var c = card('p9a');
  R.B = {st: c.querySelector('.st').textContent, waiting: c.classList.contains('waiting'),
    yellow: getComputedStyle(c).borderTopColor === getComputedStyle(q('.steps li.wip')).backgroundColor, p9b: card('p9b').classList.contains('waiting')};
  LV = function () { return {lanes: lanes(), needs: [], clashes: [], doneToday: {agents: 0, tasks: 0}, feed: [], at: 'C'}; };
}, 5500);
setTimeout(function () {
  var c = card('p9a');
  R.C = {st: c.querySelector('.st').textContent, waiting: c.classList.contains('waiting'), who: who('p9a'),
    top: ref.top > 0 && $('tv').scrollTop === ref.top, tc: q('.tcards') === ref.tc, card: c === ref.card};
  R.btns = [].map.call(document.querySelectorAll('#curbar button[data-g]'), function (b) { return b.dataset.g; });
  q('#curbar button[data-g="g1"]').click();
}, 8000);
setTimeout(function () {
  var g = [].filter.call($('groups').children, function (x) { return x.dataset.id === 'g1'; })[0];
  R.D = {now: document.documentElement.classList.contains('v-now'), hash: location.hash, scrolled: $('nv').scrollTop > 0,
    dy: Math.round(g.getBoundingClientRect().top - $('nv').getBoundingClientRect().top), open: q('#curbar details').open};
  var p = document.createElement('pre'); p.id = 'result'; p.textContent = JSON.stringify(R); document.body.appendChild(p);
}, 10000);
})();
