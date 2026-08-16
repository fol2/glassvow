# 05 — Foreshadow Ledger(伏筆賬簿)

> 反轉故事在 100K 字規模下不穿崩,靠的就是這本賬。**每一句文案(已 shipped
> 或新寫)都要入賬**:表面讀法 / 揭後讀法 / 揭示階梯等級(見 00 §5)/
> 洩露風險。規則:
>
> 1. 一句只有表面讀法而揭後讀不通 → 改到讀通為止。
> 2. 一句在其等級之前就洩露 → 降寫或改期。
> 3. climb/垂直語彙 → 標 `[REWRITE:climb]`,逐句清洗。
> 4. 出處編號 convention:whisper N = `content/full-content.json`
>    `.whispers` 第 N 句(**1-indexed**)[#258 定案]。

| # | 句子(shipped 原文) | 出處 | 級 | 表面讀法 | 揭後讀法 | 狀態 |
|---|---|---|---|---|---|---|
| 1 | Your monument does not always lie down. | whisper 11(編號按 convention 更正 #258) | L1 | 詩意的悼詞 | 碑是站着死去的行者本人;他們沒躺下,因為仍在排隊等門開 | 保留,核心伏筆 |
| 2 | 死者朝聖兩次:一次以肉身,一次以記憶。 / The dead walk twice: once in flesh, once in memory. | whisper 4 | L1 | 詩句 | 機制說明書:行者以肉身走一次(真死),留者以記憶再走一次 | 已重寫(Batch 1 #301,en;zh 原句無 climb)[SETTLED James 2026-08-16:照舊——明晰度 blocker 判過,語義保留維持] |
| 3 | I remember the stone. You walked away before I stopped calling. | Own Shade 碎句 | L1 | 影在追憶 | 控訴對象反轉:死者臨終叫住的 you 就是玩家——行開了沒回頭的是留者 | 保留,全 cast 最重一句 |
| 4 | 你留下過一道形影。這條路,已學會留住我們。 / You have left a shape behind. The road has learned to keep us. | ownShade fragments[1]=ownShade2 死亡句(與 row 13 合併重寫為一句) | L1 | 影控訴你留下過它、路把它留住 | 雙讀:「你留下的形影」=爐邊那個;「我們」=路留住的碑,影自數其中 | 已重寫 v2(Batch 1 #301,lint 後收回影聲線:第二人稱+現在完成式)待審;降回 body ceiling L1 |
| 5 | 我們從來不是為了逃出去而朝聖;我們一直把光送往鎖孔。 / We were never walking to be free. We were carrying light to the lock. | Own Shade 收束(closer) | L2 | 朝聖目的自白 | 字面為真:行者是送火的隊伍;lock 就是門 | 已重寫(Batch 1 #301,en;zh 保留)待審 |
| 6 | Five pages make a chapter; five prices make a confession. | whisper 14(出處更正 #258 R2 N7;非 Lamplighter 對白) | L1 | 怪話 | 某代行者的遺言,說的是掌燈人的五價=認人啟事 | 保留;影響 §8.5 逐句分配 |
| 7 | 守爐人贈過你一份恩賜。我要那份贈禮,不要你的感激。 / The Keeper gave you a boon. Give me the gift, not the gratitude. | hollowLamplighter meetings[3].ask | L1 | 掌燈人索要爐邊的贈禮 | 守爐人=留低嗰個;boon 是歷代行者遺物——它一直用死者行裝資助下一個死者 | 已重寫(Batch 1 #301:稱謂落 守爐人;zh 舊句「最初的掌燈人」屬誤譯一併修正)待審 |
| 8 | A pale hand has touched the dark side of the glass. | whisper 2(出處更正 #258;原誤記 thinGlass omen) | L1 | 不祥之兆 | 玻璃另一面一直有人——鏡中那側是留者/隊伍 | 保留 |
| 9 | 第三頁——一名朝聖者站着死去。他止步之處,路未止。 / THIRD PAGE — A pilgrim died standing. Where he stopped, the road did not. | Unreadable Page 頁 3 | L1 | 怪談 | 碑的成因明文照舊;「路未止」=鏡中歸途 | 已重寫(Batch 1 #301:climb 清洗,站死句保留,冷筆記錄體)[SETTLED James 2026-08-16];降回 body ceiling L1 |
| 10 | (mirror.png:鏡中淺笑黑影) | 事件美術 | L0 | 詭異鏡像 | 鏡中人是留者=你;淺笑因為它認得你 | 資產不改,文案圍繞它寫 |
| 11 | The gaunt keeper remembers the road you did not take. | whisper 9 | L1 | 守關人記得你的岔路 | gaunt keeper=Lamplighter(referent 定案,避撞 Keeper 頭銜);你沒行的路=留者從未走過的路 | 保留 [#258 R2 N4] |
| 12 | 第二頁——蒼白身影把碎片攜往西方,使門後之物無從追隨。 / SECOND PAGE — Pale figures carried the shards west, so the thing beyond the door could not follow. | Second Page | L1 | 懼門後之物而藏碎片 | 搬運機制為真(00 §3.7 西行歸爐);動機半句=行者年代 legend-drift(門後只有金城) | 已重寫(Batch 1 #301)待審;降回 body ceiling L1 [#258 R1 Q4A + R2 Q14] |
| 13 | (舊句後半,與 row 4 合併重寫——新句見 row 4) | ownShade2 死亡句後半 | — | — | — | 已重寫(Batch 1 #301)併入 row 4 [#258 R2 N7] |
| 19 | 我見過。永恆君王之後沒有破曉——只有一扇偽裝成破曉的門。 / I have seen it. Beyond the Sovereign there is no dawn — only a door pretending to be one. | ownShade fragments[2]=ownShade3(The Shade That Remembers)死亡句 | L1 | 影的絕望見證 | 字面為真:「我見過」——影死前真的見過門;門冒充的正是每個勝者以為的黎明 | 已重寫 v2(Batch 1 #301,lint 後補第一身見證)待審;降回 body ceiling L1 [#258 verify 補漏] |
| 14 | half a breath behind — and it is smiling | Silvered Mirror 事件 | L1 | 鏡中怪異 | 鏡中那側=留者;它認得你(L0 motif 的文字版,定級 L1) | 保留 [#258 R2 N7] |
| 15 | carried away from a window no wall could hold | Lamplighter 會面 1 | L1 | 傳說 | legend-drift:六格從未安裝成窗;他的傳聞版本(00 §4 hearsay) | 保留,記 drift [#258 R2 N7] |
| 16 | 第八凶兆(The Eighth Omen)之「第八」 | quest 標題/文本 | L1 | 凶兆編號 | 門影投落為真;「第八」=第八座碑/隊伍第八人(棄「第八次分身」數法) | 保留 [#258 R2 N5] |
| 17 | 第五頁——彩窗是一幅地圖,不是紀念碑。將它點亮,再望向王冠之後。 / FIFTH PAGE — The Rose Window is a map, not a memorial. Light it, then look beyond the crown. | Fifth Page(closer) | L2 | 頁文自辯 | 「不是紀念碑」照舊反讀;「map」=窗中隊伍本身就是路線圖;句尾取「王冠之後」公式(row 31) | 已重寫句尾(Batch 1 #301)待審 [#258 R2 N6] |
| 18 | "The Shade That Returned" / …fell… 語彙 | 事件/quest 文本 | L1 | 亡影歸來/倒下 | 無人回來——returned 是留者錯認;fell 與站死 canon 衝突,ironic 重讀:倒下的是意志,不是身體 | 逐句記 ironic 重讀;衝突句排期改寫 [#258 R2 N7];quest 側(ownShade.inscription「銘記墜落」)已於 Batch 1 重寫,event 側留後批 |
| 20 | 「同一團火裁成的六片」(裁-語彙) | rose window quest 舖底文案(00 §2.2 引述) | L1 | 窗的來歷:火被有意裁開成六格 | legend-drift:真相是火撞門**碎**成(00 §2.2)——傳說把意外修飾成設計,揭後讀更凍;「裁」照用,不改 shipped 句 | 保留,記 drift [SETTLED — #259 Q7] |

## 新寫文案入賬區

(開稿後逐批 append;canon-lint workflow 會校驗每批新行都已入賬。)

#261 定名批(名字是 player-facing 字串,先入賬;shipped 落地見各欄出處):

| # | 句子(名) | 出處 | 級 | 表面讀法 | 揭後讀法 | 狀態 |
|---|---|---|---|---|---|---|
| 21 | 黑曜王庭 / The Obsidian Court | acts[2].name(置換歸 #232) | L0 | 有個王的黑曜宮庭 | 廷臣=千年停下的眾人;王=不肯完成的你 | 新名 [#261 Q8] |
| 22 | 鏡中歸途 / The Mirrored Road | acts[3].name(#220) | L4 | 鏡中的歸路 | 盡頭=爐邊;「歸」是全遊戲第一次字面為真 | 新名 [#261 Q9] |
| 23 | 永恆留者 / The Eternal Keeper | acts[3].bossName(#220) | L4 | 終戰 boss 名 | 與永恆君王孖生——不肯開始/不肯完成的兩極並排 | 新名 [#261 Q10] |
| 24 | 守爐人 / the Keeper | 爐邊 NPC 顯示名(落地隨 copy batch) | L0 | 看火者 | 它「守」爐,因為它從未離開過爐邊 | 新名 [#261 Q11] |
| 25 | 金城 / the Gilded City | 傳說指涉(落地隨 copy batch) | L1 | 門後的黃金應許 | 爐邊真貌;應許=歸家;名是眾人叫錯的(legend-drift) | 新名 [#261 Q12] |
| 26 | 續火 / Rekindle | ui.menu.beginClimb 置換(**#232 Q2 改判**:分身在新 run 出發一刻;resume 掣改取 row 27) | L0 | 重燃爐火,再上路 | 火再撕你一次;續的是儀式,不是你——派新行者出發正是分身本身 | 新名 [#261 Q13;掣位 #232 Q2] |

Batch 1(#301)新名與公式行:

| # | 句子(名/式) | 出處 | 級 | 表面讀法 | 揭後讀法 | 狀態 |
|---|---|---|---|---|---|---|
| 27 | 返回路上 / Back to the Road | ui.menu.continueClimb(置換 #232) | L0 | 續行中斷的旅程 | 你「返回」的路,盡頭是爐邊(接 row 22 鏡中歸途) | 新名 [#232 Q2] |
| 28 | 留在路上 / Stay on the Road | ui.menu.keepClimbing(置換 #232) | L0 | 不離開,繼續行 | 「留」字反照:留在路上的是行者,留在爐邊的是你 | 新名 [#232 Q2 修訂書面語——舊簽「留喺路上」廢:喺不在字庫且屬口語] |
| 29 | 入城 / ARRIVED | ui.dawn.title + ui.end.ascended(置換 #232 Q4) | L1 [SETTLED James 2026-08-16] | 你抵達了 | 抵達的是隊伍(ascended.png 隊列入門);城=爐邊,入城=歸家 | 新名 [#232 Q4];級已簽 L1(響於 Act III 勝利的雙讀屬設計) |
| 30 | 第 {n} 塊引路石 / WAYSTONE n | ui.end.floors / ui.hud.* 計數(置換 #232 Q3;落地歸 #303) | L0 | 行程以引路石計 | [SETTLED James 2026-08-16]每塊石都被之前每一個行者點亮過;你數的是隊伍反覆量過的同一段路 | 新名 [#232 Q3];揭後已簽 |
| 31 | 王冠之後 / beyond the crown | 公式,七址:ui.dawn.act4RevealCopy、ui.dawn.unlock.act4、q.hollowLamplighter.meetings[1].paid、q.unreadablePage.pages[4]、whisper 21、main.gd:372、dawn_phone_containment.gd:140;本批另 usurper.death 與 whisper 20 取此式 | L1 | 封門在王庭之外、王座之後 | 「之後」雙關:過了「不肯完成」,路便向家;門從來不在上方,只在更遠處 | 新公式 [SETTLED James 2026-08-16 — 一次簽,七址共用] |

## Batch 1(#301)入賬區 [PROPOSED — 待 James review]

六 quest 線 + 24 whispers 全句入賬(quest/whisper 名、mode、itemName、
huntName 等無敘事雙讀的字串不立行)。zh 為源語;「保留」=兩語照舊。
出處縮寫:q.=content.quests.;w N=content.whispers 第 N 句(1-indexed)。
行文全表連逐代 mini-bio 分配表見
`docs/story/batches/2026-08-16-batch1-quests-whispers.md`。
已重寫句中,rows 2/4/5/7/9/12/17/19 於主表就地更新,不重列。

| # | 句子 | 出處 | 級 | 表面讀法 | 揭後讀法 | 狀態 |
|---|---|---|---|---|---|---|
| 32 | 擊敗三名蒼白之敵,追隨它們留下的寒冷光塵。 / Defeat three pale foes and follow the cold motes they leave behind. | q.paleOnes.huntInscription | L1 | 狩獵指引 | 光塵=行者未完的意志;「追隨」=隊伍給你引路 | 保留 |
| 33 | 狩獵蒼白眾。從忘卻色彩的琉璃中收集九粒光塵。 / Hunt the Pale Ones. Gather nine motes from glass that has forgotten colour. | q.paleOnes.inscription | L1 | 收集目標 | 玻璃=記憶;忘卻色彩=褪色的記憶;蒼白=耗剩意志的顏色 | 保留 |
| 34 | 沒有光塵回應透鏡。 / No mote answers the Lens. | q.paleOnes.progress[0] | L1 | 進度提示 | 死者之光不應器物,只應人 | 保留 |
| 35 | 第一粒蒼白光塵令提燈生寒。 / The first pale mote chills the lantern. | q.paleOnes.progress[1] | L1 | 進度提示 | 你收集的是死者殘留——遺物冰冷 | 保留 |
| 36 | 擊敗那個仍記得路的自己。三道影必須熄滅。 / Defeat the self that still remembers the road. Three shades must go out. | q.ownShade.inscription | L1 | 你的分身在路上纏擾你 | 影=你之中仍記得怎樣行的那部分(00 §7);熄=憶迴聲之滅,不觸碑 | 重寫(舊「銘記墜落」撞站死 canon,row 18) |
| 37 | 攜無焰提燈行至封門之前,揭穿篡位者的面具。 / Carry the lantern with no flame to the sealed door, and unmask the Usurper. | q.usurper.inscription | L1 | quest 目標 | 你在把第一行者自己的燈帶回他面前 | 重寫(前提重錨:登頂→門前;summit 清洗) |
| 38 | 冰冷琉璃。沒有燈芯。商人不肯說是誰留下它。 / Cold glass. No wick. The merchant will not say who left it. | q.usurper.itemText | L1 | 來歷不明的貨 | 燈由蒼白眾攜返西方(00 §2.2);商人知工藝不知機制(矩陣) | 保留 |
| 39 | 貨冷,價暖。帶着足以買下一次破曉的金幣再來。 / Cold goods, warm price. Come back carrying a dawn's worth of gold. | q.usurper.poor | L1 | 商人開價 | 「一次破曉的價」——破曉在這世界確有價目 | 保留 |
| 40 | 如今,王座知曉你攜着何物。 / Now the throne knows what you carry. | q.usurper.bought | L1 | 偽王察覺你來 | 王座認得的是他自己的燈——他親手熄掉的那盞 | 重寫(summit 清洗) |
| 41 | 面具已碎。望向王冠之後。 / The mask is broken. Look beyond the crown. | q.usurper.death(closer) | L2 | 勝利指引 | 過了「不肯完成」,門就在那裏(#217 的 sealed door overlay 正是此刻畫面);取 row 31 公式 | 重寫(舊「往上看」) |
| 42 | 在第八凶兆籠罩下抵達破曉。 / Reach dawn beneath the Eighth Omen. | q.eighthOmen.inscription | L1 | quest 目標 | 你在一扇門的影下走完全程 | 保留(「籠罩下」場景內字面,Tier B) |
| 43 | // 窗片凝視 // / // THE PANE WATCHES // | q.eighthOmen.floorEchoes[0] | L1 | 詭異迴響 | 窗的另一面一直有人看着 | 保留 |
| 44 | // 八並非數字 // / // EIGHT IS NOT A NUMBER // | q.eighthOmen.floorEchoes[1] | L1 | 詭異迴響 | 「八」是隊伍第八人/第八座碑(row 16) | 保留 |
| 45 | // 攜錯誤之光向東 // / // CARRY THE WRONG LIGHT EAST // | q.eighthOmen.floorEchoes[2] | L1 | 詭異迴響 | 門只認完整的一團火——任何殘光皆「錯」 | 重寫(UPWARD→EAST) |
| 46 | // 王冠只是一副面具 // / // THE CROWN IS A MASK // | q.eighthOmen.floorEchoes[3] | L1 | 詭異迴響 | 王位本身就是覆在鎖上的面具(第四頁同讀) | 保留 |
| 47 | 攜無法辨讀之頁贏得五次破曉。 / Win five dawns carrying the Unreadable Page. | q.unreadablePage.inscription | L1 | quest 目標 | 頁要「捱過」五次別人的死才讀得全 | 保留 |
| 48 | 第四頁——永恆君王取來一盞空燈,在鎖上披起王者形貌。 / FOURTH PAGE — The Sovereign took an empty lantern and wore a king's shape over the lock. | q.unreadablePage.pages[3] | L1 | 偽王起源傳說 | 逐字為真:00 §2.1 的歷史本身 | 保留 |
| 49 | 沿未燃之路,向空燈掌燈人付出五重代價。 / Pay the Hollow Lamplighter five prices along the Unlit Way. | q.hollowLamplighter.inscription | L1 | quest 目標 | 五價=認人啟事(00 §7);未燃之路=他一直走在無火的那側 | 保留 |
| 50 | 你的提燈太吵。把它接下來收集的三點餘燼交給我。 / Your lantern is noisy. Give me the next three embers it catches. | q.hollowLamplighter.meetings[0].ask | L1 | 怪老人索價 | 「吵」=你的燈滿載未完意志;他聽得出 | 保留 |
| 51 | 接下來三點餘燼,歸於空燈。 / The next three embers belong to the hollow lantern. | q.hollowLamplighter.meetings[0].accepted | L1 | 交易確認 | 空燈收火——他在替誰收集? | 保留 |
| 52 | 現在便許下餘燼。提燈會先於你付清。 / Promise the embers now. The lantern will pay before you do. | q.hollowLamplighter.meetings[0].cannot | L1 | 賒賬條款 | 「先於你付清」——燈比人長命,行者總是先走 | 保留 |
| 53 | 金幣記得每一隻手。讓一百六十枚忘記你的手。 / Gold remembers every hand. Let one hundred and sixty pieces forget yours. | q.hollowLamplighter.meetings[1].ask | L1 | 怪老人索價 | 記得/忘記=全線母題;他要你練習被忘記 | 保留 |
| 54 | 蒼白眾凝望着指向王冠之後的路。 / The Pale Ones watch the paths that point beyond the crown. | q.hollowLamplighter.meetings[1].paid | L1 | 情報 | 他們看守的正是引你過王庭往門的路(指路者,00 §4);取 row 31 公式 | 重寫(公式) |
| 55 | 你的錢囊尚暖,卻還不夠暖。 / Your purse is warm, but not warm enough. | q.hollowLamplighter.meetings[1].cannot | L1 | 錢不夠 | 暖=將將離手的體溫;他數的從來不是錢 | 保留 |
| 56 | 路清點容器。把十二格容量交給我。 / The road counts the vessel. Give me twelve measures of yours. | q.hollowLamplighter.meetings[2].ask | L1 | 怪老人索價(HP) | 路對容器的清點=沿路碑列;他說得比自己知的更真 | 重寫(舊「尖塔清點容器」) |
| 57 | 你的前身站立而死,面向東方。 / Your forebears died standing, facing east. | q.hollowLamplighter.meetings[2].paid | L1 [SETTLED James 2026-08-16:保站轉向] | 表面虛構下=「你以前死嗰幾次」(死而復返的錯覺自足) | 反向雙讀:「前身」是另一些人;站立而死者成碑,面向東方即面向門 | 重寫(舊「君王之上的階梯」;James 判刪「見過門」半句) |
| 58 | 我不會把你挖空至三十以下。換一副更大的容器再來。 / I will not hollow you below thirty. Return with a larger vessel. | q.hollowLamplighter.meetings[2].cannot | L1 | 拒收條款 | 「挖空」——空燈掌燈人自己就是被挖空的容器 | 保留 |
| 59 | 空燈就是換取面見那副面具的信物。 / The empty lantern is the token that purchases an audience with the mask. | q.hollowLamplighter.meetings[3].paid | L1 | 情報 | 偽王只接見帶着他的燈的人——他在等它回來 | 保留 |
| 60 | 你已花掉那份贈禮。帶一份仍屬於你的來。 / You have spent the gift already. Bring me one that is still yours. | q.hollowLamplighter.meetings[3].cannot | L1 | 拒收條款 | 「仍屬於你的」在這條路上越來越少 | 保留 |
| 61 | 最後代價:只留一記心跳在這提燈裏。其餘全歸黑暗。 / Last price: leave this lantern with one heartbeat. The rest belongs to the dark. | q.hollowLamplighter.meetings[4].ask | L1 | 最後索價(HP→1) | 認人的最後一步:看你剩一記心跳時是不是同一個 | 保留 |
| 62 | 點亮窗片。門會認得你。 / Light the panes. The door will know you. | q.hollowLamplighter.meetings[4].paid | L1 | 報酬:門的條件 | 傳聞版門條件(00 §4 hearsay)——誠實的錯誤見證;門認的其實是「行過的人+完整的火」 | 保留(hearsay 錨) |
| 63 | 一記心跳已足夠。如今只剩拒絕才算貧乏。 / One heartbeat is enough. Refusal is the only poverty left. | q.hollowLamplighter.meetings[4].cannot | L1 | 拒收條款 | 拒絕=全書三種拒絕的母題字 | 保留 |
| 64 | 有一種顏色,長路拒絕為它命名。 / There is a colour the road refuses to name. | w 1 | L1 | 詭異詩句 | 無名之色=蒼白——耗剩意志的顏色,路上無人肯叫破 | 重寫(舊句名 Spire) |
| 65 | 六處空位在等候,那裏不曾立過窗。 / Six spaces wait where no window stands. | w 3 | L1 | 詭異詩句 | 彩窗六格在等燼璃;「不曾立過窗」接 row 15 drift | 保留 |
| 66 | 無焰的提燈仍是一把鑰匙。 / A lantern without flame is still a key. | w 5 | L1 | 謎語 | usurper 線指引;空燈=面見面具的信物 | 保留 |
| 67 | 數一數接不住破曉的窗片。 / Count the panes that do not catch the dawn. | w 6 | L1 | 謎語 | 未亮的格=未歸的火;數窗=數還欠隊伍幾多步 | 保留 |
| 68 | 這一頁,唯有捱過破曉,方能讀懂。 / A page can be read only after it survives the dawn. | w 7 | L1 | 謎語(五勝解頁) | 「捱過破曉」的是頁,不是攜頁的人——勝仗行者同樣死(00 §3.7) | 重寫(舊「捱過頂點」) |
| 69 | 第八凶兆不寫在七者之中。 / The eighth sign is not written among the seven. | w 8 | L1 | 謎語 | 第八=冊外之物=門影(row 16) | 保留 |
| 70 | 蒼白微粒如霜,聚在隱縫周圍。 / Pale motes gather like frost around a hidden seam. | w 10 | L1 | 詭異觀察 | 隱縫=世界的接口;霜=殘留意志遇冷凝聚 | 保留 |
| 71 | 商人櫃下藏着一件冰冷之物。 / The merchant keeps one cold thing beneath the counter. | w 12 | L1 | 情報 | 冷貨=無焰提燈;商人收拾行者遺物(02-cast) | 保留 |
| 72 | 破碎字形是完整句子的影子。 / Broken glyphs are the shadow of a complete sentence. | w 13 | L1 | 謎語 | 頁的殘缺是投影——原句在門上(w 22 呼應) | 保留 |
| 73 | 三次死亡會教你的影直言。 / Three deaths will teach your shade to speak plainly. | w 15 | L1 | 謎語(quest 機制) | 「你的影」學會直言時,說的是控訴(row 3) | 保留 |
| 74 | 守夜有一扇窗,雖無牆承載它。 / The Vigil has a window, though no wall holds it. | w 16 | L1 | 詭異觀察 | 窗不屬任何牆——它是 threshold 的西面(01 地理) | 保留 |
| 75 | 每一片燼璃,點亮彩窗的一格。 / Each shard lights one pane of the Rose Window. | w 17 | L1 | 機制提示 | 每片歸位=火逐片透回;窗在重組碎裂那一夜 | 重寫(zh 正名 燼璃/彩窗,舊譯「餘燼琉璃」違 06;en 分清 shard/窗兩 locked terms) |
| 76 | 蒼白眾並非在獵你。他們在指向東方。 / The Pale Ones are not hunting you. They are pointing east. | w 18 | L1 | 反直覺情報 | 字面為真:指路者(00 §4);東=門的方向 | 重寫(舊「向上指」) |
| 77 | 永恆君王,只是門前披上的一副面具。 / The Sovereign is a mask worn before the last door. | w 19 | L1 | 情報 | 面具下無臉——王位本身是覆鎖之物(第四頁同讀,L1 先例) | 重寫(舊「最終階梯之下」;斷定強度維持 shipped「只是」級,不加碼) |
| 78 | 當彩窗六格燃起,望向王冠之後。 / When six panes burn, look beyond the crown. | w 20 | L1 | 指引 | 六格燃起=開封之刻;取 row 31 公式(「齊」不在字庫,避字改句——同「喺」教訓) | 重寫(舊「頂點之外」) |
| 79 | 王冠之後,有一扇封印之門。 / There is a sealed door beyond the crown. | w 21 | L1 | 情報 | row 31 公式本體址 | 重寫(舊「王冠之上」) |
| 80 | 它的銘文等候得比守夜更久。 / Its inscription has waited longer than the Vigil. | w 22 | L1 | 詭異觀察 | 門上的字先於爐火——碎裂之夜前門已在等 | 保留 |
| 81 | 帶六片碎片到彩窗。 / Bring six shards to the Rose Window. | w 23 | L1 | 明文指令 | 最清醒的遺言:怕詩被誤讀,只留指令 | zh 正名(玫瑰窗→彩窗,06 鎖詞);en 保留 |
| 82 | 朝聖仍在繼續。 / The pilgrimage continues. | w 24 + ui.map.sealedDoor.inscription + 音軌名(一語三址,見 batch 檔) | L1 | 未完的旅程 | 隊伍仍在長;路過門後仍在繼續——Act IV 字面兌現 | zh 保留;en 重寫(舊 The climb continues.) |
| 83 | 第八凶兆從來不是凶兆。它是一扇門投下的影。 / THE EIGHTH OMEN WAS NEVER AN OMEN. IT WAS THE SHADOW OF A DOOR. | q.eighthOmen.resolved(closer) | L2 | quest 結案句 | 門影投落為真;「第八」=隊伍第八人(motif 見 row 16,該行維持 L1 服務 floorEchoes[1]/w 8) | 保留;Batch 1 專行釐清 closer 級(row 16 不動) |

## Batch 2(#315)入賬區 [SETTLED — James review 完成 2026-08-16]

開場 scene(`story.opening.*`,ceiling L0)+ 掌燈人五會 script
(`story.lamplighter-m{i}.*`,ceiling L1)。shipped 交易句(rows 49–63)
不重列;本區只入本批新句。全文與 script 結構見
`docs/story/batches/2026-08-16-batch2-opening-lamplighter.md`。

| # | 句子 | 出處 | 級 | 表面讀法 | 揭後讀法 | 狀態 |
|---|---|---|---|---|---|---|
| 84 | 你醒了。 / You're awake. | story.opening.b1.l1(Keeper) | L0 | 死後在爐邊醒來 | #259 Q1 定式:「醒」字面真——留者每次都只是醒來,從未回來過;Keeper 一字不多 | 新寫 |
| 85 | 慢慢來。路不會走掉。 / Take your time. The road isn't going anywhere. | story.opening.b1.l2(Keeper) | L0 | 溫柔的安慰 | 反催促規則的正面演出:關懷即麻醉;路確實走不掉——路上的隊伍也在等 | 新寫 |
| 86 | 帶上這個。前人留下的,如今是你的了。 / Take this. Those before you left it behind; now it's yours. | story.opening.b2.l1(Keeper) | L0 | 前輩朝聖者的遺贈 | 字面真:boon=歷代行者遺物——它用死者行裝資助下一個死者(00 §2.4) | 新寫 |
| 87 | 路向東,盡頭有一道封門。尋回六片燼璃,門便會開。 / The road runs east. At its end stands a sealed door. Bring back the six shards of emberglass, and it will open. | story.opening.b2.l2(Keeper) | L0 | 旅程目標(表面明文事實,#262 Q3 任何級可直說) | 字面真而漏一半:門開那刻是隊伍推的(00 §2.6);misleading by omission | 新寫 |
| 88 | 他們說,門後是金城。到了那裏,你便到家了。 / Beyond it, they say, lies the Gilded City. Reach it, and you will be home. | story.opening.b2.l3(Keeper) | L0 | 傳說中的應許+祝福套語 | 雙重誠實:「他們說」是真(眾人 legend);「到家」字面即 canon——金城=爐邊真貌,入城=歸家(#259 Q3) | 新寫 [SETTLED James 2026-08-16] |
| 89 | 你提起燈,推門而出。長路向東,天未亮。 / You take up the lantern and step out. The long road runs east, and the sky is not yet light. | story.opening.b3.l1(敘) | L0 | 出發 | 「推門」與 00 §2.6 的推門暗韻;天未亮=破曉(勝利)之前,字面地理 | 新寫 |
| 90 | 身後,爐火仍亮着。 / Behind you, the fire is still burning. | story.opening.b3.l2(敘) | L0 | 家還在背後 | 爐火當然仍亮——留下的那個還在;離開才是錯覺 | 新寫 |
| 91 | 守夜開始了。 / The vigil begins. | story.opening.b4.l1(敘;linger shot) | L0 | 爐火為你守夜 | 留者的守夜由分身一刻開始;linger 畫面(兜帽坐像)零文字確認照舊 | 新寫 [SETTLED James 2026-08-16] |
| 92 | 路上坐着一個提燈的老人。燈是空的,沒有火。 / An old man sits by the road, holding a lantern. There is no flame in it. | story.lamplighter-m1.pre.l1(敘) | L1 | 路上的怪老人 | 空燈=意志已離開的器皿(01 火的物理);他自己就是被挖空的容器(row 58) | 新寫 |
| 93 | 你的燈燒得太滿。滿燈的人,我見得多。 / Your lantern burns too full. I have seen plenty like you. | story.lamplighter-m1.pre.l2(掌) | L1 | 老行尊的牢騷 | 「見得多」開多代行者線:滿燈的人他全見過,個個一去不回 | 新寫 |
| 94 | 這張面孔,又是往東走的。 / This face. East again, then. | story.lamplighter-m1.pre.l3(掌) | L1 | 又一個東行的朝聖者 | 「又」的歸屬歧義:又一個人,還是又一次這張面孔?慢性毒第一滴 | 新寫 |
| 95 | 油可以分,火不能分。火要自己帶到最後。 / Oil can be shared. Flame cannot. Flame you carry to the end yourself. | story.lamplighter-m1.post.l1(掌) | L1 | 掌燈人的行話 | 火=意志:意志分不了,只能由行者親自帶到底——帶到站着死去為止 | 新寫 |
| 96 | 他把三點餘燼收進空燈。燈沒有亮。 / He gathers the three embers into the hollow lantern. The lantern does not light. | story.lamplighter-m1.post.l2(敘) | L1 | 詭異:餘燼點不亮燈 | 空燈不承意志——器皿早已空;他收的從來不是火,是認人的線索 | 新寫 |
| 97 | 上次是你。三點餘燼,一分不少。這雙手,我記得。 / Last time — that was you. Three embers, not one short. I remember these hands. | story.lamplighter-m2.pre.l2(掌) | L1 | 他記得你上次付價 | **明文「上次」句本體(00 §3.6)**:觀察全真(面孔、手、數目),結論「是你」按 canon 屬誠實錯認——跨 run 時身體是另一個;drift 記賬(fair-play 第 7 條) | 新寫;上次句錨 |
| 98 | 手瘦了。路上的日子,誰都一樣。 / Thinner, these hands. The road feeds no one well. | story.lamplighter-m2.pre.l3(掌) | L1 | 風霜之嘆 | 差異觀察:同 run=消耗,跨 run=另一雙手;兩情境皆真 | 新寫 |
| 99 | 他把金幣一枚一枚數過,不收起,只沿路放好,向東。 / He counts the coins one by one, and does not pocket them. He lays them out along the road, piece by piece, pointing east. | story.lamplighter-m2.post.l1(敘) | L1 | 怪癖 | 一枚一枚向東排開=沿路一座一座的隊;他不自覺在重演路的真相 | 新寫 |
| 100 | 去。忘記是要學的。 / Go on. Forgetting takes practice. | story.lamplighter-m2.post.l2(掌) | L1 | 對散財的豁達 | 整個世界靠練熟了的忘記運轉:留者忘記自己沒走過,眾人忘記行者 | 新寫 |
| 101 | 這一次,老人站着等你。未看清你的面孔,他不開口。 / This time the old man is on his feet, waiting. Until he has looked you full in the face, he does not speak. | story.lamplighter-m3.pre.l1(敘) | L1 | 老人鄭重其事 | 認人越見越急(#260 Q3):由坐到站,先驗貨後開口 | 新寫 |
| 102 | 站近一點。提高你的燈,讓我看一看這張面孔。 / Stand closer. Raise your lantern — let me see this face properly. | story.lamplighter-m3.pre.l2(掌) | L1 | 老眼昏花 | 他的燈照不了人(無火);認人要靠你自己的光 | 新寫 |
| 103 | 額上多了一道傷痕。上次沒有。……路上的事,自然。 / A scar on your brow. Last time there was none. …The road gives them out. Naturally. | story.lamplighter-m3.pre.l3(掌) | L1 | 見你添了傷 | 明文「上次」句之二:差異是真差異(另一個身體),「自然」是他親手把證據解釋走——誠實見證人錯誤結論的現場 | 新寫 [SETTLED James 2026-08-16] |
| 104 | 別那樣看我。老人家見到什麼,便說什麼。 / Don't look at me like that. An old man tells what he has seen — no more than that. | story.lamplighter-m3.post.l1(掌) | L1 | 倔強老人 | 他的憲章句:每句都真,結論都錯(00 §4 hearsay 行的自白) | 新寫 |
| 105 | 他退後一步,再看你一眼——由面孔,看到腳。 / He steps back and looks you over once more — from the face down to the boots. | story.lamplighter-m3.post.l2(敘) | L1 | 上下打量 | 全身核對:第三會後他已在懷疑什麼,只是說不出口 | 新寫 |
| 106 | 老人的目光越過你,落在你帶着的東西上,一件一件地數。 / The old man's eyes go past you, to the things you carry, counting them one by one. | story.lamplighter-m4.pre.l1(敘) | L1 | 盤點你的行裝 | 認人升級:認物——物比人可靠,物不會換一個身體 | 新寫 |
| 107 | 西面爐火出來的東西,我一眼認得。這麼多年,樣式沒有變過。 / Things from the western fire — I know them at a glance. All these years, the make has never changed. | story.lamplighter-m4.pre.l2(掌) | L1 | 老工匠認得老手工 | 樣式當然沒變:boon 是同一批死者遺物循環派發(00 §2.4);他看見證據,讀不出結論 | 新寫 |
| 108 | 回我一句就好。上次站在這裏的,是不是你? / Give me one answer, that is all. Last time, standing where you stand — was that you? | story.lamplighter-m4.pre.l3(掌) | L1 | 老人的怪問題 | 明文「上次」句之三:認人啟事問到口。答案玩家自己都答錯——他有記憶,身體不是他 | 新寫 [SETTLED James 2026-08-16] |
| 109 | 你還未出聲,他已擺了擺手,像不願知道那一句之後的事。 / Before you can make a sound, he waves the question away — as if he would rather not learn where it leads. | story.lamplighter-m4.pre.l4(敘) | L1 | 老人怕尷尬 | 他怕的是答案的下文:太多同一張面孔已教過他,有些事問穿就守不住 | 新寫 |
| 110 | 他把贈禮收好。空燈放在腳前,依然黑着。 / He puts the gift away. The hollow lantern sits by his feet, dark as ever. | story.lamplighter-m4.post.l1(敘) | L1 | 交易完成 | 守爐人的贈禮也點不亮空燈——死者的行裝沒有火,只有記認 | 新寫 |
| 111 | 下一程遠。自己要慢慢用。 / The next stretch is long. Spend yourself slow. | story.lamplighter-m4.post.l2(掌) | L1 | 粗聲的關心 | 「用自己」講到明:行者正是被逐程用掉的東西;m5 的心跳價由此接力 | 新寫 |
| 112 | 未燃之路的盡頭,老人提着空燈,站在路的正中,不讓你過。 / Where the Unlit Way runs out, the old man stands in the middle of the road, hollow lantern raised. He does not let you pass. | story.lamplighter-m5.pre.l1(敘) | L1 | 最後的攔路 | 認人最後機會:過此以後他再驗不到下一個面孔 | 新寫 |
| 113 | 最後一次。過了我,這條路上再沒有人向你收東西。 / The last price. Past me, no one on this road will ask anything more of you. | story.lamplighter-m5.pre.l2(掌) | L1 | 最後一道關 | 字面真:再往東只剩王庭與門——路向行者收的最後一樣東西是命,但那不叫「收」 | 新寫 |
| 114 | 我提這盞燈,認了一生的人。面孔,我認得出;人,我從來不曾說得定。 / A lifetime under this lamp, learning the ones who pass. The faces I know. The people I was never sure of. | story.lamplighter-m5.pre.l3(掌) | L1 | 老人自嘲眼力衰退 | 字面真到骨:面孔全部相同、人代代不同,誰都分不出;五價=認人啟事的敗訴陳詞 | 新寫 [SETTLED James 2026-08-16 — L1 explicit sign-off:lint 結構陳述軸兩 warn 判撤,hedge 個人認不出成立] |
| 115 | 去。這一段,我送過太多人。 / Go. I have seen many off along this stretch. | story.lamplighter-m5.post.l1(掌) | L1 | 見慣別離 | 「送」的殮葬義浮出:他一直在做的是送行(00 §7 掌燈人揭後本體) | 新寫 |
| 116 | 他讓開路,提起空燈,向東照了照——燈中沒有光;他仍是照了。 / He steps aside and lifts the hollow lantern toward the east, as if to light the way. There is no light in it. He lifts it all the same. | story.lamplighter-m5.post.l2(敘) | L1 | 感人的老儀式 | 無火而照=無器之意志;未燃之路的名字在這個手勢裏 | 新寫 |
| 117 | 路上若再見提燈的,替我看一看那張面孔。 / If you meet another out there who carries a lamp — look close at the face, for me. | story.lamplighter-m5.post.l3(掌) | L1 | 老人的怪託付 | 下一個提燈者=無焰提燈的永恆君王;那張「面孔」是貼着鎖的面具(03-acts)——他把認人之責交給你 | 新寫 |
| 118 | 未燃之路再向東,老人又在等。空燈放在身前。 / Farther east along the Unlit Way, the old man is waiting again, the hollow lantern set before him. | story.lamplighter-m2.pre.l1(敘) | L1 | 又一次會面 | 「又在等」:等的母題(01 水=等)輕拍一下;他等的是核對下一張面孔 | 新寫 |

## `[REWRITE:climb]` 清單狀態 — 已關閉

全量掃描由 #232 的十四-agent 量度完成,記錄於
[#301 的掃描 comment](https://github.com/fol2/glassvow/issues/301#issuecomment-5304721761)
(2026-08-15)。content.* 側 Tier A 句已全數入賬:quest/whisper 句在
Batch 1 區(rows 32–82)重寫或保留;ui.* 側歸 #303(chrome)與 #228
(prose);scene/finale 側歸 #263/#309;音軌名同 batch 檔「一語三址」節。
原 [TODO] 於 Batch 1(#301)開稿時關閉。
