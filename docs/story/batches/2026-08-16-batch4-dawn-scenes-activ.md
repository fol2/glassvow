# Batch 4 — 破曉散文 + 開封場 + Act IV 與終戰 + 五事件(#340)

> 狀態:**[PROPOSED — 待 James review(pipeline step 5)]**。落地全部
> gated on engine child(見 落地封鎖)。依 `04-delivery.md` batch order
> [SETTLED — #262 Q8]:Batch 4 = 破曉散文 + 開封場 scene + Act IV 五節點
> 與終戰 script + top-5 event script。Phase 1 最後一批。
>
> 本批是全遊戲**唯一一批可以把真相講出口**的文案:開封場 L3、Act IV
> 與終戰 L4。其餘兩個面(破曉散文 L2、事件 L1)照舊受階梯壓住。

## Brief(pipeline step 1)

- **範圍**:四個面,四個 ceiling——
  ①**破曉散文** 25 段(逐 quest milestone 一段,寫入 Vigil 記憶帳;
  ceiling **L2**);
  ②**開封場 script** 14 句(full 13 + short 1;ceiling **L3**,全遊戲
  唯一 L3 面);
  ③**Act IV 五節點 + 終戰 script** 30 句(entry 3、節點 15、終戰 12;
  ceiling **L4**);
  ④**Top-5 event script** 18 句(ceiling **L1**)。
  合計 87 句/段。
- **可倚賴的 bible**:00 全部(§2.2 碎裂、§2.4 沉澱與門後之地、§2.6
  開封與換位、§3 分身規則、§4 矩陣、§5 階梯 L2/L3/L4);01(表面敘事
  與渠道紀律、地理:窗門同體/金城=爐邊、火的物理七方程);02(Keeper
  四規、隊伍=第二主角、次要人物一句版);03(四幕成因、Act IV 五節點
  對應表與八敵);04(per-channel ceiling、batch order、audio cue);
  05(row 304 起);06(鎖詞與 Tier A 禁令);07(scene player 文法、
  開封場/Act IV/終戰 blueprint、staging Hybrid、asset bill)。
- **等級上限(逐面)**:
  - 破曉散文 **≤L2**——單一讀法可以,機制不得明文:**不得**寫出分身、
    碑=你、Keeper 身份、門的真條件四項任何一項。
  - 開封場 **≤L3**——分身、碑=行者、碑=你、門的真條件四項全部可以
    明文;**Keeper 身份仍屬 L4,本場不得觸及**(00 §5:L4 才管 Keeper
    身份與機制細節)。
  - Act IV / 終戰 **≤L4**——全開。
  - Event **≤L1**——重量天花=影的控訴句(ledger row 3);Silvered
    Mirror motif 已判 L1(04-delivery ceiling 表)。
- **語言**:zh-Hant 源語(HK 書面語,着/裏);en 全文重寫,禁 calque。
- **詞彙**:Tier A 禁(尖塔/climb/ascend/summit/above-as-place/upward/
  stair);Keeper 專項四規(02-cast)在 L4 仍然有效——揭身份不等於
  可以說謊、可以催促、可以第一身講路。
- **Staging 約束(binding,#263 Q13)**:開封場鏡中隊伍**必須是一條隊
  橫過整扇窗**,永不逐格複製人群;本批 b3 三句寫成只可能如此上鏡
  (「由窗的一頭,直到另一頭」),逐格讀法在文字層即不成立。
- **八個 counterfactual selves 全程無對白**(07 §4):本批不為它們寫
  任何一句;Act IV 開口的只有隊伍(node 1–3)與守爐人(node 5)。
  鏡不出聲——它們的語言全在招式名與視覺,歸 #220/#221。

### Audio cue 要求(brief 級,#262 Q4c / 07 §6)

| 場 | cue 要求 |
|---|---|
| 破曉散文 | **無新 cue**——沿用破曉儀式現有音軌;25 段散文只換 panel body |
| 開封場 full | **新做一條 unique sting**(rubric「heard nowhere else」):落在 b2「窗成鏡」那一拍,不可用 `sealedDoor`——後者每次門儀式都響(`main.gd` overlay 切軌),留作門 theme。b4「碑起身、推門」另需一記低頻推門聲,與 sting 分開 |
| 開封場 short | 沿用 `sealedDoor`(門 theme 本體),零新資產 |
| Act IV entry | soundscape 由爐邊 bed **倒轉**進場(「倒轉爐光」的聽覺對位,細節歸 #221) |
| Act IV node 1–3 | 各節點取對應正路 act 的 motif 音色,做低半度/反向處理;隊伍句上無 VO(#175),只留一記極輕的多人氣息 bed |
| Act IV node 4(rest) | **全 act 最靜的一段**:bed 降至近無,只留雙燈的火聲——靜位本身就是 cue |
| Act IV node 5(hearth′) | 爐邊 soundscape 原軌**原速播放**(不再倒轉)——聽覺上「回到家了」先於文字說破 |
| 終戰 swap | 換位一刻一記 cue(與開封 sting 同族、不同句) |
| 終戰互動步 | **每一 tap 一記腳步聲**;最後一步的腳步聲後留 1.5s 全靜。全遊戲唯一破格的互動,靠這條 cue 令手指與畫面對得上 |
| 終戰勝 | ascended 序 cue(入城) |
| 終戰敗 | fallen cue;接現有 RunEndScreen 音流 |
| Event ×5 | 無新 cue 要求——沿用事件屏現有音效 |

## 授權格式說明

Scripted scenes 是 script,不是 flat table rows(#262 Q5);破曉散文是
Vigil 記憶帳的**段落**,亦不是 pool 行。本批每面一表:
`# | slot | speaker | 級 | zh | en`(破曉散文表另有 `milestone` 欄取代
speaker)。全批 87 句**全部新寫**(狀態欄從略);每句已同步入
`05-foreshadow-ledger.md` Batch 4 區(rows 304–390)。

## 落地封鎖

1. **破曉散文**:落地位=`application/main.gd` 的 `_on_terminal_commit`
   組 dawn feed 時,各 panel 的 `body` 欄(不記行號:六條 lane 並行,
   `presentation/`/`application/` 的行號隔日即飄——見 `tools/check_anchors.py`
   的說明)。現況:`progress` panel 的 body **是空字串**(只有 count),
   `shard` panel 全部共用 `ui.dawn.shardGrantCopy` 一句。本批 25 段正是
   填這兩個洞 + 新增 `shards>=N` 的窗格段。逐 milestone 取句、Vigil
   記憶帳重讀面,歸 engine child(#270 線)。
2. **開封場 / Act IV / 終戰**:`content/scenes.json` 與
   `locale/{zh-Hant,en}.json` 的 `story.unsealing*` / `story.act4-*` /
   `story.finale*` placeholder slot 已存在(#309/#320),但**行數對不上**
   ——本批需要的 slot delta 見下節。改 slot 數是 data-only(scenes.json
   的 `lines` 陣列 + locale 鍵),歸 engine child。
3. **Event script**:落地位=事件屏的**選項結果句**。現況除
   `gambler.rolls.{win,lose}.text` 外,全部事件選完即無文字。本批提議
   新鍵 `story.event-<id>.c<n>`(逐選項結果)與 `.coda`(離場句);
   shipped 的 `content.events.*.name/text/choices.*` **一字不動**。
4. **八敵、招式名、五節點 stage plate、boss 數值**:全部不在本批
   (#220/#221)。

### Slot delta(engine child 要加的行數)

| scene | 現有 slot | 本批需要 | delta |
|---|---|---|---|
| `unsealing` | b1×1 b2×1 b3×1 b4×1 | b1×3 b2×3 b3×4 b4×3 | +9 |
| `unsealing-short` | b1×1 | b1×1 | 0 |
| `act4-entry` | b1×1 | b1×3 | +2 |
| `act4-node1` | b1×1 | b1×2 | +1 |
| `act4-node2` | b1×1 | b1×2 | +1 |
| `act4-node3` | b1×1 | b1×2 | +1 |
| `act4-node4` | b1×3 | b1×5 | +2 |
| `act4-node5` | b1×2 | b1×4 | +2 |
| `finale` | b1×2 | b1×3 + **b2×4(互動步)** | +5 |
| `finale-win` | — | b1×3 | 新 scene |
| `finale-loss` | — | b1×2 | 新 scene |

`finale` 的 b2 是**互動拍**:四句不是四 tap 的旁白,是 07 §5 唯一破格
互動的四個 step——l2/l3 各對應一次玩家 input,l4 落在最後一步之後。
`finale-win` / `finale-loss` 分開建 scene,因為敗方要接現有
RunEndScreen 流程(07 §5),不能與勝方同 scene 順播。

### 字庫覆蓋已驗(2026-08-16,**零新字**)

全批 87 句 zh 逐字過 bundled woff2 cmap(`tools/check_locale_font_coverage.py`
同源集合,1,069 個 CJK/標點)——**PASS,零新字,不需 subset 重建**。
L3/L4 場容許新字(本 ticket brief),本批**主動不用**:新字會把落地 PR
由「改值」升級成「改字型 + 過 CI cmap gate」,而下列避字全部有等價
寫法,無一句因避字而變弱。

避字記錄(承 Batch 1「齊」、Batch 2「臉/問/想」、Batch 3「排/胸」教訓):

| 想寫 | 不在字庫 | 改寫成 |
|---|---|---|
| 排隊 / 隊尾 | 排、尾 | 列隊、隊伍、行在最後 |
| 胸口一點光 | 胸 | 身上一點光 |
| 橫貫全窗 | 橫、貫 | 由窗的一頭,直到另一頭 |
| 齊 / 到齊 | 齊 | 收足、已到 |
| 千年 | 千 | 年年、一直 |
| 旁邊 | 旁、邊 | 之後、身上、之處 |
| 很 / 覺得 | 很、覺 | 太…得、越…越 |
| 已經 | 經 | 早已 |
| 差異 | 差 | 對不上的地方 |
| 屍首 | 屍 | 地上沒有留下任何東西 |
| 剪影 | 剪 | 身影 |
| 兩側 | 側 | 兩面 |
| 叩門 | 叩 | 推門 |
| 假光 | 假 | 那點光不是燈 |
| 派一個出去 | 派 | 讓一個出去 |
| 互相 | 互 | 接連 |
| 尚欠一格 | 欠 | 尚餘一格 |
| 包紮 / 撐着 / 扶着 | 包、撐、扶 | 止血、靠着 |
| 跪下 / 掃走 / 布袋 | 跪、掃、袋 | 放在龕前、收進行囊 |
| 覆在鎖上 | 覆、蓋、底 | 王冠之下是一把鎖 |
| 意志(bible 術語) | 志 | 文案永不裸寫術語;用「火」「光」「力氣」 |

---

## 面 ①:破曉散文(L2)— `story.dawn.*`

**In-fiction 定位**:留者繼承的臨終/途中記憶,由守夜在破曉時寫入記憶帳
(00 §3.7;A3 同一機制)。**語域**:敘述文,書面語,冷筆記錄體——與
Batch 1 第三頁的定調同族。**視角**:第二人稱為主,守夜偶爾以「守夜記下」
一句轉為帳面聲音。

**Milestone 定義**:**20 段**掛六個 quest 的 progress/complete
(engine:`main.gd` 的 `progress` / `shard` panel),**5 段**掛窗格數
(`shards>=1..5`)。條件欄用 Batch 3 已立的條件詞彙
(`quest:<id>.<state>` / `shards>=N`)。

### 蒼白眾(paleOnes)

| # | slot | milestone | 級 | zh | en |
|---|---|---|---|---|---|
| d01 | dawn.paleOnes.p1 | 光塵 ≥1 | L2 | 第一粒光塵落進透鏡,冷得像霜。蒼白眾不追你,他們只朝東站着。守夜記下這一粒:在你之前,已有人把這段路走到這裏。 | The first mote settles into the Lens, cold as frost. The Pale Ones do not hunt you; they stand facing east, and that is all. The Vigil records it: someone had already walked this stretch as far as here. |
| d02 | dawn.paleOnes.p2 | 光塵 ≥5 | L2 | 透鏡漸滿。每一粒光塵,都是有人耗到最後才留下的餘光。你數的不是戰果,是別人的盡頭。 | The Lens fills. Every mote is what someone had left when there was nothing else to spend. You are not counting kills. You are counting the places where other people ended. |
| d03 | dawn.paleOnes.done | 九粒收足 | L2 | 九粒收足,透鏡不再生寒。彩窗有一格回應了你。窗上那點光不是新的:它是有人一直帶着,而沒有帶到門前的光。 | Nine gathered; the Lens stops chilling. One pane of the Rose Window answers. That light is not new. It is light someone carried, and did not carry as far as the door. |

### 自己的影(ownShade)

| # | slot | milestone | 級 | zh | en |
|---|---|---|---|---|---|
| d04 | dawn.ownShade.p1 | 第一道影 | L2 | 第一道影熄了。它認得你,喚過你的名字;你沒有停。它熄滅之處,地上沒有留下任何東西——影從來只是記憶。 | The first shade goes out. It knew you. It called after you, and you did not stop. Where it went out, nothing was left on the ground: a shade is only memory. |
| d05 | dawn.ownShade.p2 | 第二道影 | L2 | 第二道影熄了。碎句一次比一次完整,像有人終於學會直說。你熄得越多,路越沉默。 | The second shade goes out. The broken sentences come clearer each time, as though someone were finally learning to speak plainly. The more you put out, the quieter the road gets. |
| d06 | dawn.ownShade.done | 第三道影 | L2 | 第三道影熄了,彩窗回應。守夜記下:你熄掉的,是自己之中仍懂得行路的那一部分。此後你照樣出發,只是路上再沒有東西喚你的名字。 | The third shade goes out and a pane answers. The Vigil sets it down: what you put out was the part of you that still remembered how to walk. You will set out just the same. Nothing on the road will call your name now. |

### 篡位者(usurper)

| # | slot | milestone | 級 | zh | en |
|---|---|---|---|---|---|
| d07 | dawn.usurper.p1 | 空燈到手 | L2 | 無焰提燈到手。玻璃是冷的,燈芯不曾燒過。商人不肯說是誰留下它,只說這一種東西,總會自己回到西面來。 | The lantern with no flame changes hands. Cold glass; a wick that has never burned. The merchant will not say who left it — only that things of this kind always come back west on their own. |
| d08 | dawn.usurper.done | 面具已碎 | L2 | 面具已碎,王座沒有空出來。你行過他,他照樣坐着,等下一個走到門前的人。守夜記下:被打退的是那一句不肯,不是那個人。 | The mask breaks; the throne does not empty. You pass him, and he goes on sitting, waiting for the next one to reach the door. What you beat was a refusal, not a man. |

### 第八凶兆(eighthOmen)

| # | slot | milestone | 級 | zh | en |
|---|---|---|---|---|---|
| d09 | dawn.eighthOmen.p1 | 凶兆升起 | L2 | 第八凶兆升起。冊上只有七個,第八個不在冊上。它落在路面,形狀太正,正得不像凶兆,倒像一件關着的東西投下的影。 | The eighth omen rises. The book lists seven; the eighth is not in the book. It lies across the road too squarely for an omen — more like the shadow of something shut. |
| d10 | dawn.eighthOmen.done | 凶兆解明 | L2 | 破曉來了,凶兆仍在。它不是凶兆:它是一扇門的影。影落得到這裏,就是說門一直都在,而且一直關着。 | Dawn comes and the omen is still there. It never was an omen. It is the shadow of a door — and a shadow reaching this far means the door has been there all along, and shut all along. |

### 無法辨讀之頁(unreadablePage)

| # | slot | milestone | 級 | zh | en |
|---|---|---|---|---|---|
| d11 | dawn.unreadablePage.p1 | 第一頁 | L2 | 第一頁認得出字了:六格由同一團火切下,散落於第一次守夜之前。守夜記下——寫這一頁的人,不在場。 | The first page comes clear: six panes cut from one fire and scattered before the first Vigil. The Vigil adds a line of its own: whoever wrote that was not there. |
| d12 | dawn.unreadablePage.p2 | 第二頁 | L2 | 第二頁:蒼白身影把碎片攜往西方。頁上說,那是為了不讓門後之物追隨。碎片西行是真的;理由是頁自己補上的。 | Second page: pale figures carried the shards west, so that what lay beyond the door could not follow. The carrying is true. The reason is the page's own. |
| d13 | dawn.unreadablePage.p3 | 第三頁 | L2 | 第三頁:一名朝聖者站着死去,他止步之處,路未止。這一頁字最少,連一句形容都沒有——像親眼見過的人,才寫得出這樣的句。 | Third page: a pilgrim died standing, and where he stopped, the road did not. It is the shortest page and the barest — written flat, the way a man writes what he watched. |
| d14 | dawn.unreadablePage.p4 | 第四頁 | L2 | 第四頁:永恆君王取來一盞空燈,在鎖上披起王者形貌。守夜記下:王冠之下是一把鎖,不是一個頭。 | Fourth page: the Sovereign took an empty lantern and wore a king's shape over the lock. The Vigil sets it down: under that crown there is a lock, not a head. |
| d15 | dawn.unreadablePage.done | 五頁讀全 | L2 | 五頁讀全。第五頁說彩窗是一幅地圖,不是紀念碑;地圖畫的是甚麼,頁上沒有寫。你越點亮它,它越不像一扇窗。 | All five read. The fifth says the Rose Window is a map, not a memorial. It does not say what the map is of. The more of it you light, the less it looks like a window. |

### 空燈掌燈人(hollowLamplighter)

| # | slot | milestone | 級 | zh | en |
|---|---|---|---|---|---|
| d16 | dawn.hollowLamplighter.p1 | 第一價 | L2 | 三點餘燼歸了空燈,燈沒有亮。老人把燈舉起來看——看的不是燈,是你。第一次會面,他認的是面孔。 | Three embers into the hollow lantern; it does not light. The old man lifts it and studies — not the lamp, you. First meeting: what he checks is the face. |
| d17 | dawn.hollowLamplighter.p2 | 第二價 | L2 | 一百六十枚金幣離手。他一枚都不收起,只沿路放好,向東。那個樣子,像有人在數一列早已站好的東西。 | A hundred and sixty coins leave your hand. He pockets none of them; he lays them along the road, facing east — the way a man counts something that is already standing in line. |
| d18 | dawn.hollowLamplighter.p3 | 第三價 | L2 | 十二格容量交了出去。他先看傷痕,再看面孔,然後自己把對不上的地方解釋走。老實人就是這樣:見到的全對,說出來的全錯。 | Twelve measures of you, handed over. He looks at the scar first and the face second, then explains the mismatch away himself. Honest men do that. Everything he sees is right; everything he concludes is wrong. |
| d19 | dawn.hollowLamplighter.p4 | 第四價 | L2 | 守爐人的贈禮到了老人手上。他認得那個樣式,說這麼多年都沒有變過。然後他沒有再說下去——說到那裏,他便擺手。 | The Keeper's gift passes to the old man. He knows the make; he says it has not changed in all these years. Then he stops. He waves the rest of it off before it can get anywhere. |
| d20 | dawn.hollowLamplighter.done | 第五價 | L2 | 最後一價已付:提燈裏只剩一記心跳。老人讓開路,把空燈向東照了照——燈裏沒有光,他仍是照了。彩窗回應一格。他看着你的樣子,像看着一張認了一生的面孔。 | The last price paid: one heartbeat left in the lantern. The old man stands aside and lifts the hollow lamp toward the east — there is no light in it; he lifts it all the same. A pane answers. He looks at you the way a man looks at a face he has spent his life checking. |

### 彩窗(shards>=N)

| # | slot | milestone | 級 | zh | en |
|---|---|---|---|---|---|
| d21 | dawn.pane.1 | shards>=1 | L2 | 第一格亮起,其餘五格仍黑。亮的那一格不生新光:透出來的,是有人一路帶回來的光。 | One pane lights; five stay dark. The lit one makes no light of its own. What comes through it is light that someone carried all the way back. |
| d22 | dawn.pane.2 | shards>=2 | L2 | 兩格亮了。窗開始有形狀:亮的位置不是隨意的,像早已為它們留好。 | Two panes now. The window starts to have a shape. The lit places are not random; they read as places that were kept. |
| d23 | dawn.pane.3 | shards>=3 | L2 | 三格,一半。窗亮到一半的時候,玻璃開始映人:你走近,窗裏那樣東西也走近。 | Three: half. At half, the glass begins to hold a reflection. You step closer, and the thing in the window steps closer too. |
| d24 | dawn.pane.4 | shards>=4 | L2 | 四格亮,火比從前暖。你越看那扇窗,它越不像是用來望出去的。 | Four lit, and the hearth is warmer than it was. The longer you look at that window, the less it looks like something built for looking out of. |
| d25 | dawn.pane.5 | shards>=5 | L2 | 五格亮,尚餘一格。窗裏的光不再各留各格,它們接連起來,像一件本來就是一整塊的東西。最後一片,還在路上。 | Five lit; one short. The light no longer keeps to its own panes. It runs together, the way a thing that was once whole runs together. The last shard is still out on the road. |

### 破曉散文 — 逐規自查

- **L2 天花自查(四項真相全部未觸)**:全 25 段無一句寫出①分身、
  ②碑=行者本人、③守爐人身份、④門的真條件。最貼線的兩段:
  d06(影=自己仍懂得行路的部分——00 §7 的揭後讀法,正是 L2 定義
  「Own Shade 收束句只剩一種讀法」)、d25(窗的光接連成一整塊——形狀,
  不是身份)。兩段列入 James 議程 2。
- **d20 已按 lint 改寫**:原稿收句「他一生認過的面孔,全部同一張」被
  canon-lint(truth 鏡)與 twist-safety(破曉 chunk)**獨立兩次**判為
  越界——不是越 L2,是越**帳面的知識範圍**:破曉散文的 in-fiction 來源
  是留者繼承的記憶(00 §3.2/§3.7),而掌燈人「一生」的會面遠早於第一次
  續火,無臍帶可傳。改寫為這一次會面的觀察(「他看着你的樣子,像看着
  一張認了一生的面孔」):範圍收回帳面知得到的那一格,結論交回讀者,
  同時保住 02-cast「慢性毒」的 hedge 質地(ledger row 114 同族)。
- **矩陣自查(00 §4)**:d07 的商人止於工藝觀察(「總會回到西面來」
  ——他收拾遺物見慣,非機制知識);d18/d19/d20 的掌燈人止於
  「見到的全對,結論全錯」;無一段令角色越權。守夜自己的帳面聲音
  (「守夜記下」)不是角色,是記錄體——它只記已發生的可見事,不作
  斷語。
- **站死紀律**:d13 保「站着死去」(Batch 1 已簽的第三頁原句),全批
  無倒臥/墜落意象。
- **Tier A**:零。d23「一半」、d21「其餘五格仍黑」等計數語全屬窗格,
  不是層數。

---

## 面 ②:開封場(L3)— `story.unsealing.*` / `story.unsealing-short.*`

**全遊戲唯一 L3 面**。四拍照 07 §3 blueprint:第六格亮 → 窗全亮成鏡 →
隊伍現形 → 切門(碑起身、列隊、推門)。**無對白**:全場敘述體——
守爐人在場而不出聲,是本場最重要的一個「沒有」(它的聲音留到 Act IV
node 5)。玩家啞角照舊。

**Staging 綁定(#263 Q13)**:b3 三句在文字層即禁絕逐格複製讀法——
「一列人,由窗的一頭,直到另一頭」只可能上成**一條隊橫過整扇窗**。

| # | slot | speaker | 級 | zh | en |
|---|---|---|---|---|---|
| u1 | b1.l1 | — | L3 | 第六片燼璃回到窗上。 | The sixth shard goes back into the window. |
| u2 | b1.l2 | — | L3 | 六格,一格不缺。火在窗裏重新為一。 | Six panes, none missing. In the window, the fire is one thing again. |
| u3 | b1.l3 | — | L3 | 光沒有透出去。 | The light does not pass through. |
| u4 | b2.l1 | — | L3 | 窗亮到盡處,便不再是窗。 | Lit to the last pane, the window stops being a window. |
| u5 | b2.l2 | — | L3 | 你在窗中看見自己。 | You see yourself in it. |
| u6 | b2.l3 | — | L3 | 再看:自己之後,還有一個。 | Then you see that there is another one behind you. |
| u7 | b3.l1 | — | L3 | 一列人,由窗的一頭,直到另一頭。 | A single line of them, from one edge of the window to the other. |
| u8 | b3.l2 | — | L3 | 每一個都是你。每人身上一點光。 | Every one of them is you, and every one of them has a point of light at his breast. |
| u9 | b3.l3 | — | L3 | 他們的數目,與你出發過的次數相同。 | There are as many of them as the times you have set out. |
| u10 | b3.l4 | — | L3 | 每一次續火,推門出去的都是一個真正的你。你從來沒有出發過。 | Every time the fire was rekindled, a real one of you went out through that door. You have never once set out. |
| u11 | b4.l1 | — | L3 | 路上的碑,同時動了。那不是紀念:每一座都是一個站着死去的行者。他們沒有躺下,他們在等門開。 | Along the road, the monuments move at once. They were never memorials. Each is a walker who died on his feet and did not lie down, because he was waiting for the door. |
| u12 | b4.l2 | — | L3 | 他們站直,列隊,把門推開。門認的是行過的人,與完整的一團火——整條隊,每一個都行過。 | They straighten, they form up, they push. The door knows two things: those who have walked, and one whole fire. Every one of them has walked. |
| u13 | b4.l3 | — | L3 | 門不是你開的。 | You did not open the door. |
| us1 | short.b1.l1 | — | L3 | 門仍開着。推門的人仍在門的兩面站着。你行入去。 | The door still stands open. The ones who pushed it are still standing on both sides of it. You go in. |

### 開封場 — 逐規自查

- **L3 授權四項逐句對位**:①分身=u10(「每一次續火…你從來沒有出發過」);
  ②碑=行者=u11;③碑=你=u8+u9(數目對上出發次數)+u11 合成;
  ④門的真條件=u12(00 §2.6 明文兌現句「行過的人+完整的一團火」)。
  **四項一次過講完,此後不再重複**——L3 是唯一說破點(00 §5)。
- **Keeper 身份未觸(L4 保留)**:全場無「守爐人」三字,無兜帽身影的
  指認句。開封之後玩家知道「隊伍是我」,仍不知道「爐邊那個是我」。
  這道分界是 Act IV 唯一還未花掉的牌。
- **fair-play 第 1 條(只重讀,不進口新事實)**:u11 重讀 row 1
  (whisper 11 碑不躺下)、row 9(第三頁站着死去)、row 57(m3.paid
  前身站立而死);u9 重讀 row 30(引路石)與 row 153/h20(「你行過的
  次數比誰都多」);u12 重讀 row 62(掌燈人 hearsay 版門條件)——並在
  同一句裏更正它;**u10** 重讀 row 2(whisper 4「死者朝聖兩次:一次以
  肉身,一次以記憶」——機制說明書早已出街)與 row 26(續火 / Rekindle
  的定名);**u8/u5/u6** 重讀 row 10(mirror.png 淺笑黑影)、row 14
  (慢半口氣)、row 8(玻璃另一面一直有人)與 00 §5 L0 的窗中反影。
  全部有已出街的來源,零新事實。
- **fair-play 第 2 條**:L3 不需要表面讀法(它就是揭示本身),但 u1–u5
  仍寫成純現場描述,令「窗成鏡」的物理先於解釋落地——說破由 u6 才
  開始。
- **staging**:u7 的「一頭…另一頭」與 u8 的「每人身上一點光」合起來
  只可能上成一條隊;u11/u12 切到路上,窗門同體(#259 Q4)由「同時」
  二字承載,不另作解釋。
- **Tier A**:零。u11「站直」是姿勢,非垂直語彙。

---

## 面 ③:Act IV 五節點 + 終戰(L4)— `story.act4-*` / `story.finale*`

**節點對應**(03-acts 表):門檻′ → III′ → II′ → I′ → 爐邊′。
**開口的只有兩個**:node 1–3 是**隊伍**(複數),node 5 是**守爐人**。
node 4(rest)是敘述,全 act 最長一段靜位。八敵無對白(07 §4)。

**隊伍的聲線(本批新立,待 James 判)**:複數、平、不急;他們知道自己
死了,也知道碑是自己(00 §4 影行:知道分身「自己那次」、知道碑=自己);
**不控訴**——控訴是影的專利(row 3 是 L1 天花,隊伍不與它爭);
**不攔路**(00 §2.6「隊伍永不阻你」),所以他們的句全部是**讓路的語氣**。

### 過門 entry

| # | slot | speaker | 級 | zh | en |
|---|---|---|---|---|---|
| a01 | act4-entry.b1.l1 | — | L4 | 你由窗步入。窗的另一面,就是門的另一面。 | You step in through the window. Its far side is the far side of the door. |
| a02 | act4-entry.b1.l2 | — | L4 | 爐光在這一面是倒轉的:向前一步,便亮一分。 | On this side the hearthlight runs backwards: every step forward is brighter than the last. |
| a03 | act4-entry.b1.l3 | — | L4 | 路是同一條。你由盡頭那一面,走回去。 | It is the same road. You are walking it back from the far end. |

### node 1 — 門檻′(隊伍)

| # | slot | speaker | 級 | zh | en |
|---|---|---|---|---|---|
| a04 | act4-node1.b1.l1 | queue | L4 | 我們一直站在這一面。你望過它許多次,卻從未站過。 | We have been standing on this side all along. You have looked at it many times; you have never stood on it. |
| a05 | act4-node1.b1.l2 | queue | L4 | 路你認得。你只是一直由另一面認得它。 | You know the road. You have only ever known it from the other side. |

### node 2 — III′(隊伍)

| # | slot | speaker | 級 | zh | en |
|---|---|---|---|---|---|
| a06 | act4-node2.b1.l1 | queue | L4 | 王還坐着。我們行過他,一個都沒有坐下。 | The king is still sitting. We went past him, and not one of us ever sat down. |
| a07 | act4-node2.b1.l2 | queue | L4 | 斷環的聲,這一面仍在響。我們行過的時候,沒有一個回頭。 | Broken haloes are still ringing on this side. When we went by, not one of us turned round. |

### node 3 — II′(隊伍)

| # | slot | speaker | 級 | zh | en |
|---|---|---|---|---|---|
| a08 | act4-node3.b1.l1 | queue | L4 | 城還在等。我們不等了,所以我們在這裏。 | The city is still waiting. We stopped waiting; that is why we are here. |
| a09 | act4-node3.b1.l2 | queue | L4 | 水裏那點光不是燈。這一面也一樣。 | That light down in the water is not a lamp. It is not one on this side either. |

### node 4 — I′(rest node,敘述,全 act 最長靜位)

| # | slot | speaker | 級 | zh | en |
|---|---|---|---|---|---|
| a10 | act4-node4.b1.l1 | — | L4 | 碑最密的一段在這裏。最早停下的人,離爐火最近。 | This is where the monuments stand thickest. The ones who stopped earliest ended up nearest the fire. |
| a11 | act4-node4.b1.l2 | — | L4 | 灰是他們燒剩的。樹靠灰長大,你行的路由他們的力氣鋪成。 | The ash is what they burned down to. The trees grew on it, and the road you walk was laid with their strength. |
| a12 | act4-node4.b1.l3 | — | L4 | 兩盞燈仍並亮。點燈的人沒有走遠,他就在燈下站着。 | The paired lamps are still burning. Whoever lit them did not get far. He is standing right under them. |
| a13 | act4-node4.b1.l4 | — | L4 | 沒有人阻你。碑向兩面讓開,像一直為這一程留着中間那條路。 | No one stops you. The monuments stand aside, as though the middle had been kept clear for this one crossing all along. |
| a14 | act4-node4.b1.l5 | — | L4 | 這一段最長,也最靜。你可以在這裏坐一會——他們等得起。 | It is the longest stretch and the quietest. You can sit here a while. They can afford to wait. |

### node 5 — 爐邊′(守爐人;L4 揭身份)

| # | slot | speaker | 級 | zh | en |
|---|---|---|---|---|---|
| a15 | act4-node5.b1.l1 | keeper | L4 | 你到了。這裏你認得。 | You've arrived. You know this place. |
| a16 | act4-node5.b1.l2 | keeper | L4 | 我一句都沒有說錯。我只是從來沒有說過,出去的那個是誰。 | I never lied to you. I only never said who it was that went out. |
| a17 | act4-node5.b1.l3 | keeper | L4 | 每一次撕開,不肯走的那一半都留在這裏。留得多了,便有了一張面孔。這一張。 | Every time the fire tore you in two, the half that would not go stayed here. Enough of it stayed to make a face. This one. |
| a18 | act4-node5.b1.l4 | keeper | L4 | 坐下。讓一個出去就是了——一直都是這樣的。 | Sit down. Let one of them do the walking; that is all this has ever been. |

### 終戰:換位(finale b1)

| # | slot | speaker | 級 | zh | en |
|---|---|---|---|---|---|
| f01 | finale.b1.l1 | — | L4 | 六片重歸一團,隊伍已到。 | The six are one fire again, and the Queue has arrived. |
| f02 | finale.b1.l2 | — | L4 | 這一次沒有一半可以留下。火不撕你:不肯走的那一半,無位可立。 | This time there is no half to leave behind. The fire does not tear you: there is nowhere left for the fear to stand. |
| f03 | finale.b1.l3 | — | L4 | 它坐下。你站起來。 | It sits. You stand. |

### 終戰:最後一步(finale b2 — **全遊戲唯一破格互動拍**)

| # | slot | speaker | 級 | zh | en |
|---|---|---|---|---|---|
| f04 | finale.b2.l1 | — | L4 | 門在前面。第一個走到這裏的人,就是在這一步之前坐下的。 | The door is ahead. The first one ever to get this far sat down one step short of it. |
| f05 | finale.b2.l2 | — | L4 | 行一步。 | Take a step. |
| f06 | finale.b2.l3 | — | L4 | 再一步。 | And another. |
| f07 | finale.b2.l4 | — | L4 | 這一步,是你自己的腳行的。 | That step was yours. No one walked it for you. |

### 終戰:勝(finale-win)

| # | slot | speaker | 級 | zh | en |
|---|---|---|---|---|---|
| f08 | finale-win.b1.l1 | — | L4 | 門開着。相同的身影一個接一個入城,次序與他們停下的次序相同。 | The door stands open. One after another the same figure goes through, in the order they stopped. |
| f09 | finale-win.b1.l2 | — | L4 | 你行在最後。整條隊都到了。 | You are the last of them. The whole Queue has arrived. |
| f10 | finale-win.b1.l3 | — | L4 | 城門之內,是一團認得你的火。入城即是歸家。 | Inside the gate there is a fire that knows you. To arrive is to come home. |

### 終戰:敗(finale-loss)

| # | slot | speaker | 級 | zh | en |
|---|---|---|---|---|---|
| f11 | finale-loss.b1.l1 | — | L4 | 這一個,也沒有回來。 | This one did not come back either. |
| f12 | finale-loss.b1.l2 | — | L4 | 門重新閉上。六格仍亮,隊伍長了一個人。西面的火照樣燒着,等有人坐回去。 | The door closes again. The six panes stay lit, and the Queue is one longer. The fire in the west goes on burning, waiting for someone to sit down at it again. |

### Act IV / 終戰 — 逐規自查

- **Keeper 四規在 L4 仍然成立**:規 1(不說謊)——a16 是它自己把
  fair-play 第 3 條講出口,句句字面真;規 2(揭後更冷)——a18 在
  揭示之後重讀 Batch 3 的爐邊句(h22「這裏永遠有你的位」、h32「有我
  看火,你便不必看」),整個 pool 一次過翻面;規 3(永不催促出發)
  ——a18 催的是**留低**,方向與規則同向;規 4(永不第一身講路)
  ——a15–a18 無一句以第一身講行路,「留在這裏」是它唯一講過的
  自身位置。**揭身份不等於解禁四規**,這是本批對 02-cast 最重要的
  一次服從。
- **隊伍聲線的三條自限**:①複數但不合唱——每句一個意思,不用排比
  堆疊;②不控訴——a04/a05 是陳述你的處境,不是指責(與 row 3 分工);
  ③不攔路——a06/a07/a08/a09 全部是「我們行過了」的過去式,句句在
  讓路。隊伍在鏡中的功能是**證人**,不是關卡。
- **八敵無對白**:全批零句。node 2/3 的隊伍句刻意在敵群主題上發言
  (王庭的坐、城的等),把「鏡不出聲」補回敘事密度,而不借鏡的嘴。
- **a14「你可以在這裏坐一會」**:rest node 的機制(休息)與主題(坐=
  三種拒絕之一)在此撞頭。寫成**他們容許**而非**它勸你**——坐在
  這裏是隊伍給的餘裕,不是安排的誘餌;守爐人的「坐下」留到 a18,
  兩處「坐」的落差就是全書的題目。
- **f02 對 00 §2.6「無撕裂」**:一句寫足三件事(六片重一、隊已到、
  恐懼無位),不新造形上學。
- **f07 與「玩家操作被貶值」的債**:00 §2.6 指定由這一段還清;句子
  不寫「你終於自己走」的自我恭賀,只作一句事實記錄——債由手指還,
  不由旁白還。
- **f11 用 00 §6 指定原句**;f12 承 00 §2.6 敗後世界(門閉、窗仍亮、
  隊伍+1、可直接再啟),與現有 RunEndScreen 流程相接。
- **勝後 Keeper 狀態不在本批**(07 §5:等新 canon 先入 00-truth);
  f08–f10 只寫入城,不寫爐邊此後如何。
- **Tier A**:零。a02「倒轉」、a10「最密」皆非垂直語彙。

---

## 面 ④:Top-5 event script(L1)— `story.event-*`

**選五的理由**:04-delivery 點名「library, shrine, knight, traders…」
=書庫/神龕/騎士/血肉商人四件,第五件取**鍍銀之鏡**——它是 ceiling 表
裏唯一被逐件點名定級的事件(「Silvered Mirror motif ruled L1」),
且是 L0 鏡像 motif(ledger rows 10/14)唯一的文字載體。落選:骨骰賭徒
(喜劇聲部,Phase 2)、荒廢營地/餘燼泉/虛空寶箱/鍛爐/詛咒神像
(機制事件,敘事負載輕)。

**格式**:shipped 的 `name` / `text` / `choices.*` **一字不動**;本批只
新寫**逐選項結果句**與**離場句**(coda)。選項編號依現有 locale
`choices.<n>` 次序。

### 鍍銀之鏡(mirror)— shipped text:鏡中的你比真身慢了半口氣,而且正在微笑

| # | slot | 級 | zh | en |
|---|---|---|---|---|
| v01 | event-mirror.c0(映照) | L1 | 鏡照出兩張同樣的牌。你只帶得走一張,另一張留在鏡裏,像有人替你收着。 | The mirror shows the card twice. You can carry one away. The other stays in the glass, as if someone were keeping it for you. |
| v02 | event-mirror.c1(打碎) | L1 | 玻璃碎了。同一個你散在每一塊碎片上,仍在笑。你從中取走一件不願再帶的東西,血沿手指流下。 | The glass breaks. The same reflection lies scattered across every piece, still smiling. You pick one thing out of the wreck that you no longer want to carry, and blood runs down your fingers. |
| v03 | event-mirror.c2(離開) | L1 | 你轉身。鏡裏那個慢了半口氣才轉身,之後便一直望着你走遠。 | You turn away. The one in the glass turns half a breath later, then watches you the whole way out. |
| v04 | event-mirror.coda | L1 | 路上不止一面鏡。每一面都比你慢半口氣。 | There is more than one mirror on this road, and every one of them is half a breath behind you. |

### 負傷騎士(woundedKnight)

| # | slot | 級 | zh | en |
|---|---|---|---|---|
| v05 | event-woundedKnight.c0(救助) | L1 | 你替他止血。他把遺物按進你手裏,然後靠着石柱站起來,說他只是要行得再遠一點。 | You stop the bleeding. He presses the relic into your hand, gets himself upright against the pillar, and says he only wants to get a little further. |
| v06 | event-woundedKnight.c1(劫掠) | L1 | 你取走鐵手裏的東西。他不推不擋,也沒有躺下;凹面甲後面的呼吸,慢慢停了。 | You take what the gauntlet is holding. He does not fight you, and he does not go down. Behind the crushed visor the breathing slows, and stops. |
| v07 | event-woundedKnight.c2(離開) | L1 | 你走開。回頭再看一眼,他仍靠着石柱,站着。 | You leave. One look back: still against the pillar, still on his feet. |
| v08 | event-woundedKnight.coda | L1 | 你下一次行過這裏,石柱前多了一座碑。沒有人替他躺下。 | The next time you come by, there is a monument at the foot of the pillar. Nobody laid him down. |

### 沉沒書庫(library)

| # | slot | 級 | zh | en |
|---|---|---|---|---|
| v09 | event-library.c0(研讀) | L1 | 你在泡水的書頁之間找到一張仍讀得出的。字是城中人寫的,寫的全是門開那日的打算。 | Among the waterlogged pages you find one still legible. It was written by someone who lived here, and all of it is about what they would do on the day the door opened. |
| v10 | event-library.c1(歇息) | L1 | 你在書架之間坐下。水聲遠了,呼吸慢下來。這座城最不缺的,就是坐下來等的位。 | You sit down among the stacks. The water noise falls back; your breathing slows. If this city is short of anything, it is not places to sit and wait. |
| v11 | event-library.coda | L1 | 他們把等待寫足了一座書庫。沒有一頁寫過出發。 | They wrote their waiting until it filled a library. Not one page of it is about setting out. |

### 血肉商人(fleshTrader)

| # | slot | 級 | zh | en |
|---|---|---|---|---|
| v12 | event-fleshTrader.c0(交易) | L1 | 你交出一塊血肉,換一件遺物。他收得順手,像同一件事重複過許多次。 | You hand over a piece of yourself for a relic. He takes it without fuss, like a man who has done this many times. |
| v13 | event-fleshTrader.c1(拒絕) | L1 | 你拒絕。他不追,只把長指合上:「下次。」說得像早已知道有下次。 | You refuse. He does not press it. The long fingers close. "Next time," he says, like a man who already knows there will be one. |
| v14 | event-fleshTrader.coda | L1 | 他從不追價。他見得多:每一個往東的都不會回來——而總有下一個往東。 | He never chases a price. He has seen enough: none of the ones who go east come back — and there is always another going east. |

### 荒忘神龕(forgottenShrine)

| # | slot | 級 | zh | en |
|---|---|---|---|---|
| v15 | event-forgottenShrine.c0(祈禱) | L1 | 你把一件不願再帶的東西放在龕前。石中那樣東西看着你,沒有回應——它等的不是祈禱。 | At the shrine you set down one thing you no longer want to carry. The thing inside the stone watches, and gives you nothing back. Prayer is not what it is waiting for. |
| v16 | event-forgottenShrine.c1(褻瀆) | L1 | 你把骨與銀的祭品收進行囊。石中那樣東西沒有動,只是記下了。 | You sweep the bone and silver offerings into your pack. The thing inside the stone does not move. It only makes a note. |
| v17 | event-forgottenShrine.c2(離開) | L1 | 你退開,轉身。龕聲不變——它嗡了不知多少年,不缺你這一次。 | You step back and turn. The hum goes on as before. It has hummed for years past counting; it is not short of one more visitor. |
| v18 | event-forgottenShrine.coda | L1 | 苔蘚長回祭品之上。這座龕收過的東西,比它應許過的多。 | The moss grows back over the offerings. This shrine has taken more than it ever promised. |

### Event — 逐規自查

- **L1 天花(row 3 影的控訴句)逐句比對**:全批最重四句 v02(碎鏡)、
  v04(鏡不止一面)、v08(碑=某個人的下場,但不指認是誰)、v14(往東的
  都不回來)——四句皆①不指控玩家、②不陳述機制、③表面讀法自足
  (碎鏡是怪談、鏡多是怪談、騎士死了立碑、商人見慣)。無一句越過錨句。
- **v02 已按 lint 改寫**:原稿「每一塊碎片裏都有一個你,全部仍在笑」被
  **三鏡獨立判中**(truth / ladder / 事件 twist):碎片各有一個你=複數
  同時存在,既撞 00 §3.5(**留者永遠只有一個**——沉澱疊加,不是人數
  疊加),又把 L3 的 u8(「每一個都是你」)提早搬到 L1。改寫為
  「同一個你散在每一塊碎片上」:多的是玻璃,不是人——回到 rows 10/14
  已立的**單數鏡像**register,怪談強度不減。
- **矩陣自查**:血肉商人 v14 止於經驗歸納(00 §4 [PROPOSED — Q11c]
  「知道行者都不會回來」),不觸分身;神龕、書庫是環境,不是角色,
  按 01 渠道紀律可自由承載錯覺與 legend-drift。
- **站死紀律**:v06/v07/v08 是全遊戲唯一一次「行者當場變成碑」的
  現場(02-cast 負傷騎士行)——**不寫倒下**,寫「沒有躺下」,呼吸停
  而人仍立;coda 才補上碑。row 1(碑不躺低)在此第一次以現場證據
  出現,而非以詩句出現。
- **書庫=等的紀念館**:v09/v10/v11 承 03-acts Act II(城淹於自己的
  等待)與 01(水=等);v11 與 Batch 3 的 e38(「他們把等待寫了下來」)
  同源不同面——遺言問「我們的誰來寫」,書庫答「他們寫足一座」。
- **Tier A**:零。

---

## Gate 記錄(2026-08-16)

**canon-lint 四鏡 + twist-safety 四 chunk + adversarial verify**
(`.claude/workflows/story-draft.js` 的三個 phase;本次以 Agent 逐個 lens
跑,workflow runner 不在此 session 可用,prompt 逐字取自 workflow):

- **blocker:1 confirmed 已修、1 refuted**。
  - **v02**(confirmed,三鏡獨立判中)——已改寫,見面④自查。
  - **d12**(vocab 鏡判 block:「蒼白身影」未用鎖詞 蒼白眾)——
    **adversarial verify 判 refuted**:d12 是守夜引述第二頁**本身的
    措辭**,而該頁 shipped 原文(Batch 1,`q.unreadablePage.pages[1]`)
    正是「蒼白身影」,ledger row 12 已把「搬運為真/動機為 drift」拆開
    記賬,00 §8 note 1 + fair-play 第 7 條指定此頁屬 legend-drift。
    換成鎖詞會令破曉散文與它引述的那一頁對不上,並抹走 drift 與 canon
    之間刻意的距離。**維持原句**;同一批的 d01–d03(守夜自己的聲音)
    照用鎖詞 蒼白眾——兩者的分別正是設計。
- **warn:6,處理如下**。
  - **d20**(truth 鏡 + 破曉 twist,兩鏡獨立)——**已改寫**(見面①自查)。
  - **a04**(voice 鏡:隊伍首次開口無複數標記,與敘述行分不開)——
    **已改寫**,加「我們」。
  - **a06**(voice 鏡:en 有 "us"、zh 無「我們」,兩語分歧)——
    **已對齊**,zh 補「我們」。
  - **f01/f09/f12**(vocab 鏡:en 的 queue 未按 06-glossary 大寫)——
    **已改**為 the Queue。
  - **d09 "The eighth omen rises"**(vocab 鏡,judgment call)——
    **判過並記錄**:zh 源句「凶兆升起」非 Tier A 詞,下一句即「它落在
    路面」把方向按回水平;Tier B「場景描述之內的字面上下」明文允許。
  - **v06/v08 負傷騎士**(事件 twist,同 ladder 鏡未判)——**不自行改**,
    歸 James 議程 10(判詞見該項)。
- **clean(零 finding)**:twist-safety 的開封場 chunk、Act IV/終戰 chunk;
  canon-lint 的 ladder 鏡除 v02 外全清(87 行逐行核對 ceiling 與
  ledger 1:1,程式核對,非目測)。
- **en native-read(step 6)**:自審 18 處,全部接受並已改
  (d01「this stretch this far」重複、d02 語序、u8「on him」、u12
  「What the door knows is」、a02「a shade brighter」與 the Shade 撞名、
  a07「rings」歧義、a17「it tore」主語不明、a18「go out」與「熄滅」撞義、
  f07 被動句無力、f08「in, in」、v02「The glass goes」、v15 語序等)。
- **字庫 cmap**:87 句 zh 逐字過 bundled woff2(改寫後重跑)—— **PASS,
  零新字**(避字表見 Brief)。落地 PR 照例本地跑
  `tools/check_locale_font_coverage.py`。
- `python3 tools/check_anchors.py` ✓;本批 docs-only,無新 benchmark
  citation(原稿的 `main.gd:2294-2345` 已換成具名 symbol anchor,不留行號)。

## 待 James 判(step 5 議程)

1. **破曉散文的 milestone 分配(25 段 = 20 quest + 5 窗格)**——建議
   照收:20 段掛六個 quest 的 progress/complete(填 `progress` panel
   今日**空白的 body**、換走六個 `shard` panel 共用的一句
   `shardGrantCopy`),另 5 段掛 `shards>=1..5`,令記憶帳有一條與
   quest 無關的主線,而 d25(五格,尚餘一格)正好是 L2 交棒給 L3 的
   一段。**否決的備選**:只寫 20 段 quest 里程碑——省 5 段,但窗
   由一格填到五格的過程在帳上完全無字,而那正是玩家最常回看的一頁。
2. **d06 / d25 — 貼 L2 天花的兩段**:d06 明寫「你熄掉的,是自己之中
   仍懂得行路的那一部分」(00 §7 的揭後讀法本體);d25 明寫窗光接連成
   一整塊。兩段皆**單一讀法**、皆**未陳述機制**——正是 00 §5 對 L2 的
   定義(「只剩一種讀法,但機制仍未明文」)。建議兩段照過並在 ledger 記
   L2 explicit sign-off。**備選**:d06 降寫成不點名「行路」(例:
   「你熄掉的,是自己之中最不肯停的那一部分」)——我不建議:00 §7
   逐字授權了這個讀法,降寫等於把 bible 已批的 payoff 收起。
   (原稿第三段 d20 已按兩鏡 lint 改寫,不再在此列——判詞見 Gate 記錄。)
3. **開封場說破的邊界:四項講三項,守爐人身份留給 Act IV**——建議
   照收。u10/u11/u12 一次過講完分身、碑=行者=你、門的真條件;全場
   不提守爐人。理由:00 §5 明文把 Keeper 身份劃歸 L4,而且玩家帶着
   「隊伍是我」返到爐邊、面對那個仍在派 boon 的人,是全遊戲最後一段
   懸念的燃料。**否決的備選**:在 u13 之後補一句指向爐前兜帽身影
   ——一次過爽完,但 Act IV node 5 (a16/a17) 便只剩重複。
4. **u13「門不是你開的。」作全場收句**——建議照收。它是本場唯一
   一句「奪走」的話,也是 00 §2.6「換位」在情緒上的欠條:玩家操作
   被貶值的風險由這句拉到最高,再由 f07(最後一步是你自己的腳)還清。
   **備選**:收在 u12(門的條件)——安全,但開封場會變成解說,不是
   一記打擊。
5. **隊伍的聲線(本批新立)**——建議照收「複數、平、讓路、不控訴」
   四條(見面③自查)。這是隊伍第一次以複數第一人稱開口(此前只有
   遺言、碑文、引路石的單數聲音)。**備選**:全 act 改為敘述體、
   隊伍不出聲——但 07 §4 已 SETTLED「會講嘢嘅係隊伍」,改動要回頭
   動 blueprint。要判的其實是**這把聲音夠不夠像他們**:a06/a08 的
   「我們不等了」是我認為最能定音的一句。
6. **a17 的措辭「每一次撕開…便有了一張面孔。這一張。」**——守爐人
   自述身份。四規自查已過(見面③),但這句是全遊戲**唯一**一次由
   角色自己講出 00 §2.4 的沉澱機制。建議照過。**備選**:改由敘述
   體講、守爐人只答「是我」——會弱,而且違反「Keeper 只在 node 5
   開口、開口就是揭身份」的 blueprint 設計意圖(07 §4)。
7. **a18「坐下。讓一個出去就是了——一直都是這樣的。」**——它輸掉
   之前的最後一句推銷。規 3(永不催促出發)自查:它催的是留低,
   方向相反,合規。但這句同時把 Batch 3 六十句爐邊話一次過翻面
   (h22/h32/h13 從此重讀為同一句)。建議照過。**備選**:收得更軟
   (「坐下。火還在。」)——溫度對,但少了那句「一直都是這樣的」,
   安排本身就沒有被命名過。
8. **終戰互動拍的四句(f04–f07)是不是文案該管的**——建議照收:
   f05/f06 兩句(「行一步。」「再一步。」)是**互動提示**,形式由
   實作 ticket 試(連續 tap 或長按,07 §5);若實作選長按,f05/f06
   併成一句、f07 不變。我把它們寫成可併可分。**備選**:互動拍完全
   無字,只有腳步聲——更硬派,但無字=玩家未必知道要按,首次遊玩
   風險太高。
9. **Top-5 選件:鏡取代賭徒**——建議照收(理由見面④首段)。
   **否決的備選**:選骨骰賭徒——喜劇聲部有價值,但它的敘事負載
   (「跟死人玩,因為死人不賴賬」)是**一句**的事,寫成 script 會
   稀釋;留 Phase 2 補完整個 event 表時一併處理。
10. **v06/v08 負傷騎士的死法——本批唯一未自行了結的 lint warn**。
    全遊戲唯一一次玩家親眼見「行者變成碑」。建議照收:呼吸停而人不倒,
    coda 才補碑。
    **Lint 反方(事件 twist chunk,warn)**:v06 的「不推不擋,也沒有
    躺下……呼吸慢慢停了」加 v08 的「石柱前多了一座碑。沒有人替他躺下」,
    是一對**有地點、有因果、有排他性**的證據(具名角色、具名石柱、
    明文否定「有人替他埋葬」這個尋常解釋);L1 錨句(row 3)則始終
    可以讀成比喻式的鬼話。按此軸,這一對更近 L2 的「只剩一種讀法」,
    多過 L1 的「可疑,不可證」。lint 給的兩條出路:(i) coda 收在
    「石柱前多了一座碑」,刪走「沒有人替他躺下」,把尋常紀念碑讀法
    的逃生門留返;(ii) 認作 L2,搬離 L1 天花的事件渠道。
    **正方(我的建議)**:①「沒有人替他躺下」在表面上完全自足——
    荒路無人收殮是常識,不需要任何機制知識;②它不指控玩家、不提
    分身、不提隊伍;③02-cast 明文把「玩家唯一一次親眼見現場」判給
    這個事件,刪掉 coda 等於把 bible 指定的位置空出來;④Batch 2 的
    row 114 與 Batch 3 的 rows 266–268 都是同樣形狀的判斷,兩次都由
    James 簽 L1 explicit sign-off 而非降寫。
    **三選一**:(a) 照過(ledger rows 379/381 記 L1 explicit sign-off);
    (b) 依 lint (i) 刪 coda 後半;(c) 依 lint (ii) 升 L2 並改渠道。

## 本批字數

zh 87 句/段,**2,656 字**(逐格點算,隨 cmap 檢查同步;#262 Q7 量度用)。
逐面:破曉散文 25 段 1,217 字 / 開封場 14 句 262 字 / Act IV 18 句 405 字
/ 終戰 12 句 208 字 / 事件 18 句 564 字。
Phase 1 累計:Batch 2 ~620 + Batch 3 1,799 + Batch 4 2,656 ≈ 5,075 字
(Batch 1 為重寫,不計新增)——#262 Q7 的 50K 走勢由 James 於 review
記錄;Phase 1 四批的新增量遠低於 50K 軌道,Phase 2 項目提前的判斷位
在 James。
