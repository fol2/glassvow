# Batch 1 — 六 quest 線 + 24 whispers 重寫(#301)

> 狀態:**[PROPOSED — 待 James review(pipeline step 5)]**
> 依 `04-delivery.md` batch order [SETTLED — #262 Q8]:Batch 1 = 全部已 shipped
> 文案,climb 清洗與逐代分配表先行;餵 #228 / #232。

## Brief(pipeline step 1)

- **範圍**:`content.quests.*` 六線全句 pass + `content.whispers.*` 24 句
  重寫連逐代行者分配表(方法 00 §8.5 [SETTLED — #258 R3 Q16])。
- **可倚賴的 bible**:00 全部;01(地理、火的物理、渠道紀律);02(聲線);
  03(四幕深背景);04(per-channel ceiling、line table schema);05;06。
- **等級上限**:whispers ≤L1;quest bodies ≤L1;quest closers ≤L2
  (04-delivery [SETTLED — #258 R1 Q5 + R2 N3])。L1 重量天花=影的控訴句
  (02-cast [SETTLED — #260 Q5])。
- **語言**:zh-Hant 源語(HK 書面語,着/裏);en 全文重寫,禁 calque。
- **詞彙**:Tier A 禁(尖塔/Spire、爬/攀/climb、登臨/ascend、頂點/summit、
  之上作地點/above-as-place、向上/upward、階梯作路/stair);Tier B 保
  (王冠、破曉、朝聖、場景內字面上下)[SETTLED — #232 Q1]。

## 授權格式說明

依 #262 Q5 的 flat line table schema
`{id, speaker, slot, conditions, priority, once, cooldown_runs, weight, zh, en, asserts}`:
本批全屬**靜態 content key**(非 pool),`conditions/priority/once/cooldown_runs/weight`
全部留空,故表格省去該五欄;`slot` 即 id 本身。`asserts` 僅在同步對出現。
每行的 級/表面/揭後 已同步入 `05-foreshadow-ledger.md` Batch 1 區。

## 落地封鎖(本批不入 `content/`/`locale/`)

1. **#307 未決**:en content 今日無編輯位(`content/full-content.json` 由
   capture 工具重生成;#219 overlay 空殼且被 `tests/test_original_content.gd:25-28`
   釘空)。zh 編輯位(`locale/zh-Hant.json` `content.*`)今日存在,但兩語
   同批落地,一齊等。
2. **#305 未決**:`floorEchoes` 等 content key 名屬 schema registry
   (`application/locale.gd:35`),key 更名歸 #305;本批只改**值**。
3. **測試釘**(落地票要一齊改,非本批):`tests/test_locale.gd:266`(whisper 1
   verbatim)、`tests/test_locale.gd:268`(whisper 24 verbatim)。
4. **同步對**(落地時必須一齊動):
   - `quests.ownShade.fragments[1]` == `variants.ownShade2.deathDialogue`
   - `quests.ownShade.fragments[2]` == `variants.ownShade3.deathDialogue`
   -(`fragments[0]` == `variants.ownShade1.deathDialogue` 同構,本批不改字)
5. **一語三址**:whisper 24 的句子同時是 `ui.map.sealedDoor.inscription`
   (歸 #228/#303)與 `assets/audio/music/manifest.json items.sealedDoor.title`
   (credits 屏原文渲染;改名須同步 `docs/music-ledger.md`)。三址一句,
   本批定句:**「朝聖仍在繼續。」/ "The pilgrimage continues."**
6. **字庫覆蓋已驗**(2026-08-16):本批 22 句新 zh 全部字元已在
   `locale/*.json` corpus 之內——即落地不觸發字型 subset 重建。初稿
   「齊」不在字庫,已避字改句(「當彩窗六格燃起」);#232「喺」教訓
   同款。落地 PR 照例本地跑 `tools/check_locale_font_coverage.py`。

## 待 James 判(step 5 議程)

1. **「王冠之後 / beyond the crown」公式**——一次過簽,七址共用
   (ledger row 31;本批內三址:m2.paid、第五頁、whisper 21;另
   usurper.death 與 whisper 20 亦取此式)。
   **判(James 2026-08-16):簽——row 31 SETTLED,七址共用,06 鎖詞。**
2. **入城 / ARRIVED 的 spoiler ceiling**(ledger row 29):`ui.dawn.title`
   響於 Act III 勝利,非 Act IV 揭場——級數判定屬 story owner。
   **判(James 2026-08-16):維持 L1——雙讀屬設計,row 29 級已簽。**
3. **引路石 counter 的揭後讀法**(ledger row 30):現稿係 writer 構作
   [PROPOSED],真讀法由 James 寫定。
   **判(James 2026-08-16):構作照准——row 30 揭後已簽 SETTLED。**
4. **Usurper 前提重錨**:shipped 三句以「登頂揭偽王」為軸;橫向 canon 無
   頂可登。本批重錨為「攜燈至封門之前」——見 usurper 表。
   **判(James 2026-08-16):簽——重錨 SETTLED。**
5. **兩句 L1 天花貼線判定**:(a) m3.paid「你站立而死的前身」——表面
   虛構下讀成「你以前死嗰幾次」(反向雙讀),twist-safety 兩讀獨立覆核
   後仍留 James 終判(掌燈人渠道 ceiling 係 L1,升級無位,判「過」或
   「重寫」);(b) pages[2] 第三頁——敘述具體死場,但「有個朝聖者站着
   死去」係 row 9 SETTLED 明文保留的本體(真相一直寫在紙上係設計本身),
   頁渠道係書面記錄,register 本應敘事。確認 L1 或另判。
6. **逐代分配表**本身(00 §8.5:成表過 James normal review)。
   **判(James 2026-08-16):成表簽收 SETTLED。**
7. **whisper 4 的明晰度爭議——本批唯一 confirmed blocker**(兩個
   canon-lint lens + 一個 twist lens 獨立 flag;adversarial verify 兩次
   維持原判):「死者朝聖兩次:一次以肉身,一次以記憶。」被指以平鋪
   通則句直述分身兩半(肉身/記憶 正正對應 00 §3.2 兩媒),屬 explain
   而非 unsettle,且比 L1 錨更明——而 whisper 渠道 hard-cap L1,無
   升級位。反方:ledger row 2 的既有指令係「改『行』語彙,**語義保留**」,
   且表面讀法自足(悼亡套語);惟 verify 指出套語辯護偷換咗動詞
   (套語用「活」,句用「朝聖」——後者係遊戲機制動詞,加重機制映射)。
   **三選一,James 終判**:(a) 照舊(現稿);(b) 降寫候選:
   「死者朝聖,不止一次。」/ "The dead walk more than once."(保 eerie
   通則形,刪去兩媒對映);(c) James 自書。揀 (b)/(c) 則 zh shipped 句
   一併重開(row 2 狀態隨判更新)。
   **判(James 2026-08-16):(a) 照舊——blocker 撤銷,row 2 已記
   SETTLED。**
8. **影聲線兩個 warn 的回應**(記錄,非改動):(a) `ownShade.final` 用
   「我們」非第二人稱——**設計如此**:whisper 15「三次死亡會教你的影
   直言」明文預告 closer 的 register break,影在結案時代整條隊發聲;
   (b) m3.ask「路清點容器」的擬人——同 shipped「門會認得你」同族
   (物件作主語而其事為真),聲線容納。兩項如 James 另判,照改。
   **判(James 2026-08-16):接受照記錄。**
9. **玫瑰窗→彩窗 正名的外溢**:06 鎖詞係 彩窗,shipped zh 尚有其他
   玫瑰窗 位(roseWindow/roseTab 等 ui keys)——歸 #228/#303 一併正名,
   本批只改自己兩句(pages[4]、w23)。

---

## Quest 線 — line table

決定欄:**保留**(兩語照舊)/ **重寫**(兩語新)/ **zh保留·en重寫** 等。
級=揭示階梯(00 §5);表面/揭後全文見 ledger Batch 1 區(本表撮要)。

### paleOnes(蒼白眾 / The Pale Ones)— 全線保留

| id | speaker | 級 | 決定 | zh | en |
|---|---|---|---|---|---|
| quests.paleOnes.name | — | L0 | 保留 | 蒼白眾 | The Pale Ones |
| quests.paleOnes.huntName | — | L0 | 保留 | 狩獵蒼白眾 | Hunt the Pale Ones |
| quests.paleOnes.huntInscription | 碑刻 | L1 | 保留 | 擊敗三名蒼白之敵,追隨它們留下的寒冷光塵。 | Defeat three pale foes and follow the cold motes they leave behind. |
| quests.paleOnes.inscription | 碑刻 | L1 | 保留 | 狩獵蒼白眾。從忘卻色彩的琉璃中收集九粒光塵。 | Hunt the Pale Ones. Gather nine motes from glass that has forgotten colour. |
| quests.paleOnes.progress[0] | 系統 | L1 | 保留 | 沒有光塵回應透鏡。 | No mote answers the Lens. |
| quests.paleOnes.progress[1] | 系統 | L1 | 保留 | 第一粒蒼白光塵令提燈生寒。 | The first pale mote chills the lantern. |

揭後撮要:蒼白=耗剩之意志的顏色(01 火的物理);「忘卻色彩的琉璃」=
褪色的記憶;光塵=行者未完的意志——收集即隊伍把光遞到你手。

### ownShade(自身之影 / Your Own Shade)

| id | speaker | 級 | 決定 | zh | en |
|---|---|---|---|---|---|
| quests.ownShade.name | — | L0 | 保留 | 自身之影 | Your Own Shade |
| quests.ownShade.inscription | 碑刻 | L1 | 重寫 | 擊敗那個仍記得路的自己。三道影必須熄滅。 | Defeat the self that still remembers the road. Three shades must go out. |
| quests.ownShade.fragments[0] | 影 | L1 | 保留(row 3 錨) | 我記得那塊石。你轉身離去時,我仍未停止呼喚。 | I remember the stone. You walked away before I stopped calling. |
| quests.ownShade.fragments[1] | 影 | L1 | 重寫(rows 4/13;lint 後 v2 收回影聲線) | 你留下過一道形影。這條路,已學會留住我們。 | You have left a shape behind. The road has learned to keep us. |
| quests.ownShade.fragments[2] | 影 | L1 | 重寫(row 19;lint 後補第一身見證) | 我見過。永恆君王之後沒有破曉——只有一扇偽裝成破曉的門。 | I have seen it. Beyond the Sovereign there is no dawn — only a door pretending to be one. |
| quests.ownShade.final | 影 | **L2**(closer) | zh保留·en重寫(row 5) | 我們從來不是為了逃出去而朝聖;我們一直把光送往鎖孔。 | We were never walking to be free. We were carrying light to the lock. |

- 重寫理由:inscription 舊句「銘記墜落/remembers falling」撞「站死」canon
  (ledger row 18);「熄滅/go out」取火族語彙——影是憶迴聲,熄而不倒。
- fragments[1] 舊句下半洩 Own Shade reveal 且 Spire banned(row 13);v2 依
  lint 收回影聲線(第二人稱+現在完成式+碎句)。雙讀:表面=影控訴你留下
  過它、路把它留住;揭後=「你留下的形影」是爐邊那個,「我們」是路留住
  的碑——影把自己數在其中。降回 body ceiling L1。
- fragments[2] 舊句 Above/sky 垂直(row 19);v2 補「我見過」第一身見證
  (影的現在完成式register),令 row 19 揭後(影死前見過門)落到字面;
  「偽裝成破曉的門」:東方=破曉所在,門冒充的正是每個勝者以為的黎明。
- asserts:fragments[1]==variants.ownShade2.deathDialogue;
  fragments[2]==variants.ownShade3.deathDialogue。

### usurper(篡位者 / The Usurper)— 前提重錨:登頂 → 攜燈至門前

| id | speaker | 級 | 決定 | zh | en |
|---|---|---|---|---|---|
| quests.usurper.name | — | L0 | 保留 | 篡位者 | The Usurper |
| quests.usurper.inscription | 碑刻 | L1 | 重寫 | 攜無焰提燈行至封門之前,揭穿篡位者的面具。 | Carry the lantern with no flame to the sealed door, and unmask the Usurper. |
| quests.usurper.itemName | — | L0 | 保留 | 無焰提燈 | A Lantern with No Flame |
| quests.usurper.itemText | 商人 | L1 | 保留 | 冰冷琉璃。沒有燈芯。商人不肯說是誰留下它。 | Cold glass. No wick. The merchant will not say who left it. |
| quests.usurper.poor | 商人 | L1 | 保留 | 貨冷,價暖。帶着足以買下一次破曉的金幣再來。 | Cold goods, warm price. Come back carrying a dawn's worth of gold. |
| quests.usurper.bought | 系統 | L1 | 重寫 | 如今,王座知曉你攜着何物。 | Now the throne knows what you carry. |
| quests.usurper.death | 系統 | **L2**(closer) | 重寫 | 面具已碎。望向王冠之後。 | The mask is broken. Look beyond the crown. |

- 前提重錨 [SETTLED James 2026-08-16]:偽王坐於封門之前(00 §2.1;第四頁
  「在鎖上披起王者形貌」),quest 軸由「登頂揭面」改為「攜他的燈回到他
  面前」。
- 揭後:itemText——燈由蒼白眾攜返西方(00 §2.2),商人知工藝不知來歷
  (矩陣);bought——王座認得的是**他自己的燈**;death——王冠之後即封門
  (#217 勝後 sealed door overlay 正是玩家此刻所見)。

### eighthOmen(第八凶兆 / The Eighth Omen)

| id | speaker | 級 | 決定 | zh | en |
|---|---|---|---|---|---|
| quests.eighthOmen.name | — | L0 | 保留 | 第八凶兆 | The Eighth Omen |
| quests.eighthOmen.inscription | 碑刻 | L1 | 保留 | 在第八凶兆籠罩下抵達破曉。 | Reach dawn beneath the Eighth Omen. |
| quests.eighthOmen.resolved | 系統 | **L2**(closer) | 保留(專行 row 83;motif row 16 維持 L1) | 第八凶兆從來不是凶兆。它是一扇門投下的影。 | THE EIGHTH OMEN WAS NEVER AN OMEN. IT WAS THE SHADOW OF A DOOR. |
| quests.eighthOmen.floorEchoes[0] | 迴響 | L1 | 保留 | // 窗片凝視 // | // THE PANE WATCHES // |
| quests.eighthOmen.floorEchoes[1] | 迴響 | L1 | 保留 | // 八並非數字 // | // EIGHT IS NOT A NUMBER // |
| quests.eighthOmen.floorEchoes[2] | 迴響 | L1 | 重寫 | // 攜錯誤之光向東 // | // CARRY THE WRONG LIGHT EAST // |
| quests.eighthOmen.floorEchoes[3] | 迴響 | L1 | 保留 | // 王冠只是一副面具 // | // THE CROWN IS A MASK // |

- floorEchoes[2]:UPWARD→EAST(門在東端);「錯誤之光」揭後=門只認完整
  的一團火,任何殘光皆「錯」。(`floorEchoes` key 名更改歸 #305,本批只改值。)
- inscription「籠罩下/beneath」屬場景內字面上下,Tier B 保。

### unreadablePage(無法辨讀之頁 / The Unreadable Page)

| id | speaker | 級 | 決定 | zh | en |
|---|---|---|---|---|---|
| quests.unreadablePage.name | — | L0 | 保留 | 無法辨讀之頁 | The Unreadable Page |
| quests.unreadablePage.inscription | 碑刻 | L1 | 保留 | 攜無法辨讀之頁贏得五次破曉。 | Win five dawns carrying the Unreadable Page. |
| quests.unreadablePage.pages[0] | 頁 | L1 | 保留(row 20 SETTLED 不改) | 第一頁——六片窗片從同一團火中切下,於第一次守夜前散落各處。 | FIRST PAGE — Six panes were cut from one fire, then scattered before the first Vigil. |
| quests.unreadablePage.pages[1] | 頁 | L1 | 重寫(row 12) | 第二頁——蒼白身影把碎片攜往西方,使門後之物無從追隨。 | SECOND PAGE — Pale figures carried the shards west, so the thing beyond the door could not follow. |
| quests.unreadablePage.pages[2] | 頁 | L1 | 重寫(row 9 本體) | 第三頁——有朝聖者站着死去,在路本應終結之處,看見路仍向前。 | THIRD PAGE — A pilgrim died standing, and saw the road go on where it should have ended. |
| quests.unreadablePage.pages[3] | 頁 | L1 | 保留 | 第四頁——永恆君王取來一盞空燈,在鎖上披起王者形貌。 | FOURTH PAGE — The Sovereign took an empty lantern and wore a king's shape over the lock. |
| quests.unreadablePage.pages[4] | 頁 | **L2**(closer) | 重寫(row 17;玫瑰窗→彩窗 正名) | 第五頁——彩窗是一幅地圖,不是紀念碑。將它點亮,再望向王冠之後。 | FIFTH PAGE — The Rose Window is a map, not a memorial. Light it, then look beyond the crown. |

- 第二頁:搬運機制為真(西行歸爐,00 §3.7),動機半句照舊留 legend-drift
  (fair-play 第 7 條)——「門後之物」取代 banned「上方之物」,drift 記賬。
- 第三頁:碑因明文照舊(row 9);「路仍向前」=鏡中歸途(揭後),表面讀
  怪談自足;降回 body ceiling L1(舊句 L2)。

### hollowLamplighter(空燈掌燈人 / The Hollow Lamplighter)

| id | speaker | 級 | 決定 | zh | en |
|---|---|---|---|---|---|
| quests.hollowLamplighter.name | — | L0 | 保留 | 空燈掌燈人 | The Hollow Lamplighter |
| quests.hollowLamplighter.inscription | 碑刻 | L1 | 保留 | 沿未燃之路,向空燈掌燈人付出五重代價。 | Pay the Hollow Lamplighter five prices along the Unlit Way. |
| …meetings[0].ask | 掌燈人 | L1 | 保留 | 你的提燈太吵。把它接下來收集的三點餘燼交給我。 | Your lantern is noisy. Give me the next three embers it catches. |
| …meetings[0].accepted | 系統 | L1 | 保留 | 接下來三點餘燼,歸於空燈。 | The next three embers belong to the hollow lantern. |
| …meetings[0].paid | 掌燈人 | L1 | 保留(row 15 drift) | 六片窗片曾從一扇無牆可承的窗中被帶走。 | Six panes were carried away from a window no wall could hold. |
| …meetings[0].cannot | 掌燈人 | L1 | 保留 | 現在便許下餘燼。提燈會先於你付清。 | Promise the embers now. The lantern will pay before you do. |
| …meetings[1].ask | 掌燈人 | L1 | 保留 | 金幣記得每一隻手。讓一百六十枚忘記你的手。 | Gold remembers every hand. Let one hundred and sixty pieces forget yours. |
| …meetings[1].paid | 掌燈人 | L1 | 重寫(公式) | 蒼白眾凝望着指向王冠之後的路。 | The Pale Ones watch the paths that point beyond the crown. |
| …meetings[1].cannot | 掌燈人 | L1 | 保留 | 你的錢囊尚暖,卻還不夠暖。 | Your purse is warm, but not warm enough. |
| …meetings[2].ask | 掌燈人 | L1 | 重寫 | 路清點容器。把十二格容量交給我。 | The road counts the vessel. Give me twelve measures of yours. |
| …meetings[2].paid | 掌燈人 | L1 | 重寫 | 你站立而死的前身,已見過永恆君王之後的門。 | Your standing dead have seen the door beyond the Sovereign. |
| …meetings[2].cannot | 掌燈人 | L1 | 保留 | 我不會把你挖空至三十以下。換一副更大的容器再來。 | I will not hollow you below thirty. Return with a larger vessel. |
| …meetings[3].ask | 掌燈人 | L1 | 重寫(referent) | 守爐人贈過你一份恩賜。我要那份贈禮,不要你的感激。 | The Keeper gave you a boon. Give me the gift, not the gratitude. |
| …meetings[3].paid | 掌燈人 | L1 | 保留 | 空燈就是換取面見那副面具的信物。 | The empty lantern is the token that purchases an audience with the mask. |
| …meetings[3].cannot | 掌燈人 | L1 | 保留 | 你已花掉那份贈禮。帶一份仍屬於你的來。 | You have spent the gift already. Bring me one that is still yours. |
| …meetings[4].ask | 掌燈人 | L1 | 保留 | 最後代價:只留一記心跳在這提燈裏。其餘全歸黑暗。 | Last price: leave this lantern with one heartbeat. The rest belongs to the dark. |
| …meetings[4].paid | 掌燈人 | L1 | 保留(hearsay 錨) | 點亮窗片。門會認得你。 | Light the panes. The door will know you. |
| …meetings[4].cannot | 掌燈人 | L1 | 保留 | 一記心跳已足夠。如今只剩拒絕才算貧乏。 | One heartbeat is enough. Refusal is the only poverty left. |

- m3(舊 m2).ask:「尖塔清點容器」→「路清點容器」——聲線照舊只談看得見
  的東西;揭後:路對「容器」的清點=沿路碑列,他說得比自己知的更真。
- m3.paid:「前身」反向雙讀——表面虛構(死而復返)下讀成「你以前死嗰
  幾次」;真相下「前身」是另一些人。en 用 "your standing dead" 同構。
- m4.ask:en 舊句 "The first keeper" referent 已定=守爐人(row 7);zh 舊句
  誤譯「最初的掌燈人」,一併修正。揭後:守爐人只得一個,「贈過你」的
  正是它一直用死者行裝資助下一個死者(00 §2.4)。
- m5.paid:掌燈人的傳聞版門條件(00 §4 hearsay),誠實的錯誤見證人,保留。
- Batch 2 將把五次會面擴寫成 8–12 句 script(含明文「上次」句);本批
  只清洗 shipped 句,聲線與代價次序不動。

---

## Whispers — 24 句重寫 + 逐代分配表(00 §8.5)

規則:隊伍次序=whisper 次序=解鎖次序(第 N 勝聞第 N 句)。行者知識
上限依 00 §4(不知分身、不知碑=行者、不知 Keeper 身份、門條件只有表面
版本;臨終所感可入句,**只可 unsettle,不可 explain**)。全部 ≤L1。
mini-bio 為 writer-facing(解釋此句何以出自此人),非玩家文案。

| # | mini-bio(此代行者) | 級 | 決定 | zh | en |
|---|---|---|---|---|---|
| 1 | 最早續火而出的行者;路上一切覆着同一種灰白,他至死找不到能形容它的詞。 | L1 | 重寫 | 有一種顏色,長路拒絕為它命名。 | There is a colour the road refuses to name. |
| 2 | 死在一塊忘卻色彩的琉璃旁;彌留之際見暗面有手,以為是自己的倒影伸錯了方向。 | L1 | 保留(row 8) | 一隻蒼白的手觸過琉璃的暗面。 | A pale hand has touched the dark side of the glass. |
| 3 | 出發前在爐邊數過那六個空框;死時仍在數。 | L1 | 保留 | 六處空位在等候,那裏不曾立過窗。 | Six spaces wait where no window stands. |
| 4 | 第一個在別人的碑腳下死去的行者;臨終隱約覺得有些甚麼,說不出,便說成了詩。 | L1 | zh保留·en重寫(row 2) | 死者朝聖兩次:一次以肉身,一次以記憶。 | The dead walk twice: once in flesh, once in memory. |
| 5 | 在商人攤前見過那盞無焰之燈而沒有買;此後每逢黑夜都在後悔。 | L1 | 保留 | 無焰的提燈仍是一把鑰匙。 | A lantern without flame is still a key. |
| 6 | 死於破曉之前,面向西方;最後數的是彩窗還未亮起的格。 | L1 | 保留 | 數一數接不住破曉的窗片。 | Count the panes that do not catch the dawn. |
| 7 | 第一個攜頁上路的行者;頁在他手中始終是亂紋,死前只囑咐一句:把它傳下去。 | L1 | 重寫 | 這一頁,唯有捱過破曉,方能讀懂。 | A page can be read only after it survives the dawn. |
| 8 | 在第八凶兆下走完全程;七種凶兆他都在冊上數過,第八種不在冊上。 | L1 | 保留 | 第八凶兆不寫在七者之中。 | The eighth sign is not written among the seven. |
| 9 | 在掌燈人的燈下揀錯了岔路;至死記得老人望他的眼神,像在認一個舊人。 | L1 | 保留(row 11 錨:gaunt keeper=掌燈人) | 枯瘦的掌燈人記得你未走的路。 | The gaunt keeper remembers the road you did not take. |
| 10 | 追隨霜一樣的光塵直到一道隱縫之前;縫沒有為他開。 | L1 | 保留 | 蒼白微粒如霜,聚在隱縫周圍。 | Pale motes gather like frost around a hidden seam. |
| 11 | 倚着一座不肯倒下的碑死去;最後一句,他以為自己說的是碑。 | L1 | 保留(row 1 核心) | 你的紀念碑並不總是躺下。 | Your monument does not always lie down. |
| 12 | 與商人講過三次價;櫃下那件冷貨,他到死都未看清。 | L1 | 保留 | 商人櫃下藏着一件冰冷之物。 | The merchant keeps one cold thing beneath the counter. |
| 13 | 第一個讀出頁上完整字形的人;他明白殘缺是影,原句在別處。 | L1 | 保留 | 破碎字形是完整句子的影子。 | Broken glyphs are the shadow of a complete sentence. |
| 14 | 付滿五重代價的第一人;死前把五次會面連起來,聽出一場懺悔——誰的,他沒說。 | L1 | 保留(row 6 錨:五價) | 五頁成章;五重代價成懺言。 | Five pages make a chapter; five prices make a confession. |
| 15 | 三次擊落自己的影;第三次之後影說的話,他沒能轉述完。 | L1 | 保留 | 三次死亡會教你的影直言。 | Three deaths will teach your shade to speak plainly. |
| 16 | 回頭望爐火望得最久的一個;至死想不通,無牆之窗如何立得住。 | L1 | 保留 | 守夜有一扇窗,雖無牆承載它。 | The Vigil has a window, though no wall holds it. |
| 17 | 勝仗的行者;把燼璃交入蒼白的手,最後看見的是那些胸口的一點光。 | L1 | 重寫(zh 正名燼璃;en 分清 shard/窗) | 每一片燼璃,點亮彩窗的一格。 | Each shard lights one pane of the Rose Window. |
| 18 | 被蒼白眾「追」了一整段路;臨終才看懂,那從來不是追獵。 | L1 | 重寫 | 蒼白眾並非在獵你。他們在指向東方。 | The Pale Ones are not hunting you. They are pointing east. |
| 19 | 走進王庭、直面偽王的行者;他看見王冠底下彷彿沒有臉——只有貼着鎖的面具。 | L1 | 重寫(斷定強度對齊 shipped「只是」,不加碼) | 永恆君王,只是門前披上的一副面具。 | The Sovereign is a mask worn before the last door. |
| 20 | 攜頁至第五頁的行者;讀畢便明白窗亮之後還有一步,而他走不到了。 | L1 | 重寫(公式) | 當彩窗六格燃起,望向王冠之後。 | When six panes burn, look beyond the crown. |
| 21 | 望見過封門輪廓的行者;死前反覆說門在王冠之後,怕後來的人找錯方向。 | L1 | 重寫(公式) | 王冠之後,有一扇封印之門。 | There is a sealed door beyond the crown. |
| 22 | 在門前讀過銘文的行者;那些字比守夜更老,他不明白為何無人談起。 | L1 | 保留 | 它的銘文等候得比守夜更久。 | Its inscription has waited longer than the Vigil. |
| 23 | 隊伍裏最清醒的一個;遺言不是詩,是指令——他怕詩會被誤讀。 | L1 | zh正名(玫瑰窗→彩窗)·en保留 | 帶六片碎片到彩窗。 | Bring six shards to the Rose Window. |
| 24 | 隊伍最近的一員,上一次續火走出去的那個;遺言只有一句,像交更。 | L1 | zh保留·en重寫 | 朝聖仍在繼續。 | The pilgrimage continues. |

分配表約束自查(00 §8.5):
- **隊伍次序**:1–6 早代(路況/爐邊印象);7–15 中代(quest 經歷累積:
  頁→凶兆→掌燈人→光塵→碑→商人→字形→五價→影);16–24 晚代(窗、
  燼璃、王庭、封門,愈行愈遠)。晚代知得多的機制根據:**quest 進度跨
  run 持續**(Vigil 帳簿),晚代行者的 run 展開了更多 quest 內容、行得
  更遠——不是記憶傳承(00 §3.2:走的帶走意志,留的留住記憶;行者之間
  無記憶累積)。每 bio 只倚賴該行者自己一程的見聞。
- **矩陣上限**:無一句/一 bio 聲稱分身、碑=行者、Keeper 身份、門真條件。
  臨終所感(9 的眼神、11 的碑、18 的指路)全部止於 unsettle。
- **錨點**:whisper 9=gaunt keeper=掌燈人 ✓;whisper 14=五價 ✓。
- **揭後總讀**:第 N 勝聞第 N 句=你沿隊伍往後聽;24 句合讀是一場接力
  交更——最後一句由最近死去的那個講出,而佢就係你上次「繼續」時
  行出去嗰個。
