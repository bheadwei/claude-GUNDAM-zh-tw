# 審查：overview-stable-url 階段 3（57588d5..f8dc906）

結論：PASS（無 CRITICAL／HIGH），2 項 MEDIUM、1 項 LOW。
驗證：run-tests agent-events 105/0、overview.sh --live 121/0；/usr/bin/jq 1.6 實跑探針；grep live-events 閘門檔為空。

- restart 用排序位置 p（t, ms, 檔內序）比較，同秒事件由 ms 決定，不是 t 相等的誤判；不同 sid、compact、之後仍有事件皆正確（探針與測試）。
- 閒置主 session：舊案例改預期正是計畫裁決。Stop→UserPromptSubmit→長 PreToolUse 仍在 lanes；沒有誤傷。
- settings.json 只多 SessionStart 一條 async；README 兩處、ADR-002 增補段（含 /clear、新視窗只靠 silent）完整。

[MEDIUM] silent 會把「等你批准」的 agent 與其 need 一起收掉
File: .claude/scripts/overview.sh（$cand 的 silent 判定、$cutP 關 need）
探針：b1 最後一筆 PermissionRequest（need=approve）距今 40 分鐘 → lanes 空、needs 0、feed 有 agent_cut silent＋need_done。
Issue：使用者離開超過 30 分鐘時，被擋住的批准／AskUserQuestion 從「需要你」消失，正是最需要它的時候。計畫只排除 Bash/PowerShell，所以是照規格，但規格有洞。
Fix：最後一筆是 PermissionRequest、或 PreToolUse AskUserQuestion（即 need 仍開著）時不判 silent；restart 照舊。

[MEDIUM] 無 PreToolUse 的長工具（WebFetch、MCP、Agent 巢狀）超過 30 分鐘會被 silent 誤判
同上機制（白名單外的工具只有 PostToolUse）。嚴重度：只影響畫面且下一筆事件來時不會復活（lane 以事件重算，其實會復活，但 agent_cut 與 need_done 的 feed 紀錄會殘留）。單次工具超過 30 分鐘罕見，可接受；建議把門檻與限制寫進檔頭一句即可，不必改碼。

[LOW] 只有 Notification 的 session（例如只收到 permission_prompt）不進 lanes，需求仍在 needs；符合規格，無需處理。

測試：每條驗收都有對應案例；無「有風險路徑完全沒測」，不建 handoff。
