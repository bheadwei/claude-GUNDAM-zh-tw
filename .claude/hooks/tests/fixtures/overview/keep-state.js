// 專案圖解「重畫保留畫面狀態」的測試腳本：run-tests.sh 把它塞進範本複本的 </body> 前，用 headless chrome --dump-dom 跑。
// 流程：雙擊選模組 → 放大兩次 → 切到任務圖、展開「計畫外」明細、捲動 → 換成內容不同的 data2.js（輪詢重畫）→ 記下重畫前後的狀態；
// 再輪詢一次不變的 data2.js，量 #world 的第一個子節點是不是同一個物件（有重畫的話會被換掉）。結果以 JSON 寫進 <pre id="result">。
(function(){
var R={}, swap='data.js', ap=document.head.appendChild.bind(document.head);
document.head.appendChild=function(n){ if(n.tagName==='SCRIPT'&&/^data\.js/.test(n.getAttribute('src')||'')) n.src=swap+'?t='+Date.now(); return ap(n); };
function $(i){return document.getElementById(i)}
function st(){var m=document.querySelector('.mod.sel');var d=document.querySelector('#tv details.xtra');return {zl:$('zl').textContent,sel:m&&m.dataset.id,open:d&&d.open,scroll:$('tv').scrollTop,view:document.documentElement.className.indexOf('v-tasks')>=0?'tasks':'map',title:$('title').textContent}}
setTimeout(function(){
  var m=document.querySelector('.mod'),r=m.getBoundingClientRect(),o={clientX:r.left+r.width/2,clientY:r.top+r.height/2,bubbles:true};
  $('stage').dispatchEvent(new MouseEvent('dblclick',o));
},800);
setTimeout(function(){
  $('zin').click(); $('zin').click();
  document.querySelector('.tabs button[data-v=tasks]').click();
  var d=document.querySelector('#tv details.xtra'); d.open=true;
  $('tv').scrollTop=150;
},1500);
setTimeout(function(){ R.A=st(); swap='data2.js'; },2000);
setTimeout(function(){ R.B=st(); R.aftertitle=$('title').textContent; document.querySelector('.tabs button[data-v=map]').click(); R.Bmap=st(); R.ref=$('world').firstChild; swap='data2.js'; },4500);
setTimeout(function(){ R.same=($('world').firstChild===R.ref); delete R.ref; var p=document.createElement('pre');p.id='result';p.textContent=JSON.stringify(R);document.body.appendChild(p); },7500);
})();
