# Batch 3 — 三 pool:爐邊 / 引路石 / 敗亡遺言(#331)

> 狀態:**[SETTLED — James review 完成 2026-08-16(pipeline step 5;
> 六項議程判齊,判詞見下)]**。落地仍 gated on #270(見 落地封鎖)。
> 依 `04-delivery.md` batch order [SETTLED — #262 Q8]:Batch 3 = the three
> pools(hearth / waystone / loss),schema live。落地 gated on #270
> (line-table 引擎,claimed 進行中)——起稿不等落地(Batch 2 先例)。

## Brief(pipeline step 1)

- **範圍**:三個敘事 pool,共 170 行——①守爐人爐邊句 60(run start);
  ②引路石殘語 60(waystone interstitials);③敗亡遺言 50(loss pool,
  A2/A3:入 Vigil 敗亡帳的 defeat epitaphs)。
- **可倚賴的 bible**:00 全部(§2.2 灰的西飄、§3 分身規則、§4 矩陣、
  §5 階梯);01(渠道紀律——「喚回」永不明文;**Keeper 連假預設都禁,
  非 Keeper 渠道可自由承載錯覺**;火的物理七方程);02(Keeper 四規
  [#260 Q2]、隊伍=第二主角 [#260 Q6]);03(三幕 motif 語彙);04
  (schema [#262 Q5]、per-channel ceiling、loss 語義 [#262 Q2]);05;06。
- **等級上限**:三 pool 全部 **≤L1**(04-delivery ceiling 表);L1 重量
  天花=影的控訴句(ledger row 3)。loss pool shard-0 可及(#270)。
- **語言**:zh-Hant 源語(HK 書面語,着/裏);en 全文重寫,禁 calque。
- **詞彙**:Tier A 禁(尖塔/climb/ascend/summit/above-as-place/upward/
  stair);Keeper 專項:永不「你回來了」(#259 Q1)、永不第一身講路
  (02-cast 規 4)、永不催促出發(規 3)、句句字面真(規 1)。
- **Speaker / frame 定義**(本批的渠道釘位):
  - **爐邊句**:守爐人,run start 於爐邊。全部通過四規逐句自查(見節末)。
  - **引路石殘語**:歷代行者行經此石時的所思,殘留石畔(02-cast「waystone
    獨白」的落法;row 30 已簽——每塊石都被之前每一個行者點亮過)。
    表面讀法雙軌:玩家可讀成「路上朝聖者的殘語」,亦可讀成「自己前幾
    次經過時的念頭」(表面虛構下玩家信自己行過);真相=隊伍中某一人。
    知識上限=**該行者自己一程的見聞**(00 §4 + Batch 1 分配表約束)。
  - **敗亡遺言**:本程行者臨終語,寫入 Vigil 敗亡帳(A3;in-fiction=
    留者繼承的臨終記憶,00 §3.7)。**站死紀律**:無任何倒臥/墜落意象
    (§3.3);錯覺承載:行者渠道可預設「醒來再走」(#259 Q1 非 Keeper
    渠道條款),照常記 drift。
- **條件詞彙**(#262 Q5 Phase 1):`shards>=N` / `act=N` / `quest:<id>.<state>`;
  空=generic fallback。`priority/once/cooldown_runs/weight` 全默認省略
  (loss 的 cooldown_runs≈3 屬 pool 級語義,#262 Q2,非逐行欄)。
- **id / key 形提議**(#270 落地時對齊,語義以本表為準):
  `pool.hearth.h01–h60` / `pool.waystone.w01–w60` / `pool.loss.e01–e50`;
  slot 即 pool 名。
- **字庫覆蓋已驗(2026-08-16,零新字)**:本批全部 zh 句逐字過 bundled
  woff2 cmap(`tools/check_locale_font_coverage.py` 同源集合)。避字記錄
  (承 Batch 1「齊」、#232「喺」教訓):差→餘、掃→清、矮→暗、一線→
  一點、胸口→喉頭、排(隊)→列/隊伍、似→像、事情→如此;快/短/舊/
  聽/答/催/趕/勸/浮/滴/疊/端/計/千 等全部不在 corpus,全批避用。
  二輪修正:經過→見到、陪→自己會亮、爐邊→爐前、吹→帶、(水)底→
  (水)下、圖書館→書庫、做過→讓過、談→說/提起、和→與、
  (燈)小→光走不遠。

## 授權格式說明

依 #262 Q5 flat line table schema。本批表格欄:`id | 條件 | 級 | zh | en`
(speaker 依節固定,見節首;省略欄全默認;`asserts` 無)。每行的
表面/揭後全文已同步入 `05-foreshadow-ledger.md` Batch 3 區(rows 134–303)。

## 落地封鎖

1. **#270 未落**:pool 選擇引擎(most-specific-wins + generic fallback、
   loss 的 cooldown 與 Vigil 敗亡帳寫入)是 #270 的 acceptance;本批
   不入 `content/` / `locale/`,key 形以上述提議為準。
2. **loss 帳簿面**(A3):遺言在 Vigil 重讀時以敗亡帳 register 呈現;
   句子已按「可入帳重讀」寫成(遺言即帳文)。

---

## Pool 1 — 爐邊句(守爐人;run start;≤L1)

speaker 全部=守爐人。條件空=generic。

### 通用(h01–h46)

| id | 級 | zh | en |
|---|---|---|---|
| h01 | L1 | 你醒了。火仍在。 | You're awake. The fire is still here. |
| h02 | L1 | 坐近一點。路可以等。 | Sit closer. The road can wait. |
| h03 | L1 | 爐火整夜沒有熄。 | The fire didn't go out all night. |
| h04 | L1 | 慢慢來。夜還長。 | No hurry. The night is long. |
| h05 | L1 | 手先暖了,再拿東西。 | Warm your hands first. The rest can wait. |
| h06 | L1 | 這把火,由第一夜燒到現在。 | This fire has burned since the first night. |
| h07 | L1 | 灰我清過了,柴也添過了。 | I've cleared the ash and fed the fire. |
| h08 | L1 | 外面有霜。多帶一層。 | There's frost out. Take another layer. |
| h09 | L1 | 路上冷,這裏不冷。 | The road is cold. It is not cold here. |
| h10 | L1 | 你的燈,我上了油。 | I've oiled your lantern for you. |
| h11 | L1 | 芯是新的,油是滿的。 | New wick. Full oil. |
| h12 | L1 | 願意走的時候,才走。 | Leave when you want to. Not a moment sooner. |
| h13 | L1 | 我在這裏。一直都在。 | I'm here. I always am. |
| h14 | L1 | 守夜的事,交給我。 | Leave the vigil to me. |
| h15 | L1 | 火光認得你。 | The firelight knows you. |
| h16 | L1 | 東西都在原位。這裏不變。 | Everything is where it was. Nothing changes here. |
| h17 | L1 | 窗我抹過了。亮的格,更亮。 | I've wiped the panes. The lit ones shine better for it. |
| h18 | L1 | 別站在門口,風大。 | Don't stand in the doorway — the wind. |
| h19 | L1 | 你睡着時,火暗了一次。我添了柴。 | The fire sank while you slept. I fed it. |
| h20 | L1 | 這條路,你行過的次數,比誰都多。 | No one has walked that road more times than you. |
| h21 | L1 | 第一段路,你會見到許多碑。不必停。 | The first stretch has many monuments. You needn't stop for them. |
| h22 | L1 | 這裏永遠有你的位。 | There will always be a place for you here. |
| h23 | L1 | 走得多遠,火都在原地。 | However far you walk, the fire stays where it is. |
| h24 | L1 | 選一件合手的。前人的手,與你的一樣。 | Take whichever fits your hand. The hands before yours were just the same. |
| h25 | L1 | 全是留下來的東西。留下來的,自有用處。 | It's all left-behind things. What stays behind has its uses. |
| h26 | L1 | 帶上它。它認得路。 | Take it. It knows the road. |
| h27 | L1 | 火留給我,你帶燈。 | The fire stays with me. The lamp goes with you. |
| h28 | L1 | 這道門,從不上鎖。 | That door is never locked. |
| h29 | L1 | 外面起風了。再坐一會。 | The wind's up. Sit a while longer. |
| h30 | L1 | 六格都亮起的那一天,門會開。 | The day all six panes are lit, the door will open. |
| h31 | L1 | 金城不會走掉。 | The Gilded City isn't going anywhere. |
| h32 | L1 | 有我看火,你便不必看。 | I'll watch the fire, so you don't have to. |
| h33 | L1 | 累了便睡。火自己會亮。 | Sleep when you're tired. The fire minds itself. |
| h34 | L1 | 今夜的火,燒得穩。 | The fire burns steady tonight. |
| h35 | L1 | 你望東面望得太久了。火在這一面。 | You've been looking east too long. The fire is on this side. |
| h36 | L1 | 慢火才燒得久。 | A slow fire burns longest. |
| h37 | L1 | 破曉之前,總是最冷。 | It's coldest just before dawn. |
| h38 | L1 | 燈也要歇。人更加要。 | Even lamps rest. People need it more. |
| h39 | L1 | 出去之前,再暖一暖手。 | Before you go, warm your hands once more. |
| h40 | L1 | 向東,一直向東。這一句不會錯。 | East, and keep east. That much is always true. |
| h41 | L1 | 灰會落,火會亮。一直如此。 | Ash falls; fire burns. It has always been so. |
| h42 | L1 | 我不送了。門口風大。 | I won't see you out. The wind at the door is cruel. |
| h43 | L1 | 窗中的東西,有一日你會看清。 | One day you will see that window clearly. |
| h44 | L1 | 今夜與上一夜,一樣長。 | Tonight is as long as the last one. |
| h45 | L1 | 多帶一枚金幣。路上伸手的多。 | Take an extra coin. The road is full of open hands. |
| h46 | L1 | 這一面暖。坐這一面。 | This side is warmer. Sit on this side. |

### 條件行(h47–h60)

| id | 條件 | 級 | zh | en |
|---|---|---|---|---|
| h47 | shards>=1 | L1 | 窗亮了一格。夜沒有之前那麼暗了。 | One pane is lit. The nights are not so dark now. |
| h48 | shards>=1 | L1 | 那一格的光,顏色像爐火。 | The light in that pane — the colour of this fire. |
| h49 | shards>=2 | L1 | 兩格了。窗開始記起自己的樣子。 | Two now. The window is remembering its shape. |
| h50 | shards>=2 | L1 | 兩格亮了。餘下的,路知道在甚麼地方。 | Two are lit. The road knows where the rest are waiting. |
| h51 | shards>=3 | L1 | 三格,半扇窗。半團火。 | Three panes. Half a window. Half a fire. |
| h52 | shards>=3 | L1 | 窗亮到一半,我在夜裏都看得見它了。 | Half-lit now. I can see it even in the dark hours. |
| h53 | shards>=4 | L1 | 四格。窗開始照出這裏的東西了。 | Four. The window has begun to show the room. |
| h54 | shards>=4 | L1 | 還有兩片。之後的事,之後再說。 | Two shards left. What comes after can wait for after. |
| h55 | shards>=5 | L1 | 五格,餘一片。慢慢來。 | Five panes. One to go. There's no hurry. |
| h56 | shards>=5 | L1 | 五格了。窗比火還亮。 | Five. The window outshines the fire now. |
| h57 | quest:usurper.bought | L1 | 那盞燈冷。別放近火。 | That lantern is cold. Keep it away from the fire. |
| h58 | quest:ownShade.resolved | L1 | 今夜靜。連影都不吵了。 | Quiet tonight. Even the shadows have stopped their noise. |
| h59 | quest:hollowLamplighter>=1 | L1 | 路上那位提燈的老人家——他說的,信一半就好。 | That old lamp-keeper on the road — believe half of what he says. |
| h60 | shards>=3 | L1 | 三片歸位。餘下三片,在更東的地方。 | Three home. The other three lie further east. |

**Keeper 四規自查**(逐類):

- **規 1(字面真)**:h03/h06(自第一夜燒到現在,00 §2.2);h13(從未
  離開過爐邊,#261 Q11);h15(爐火是它的第二張臉,02-cast);h20
  (02-cast 授權句式「你行過幾多次」——走出去的每一個都是真正的你,
  00 §1);h23/h31(字面地理:路的盡頭=爐邊、金城=爐邊真貌,#259
  Q3);h24(同一雙手,字面);h30(o4 已簽同款漏一半條件句,§2.6);
  h48(同一團火,字面);h50(「路知道」=隊伍知道,指路者 00 §4——
  物件作主語而其事為真,m3.ask 先例);h59(誠實的錯誤見證人:事實半
  全真、結論半全錯——「信一半」是字面上正確的忠告)。
- **規 2(揭後更冷)**:逐行入 ledger rows 134–193。
- **規 3(永不催促)**:全批無一句促行;h02/h04/h29/h35/h46/h55 反向
  演出(軟性挽留=關懷即麻醉);h12 係規 3 機制的正面演出(「必須顯
  得是你自己要走」)。
- **規 4(永不第一身講路)**:全批 Keeper 第一身動詞只及爐邊事務
  (清灰、添柴、上油、抹窗、看火);路只以第三身事實或「你」句式出現。
- **#259 Q1(連假預設都禁)**:全批無「回來/歸來」語;h01 用「醒」
  定式;無一句預設玩家行過歸途(燼璃歸位不落「你帶回」——h50/h60
  只講「歸位/在甚麼地方」,搬運者不點名)。

## Pool 2 — 引路石殘語(行者殘語;waystone reached;≤L1)

speaker 全部=行者殘語(frame 見 brief)。

### 通用(w01–w18)

| id | 級 | zh | en |
|---|---|---|---|
| w01 | L1 | 燈到石,石亮。原來石一直在等火。 | The lamp reaches the stone, and the stone lights. It was waiting for fire all along. |
| w02 | L1 | 這段路,足跡比人多。 | More footprints than people on this stretch. |
| w03 | L1 | 一步一步數。數到忘了為甚麼要數。 | Counting steps, until I forget why I'm counting. |
| w04 | L1 | 石是誰放的?路沒有說。 | Who set these stones? The road isn't saying. |
| w05 | L1 | 碑全部面向東。沒有一座面向爐火。 | The monuments all face east. Not one faces the fire. |
| w06 | L1 | 油還有,便不去數餘下的石。 | While there's oil, don't count the stones ahead. |
| w07 | L1 | 風把灰帶向西。灰認得那個方向。 | The wind carries the ash west. The ash knows that way. |
| w08 | L1 | 石座有燒痕,一層下面另有一層。 | Scorch marks at the stone's base — a layer, and under it another. |
| w09 | L1 | 越往東,路越靜。 | The further east, the quieter the road. |
| w10 | L1 | 回頭,西面仍有火光。仍未算遠。 | Looking back, the firelight is still there. Not far yet, then. |
| w11 | L1 | 引路石不引人回頭。 | Waystones never point back. |
| w12 | L1 | 像有人與我同行。回頭,只有碑。 | It feels like company on this road. I look back — only monuments. |
| w13 | L1 | 火不重。重的是油。 | The flame weighs nothing. The oil is the weight. |
| w14 | L1 | 到下一塊石再歇。到了,又說下一塊。 | Rest at the next stone. At the stone: the next one, then. |
| w15 | L1 | 石只數走過的,不數剩下的。 | The stones count what's walked, never what's left. |
| w16 | L1 | 破曉在東面。一直在東面。 | Dawn is east. It stays east. |
| w17 | L1 | 路剩多少,無人能說。 | No one can say how much road is left. |
| w18 | L1 | 有一座碑,手仍舉着,像要接甚麼。 | One monument still holds its arm out, as if to catch something. |

### 灰燼樹林(act=1;w19–w32)

| id | 級 | zh | en |
|---|---|---|---|
| w19 | L1 | 灰落在燈罩上,一層,又一層。 | Ash on the lamp glass. A layer, then a layer. |
| w20 | L1 | 林靠灰養大。灰是誰養大的? | The forest feeds on ash. What feeds the ash? |
| w21 | L1 | 第一段,碑最密。起步之地,停步的人最多。 | The monuments stand thickest here, where the road begins. |
| w22 | L1 | 兩盞燈並亮。火是新的。誰點的? | Two lanterns burning side by side. The flames are fresh. Whose? |
| w23 | L1 | 孢子懸在光裏,像未落的灰。 | Spores hang in the lamplight, like ash that won't come down. |
| w24 | L1 | 樹下有蒼白面具,不止一副。 | Pale masks under the tree. More than one. |
| w25 | L1 | 根從灰裏伸出來,握着甚麼。 | Roots reach out of the ash, holding something. |
| w26 | L1 | 灰收走腳步聲。這段路,靜得像沒有人走過。 | The ash takes the sound of my steps. As if no one had ever walked here. |
| w27 | L1 | 有一座碑靠着樹。樹先到,還是碑先到? | A monument leans against a tree. Which of them came first? |
| w28 | L1 | 燒過的林仍在長。長出來的,總會再燒。 | The burnt forest keeps growing. What grows will burn again. |
| w29 | L1 | 這裏的白,不像任何一種白。 | The white here is not like any other white. |
| w30 | L1 | 他們向灰祈禱。灰不應人。 | They pray to the ash. The ash answers no one. |
| w31 | L1 | 燈光照到的,全是灰。照不到的,不去看。 | Everything in the lamplight is ash. What's past the light, I don't look at. |
| w32 | L1 | 過了樹林,他們說,有一座城。 | Past the forest, they say, there is a city. |

### 沉沒之城(act=2;w33–w46)

| id | 級 | zh | en |
|---|---|---|---|
| w33 | L1 | 水過了城的第二層。城沒有走。 | The water has taken the city's second storey. The city has not moved. |
| w34 | L1 | 這座城留下來等。水,也留下來。 | The city stayed to wait. So did the water. |
| w35 | L1 | 水下有光。那光不引路,只引人。 | There's a light under the water. It leads to nothing — it only leads people. |
| w36 | L1 | 鐵欄蝕剩一半。原來等待,咬得動鐵。 | The iron rail is eaten half through. So waiting has teeth after all. |
| w37 | L1 | 書庫沉在水裏。他們寫下的,如今水在讀。 | The library is under the water. What they wrote, the water is reading now. |
| w38 | L1 | 水裏有人走動。不上來,也不沉下去。 | Someone is moving in the water. Not rising. Not sinking. |
| w39 | L1 | 水下有一口鐘,不響。它還在等甚麼? | A bell under the water, silent. What is it still waiting for? |
| w40 | L1 | 城門沒有關。他們不是出不去。 | The gates were never shut. It isn't that they couldn't leave. |
| w41 | L1 | 這裏的水不流。等着的東西,都不流。 | The water here doesn't flow. Nothing that waits does. |
| w42 | L1 | 窗內有人影,仍立在原地。 | Figures at the windows, still standing where they stood. |
| w43 | L1 | 他們信門開那日,人人有份。 | They believed that when the door opened, it would open for everyone. |
| w44 | L1 | 城選了等。水是等的樣子。 | The city chose to wait. The water is what waiting looks like. |
| w45 | L1 | 城中無一人向東行,無一人向西返。 | No one in this city walks east. No one walks back west. |
| w46 | L1 | 潮聲像在數甚麼。 | The tide sounds like counting. |

### 黑曜王庭(act=3;w47–w60)

| id | 級 | zh | en |
|---|---|---|---|
| w47 | L1 | 黑曜不透光。燈照上去,只照見自己。 | Obsidian lets no light through. Raise the lamp to it, and you see only yourself. |
| w48 | L1 | 斷了的光環落在地上,無人拾起。 | Broken halos on the ground. No one gathers them. |
| w49 | L1 | 越近門,人越多。全部坐着。 | The nearer the door, the more of them. All seated. |
| w50 | L1 | 這裏的星低,低得像在看。 | The stars hang low here. Low enough to watch. |
| w51 | L1 | 他們讓路,像讓過許多次。 | They make way for me, as if they had done it many times before. |
| w52 | L1 | 庭中無火。他們坐在星光裏,坐了太久。 | No fire in the court. They sit in starlight, and have sat too long. |
| w53 | L1 | 王座之後,他們說,再沒有路。 | Beyond the throne, they say, the road ends. |
| w54 | L1 | 石上刻着一列數目。最後一筆是新的。 | A column of tally marks cut into the stone. The last one is fresh. |
| w55 | L1 | 坐着的人望着我,像在等我坐下。 | The seated ones watch me, as if waiting for me to sit. |
| w56 | L1 | 黑曜裏面,有光死在途中。 | Inside the obsidian, light has died on its way through. |
| w57 | L1 | 王冠之後的事,他們不說。 | Of what lies beyond the crown, they do not speak. |
| w58 | L1 | 這段路無灰無水,只有黑曜與靜。 | No ash on this stretch, no water. Only obsidian, and the quiet. |
| w59 | L1 | 燈的光,在這裏走不遠。 | Lamplight doesn't travel far here. |
| w60 | L1 | 離門越近,越少人提起它。 | The closer the door, the less anyone speaks of it. |

**矩陣自查**:全部止於一程之內的見聞與傳聞(「他們說」句記 drift:
w32/w43/w53);無一句聲稱分身/碑=行者/Keeper 身份/門真條件;w05 係
可見事實的並置(碑向東,m3.paid 已簽),w12 止於錯覺感。

## Pool 3 — 敗亡遺言(行者遺言;defeat → Vigil 敗亡帳;≤L1)

speaker 全部=行者遺言(本程行者臨終語)。

### 通用(e01–e20)

| id | 級 | zh | en |
|---|---|---|---|
| e01 | L1 | 燈還亮。人先熄。 | The lamp is still burning. I go out first. |
| e02 | L1 | 腳不肯躺。由它站。 | My legs won't lie down. Let them stand, then. |
| e03 | L1 | 東面有一點亮了。全亮,看不到了。 | There's a little light in the east. I won't see it full. |
| e04 | L1 | 油交給風,路交給後來的人。 | The oil goes to the wind. The road goes to whoever comes after. |
| e05 | L1 | 把燈放好。火不該隨我熄。 | Set the lamp down safe. The flame shouldn't go out with me. |
| e06 | L1 | 冷從腳上來。數到七,不數了。 | The cold rises from my feet. I counted to seven, then stopped. |
| e07 | L1 | 就到這裏?就到這裏。 | This far, then? This far. |
| e08 | L1 | 不必記我。路會記。 | Don't remember me. The road will. |
| e09 | L1 | 我未到。有人會到。 | Not me. But someone will get there. |
| e10 | L1 | 門等得起。我等不起了。 | The door can afford to wait. I no longer can. |
| e11 | L1 | 握不住燈了。誰在接? | I can't hold the lamp any longer. Who is taking it? |
| e12 | L1 | 風向西。替我帶一句到爐前。 | The wind runs west. Carry a word to the hearth for me. |
| e13 | L1 | 不必立碑。醒來再走就是。 | Skip the monument. I'll wake and walk it again. |
| e14 | L1 | 爐前見。 | See you by the fire. |
| e15 | L1 | 這次不算。 | This one doesn't count. |
| e16 | L1 | 面向東。記得面向東。 | Face east. Remember to face east. |
| e17 | L1 | 門開那日,替我多行一步。 | When the door opens, walk one step of it for me. |
| e18 | L1 | 燈裏還有油。用不完了。 | There's oil left in the lamp. More than I'll be needing. |
| e19 | L1 | 行到第幾塊石?石記得,我不記得了。 | Which stone was I on? The stone remembers. I don't. |
| e20 | L1 | 路未完。我完了。 | The road isn't finished. I am. |

### 灰燼樹林(act=1;e21–e30)

| id | 級 | zh | en |
|---|---|---|---|
| e21 | L1 | 灰在燈上又一層。這次不抹了。 | Ash on the lamp again. This time I won't wipe it. |
| e22 | L1 | 未出樹林。第一段都未過。 | Still in the forest. Not even past the first stretch. |
| e23 | L1 | 兩盞燈仍並亮。我這盞,誰來添油? | The paired lamps still burn. Who will oil mine? |
| e24 | L1 | 根在灰下握着的,原來是這個。 | So this is what the roots were holding. |
| e25 | L1 | 樹在長。我停了,它還在長。 | The trees keep growing. I stop; they don't. |
| e26 | L1 | 面具白。灰白。我的手,也開始白。 | The masks are white. The ash is white. My hands are turning white now. |
| e27 | L1 | 靜。只剩燈芯的聲。 | Quiet. Only the wick still speaking. |
| e28 | L1 | 出發時天未亮。原來一直都未亮。 | It wasn't light when I set out. It never grew light. |
| e29 | L1 | 還以為第一段容易。 | I thought the first stretch would be the easy one. |
| e30 | L1 | 樹林之後,他們說有一座城。我看不到了。 | Past the forest, they say, there's a city. Not for me. |

### 沉沒之城(act=2;e31–e40)

| id | 級 | zh | en |
|---|---|---|---|
| e31 | L1 | 水到喉頭。就站在這裏,等它再上。 | Water at my throat. I'll stand here and let it rise. |
| e32 | L1 | 城等了那麼久。多我一個。 | The city has waited so long. One more, then. |
| e33 | L1 | 水下那口鐘,響過沒有? | That bell under the water — did it ever ring? |
| e34 | L1 | 水下那點光,不是燈。 | That light down in the water is not a lamp. |
| e35 | L1 | 水中的人仍在走。原來,等是走不完的。 | The drowned are still walking. Waiting, it turns out, is a road without an end. |
| e36 | L1 | 鐵有蝕,城有水。人有甚麼? | Iron has rust. The city has water. What do we have? |
| e37 | L1 | 燈在水上仍亮着,亮得比我久。 | The lamp still burns above the water. Longer than I will. |
| e38 | L1 | 他們把等待寫了下來。我們的,誰來寫? | They wrote their waiting down. Who will write ours? |
| e39 | L1 | 潮退了,又漲。第幾次了? | The tide falls and rises. Which time is this? |
| e40 | L1 | 這座城不出聲。今夜多一個不出聲的。 | The city makes no sound. Tonight there is one more who doesn't. |

### 黑曜王庭(act=3;e41–e50)

| id | 級 | zh | en |
|---|---|---|---|
| e41 | L1 | 門就在前面。我聞到它的冷。 | The door is just ahead. I can smell its cold. |
| e42 | L1 | 不坐。他們坐,我不坐。 | I will not sit. Let them sit. Not me. |
| e43 | L1 | 有光環斷了,不知是誰的。 | A halo broke somewhere. I don't know whose. |
| e44 | L1 | 星在看。看便看。 | The stars are watching. Let them watch. |
| e45 | L1 | 王冠之後有甚麼,我到不了了。 | Whatever lies beyond the crown, I will not reach it. |
| e46 | L1 | 黑曜裏有個我。它不動了。 | There I am in the obsidian. That one has already stopped moving. |
| e47 | L1 | 坐着的人望過來。我明白那個眼神了。 | The seated ones are looking at me. I understand that look now. |
| e48 | L1 | 庭中無火。我的熄了,便真的無火了。 | No fire in this court. When mine goes, there will be none at all. |
| e49 | L1 | 就在門前。原來門前也是路。 | At the very door. So even the doorstep is still road. |
| e50 | L1 | 油盡了。火去了甚麼地方? | The oil is spent. Where has the fire gone? |

**站死紀律自查**:全批無倒臥/墜落意象;e02/e16/e31/e42 反面演出(站着
終結);「落在灰上」一類已於起稿剔走。**錯覺承載自查**:e13/e14/e15
以行者渠道承載「醒來再走」錯覺(#259 Q1 非 Keeper 條款;drift 入賬);
無一句陳述機制。**unsettle-not-explain**:e24/e26/e35 止於一程之內的
臨終所感,無一句越 00 §4 矩陣。

---

**Gate 記錄(2026-08-16)**:canon-lint 四鏡+twist-safety 三 chunk+
adversarial verify(story-draft.js workflow)——**1 confirmed blocker**:
e06 en 「The cold climbs from my feet」的 "climbs" 屬 Tier A 禁字
(zh 源句「冷從腳上來」無問題,en rewrite 引入)——已改
"The cold rises from my feet."(rises=場景內字面,Tier B)。其餘
warn 兩項:h59 聲線(乾涼是否越出溫厚)與 w05 後半句(全稱斷言的
指向性)——兩項早已列入議程 2/4,判斷位歸 James。en native-read
(step 6):**1 flag**,接受——e28 "It never did get light" 的 emphatic
did 偏口語,改 "It never grew light."。字庫 cmap 逐字 PASS(零新字);
`check_anchors.py` ✓;本批 docs-only,無新 benchmark citation。

## 待 James 判(step 5 議程)

1. **敗亡遺言的錯覺三連(e13/e14/e15)**——「不必立碑。醒來再走就是。」
   「爐前見。」「這次不算。」全批最凍的三句:行者渠道承載復活錯覺,
   #259 Q1 明文允許(非 Keeper 渠道自由承載,記 drift),且正是 A2
   「敗仗都有一個未聽過的 beat」的本體。表面讀=朝聖者對爐火應許的
   信心,自足;揭後=三句全錯而各有一個字面真的殘核(碑會立/爐邊
   有人/隊伍確實加一)。過/降寫?
   **判(James 2026-08-16,full digest 後):照過——三句照收,ledger
   rows 266–268 記 L1 explicit sign-off + drift。**
2. **h59「信一半就好」**——守爐人評掌燈人。字面真(誠實的錯誤見證人
   ——事實半全真、結論半全錯,「信一半」是字面正確的忠告);聲線判
   定:溫厚裏的一點乾涼,是否越出「溫厚、疲倦」?過/刪?
   **判(James 2026-08-16):照過——乾涼屬聲線之內;lint warn 撤。**
3. **h43「窗中的東西,有一日你會看清。」**——全批最貼 L1 天花的爐邊
   句(L3 開封場的前指)。不確認任何真相、不指明「東西」;但方向感
   比其他爐邊句重。過/降寫?
   **判(James 2026-08-16):照過——止於應許,L1 合規。**
4. **w05「碑全部面向東。沒有一座面向爐火。」**——引路石渠道最重一句:
   兩個可見事實的並置(面向東已簽,m3.paid),後半句的指向性係新加。
   重量自查:無指控、無結構陳述,仍低於影錨句。過/刪後半?
   **判(James 2026-08-16):照過——row 198 記 L1 explicit sign-off;
   lint warn 撤。**
5. **id/條件形制**——`pool.{hearth,waystone,loss}.{h,w,e}NN` 與
   `shards>=N / act=N / quest:<id>.<state>`,#270 落地對齊(語義以本表
   為準)。照准?
   **判:review 中列為形制默認,未另判;#270 落地如需改形,歸 #270,
   語義以本表為準。**
6. **爐邊句的條件分佈**——generic 46 + shard 條件 12 + quest 條件 2。
   Phase 2 再加 60 句 shard-aware 變體(04-delivery)。照准?
   **判:同上——形制默認,未另判;Phase 2 擴充時重開。**

## 本批字數

zh 170 行,1,799 字(cmap 檢查同步逐格點算;#262 Q7 量度用)。
