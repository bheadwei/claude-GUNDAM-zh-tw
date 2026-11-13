# 審查：專案地圖改版階段 1（4e95685..3923a32）
結論：通過（無 CRITICAL／HIGH）。

- [MEDIUM] .claude/hooks/tests/run-tests.sh:3535 / 3552：沒有 chrome 時只印 ok 略過，計入通過數。畫面「保留狀態」的 6 條斷言在 CI 沒 chrome 時等於沒跑，卻是綠的。
- [LOW] .claude/scripts/overview.sh:1801-1807：資料沒變就不重寫 → 畫面「資料時間」停在舊的 generatedAt，使用者看起來像沒更新。屬規格取捨。
- [LOW] .claude/hooks/tests/fixtures/overview/keep-state.js:22：R.aftertitle 寫入後沒人讀（死碼）。
- [LOW] index.html:822-826：OPEN 只增不減，key 為 loose|模組|label、plan|source|file|extra，量級小、無碰撞（皆含前綴；僅 source/file 含 | 才可能撞，現實不會）。
