# Batch 2 — 開場 scene + 掌燈人五會 script(#315)

> 狀態:**[SETTLED — James review 完成 2026-08-16(pipeline step 5;
> 六項議程判齊,判詞見下)]**。掌燈人 scene 落地仍 gated on engine
> child(scene player 接駁);opening 8 句隨本批落 `locale/`。
> 依 `04-delivery.md` batch order [SETTLED — #262 Q8]:Batch 2 = opening
> scene + Lamplighter ×5,落地明文「上次」句(00 §3.6);unblock #176。

## Brief(pipeline step 1)

- **範圍**:①開場 scene 全劇本(四拍,07-scenes §2;8 句,對應 #309 已
  落的 `story.opening.*` 8 個 slot);②掌燈人五次會面 script(每會
  8–9 句,新句包住 Batch 1 已定的 ask/accepted/paid/cannot,shipped 句
  一字不動)。
- **可倚賴的 bible**:00 全部(§3.6 上次句、§5 L0 註);01(渠道紀律:
  「喚回」永不明文;Keeper 連假預設都禁);02(Keeper 四規、掌燈人聲線
  與五價約束);03(未燃之路沿途);04(ceiling 表、audio cue);
  05;06;07(scene player 文法、開場四拍、asset bill)。
- **等級上限**:opening ≤L0(真相零文字確認;目的地/六片/門開條件屬
  表面明文事實,任何級可直說 [SETTLED — #262 Q3]);Lamplighter ≤L1
  (L1 重量天花=影的控訴句,ledger row 3)。
- **語言**:zh-Hant 源語(HK 書面語,着/裏);en 全文重寫,禁 calque。
- **詞彙**:Tier A 禁(尖塔/climb/ascend/summit/above-as-place/upward/
  stair);Keeper 專項:永不「你回來了」(#259 Q1)、永不第一身講路
  (02-cast 規 4)、永不催促出發(規 3)。
- **Audio cue(brief 級,#262 Q4c / 07 §6)**:opening=爐邊 soundscape
  +出發轉場 cue(拍③);掌燈人會面無專屬 cue 要求(歸 hosting surface)。

## 授權格式說明

Scripted scenes 是 script,不是 flat table rows(#262 Q5)。本批每場一表:
`# | speaker | 級 | 狀態 | zh | en`。`狀態` = **新**(本批新寫)/
**shipped**(Batch 1 已定,一字不動,只標位置)。每句新行已同步入
`05-foreshadow-ledger.md` Batch 2 區(rows 84–118)。

## 落地封鎖(step 5 已過:opening 隨本批落 `locale/`;掌燈人 scene 仍鎖)

1. **Opening 落地位已存在**:`locale/{zh-Hant,en}.json` `story.opening.*`
   8 個 placeholder slot(#309,PR #314),與本批 8 句一一對應——落地
   純改值,`content/scenes.json` 不用動,無 test 釘。
2. **掌燈人 scene 落地位未存在**:本批提議 key 形
   `story.lamplighter-m{1..5}.pre.l{n}` / `.post.l{n}`,scene 條目與
   HollowScreen 的接駁(pre beats → ask/pay 交易照舊 → post beats)歸
   engine child ticket(scene player #309 slice 2 之後);**shipped
   ask/accepted/paid/cannot 留在 `content.quests.hollowLamplighter`,
   不複製**——scene 只包前後,交易屏一字不改。
3. **字庫覆蓋已驗(2026-08-16,零新字)**:本批全部新 zh 句逐字過
   `locale/*.json` corpus——落地不觸發字型 subset 重建。避字記錄:臉→面孔、
   說話→開口、問→回我一句、想→願、練→學、眼角→額上、疤→傷痕、
   借→分、省着用→慢慢用(邊/些/話/問/想/旁/吧/敢 等全部不在 corpus)。落地 PR 照例
   本地跑 `tools/check_locale_font_coverage.py`。
4. **L0 畫面 plant 不在本批**:出發 linger(爐前兜帽坐像)+ 窗中反影
   遲半拍係**每次出發**的常設 ambient 演出(07 §2),歸 engine;本批
   拍④只落 linger shot 上面嗰句字。

## 待 James 判(step 5 議程)

1. **目的地名法(#262 Q3 / 07 §2 拍②)——本批要判的正主**:建議
   **門+金城並用**:拍② l2 名封門與開門條件(表面明文事實),l3 以
   「他們說」帶出金城,收「到了那裏,你便到家了」。備選:(a) 只名門
   (刪金城句,金城留給眾人 NPC);(b) 只名金城。建議理由:rubric 要
   目的地在首戰前有名有姓;金城以傳聞語態出場=Keeper 誠實(眾人確係
   咁講)兼字面真(門後正是金城=爐邊);「到家」句係全批最凍的一句
   ——字面即 canon(入城=歸家,#259 Q3)。
   **判(James 2026-08-16):門+金城並用——簽。**
2. **拍② l3「到了那裏,你便到家了。」**——Keeper 字面真確認:金城=
   爐邊真貌,到=家。表面讀=祝福套語。L0 判定:不確認四項真相任何
   一項。過/重寫?
   **判(James 2026-08-16):照過。**
3. **拍④ linger 句「守夜開始了。」**——linger shot 收場字。表面=爐火
   為你守夜;揭後=留者的守夜由分身一刻開始。畫面 plant 零文字確認
   照舊(句不指向兜帽身影)。
   **判(James 2026-08-16):照過。**
4. **m5 l2「面孔,我認得出;人,我從來不曾說得定。」**——全批貼 L1 天花
   最近的一句:表面=老人認人老矣的自嘲,自足;揭後=字面真(面孔
   全同、人代代不同,無人分得出)。重量自查:仍低於影的控訴句(不
   指控玩家、不斷言機制)。**Lint 反方(2026-08-16 workflow,兩 warn,
   0 block)**:影錨句係一次過、斜面的第二人稱控訴,從無陳述「同面
   異人」結構;此句以一生總結的對偶句直落結構本身——在「陳述結構」
   呢條軸上比錨句更明;若照此軸判過線,掌燈人渠道 ceiling L1 無升級
   位,只能降寫(例:把「一生說不定」收窄成「這一次說不定」的當下
   猶疑)。正方照舊:hedge 為個人的認不出,無斷言、無指控,表面
   自足。三選一:(a) 照過(ledger row 114 記 L1 explicit sign-off);
   (b) 降寫成當下猶疑;(c) James 自書。
   **判(James 2026-08-16):(a) 照過——row 114 記 L1 explicit
   sign-off,兩 warn 撤銷。**
5. **m3 l2 傷痕句**——「上次沒有」的差異觀察。兩情境自查:同 run 兩會
   =同一行者,途中添傷,句真;跨 run=另一個身體,句更真。掌燈人
   自己補一句「路上的事,自然」把差異解釋走——誠實見證人的錯誤結論
   本體。過?
   **判(James 2026-08-16):照過。**
6. **m4 l2 直問句「上次站在這裏的,是不是你?」**——認人啟事問到口。
   玩家係啞角,唔答;n2 讓佢自己擺手迴避。呢下「怕知道」係五價逐次
   貼身(#260 Q3)的第四步。過?
   **判(James 2026-08-16):照過。**

**Gate 記錄(2026-08-16)**:canon-lint 四鏡+twist-safety 三 chunk+
adversarial verify——**0 blockers**;2 warns 均為 m5 l2(已併入議程 4)。
en native-read(step 6):7 flags,接受 4(m1.1 冗筆、m2.2 語序、m5.3
收句、m5.6 look close)、修訂 1(m1.2 改人做焦點)、**婉拒 2 並記錄**:
(a) m4.2 "the make"——老工匠 diction,合聲線,不改;(b) m4.6 "spend
yourself"——雙讀本體(行者=被逐程用掉之物),中性化即殺句,只把
slowly 收成 flat adverb "slow" 合老派口吻。字庫零新字已驗;
`check_anchors.py` ✓。

---

## 開場 scene(L0)— `story.opening.*`

拍①③④用 `opening-hearth` plate,拍②疊 #283 兜帽坐像(07 §8 asset
bill);全 opening 只播 first run(07 §2)。speaker 空白=敘述行。

| # | slot | speaker | 級 | 狀態 | zh | en |
|---|---|---|---|---|---|---|
| o1 | b1.l1 | keeper | L0 | 新 | 你醒了。 | You're awake. |
| o2 | b1.l2 | keeper | L0 | 新 | 慢慢來。路不會走掉。 | Take your time. The road isn't going anywhere. |
| o3 | b2.l1 | keeper | L0 | 新 | 帶上這個。前人留下的,如今是你的了。 | Take this. Those before you left it behind; now it's yours. |
| o4 | b2.l2 | keeper | L0 | 新 | 路向東,盡頭有一道封門。尋回六片燼璃,門便會開。 | The road runs east. At its end stands a sealed door. Bring back the six shards of emberglass, and it will open. |
| o5 | b2.l3 | keeper | L0 | 新 | 他們說,門後是金城。到了那裏,你便到家了。 | Beyond it, they say, lies the Gilded City. Reach it, and you will be home. |
| o6 | b3.l1 | — | L0 | 新 | 你提起燈,推門而出。長路向東,天未亮。 | You take up the lantern and step out. The long road runs east, and the sky is not yet light. |
| o7 | b3.l2 | — | L0 | 新 | 身後,爐火仍亮着。 | Behind you, the fire is still burning. |
| o8 | b4.l1 | — | L0 | 新 | 守夜開始了。 | The vigil begins. |

- **Keeper 四規自查**:o1 用 #259 Q1 定式(醒,永不「回來」);o2 反
  催促(規 3 的正面演出——關懷即麻醉);o3 字面真(boon=歷代行者
  遺物,00 §2.4);o4 字面真(六片歸位→§2.6 開門);o5 傳聞語態+
  字面真(金城=爐邊);全批 Keeper 無一句第一身講路(規 4)。
- **推門而出**(o6):與 00 §2.6「門是他們一齊推開的」暗韻——你推開
  的是爐邊的門,佢哋推開的是東端那道;L0 無文字確認。
- **天未亮**(o6):破曉=勝利字(Tier B),出發在破曉之前,字面地理。

## 掌燈人五會 script(L1)— `story.lamplighter-m{i}.*`

聲線(02-cast):老派、具體、只談看得見的東西;歧義來自事實本身。
五價逐次貼身=認人越見越急(#260 Q3),本批的落法:**m1 隨口一望 →
m2 斷定「上次是你」 → m3 見差異、自己解釋走 → m4 問到口、又不想知 →
m5 認輸,送行**。「上次」明文句(00 §3.6)落在 m2 l1 / m3 l2 / m4 l2。

### 會面一(價:三點餘燼)

| # | slot | speaker | 級 | 狀態 | zh | en |
|---|---|---|---|---|---|---|
| m1.1 | pre.l1 | — | L1 | 新 | 路上坐着一個提燈的老人。燈是空的,沒有火。 | An old man sits by the road, holding a lantern. There is no flame in it. |
| m1.2 | pre.l2 | 掌燈人 | L1 | 新 | 你的燈燒得太滿。滿燈的人,我見得多。 | Your lantern burns too full. I have seen plenty like you. |
| m1.3 | pre.l3 | 掌燈人 | L1 | 新 | 這張面孔,又是往東走的。 | This face. East again, then. |
| — | ask | 掌燈人 | L1 | shipped | 你的提燈太吵。把它接下來收集的三點餘燼交給我。 | Your lantern is noisy. Give me the next three embers it catches. |
| — | accepted | 系統 | L1 | shipped | 接下來三點餘燼,歸於空燈。 | The next three embers belong to the hollow lantern. |
| — | cannot | 掌燈人 | L1 | shipped | 現在便許下餘燼。提燈會先於你付清。 | Promise the embers now. The lantern will pay before you do. |
| — | paid | 掌燈人 | L1 | shipped | 六片窗片曾從一扇無牆可承的窗中被帶走。 | Six panes were carried away from a window no wall could hold. |
| m1.4 | post.l1 | 掌燈人 | L1 | 新 | 油可以分,火不能分。火要自己帶到最後。 | Oil can be shared. Flame cannot. Flame you carry to the end yourself. |
| m1.5 | post.l2 | — | L1 | 新 | 他把三點餘燼收進空燈。燈沒有亮。 | He gathers the three embers into the hollow lantern. The lantern does not light. |

### 會面二(價:一百六十金)

| # | slot | speaker | 級 | 狀態 | zh | en |
|---|---|---|---|---|---|---|
| m2.1 | pre.l1 | — | L1 | 新 | 未燃之路再向東,老人又在等。空燈放在身前。 | Farther east along the Unlit Way, the old man is waiting again, the hollow lantern set before him. |
| m2.2 | pre.l2 | 掌燈人 | L1 | 新 | 上次是你。三點餘燼,一分不少。這雙手,我記得。 | Last time — that was you. Three embers, not one short. I remember these hands. |
| m2.3 | pre.l3 | 掌燈人 | L1 | 新 | 手瘦了。路上的日子,誰都一樣。 | Thinner, these hands. The road feeds no one well. |
| — | ask | 掌燈人 | L1 | shipped | 金幣記得每一隻手。讓一百六十枚忘記你的手。 | Gold remembers every hand. Let one hundred and sixty pieces forget yours. |
| — | cannot | 掌燈人 | L1 | shipped | 你的錢囊尚暖,卻還不夠暖。 | Your purse is warm, but not warm enough. |
| — | paid | 掌燈人 | L1 | shipped | 蒼白眾凝望着指向王冠之後的路。 | The Pale Ones watch the paths that point beyond the crown. |
| m2.4 | post.l1 | — | L1 | 新 | 他把金幣一枚一枚數過,不收起,只沿路放好,向東。 | He counts the coins one by one, and does not pocket them. He lays them out along the road, piece by piece, pointing east. |
| m2.5 | post.l2 | 掌燈人 | L1 | 新 | 去。忘記是要學的。 | Go on. Forgetting takes practice. |

### 會面三(價:十二格容量)

| # | slot | speaker | 級 | 狀態 | zh | en |
|---|---|---|---|---|---|---|
| m3.1 | pre.l1 | — | L1 | 新 | 這一次,老人站着等你。未看清你的面孔,他不開口。 | This time the old man is on his feet, waiting. Until he has looked you full in the face, he does not speak. |
| m3.2 | pre.l2 | 掌燈人 | L1 | 新 | 站近一點。提高你的燈,讓我看一看這張面孔。 | Stand closer. Raise your lantern — let me see this face properly. |
| m3.3 | pre.l3 | 掌燈人 | L1 | 新 | 額上多了一道傷痕。上次沒有。……路上的事,自然。 | A scar on your brow. Last time there was none. …The road gives them out. Naturally. |
| — | ask | 掌燈人 | L1 | shipped | 路清點容器。把十二格容量交給我。 | The road counts the vessel. Give me twelve measures of yours. |
| — | cannot | 掌燈人 | L1 | shipped | 我不會把你挖空至三十以下。換一副更大的容器再來。 | I will not hollow you below thirty. Return with a larger vessel. |
| — | paid | 掌燈人 | L1 | shipped | 你的前身站立而死,面向東方。 | Your forebears died standing, facing east. |
| m3.4 | post.l1 | 掌燈人 | L1 | 新 | 別那樣看我。老人家見到什麼,便說什麼。 | Don't look at me like that. An old man tells what he has seen — no more than that. |
| m3.5 | post.l2 | — | L1 | 新 | 他退後一步,再看你一眼——由面孔,看到腳。 | He steps back and looks you over once more — from the face down to the boots. |

### 會面四(價:守爐人的贈禮)

| # | slot | speaker | 級 | 狀態 | zh | en |
|---|---|---|---|---|---|---|
| m4.1 | pre.l1 | — | L1 | 新 | 老人的目光越過你,落在你帶着的東西上,一件一件地數。 | The old man's eyes go past you, to the things you carry, counting them one by one. |
| m4.2 | pre.l2 | 掌燈人 | L1 | 新 | 西面爐火出來的東西,我一眼認得。這麼多年,樣式沒有變過。 | Things from the western fire — I know them at a glance. All these years, the make has never changed. |
| m4.3 | pre.l3 | 掌燈人 | L1 | 新 | 回我一句就好。上次站在這裏的,是不是你? | Give me one answer, that is all. Last time, standing where you stand — was that you? |
| m4.4 | pre.l4 | — | L1 | 新 | 你還未出聲,他已擺了擺手,像不願知道那一句之後的事。 | Before you can make a sound, he waves the question away — as if he would rather not learn where it leads. |
| — | ask | 掌燈人 | L1 | shipped | 守爐人贈過你一份恩賜。我要那份贈禮,不要你的感激。 | The Keeper gave you a boon. Give me the gift, not the gratitude. |
| — | cannot | 掌燈人 | L1 | shipped | 你已花掉那份贈禮。帶一份仍屬於你的來。 | You have spent the gift already. Bring me one that is still yours. |
| — | paid | 掌燈人 | L1 | shipped | 空燈就是換取面見那副面具的信物。 | The empty lantern is the token that purchases an audience with the mask. |
| m4.5 | post.l1 | — | L1 | 新 | 他把贈禮收好。空燈放在腳前,依然黑着。 | He puts the gift away. The hollow lantern sits by his feet, dark as ever. |
| m4.6 | post.l2 | 掌燈人 | L1 | 新 | 下一程遠。自己要慢慢用。 | The next stretch is long. Spend yourself slow. |

### 會面五(價:只留一記心跳)

| # | slot | speaker | 級 | 狀態 | zh | en |
|---|---|---|---|---|---|---|
| m5.1 | pre.l1 | — | L1 | 新 | 未燃之路的盡頭,老人提着空燈,站在路的正中,不讓你過。 | Where the Unlit Way runs out, the old man stands in the middle of the road, hollow lantern raised. He does not let you pass. |
| m5.2 | pre.l2 | 掌燈人 | L1 | 新 | 最後一次。過了我,這條路上再沒有人向你收東西。 | The last price. Past me, no one on this road will ask anything more of you. |
| m5.3 | pre.l3 | 掌燈人 | L1 | 新 | 我提這盞燈,認了一生的人。面孔,我認得出;人,我從來不曾說得定。 | A lifetime under this lamp, learning the ones who pass. The faces I know. The people I was never sure of. |
| — | ask | 掌燈人 | L1 | shipped | 最後代價:只留一記心跳在這提燈裏。其餘全歸黑暗。 | Last price: leave this lantern with one heartbeat. The rest belongs to the dark. |
| — | cannot | 掌燈人 | L1 | shipped | 一記心跳已足夠。如今只剩拒絕才算貧乏。 | One heartbeat is enough. Refusal is the only poverty left. |
| — | paid | 掌燈人 | L1 | shipped | 點亮窗片。門會認得你。 | Light the panes. The door will know you. |
| m5.4 | post.l1 | 掌燈人 | L1 | 新 | 去。這一段,我送過太多人。 | Go. I have seen many off along this stretch. |
| m5.5 | post.l2 | — | L1 | 新 | 他讓開路,提起空燈,向東照了照——燈中沒有光;他仍是照了。 | He steps aside and lifts the hollow lantern toward the east, as if to light the way. There is no light in it. He lifts it all the same. |
| m5.6 | post.l3 | 掌燈人 | L1 | 新 | 路上若再見提燈的,替我看一看那張面孔。 | If you meet another out there who carries a lamp — look close at the face, for me. |

- **m2.2 / m3.3 / m4.3 = 明文「上次」句**(00 §3.6 落地;rubric A4)。
  m2.2 的「上次是你」是掌燈人的誠實結論——觀察真(呢張面孔、呢對手、
  三點餘燼),結論按 canon 屬 legend-drift(fair-play 第 7 條),
  ledger row 97 兩讀齊記。
- **兩情境自查**(quest 進度跨 run 持續,五會可同 run 亦可跨 run):
  「上次」句全部寫成兩情境皆真——同 run=同一行者,字面直真;跨 run
  =另一個身體,慢性毒生效。無一句硬斷身體同一。
- **m5.6 的「提燈的」**:玩家將見的下一個提燈者=無焰提燈的永恆君王
  (usurper 線);「看一看那張面孔」預埋王冠底下無臉(03-acts)。
  掌燈人只託付一件佢一生在做的事,無知識越權。
- **矩陣自查**(00 §4):五會新句無一觸及機制/碑=行者斷言/Keeper 身份
  /門真條件;m4.2 認得爐邊物=見慣(觀察),m5.3 認唔出人=自嘲
  (觀察的失敗),全部止於 unsettle。

## 本批字數

新 zh 句 35 行,約 620 字(James 於 review 記錄,#262 Q7 量度用)。
