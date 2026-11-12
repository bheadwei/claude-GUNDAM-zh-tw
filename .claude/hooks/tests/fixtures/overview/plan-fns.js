// 任務圖的純函式測試：從畫面範本抓出 taskIds、commonDir、shortf 三個函式，用 node 跑，結果以 JSON 印出。
// 用法：node plan-fns.js <index.html>
const src = require('fs').readFileSync(process.argv[2], 'utf8');
const grab = n => { const m = src.match(new RegExp('function ' + n + '\\([\\s\\S]*?\\n}\\n')); if (!m) throw new Error('找不到 ' + n); return m[0]; };
const { taskIds, commonDir, shortf } = new Function(['taskIds', 'commonDir', 'shortf'].map(grab).join('\n') + '\nreturn {taskIds, commonDir, shortf};')();
const P = 'src/services/checkout/app/';
const big = [];
for (let i = 0; i < 20; i++) big.push(P + (i < 10 ? 'cart' : 'orders') + '/f' + i + '.py');
for (let i = 0; i < 10; i++) big.push('docs/d' + i + '.md');
const scattered = ['a/x/1.py', 'b/y/2.py', 'c/z/3.py', 'd/w/4.py'];
console.log(JSON.stringify({
  ids3: taskIds('21.2,21.3,21.4'),
  ids2: taskIds('1.2,1.3'),
  ids9: taskIds('21.2,21.3,21.4,21.5,21.6,21.7,21.8,21.9,21.10'),
  idsEmpty: taskIds(''),
  big: commonDir(big),
  bigShort: shortf(P + 'cart/store.py', commonDir(big)),
  two: commonDir([P + 'a.py', P + 'b.py']),
  scattered: commonDir(scattered),
  none: shortf('docs/x.md', ''),
}));
