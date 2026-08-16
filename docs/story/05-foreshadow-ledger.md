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
| 31 | 王冠之後 / beyond the crown | 公式,七址:ui.dawn.act4RevealCopy、ui.dawn.unlock.act4、q.hollowLamplighter.meetings[1].paid、q.unreadablePage.pages[4]、whisper 21、main.gd:375(舊記 :372,#303 量得已飄 +3)、dawn_phone_containment.gd:140;本批另 usurper.death 與 whisper 20 取此式 | L1 | 封門在王庭之外、王座之後 | 「之後」雙關:過了「不肯完成」,路便向家;門從來不在上方,只在更遠處 | 新公式 [SETTLED James 2026-08-16 — 一次簽,七址共用] |

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

## #303 — ui.\* chrome 清洗(2026-08-16)

世界尺度的主語位由 **路 / the road** 接(06-glossary 新增鎖詞,James
2026-08-16 判)。以下各行**只換名詞、不重寫句式**——James 簽的是「掃埋,
尖塔→路」,審核方式為逐句讀 PR diff。凡 zh 側原本已是 朝聖之路(Tier B)
的行,只動 en。

| # | 句子(現行) | 出處 | 級 | 表面讀法 | 揭後讀法 | 狀態 |
|---|---|---|---|---|---|---|
| 119 | 路如常。未立任何誓言。 / The road as it is. No vows sworn. | ui.embark.noVows | L0 | 這次不立誓 | 路從不變;變的是每次派出去的那個 | 重寫(舊 尖塔如常 / The Spire as it is) |
| 120 | 選擇你面對路途的方式。 / Choose how you meet the road. | ui.embark.subChoose | L0 | 選難度 | 「面對」的是同一段路的第 n 次 | 重寫(舊 尖塔) |
| 121 | 提燈已燃。路在等待。 / The lantern is lit. The road waits. | ui.embark.subWait | L0 | 出發前一刻 | 等的是路,不是你——隊伍排着(01 水=等) | 重寫(舊 尖塔在等待) |
| 122 | THE PILGRIMAGE BEGINS | ui.embark.title(en) | L0 | 啟程字 | — | en 對齊 zh 既有「朝聖啟程」(舊 THE CLIMB BEGINS) |
| 123 | 永恆君王已化塵。破曉越過長路——這是漫長年代中的第一次。 / …Dawn breaks over the road — the first in an age. | ui.end.ascendedSub | L1 | 勝利辭 | 破曉越過的是整條隊伍量過的路,不是一座塔 | 重寫(舊 越過尖塔 / over the Spire) |
| 124 | 一段朝聖之路在第 {floor} 塊引路石終結。路留下它所奪走的——守夜卻會銘記。 / Here ended a run, at waystone {floor}. The road keeps what it takes — but the Vigil remembers. | ui.end.fallenSub | L1 | 敗北辭 | 「路留下它所奪走的」=碑;所奪走的那個仍站着(row 1) | 重寫(舊 尖塔留下 / The Spire keeps;計數併 row 30) |
| 125 | 沿提燈之路前行。… / Follow the road of lanterns onward. … | ui.help.climbBody・climbTitle | L0 | 玩法說明 | — | 重寫(舊 前往尖塔 / up the Spire);en 標題對齊 zh 既有「朝聖之路」 |
| 126 | …留給願意踏上更殘酷朝聖之路的人。 / …for those who'd walk a crueler road. | ui.help.vigilBody(en) | L0 | 誓言階梯說明 | — | en 對齊 zh(舊 climb a crueler Spire);zh 側原已乾淨 |
| 127 | {aspect} 立於路途起點。… / {aspect} stands at the head of the road. … | ui.lamp.sub | L0 | 掌燈人場景 | 「起點」對「路上若再見提燈的」(row 117):他一直站在同一個起點 | 重寫(舊 尖塔腳下 / at the foot of the Spire) |
| 128 | 爐火噼啪。片刻之間,路安靜。 / …For a moment, the road is quiet. | ui.rest.sub | L0 | 休息點 | 路安靜=隊伍暫停;安靜的從來不是你 | 重寫(舊 尖塔安靜 / the Spire is quiet) |
| 129 | 離開路途? / LEAVE THE ROAD? | ui.menu.leaveSpireTitle | L0 | 離開確認 | 「離開路」對「留在路上」(row 28):兩個掣是同一組反照 | 重寫(舊 離開尖塔 / LEAVE THE SPIRE?);zh 初稿「離開路上?」語法不通,改「路途」 |
| 130 | 空燈掌燈人踏上路途。 / The Hollow Lamplighter walks the road. | ui.dawn.unlock.lamplighter | L1 | 解鎖通告 | 他一直在路上——解鎖的是你見到他,不是他出現 | 重寫(舊 踏上尖塔 / walks the Spire) |
| 131 | 朝聖之路上如今可找到藥瓶。/ 新卡牌與遺物加入朝聖之路。 / Phials may now be found on the road. · New cards and relics join the pilgrimage. | ui.dawn.unlock.phials・pool | L0 | 解鎖通告 | — | **zh 兩行皆未動**(原已是 朝聖之路,Tier B);只有 en 對齊(舊 on the climb / enter the climb) |
| 132 | {runs} pilgrimages · {wins} dawns · … | ui.brand.stats・ui.vigil.stats(en) | L0 | 統計行 | 數的是派出去的次數 | en 對齊 zh 既有「{runs} 次朝聖」(舊 {runs} climbs);`{runs}` 佔位符不動,故不取 "run" |
| 132b | {action} 以巡視路途 / {action} to survey the road | ui.map.survey | L0 | 地圖提示 | — | 置換(舊 巡視尖塔 / survey the Spire),#232 簽定字面。**此鍵全樹零 reader**——實際渲染的是 ui.pilgrimage.survey(「巡視朝聖之路」)與 .surveyChoose;兩者同一動詞兩個受詞,連同刪鍵一併歸 [#305](https://github.com/fol2/glassvow/issues/305) |
| 133 | (功能字串:climb → run) | ui.persistence.reloadClimb・runSaveBody・runSaveRetryFail・ui.embark.warnSaved・ui.end.bequestTitle・ui.settings.resetConfirmBody・resetWarn・resetConfirmPlain | L0 | 存檔/重設提示 | 無揭後讀法:此八行是機器語,不是敘述 | en 置換(#232 簽);zh 八側原已是 朝聖之路(Tier B),不動 |

## Batch 3(#331)入賬區 [SETTLED — James review 完成 2026-08-16]

三 pool 全句入賬(爐邊 h / 引路石 w / 敗亡遺言 e;出處=
`pool.<slot>.<id>`,詳表與條件欄見
`docs/story/batches/2026-08-16-batch3-pools.md`)。全批 L1、全批新寫
(狀態欄從略);zh 為源語。

| # | 句子 | 出處 | 級 | 表面讀法 | 揭後讀法 |
|---|---|---|---|---|---|
| 134 | 你醒了。火仍在。 / You're awake. The fire is still here. | pool.hearth.h01 | L1 | 迎接晨醒 | #259 Q1 定式——醒非歸;「火仍在」=它仍在,火是它的臉 |
| 135 | 坐近一點。路可以等。 / Sit closer. The road can wait. | pool.hearth.h02 | L1 | 不必急 | 在等的正是路上那條隊;等=全書母題 |
| 136 | 爐火整夜沒有熄。 / The fire didn't go out all night. | pool.hearth.h03 | L1 | 爐火安好 | 它從不熄——守夜與沉澱同壽 |
| 137 | 慢慢來。夜還長。 / No hurry. The night is long. | pool.hearth.h04 | L1 | 溫言安慰 | 守夜之夜無盡;破曉(勝利)永在東面未到 |
| 138 | 手先暖了,再拿東西。 / Warm your hands first. The rest can wait. | pool.hearth.h05 | L1 | 關懷 | 關懷即麻醉(#260 Q1);儀式以溫柔運行 |
| 139 | 這把火,由第一夜燒到現在。 / This fire has burned since the first night. | pool.hearth.h06 | L1 | 爐火的年資 | 第一夜=碎裂之夜;爐火是原初之火餘燼(00 §2.2) |
| 140 | 灰我清過了,柴也添過了。 / I've cleared the ash and fed the fire. | pool.hearth.h07 | L1 | 家常打點 | 灰=行者燒剩(§2.2 同源);它日日清理儀式的餘燼 |
| 141 | 外面有霜。多帶一層。 / There's frost out. Take another layer. | pool.hearth.h08 | L1 | 添衣叮嚀 | 它為死者備行裝——一直如此 |
| 142 | 路上冷,這裏不冷。 / The road is cold. It is not cold here. | pool.hearth.h09 | L1 | 爐邊之暖 | 安排的推銷詞:留低=不冷;八字講盡誘因 |
| 143 | 你的燈,我上了油。 / I've oiled your lantern for you. | pool.hearth.h10 | L1 | 打點行裝 | 用死者遺物資助下一個死者(00 §2.4)同構——燈油也是資助 |
| 144 | 芯是新的,油是滿的。 / New wick. Full oil. | pool.hearth.h11 | L1 | 裝備妥當 | 每一程都由它裝備;新芯滿油=儀式的例行 |
| 145 | 願意走的時候,才走。 / Leave when you want to. Not a moment sooner. | pool.hearth.h12 | L1 | 尊重你的步伐 | 規 3 的機制本體——必須顯得是你自己要走(02-cast) |
| 146 | 我在這裏。一直都在。 / I'm here. I always am. | pool.hearth.h13 | L1 | 可靠的陪伴 | 字面真到盡——它從未離開過爐邊(#261 Q11) |
| 147 | 守夜的事,交給我。 / Leave the vigil to me. | pool.hearth.h14 | L1 | 分工 | 守夜就是它的存在方式;「交給我」=安排本身 |
| 148 | 火光認得你。 / The firelight knows you. | pool.hearth.h15 | L1 | 爐火溫馨 | 爐火是它的第二張臉(02-cast)——認得你的是它 |
| 149 | 東西都在原位。這裏不變。 / Everything is where it was. Nothing changes here. | pool.hearth.h16 | L1 | 安穩 | 千 run 不變=儀式凝固;m4.2「樣式沒變」同景 |
| 150 | 窗我抹過了。亮的格,更亮。 / I've wiped the panes. The lit ones shine better for it. | pool.hearth.h17 | L1 | 家務 | 它擦拭的是隊伍的計數板 |
| 151 | 別站在門口,風大。 / Don't stand in the doorway — the wind. | pool.hearth.h18 | L1 | 擋風關懷 | 把你由 threshold 引回火邊;門口是它永不站的位置 |
| 152 | 你睡着時,火暗了一次。我添了柴。 / The fire sank while you slept. I fed it. | pool.hearth.h19 | L1 | 夜間照料 | 你每次「睡着」,它都在維持儀式 |
| 153 | 這條路,你行過的次數,比誰都多。 / No one has walked that road more times than you. | pool.hearth.h20 | L1 | 讚許老手 | 「你」=歷代每一個真正的你(00 §1);二十個你行過 |
| 154 | 第一段路,你會見到許多碑。不必停。 / The first stretch has many monuments. You needn't stop for them. | pool.hearth.h21 | L1 | 路況提點 | 它明知碑是誰;「不必停」=不要看清 |
| 155 | 這裏永遠有你的位。 / There will always be a place for you here. | pool.hearth.h22 | L1 | 家的保證 | 永遠有位=安排永續;那個位是留者的座 |
| 156 | 走得多遠,火都在原地。 / However far you walk, the fire stays where it is. | pool.hearth.h23 | L1 | 家在原地 | 字面地理——路的盡頭就是爐邊(#259 Q3) |
| 157 | 選一件合手的。前人的手,與你的一樣。 / Take whichever fits your hand. The hands before yours were just the same. | pool.hearth.h24 | L1 | 揀件合用 | 前人的手與你的一樣——字面同一雙手 |
| 158 | 全是留下來的東西。留下來的,自有用處。 / It's all left-behind things. What stays behind has its uses. | pool.hearth.h25 | L1 | 惜物 | 自我指涉:「留下來的」包括它自己;最有用處的正是留低嗰個 |
| 159 | 帶上它。它認得路。 / Take it. It knows the road. | pool.hearth.h26 | L1 | 老物可靠 | 行裝行過的次數比「你」更多;物比人長命(row 107 同族) |
| 160 | 火留給我,你帶燈。 / The fire stays with me. The lamp goes with you. | pool.hearth.h27 | L1 | 分工道別 | §3.2 分身分工的反照——火留、燈走;走的帶走意志 |
| 161 | 這道門,從不上鎖。 / That door is never locked. | pool.hearth.h28 | L1 | 隨時歡迎 | 儀式需要門常開;上鎖=安排終結 |
| 162 | 外面起風了。再坐一會。 / The wind's up. Sit a while longer. | pool.hearth.h29 | L1 | 天氣挽留 | 軟性挽留=規 3 反向;拖一刻是一刻 |
| 163 | 六格都亮起的那一天,門會開。 / The day all six panes are lit, the door will open. | pool.hearth.h30 | L1 | 目標明示(表面明文事實) | o4 已簽同款——漏了「行過的人」那一半(§2.6) |
| 164 | 金城不會走掉。 / The Gilded City isn't going anywhere. | pool.hearth.h31 | L1 | 不必急的安慰 | 字面真到痛——金城=爐邊真貌,它正在此(#259 Q3) |
| 165 | 有我看火,你便不必看。 / I'll watch the fire, so you don't have to. | pool.hearth.h32 | L1 | 分擔 | 安排的鏡像句——真相是你走使它不必走 |
| 166 | 累了便睡。火自己會亮。 / Sleep when you're tired. The fire minds itself. | pool.hearth.h33 | L1 | 體貼 | 火自己會亮,因為火就是它 |
| 167 | 今夜的火,燒得穩。 / The fire burns steady tonight. | pool.hearth.h34 | L1 | 爐況 | 儀式運行如常;穩=無人打破 |
| 168 | 你望東面望得太久了。火在這一面。 / You've been looking east too long. The fire is on this side. | pool.hearth.h35 | L1 | 拉你回暖 | 把目光由門拉回火;留的引力有一張溫柔的口 |
| 169 | 慢火才燒得久。 / A slow fire burns longest. | pool.hearth.h36 | L1 | 爐邊格言 | 它的哲學:拖長儀式;慢=永不完 |
| 170 | 破曉之前,總是最冷。 / It's coldest just before dawn. | pool.hearth.h37 | L1 | 老話 | 破曉=勝利字;最後一段(黑曜)最冷,亦最近終結 |
| 171 | 燈也要歇。人更加要。 / Even lamps rest. People need it more. | pool.hearth.h38 | L1 | 勸歇 | 「歇」是它要你熟習的動作;歇的終點是留低 |
| 172 | 出去之前,再暖一暖手。 / Before you go, warm your hands once more. | pool.hearth.h39 | L1 | 送行關懷 | 為出發的那個暖手——為死者暖手 |
| 173 | 向東,一直向東。這一句不會錯。 / East, and keep east. That much is always true. | pool.hearth.h40 | L1 | 方向保證 | 一直向東的盡頭是西(#259 Q3 一個圈);「不會錯」=終會歸家 |
| 174 | 灰會落,火會亮。一直如此。 / Ash falls; fire burns. It has always been so. | pool.hearth.h41 | L1 | 世界如常 | 「一直如此」=行者的年代(§2.3);常態即儀式 |
| 175 | 我不送了。門口風大。 / I won't see you out. The wind at the door is cruel. | pool.hearth.h42 | L1 | 不送之禮 | 字面真——它不能送:它從未離開過爐火 |
| 176 | 窗中的東西,有一日你會看清。 / One day you will see that window clearly. | pool.hearth.h43 | L1 | 彩窗之美/quest 應許 | L3 開封場前指——看清那日=見隊伍(議程 3 照過,James 2026-08-16) |
| 177 | 今夜與上一夜,一樣長。 / Tonight is as long as the last one. | pool.hearth.h44 | L1 | 夜夜如一 | 循環自身;每一夜它都在場 |
| 178 | 多帶一枚金幣。路上伸手的多。 / Take an extra coin. The road is full of open hands. | pool.hearth.h45 | L1 | 旅費叮嚀 | 伸手的包括收遺物的與索代價的;它全認得 |
| 179 | 這一面暖。坐這一面。 / This side is warmer. Sit on this side. | pool.hearth.h46 | L1 | 讓座 | 「這一面」對「另一面」——鏡面 motif 的家常版 |
| 180 | 窗亮了一格。夜沒有之前那麼暗了。 / One pane is lit. The nights are not so dark now. | pool.hearth.h47 | L1 | 進度+安慰 | 火在歸位;夜(守夜)漸近終結,它口不對心 |
| 181 | 那一格的光,顏色像爐火。 / The light in that pane — the colour of this fire. | pool.hearth.h48 | L1 | 巧合的美 | 非巧合——同一團火(§2.2 字面) |
| 182 | 兩格了。窗開始記起自己的樣子。 / Two now. The window is remembering its shape. | pool.hearth.h49 | L1 | 詩意 | 玻璃=記憶;窗在記起碎裂之夜(00 §8.6) |
| 183 | 兩格亮了。餘下的,路知道在甚麼地方。 / Two are lit. The road knows where the rest are waiting. | pool.hearth.h50 | L1 | 尋寶提示 | 「路知道」=隊伍知道;指路者在等你去取(00 §4) |
| 184 | 三格,半扇窗。半團火。 / Three panes. Half a window. Half a fire. | pool.hearth.h51 | L1 | 進度過半 | 火重一之半;倒數開始 |
| 185 | 窗亮到一半,我在夜裏都看得見它了。 / Half-lit now. I can see it even in the dark hours. | pool.hearth.h52 | L1 | 窗亮可喜 | 它夜夜看着自己的終結逐格亮起 |
| 186 | 四格。窗開始照出這裏的東西了。 / Four. The window has begun to show the room. | pool.hearth.h53 | L1 | 玻璃反光 | 成鏡前奏(L3);照出「這裏」=鏡的另一面在成形 |
| 187 | 還有兩片。之後的事,之後再說。 / Two shards left. What comes after can wait for after. | pool.hearth.h54 | L1 | 不急不急 | 「之後的事」=開封與換位;它不願說下去 |
| 188 | 五格,餘一片。慢慢來。 / Five panes. One to go. There's no hurry. | pool.hearth.h55 | L1 | 進度+安慰 | 拖延=它的求生;「慢慢來」是對自己說的 |
| 189 | 五格了。窗比火還亮。 / Five. The window outshines the fire now. | pool.hearth.h56 | L1 | 窗的光彩 | 記憶之光壓過留者之火;隊伍的光>留的火 |
| 190 | 那盞燈冷。別放近火。 / That lantern is cold. Keep it away from the fire. | pool.hearth.h57 | L1 | 器物保養 | 它認得那盞燈——第一行者之燈回到爐前;不想它近火 |
| 191 | 今夜靜。連影都不吵了。 / Quiet tonight. Even the shadows have stopped their noise. | pool.hearth.h58 | L1 | 安靜可喜 | 你熄了自己仍記得行的那部分;它滿意 |
| 192 | 路上那位提燈的老人家——他說的,信一半就好。 / That old lamp-keeper on the road — believe half of what he says. | pool.hearth.h59 | L1 | 風趣提點 | 字面正確的忠告——事實半全真、結論半全錯(00 §4 hearsay)(議程 2 照過,James 2026-08-16) |
| 193 | 三片歸位。餘下三片,在更東的地方。 / Three home. The other three lie further east. | pool.hearth.h60 | L1 | 進度指引 | 「更東」的盡頭是西;三片在等隊伍遞回 |
| 194 | 燈到石,石亮。原來石一直在等火。 / The lamp reaches the stone, and the stone lights. It was waiting for fire all along. | pool.waystone.w01 | L1 | 石燈機關 | 等=母題;石等過每一代行者的火(row 30) |
| 195 | 這段路,足跡比人多。 / More footprints than people on this stretch. | pool.waystone.w02 | L1 | 路多人行 | 人一個一個來,足跡累積成隊伍的量 |
| 196 | 一步一步數。數到忘了為甚麼要數。 / Counting steps, until I forget why I'm counting. | pool.waystone.w03 | L1 | 行路自遣 | 數=全書計數母題;行者都在數,終有人替你數 |
| 197 | 石是誰放的?路沒有說。 / Who set these stones? The road isn't saying. | pool.waystone.w04 | L1 | 無主之石 | 開放之問;「路自己學會留住我們」(row 4)一族 |
| 198 | 碑全部面向東。沒有一座面向爐火。 / The monuments all face east. Not one faces the fire. | pool.waystone.w05 | L1 | 碑向日出 | 站死面向東=面向門(m3.paid);隊伍列隊的方向(議程 4 照過——L1 explicit sign-off,James 2026-08-16) |
| 199 | 油還有,便不去數餘下的石。 / While there's oil, don't count the stones ahead. | pool.waystone.w06 | L1 | 行路智慧 | 數不到的是餘路——與隊伍一樣知前不知後 |
| 200 | 風把灰帶向西。灰認得那個方向。 / The wind carries the ash west. The ash knows that way. | pool.waystone.w07 | L1 | 風向觀察 | §2.2 西飄字面——灰歸爐;燒盡者回爐膛 |
| 201 | 石座有燒痕,一層下面另有一層。 / Scorch marks at the stone's base — a layer, and under it another. | pool.waystone.w08 | L1 | 石座痕漬 | 一層=一代;row 30 的實物證據 |
| 202 | 越往東,路越靜。 / The further east, the quieter the road. | pool.waystone.w09 | L1 | 路況 | 越東越近門;人聲讓位於等待 |
| 203 | 回頭,西面仍有火光。仍未算遠。 / Looking back, the firelight is still there. Not far yet, then. | pool.waystone.w10 | L1 | 未走遠 | 幾遠都不算遠——盡頭仍是爐邊(#259 Q3) |
| 204 | 引路石不引人回頭。 / Waystones never point back. | pool.waystone.w11 | L1 | 石的設計 | 行者之路單向;沒有人回去過 |
| 205 | 像有人與我同行。回頭,只有碑。 / It feels like company on this road. I look back — only monuments. | pool.waystone.w12 | L1 | 錯覺自嘲 | 錯覺為真——隊伍確與你同行,而他們就是碑 |
| 206 | 火不重。重的是油。 / The flame weighs nothing. The oil is the weight. | pool.waystone.w13 | L1 | 行囊感受 | 火=意志無重;重的是攜帶它的器皿(01 物理) |
| 207 | 到下一塊石再歇。到了,又說下一塊。 / Rest at the next stone. At the stone: the next one, then. | pool.waystone.w14 | L1 | 自我哄勸 | 「下一塊」講到站着死去為止 |
| 208 | 石只數走過的,不數剩下的。 / The stones count what's walked, never what's left. | pool.waystone.w15 | L1 | 石的計法 | 與隊伍同構——知已走,不知餘下 |
| 209 | 破曉在東面。一直在東面。 / Dawn is east. It stays east. | pool.waystone.w16 | L1 | 方位常識 | 破曉=勝利,永在前方;行者無人見過全亮 |
| 210 | 路剩多少,無人能說。 / No one can say how much road is left. | pool.waystone.w17 | L1 | 路長未知 | 隊伍的長度同樣無人能說 |
| 211 | 有一座碑,手仍舉着,像要接甚麼。 / One monument still holds its arm out, as if to catch something. | pool.waystone.w18 | L1 | 碑姿怪異 | 臨終姿勢——交出/接住的一刻凝住(§3.7) |
| 212 | 灰落在燈罩上,一層,又一層。 / Ash on the lamp glass. A layer, then a layer. | pool.waystone.w19 | L1 | 灰景 | 層層灰下又一層——年代的積聚 |
| 213 | 林靠灰養大。灰是誰養大的? / The forest feeds on ash. What feeds the ash? | pool.waystone.w20 | L1 | 生態怪談 | 灰=行者燒剩的力氣(#261 Q3);答案是行者 |
| 214 | 第一段,碑最密。起步之地,停步的人最多。 / The monuments stand thickest here, where the road begins. | pool.waystone.w21 | L1 | 起步碑多 | 第一段淘汰最多(03-acts);最早的碑在此 |
| 215 | 兩盞燈並亮。火是新的。誰點的? / Two lanterns burning side by side. The flames are fresh. Whose? | pool.waystone.w22 | L1 | 有人先行 | 「有人仍在點燈」(act1-mid);火新=隊伍未停 |
| 216 | 孢子懸在光裏,像未落的灰。 / Spores hang in the lamplight, like ash that won't come down. | pool.waystone.w23 | L1 | 孢子浮光 | 未落的灰=未燒盡的殘意 |
| 217 | 樹下有蒼白面具,不止一副。 / Pale masks under the tree. More than one. | pool.waystone.w24 | L1 | 詭異遺物 | 拜灰者的面具;蒼白=耗剩意志之色 |
| 218 | 根從灰裏伸出來,握着甚麼。 / Roots reach out of the ash, holding something. | pool.waystone.w25 | L1 | 樹根怪狀 | 根靠灰活——握着行者燒剩的力氣(#261 Q3) |
| 219 | 灰收走腳步聲。這段路,靜得像沒有人走過。 / The ash takes the sound of my steps. As if no one had ever walked here. | pool.waystone.w26 | L1 | 靜路 | 無數人走過;灰把他們的聲音一併收走 |
| 220 | 有一座碑靠着樹。樹先到,還是碑先到? / A monument leans against a tree. Which of them came first? | pool.waystone.w27 | L1 | 閒問 | 碑先到——樹是靠灰後長的 |
| 221 | 燒過的林仍在長。長出來的,總會再燒。 / The burnt forest keeps growing. What grows will burn again. | pool.waystone.w28 | L1 | 山火循環 | 續火的循環——長出來的總會再燒(儀式) |
| 222 | 這裏的白,不像任何一種白。 / The white here is not like any other white. | pool.waystone.w29 | L1 | 顏色難名 | 蒼白——路拒絕命名的那種白(w 1 同讀) |
| 223 | 他們向灰祈禱。灰不應人。 / They pray to the ash. The ash answers no one. | pool.waystone.w30 | L1 | 邪教怪人 | 灰不應人,因為灰是耗盡的意志——無可應 |
| 224 | 燈光照到的,全是灰。照不到的,不去看。 / Everything in the lamplight is ash. What's past the light, I don't look at. | pool.waystone.w31 | L1 | 夜行紀律 | 光=意志透物;照不到處=不看的真相 |
| 225 | 過了樹林,他們說,有一座城。 / Past the forest, they say, there is a city. | pool.waystone.w32 | L1 | 前路傳聞 | 城=等的下場;傳聞照記(drift) |
| 226 | 水過了城的第二層。城沒有走。 / The water has taken the city's second storey. The city has not moved. | pool.waystone.w33 | L1 | 水浸廢城 | 城沒有走=第三種拒絕(停在中途等) |
| 227 | 這座城留下來等。水,也留下來。 / The city stayed to wait. So did the water. | pool.waystone.w34 | L1 | 廢城與積水 | 水=等(#261 Q4);兩個「留下來」同一件事 |
| 228 | 水下有光。那光不引路,只引人。 / There's a light under the water. It leads to nothing — it only leads people. | pool.waystone.w35 | L1 | 水底異光 | 假光=無意志的模仿(deepmaw);引人不引路 |
| 229 | 鐵欄蝕剩一半。原來等待,咬得動鐵。 / The iron rail is eaten half through. So waiting has teeth after all. | pool.waystone.w36 | L1 | 鏽蝕之景 | 蝕=等待對器皿的慢蝕(#261 Q4)字面 |
| 230 | 書庫沉在水裏。他們寫下的,如今水在讀。 / The library is under the water. What they wrote, the water is reading now. | pool.waystone.w37 | L1 | 沉沒書庫 | 他們的紀錄歸於等;水讀=等吞掉記錄 |
| 231 | 水裏有人走動。不上來,也不沉下去。 / Someone is moving in the water. Not rising. Not sinking. | pool.waystone.w38 | L1 | 水中怪影 | 淹死的等待者——等未散故仍走動(#261 Q4) |
| 232 | 水下有一口鐘,不響。它還在等甚麼? / A bell under the water, silent. What is it still waiting for? | pool.waystone.w39 | L1 | 沉鐘 | 連器皿都在等;等成了地方的物理 |
| 233 | 城門沒有關。他們不是出不去。 / The gates were never shut. It isn't that they couldn't leave. | pool.waystone.w40 | L1 | 廢城之謎 | 不是不能走,是選了等——三種拒絕的中段 |
| 234 | 這裏的水不流。等着的東西,都不流。 / The water here doesn't flow. Nothing that waits does. | pool.waystone.w41 | L1 | 死水 | 等=不流的意志(01 物理字面) |
| 235 | 窗內有人影,仍立在原地。 / Figures at the windows, still standing where they stood. | pool.waystone.w42 | L1 | 窗中殘影 | 大部分人淹沒時仍在等(03-acts);立在原地=等的姿勢 |
| 236 | 他們信門開那日,人人有份。 / They believed that when the door opened, it would open for everyone. | pool.waystone.w43 | L1 | 信仰紀錄 | legend-drift 明文(#261 Q1)——門不認眾人(§2.2) |
| 237 | 城選了等。水是等的樣子。 / The city chose to wait. The water is what waiting looks like. | pool.waystone.w44 | L1 | 詠嘆 | 水是等的樣子——物理方程直落景語 |
| 238 | 城中無一人向東行,無一人向西返。 / No one in this city walks east. No one walks back west. | pool.waystone.w45 | L1 | 死城 | 不走亦不返=等的完全式;兩個方向都放棄 |
| 239 | 潮聲像在數甚麼。 / The tide sounds like counting. | pool.waystone.w46 | L1 | 潮聲擬人 | 數=Herald 母題;城在數門開的日子 |
| 240 | 黑曜不透光。燈照上去,只照見自己。 / Obsidian lets no light through. Raise the lamp to it, and you see only yourself. | pool.waystone.w47 | L1 | 黑石反光 | 黑曜不透光(01 物理);照見自己=鏡 motif 前奏 |
| 241 | 斷了的光環落在地上,無人拾起。 / Broken halos on the ground. No one gathers them. | pool.waystone.w48 | L1 | 廢墟遺物 | 斷環=放棄一刻熄掉的光(00 §8.6);無人拾=無人回頭 |
| 242 | 越近門,人越多。全部坐着。 / The nearer the door, the more of them. All seated. | pool.waystone.w49 | L1 | 門前人多 | 千年廷——走到門前又不肯完成的人(#261 Q2) |
| 243 | 這裏的星低,低得像在看。 / The stars hang low here. Low enough to watch. | pool.waystone.w50 | L1 | 星夜低垂 | 注視之眼 motif;王庭一直被看/在看 |
| 244 | 他們讓路,像讓過許多次。 / They make way for me, as if they had done it many times before. | pool.waystone.w51 | L1 | 有禮的讓路 | 千年來讓過每一個行者;讓路=他們唯一還做的事 |
| 245 | 庭中無火。他們坐在星光裏,坐了太久。 / No fire in the court. They sit in starlight, and have sat too long. | pool.waystone.w52 | L1 | 無火之庭 | 無火=無意志;星光非他們的光 |
| 246 | 王座之後,他們說,再沒有路。 / Beyond the throne, they say, the road ends. | pool.waystone.w53 | L1 | 盡頭傳聞 | drift——王座之後其實是門(row 31 公式的反面) |
| 247 | 石上刻着一列數目。最後一筆是新的。 / A column of tally marks cut into the stone. The last one is fresh. | pool.waystone.w54 | L1 | 怪異刻痕 | 數隊伍的人(Herald 族);新一筆=隊伍剛長了 |
| 248 | 坐着的人望着我,像在等我坐下。 / The seated ones watch me, as if waiting for me to sit. | pool.waystone.w55 | L1 | 注視的壓力 | 他們在等你加入「停下」;坐=第三種拒絕的姿勢 |
| 249 | 黑曜裏面,有光死在途中。 / Inside the obsidian, light has died on its way through. | pool.waystone.w56 | L1 | 石中幽光 | 黑曜=不再讓意志通過的記憶;光死在途中=被放棄 |
| 250 | 王冠之後的事,他們不說。 / Of what lies beyond the crown, they do not speak. | pool.waystone.w57 | L1 | 忌諱 | 王冠之後=封門(row 31);不說=不肯面對最後一步 |
| 251 | 這段路無灰無水,只有黑曜與靜。 / No ash on this stretch, no water. Only obsidian, and the quiet. | pool.waystone.w58 | L1 | 荒涼對比 | 無灰無水=無燒盡無等待——只剩放棄(黑曜) |
| 252 | 燈的光,在這裏走不遠。 / Lamplight doesn't travel far here. | pool.waystone.w59 | L1 | 燈光微弱 | 光=意志透物;黑曜盡吞光——放棄之地不讓意志過 |
| 253 | 離門越近,越少人提起它。 / The closer the door, the less anyone speaks of it. | pool.waystone.w60 | L1 | 忌諱漸深 | 越近真相越無人言;沉默也是拒絕 |
| 254 | 燈還亮。人先熄。 / The lamp is still burning. I go out first. | pool.loss.e01 | L1 | 油盡燈枯的反轉 | 燈(器)比人長命;火將由蒼白之手接走(§3.7) |
| 255 | 腳不肯躺。由它站。 / My legs won't lie down. Let them stand, then. | pool.loss.e02 | L1 | 倔強遺言 | 站死物理字面(§3.3)——腳不肯躺,因為碑不躺 |
| 256 | 東面有一點亮了。全亮,看不到了。 / There's a little light in the east. I won't see it full. | pool.loss.e03 | L1 | 憾別 | 破曉=勝利;全亮那日,整條隊會替他看到(§2.6) |
| 257 | 油交給風,路交給後來的人。 / The oil goes to the wind. The road goes to whoever comes after. | pool.loss.e04 | L1 | 豁達交託 | 字面成真——風把灰帶西,路交給下一個(§2.2/§2.3) |
| 258 | 把燈放好。火不該隨我熄。 / Set the lamp down safe. The flame shouldn't go out with me. | pool.loss.e05 | L1 | 惜火 | 火(意志)真不隨他熄——隊伍接力;他說中了機制 |
| 259 | 冷從腳上來。數到七,不數了。 / The cold rises from my feet. I counted to seven, then stopped. | pool.loss.e06 | L1 | 臨終計數 | 第八不在數中(w 8)——門影正落在他身上 |
| 260 | 就到這裏?就到這裏。 / This far, then? This far. | pool.loss.e07 | L1 | 自問自答 | 「這裏」成為他永遠的位置——碑立於此 |
| 261 | 不必記我。路會記。 / Don't remember me. The road will. | pool.loss.e08 | L1 | 謙卑 | 路已學會留住我們(row 4);記的方式是碑 |
| 262 | 我未到。有人會到。 / Not me. But someone will get there. | pool.loss.e09 | L1 | 信念 | 字面真——隊伍終會到(§2.6);「有人」也包括站着等的他 |
| 263 | 門等得起。我等不起了。 / The door can afford to wait. I no longer can. | pool.loss.e10 | L1 | 認命 | 門等得比守夜久(w 22);而他其實剛加入等的行列 |
| 264 | 握不住燈了。誰在接? / I can't hold the lamp any longer. Who is taking it? | pool.loss.e11 | L1 | 脫力 | 接燈的是蒼白的手(§3.7);問句的答案就在身旁 |
| 265 | 風向西。替我帶一句到爐前。 / The wind runs west. Carry a word to the hearth for me. | pool.loss.e12 | L1 | 寄語家鄉 | 遺言傳回爐前的機制自述(§2.3)——這句正是如此傳回 |
| 266 | 不必立碑。醒來再走就是。 / Skip the monument. I'll wake and walk it again. | pool.loss.e13 | L1 | 復活信仰的灑脫 | 碑會立(就是他);醒來的另有其人——兩截皆錯而各有真核(議程 1 照過——L1 sign-off + drift,James 2026-08-16) |
| 267 | 爐前見。 / See you by the fire. | pool.loss.e14 | L1 | 再會之約 | 爐前確有人「見」——以為自己是他的那個(議程 1 照過——L1 sign-off + drift,James 2026-08-16) |
| 268 | 這次不算。 / This one doesn't count. | pool.loss.e15 | L1 | 不服輸 | 算到盡——隊伍加一,碑加一,帳上有名(議程 1 照過——L1 sign-off + drift,James 2026-08-16) |
| 269 | 面向東。記得面向東。 / Face east. Remember to face east. | pool.loss.e16 | L1 | 朝聖者的體面 | 他不自知地把自己立成合格的碑(面向東=面向門) |
| 270 | 門開那日,替我多行一步。 / When the door opens, walk one step of it for me. | pool.loss.e17 | L1 | 託付 | 字面應驗——門開那日整條隊行齊,他那一步有人行(§2.6) |
| 271 | 燈裏還有油。用不完了。 / There's oil left in the lamp. More than I'll be needing. | pool.loss.e18 | L1 | 輕描淡寫 | 器有餘而意志盡;燈油用不完=火先走了 |
| 272 | 行到第幾塊石?石記得,我不記得了。 / Which stone was I on? The stone remembers. I don't. | pool.loss.e19 | L1 | 迷糊 | 石記得(row 30)——隊伍反覆量過的路,石都記住 |
| 273 | 路未完。我完了。 / The road isn't finished. I am. | pool.loss.e20 | L1 | 認命對句 | 路未完——他那一段由隊伍接着行 |
| 274 | 灰在燈上又一層。這次不抹了。 / Ash on the lamp again. This time I won't wipe it. | pool.loss.e21 | L1 | 疲極小事 | 不抹了=最後一次選擇;灰將蓋過他的燈 |
| 275 | 未出樹林。第一段都未過。 / Still in the forest. Not even past the first stretch. | pool.loss.e22 | L1 | 出師未捷 | 他加入第一段最密的碑列(w21 同景) |
| 276 | 兩盞燈仍並亮。我這盞,誰來添油? / The paired lamps still burn. Who will oil mine? | pool.loss.e23 | L1 | 掛念路燈 | 他的燈自有人添——隊伍會經過;答案他看不到 |
| 277 | 根在灰下握着的,原來是這個。 / So this is what the roots were holding. | pool.loss.e24 | L1 | 臨終謎語 | 根握着行者燒剩的力氣;「這個」=他此刻燒盡的自己(#261 Q3) |
| 278 | 樹在長。我停了,它還在長。 / The trees keep growing. I stop; they don't. | pool.loss.e25 | L1 | 感嘆生生不息 | 樹靠他的灰長;他停下正是樹長的原因 |
| 279 | 面具白。灰白。我的手,也開始白。 / The masks are white. The ash is white. My hands are turning white now. | pool.loss.e26 | L1 | 失血蒼白 | 蒼白=耗剩意志之色(01);他正變成那種白——蒼白眾的白 |
| 280 | 靜。只剩燈芯的聲。 / Quiet. Only the wick still speaking. | pool.loss.e27 | L1 | 靜夜臨終 | 芯聲=火將盡;最後陪他的是器皿 |
| 281 | 出發時天未亮。原來一直都未亮。 / It wasn't light when I set out. It never grew light. | pool.loss.e28 | L1 | 命途嗟嘆 | 天未亮=破曉未到;對行者而言天從未亮過(勝敗同死,§3.7) |
| 282 | 還以為第一段容易。 / I thought the first stretch would be the easy one. | pool.loss.e29 | L1 | 輕率的悔 | 第一段淘汰最多;「容易」是爐前聽回來的想像 |
| 283 | 樹林之後,他們說有一座城。我看不到了。 / Past the forest, they say, there's a city. Not for me. | pool.loss.e30 | L1 | 未見之城 | 城=等的下場;他反而免了第二種拒絕 |
| 284 | 水到喉頭。就站在這裏,等它再上。 / Water at my throat. I'll stand here and let it rise. | pool.loss.e31 | L1 | 溺前的平靜 | 站着等水=以等待死於等待之城;act2 主題成為死法 |
| 285 | 城等了那麼久。多我一個。 / The city has waited so long. One more, then. | pool.loss.e32 | L1 | 自嘲 | 多一個等的——他站成碑,加入城的等 |
| 286 | 水下那口鐘,響過沒有? / That bell under the water — did it ever ring? | pool.loss.e33 | L1 | 臨終懸念 | 鐘未響過——門未開過;響那日全城的等才有下文 |
| 287 | 水下那點光,不是燈。 / That light down in the water is not a lamp. | pool.loss.e34 | L1 | 遺誡 | 假光=無意志的模仿;他以最後的力氣分辨真火 |
| 288 | 水中的人仍在走。原來,等是走不完的。 / The drowned are still walking. Waiting, it turns out, is a road without an end. | pool.loss.e35 | L1 | 悟語 | 水=等;等的路走不完——他正走進去 |
| 289 | 鐵有蝕,城有水。人有甚麼? / Iron has rust. The city has water. What do we have? | pool.loss.e36 | L1 | 排比自問 | 答案是等——城已示範;他此刻正有 |
| 290 | 燈在水上仍亮着,亮得比我久。 / The lamp still burns above the water. Longer than I will. | pool.loss.e37 | L1 | 燈比人久 | 器皿長命(row 159 同族);火會被接走,燈會被拾回 |
| 291 | 他們把等待寫了下來。我們的,誰來寫? / They wrote their waiting down. Who will write ours? | pool.loss.e38 | L1 | 求記錄 | 正被寫下——這句就是 Vigil 敗亡帳的帳文(A3 自述) |
| 292 | 潮退了,又漲。第幾次了? / The tide falls and rises. Which time is this? | pool.loss.e39 | L1 | 潮汐計時 | 第幾次=數不清的重複;隊伍與潮同律 |
| 293 | 這座城不出聲。今夜多一個不出聲的。 / The city makes no sound. Tonight there is one more who doesn't. | pool.loss.e40 | L1 | 死寂 | 他加入沉默的等待者;城的人口以靜默計 |
| 294 | 門就在前面。我聞到它的冷。 / The door is just ahead. I can smell its cold. | pool.loss.e41 | L1 | 咫尺之憾 | 門的冷=千年不開之物;近得可以加入王庭,而他沒有 |
| 295 | 不坐。他們坐,我不坐。 / I will not sit. Let them sit. Not me. | pool.loss.e42 | L1 | 傲骨 | 不坐而站——兩種停下,同一個停;以拒絕的姿勢完成拒絕 |
| 296 | 有光環斷了,不知是誰的。 / A halo broke somewhere. I don't know whose. | pool.loss.e43 | L1 | 異響 | 斷環=放棄之聲;又一個庭中人熄了光 |
| 297 | 星在看。看便看。 / The stars are watching. Let them watch. | pool.loss.e44 | L1 | 不屈 | 注視之眼看着每個停下的人;他不肯坐給他們看 |
| 298 | 王冠之後有甚麼,我到不了了。 / Whatever lies beyond the crown, I will not reach it. | pool.loss.e45 | L1 | 望門興嘆 | 王冠之後=封門(row 31);到不了的,由隊伍帶他到 |
| 299 | 黑曜裏有個我。它不動了。 / There I am in the obsidian. That one has already stopped moving. | pool.loss.e46 | L1 | 鏡影怪談 | 放棄的形狀先於死亡;鏡那側 motif(Silvered Mirror 族,L1) |
| 300 | 坐着的人望過來。我明白那個眼神了。 / The seated ones are looking at me. I understand that look now. | pool.loss.e47 | L1 | 讀懂目光 | 眼神=認出「又一個」;他此刻嘗到停的滋味 |
| 301 | 庭中無火。我的熄了,便真的無火了。 / No fire in this court. When mine goes, there will be none at all. | pool.loss.e48 | L1 | 荒涼 | 他的火是全庭唯一意志;熄了=王庭回復無火常態 |
| 302 | 就在門前。原來門前也是路。 / At the very door. So even the doorstep is still road. | pool.loss.e49 | L1 | 就差一步 | 門前也是路——門後仍是路(Act IV);他的碑立在隊頭 |
| 303 | 油盡了。火去了甚麼地方? / The oil is spent. Where has the fire gone? | pool.loss.e50 | L1 | 臨終之問 | 火=意志歸於蒼白之手(§3.7);答案:向西,回爐 |

## `[REWRITE:climb]` 清單狀態 — 已關閉

全量掃描由 #232 的十四-agent 量度完成,記錄於
[#301 的掃描 comment](https://github.com/fol2/glassvow/issues/301#issuecomment-5304721761)
(2026-08-15)。content.* 側 Tier A 句已全數入賬:quest/whisper 句在
Batch 1 區(rows 32–82)重寫或保留;scene/finale 側歸 #263/#309;音軌名同
batch 檔「一語三址」節。

**ui.\* 側已於 #303 全數落地**(rows 119–133 + rows 26–31 的簽定名):
chrome 與 prose 一併掃,因為 #228 是**讀稿質檢**,不是詞彙掃除,把十一句
尖塔留到那時等於讓禁詞繼續出貨。#228 仍讀這些行的語氣與 calque。
禁令自此由 `tests/test_locale.gd` 的 `_retired_vertical_vocabulary` 機檢,
allowlist 逐條具名(已注入 mutation 驗證可以紅)。
原 [TODO] 於 Batch 1(#301)開稿時關閉。
