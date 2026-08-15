# 07 — Scripted Scenes(四場戲藍圖 + scene player)

> 派生自 `00-truth.md`、`03-acts.md`、`04-delivery.md`。本文件是 #263 的
> 產物:**blueprint 層**——每場戲「演乜、幾時演、點重播」+ 播放機器的
> spec。**劇本本文不在此**:opening 歸 Batch 2、unsealing/Act IV 歸
> Batch 4(`04-delivery.md` batch order),照 drafting pipeline 行。
> 引擎實作另開 child ticket,load `glassvow-godot` skill。
> [框架 SETTLED — #263 Q1,2026-08-16]

## 1. Scene player(播放機器)[SETTLED — #263 Q12]

一部 shared sequencer,四場戲共用;文法直接繼承 DawnScreen 已驗證嗰套
(`presentation/run/dawn_screen.gd` 的 beat state machine):

- **tap = 一句/一 beat**(提前完成 reveal,或即時推進)。
- **長按 0.6s = skip / fast-forward**——同一般 tap 的「distinct skip」。
- **persistence-gated advance**:先 save cursor 後顯示(DawnScreen 的
  `advance_requested` → store → `advance_confirmed` pattern)——process
  死中途,返嚟續返同一句;RC bar save-integrity pillar 直接受惠。
- reduce-motion 與 headless instant 行 `TransitionLayer` 現有慣例。
- **劇本係 data,唔係 code**:每場一個 shot list(art ref、motion、句序),
  zh/en 行現有 Locale overlay;Batch 落 copy 唔使掂 code,canon-lint /
  twist-safety / #300 locale lint 校 data 檔。
- 無 VO [SETTLED — #175]。
- 各場自帶 bespoke staging(mural 變鏡、換位互動 beat 等)——機器管
  句序同輸入,唔管每場的專屬演出。

**文法擁有權** [SETTLED — #263 Q2]:tap/skip 文法由本文件定(四場共用,
唔係 onboarding 專屬);#176 收窄為「opening 喺 first-run flow 的位置 +
hint 系統 + veteran skip(O-criteria)」,consume 呢套文法。

## 2. 開場(L0)[SETTLED — #263 Q4+Q5]

- **播放節奏**:full opening 只播 first run,不設重播。
- **L0 畫面 plant 唔屬 scene player**:出發時鏡頭多留一秒(爐前兜帽
  坐像)+ 窗中反影遲半拍(00 §5 L0)= **每次出發**的 ambient 演出,
  常設;咁先滿足 #270 simulation-verified planting。
- **四拍結構**:①爐邊醒來(「你醒了」,永不「你回來了」——#259 Q1)
  → ②Keeper 對白派 boon、**由 Keeper 口中名目的地**(用「門」定
  「金城」由 opening batch 決定,per #262 Q3)→ ③出發 → ④L0 linger
  shot 收場;首個 combat 前完結(rubric story-before-mechanics)。
- 對白預算 ~8–12 句(Batch 2 寫;ceiling L0,04-delivery 表)。

## 3. 開封場(L3)[SETTLED — #263 Q6+Q11]

- **觸發**:第一次帶住六片返到 Vigil 嗰刻——勝行 dawn 完結後、敗行
  run-end 完結後(第六片可以喺輸咗嘅 run 入賬:`commit_run` fold 唔理
  勝敗,量度於 `domain/state/vigil_state.gd:157-158`)。once-flag 行
  現有 `unlocks` 機制(additive,無 save bump)。
- **Full 版 beat**:第六格亮 → 窗全亮的一刻成鏡 → 隊伍現形(每人胸口
  一點光)→ 切門:沿路的碑起身、列隊、推門(00 §2.6;窗門同體
  #259 Q4——一場戲兩面剪)。
- **Short 版**:之後每次過門入 Act IV 的簡短 beat——門已開,行入
  (今日 ThresholdScreen 儀式升級承載;overlay 位照舊,wiring 歸 #222)。
- **重播**:Vigil 度 tap 彩窗本身重播 full 版(diegetic,不開新 menu)。
  重播範圍只限本場:opening 唔重播,finale 要再睇=再打 [#263 Q6]。

## 4. Act IV 五節點(L4)[SETTLED — #263 Q7]

- **過門 entry beat** 一段(threshold′ 之前)。
- **每節點到達 interstitial**:1–3 句,L4——鏡像段的認出
  (threshold′ → III′ → II′ → I′ → hearth′,03-acts 對應表)。
- **八個 counterfactual selves 全程無對白**:鏡像唔出聲;佢哋嘅語言
  全部落喺招式名/視覺(同 Shade 的「憶中○○」系列區分)。會講嘢嘅
  係隊伍,唔會講嘢嘅係鏡。
- **Rest node(I′,第四節點)**承載全 act 最長一段靜位 script——
  climax 前的唞位。
- **Keeper 只喺 node 5(hearth′)開口**,L4 揭身份。

## 5. 換位終戰(L4)[SETTLED — #263 Q8+Q9]

- 終戰「不以血量取勝收束」(03-acts):去到換位點,scripted 段開始
  ——你走,它留。fight-to-threshold 的數值機制歸 #220。
- **Bespoke interactive beat,全遊戲唯一一處破格**:最後一步由玩家
  input 親手行出(連續 tap = 一步一步,或長按到門——形式由實作
  ticket 試)。得一個 beat,唔係新 input 系統。「玩家操作被貶值」
  的債(00 §2.6)由呢隻手指還。
- **勝**:ascended 序(隊伍入城,你在隊尾)→ 返 Vigil,遊戲照玩
  (endgame mode per #210);重勝只播 short 收束。
- **敗**:行現有 RunEndScreen 流程 + finale 專用 epitaph variant
  (「這一個,也沒有回來」,00 §6),隊伍+1,照 00 §2.4 可直接再啟。
- 勝後 Keeper 狀態等新 canon 一律先入 `00-truth.md` 先落筆;勝後
  hearth 對白變化歸 Phase 2 hearth pool,不在此發明。

## 6. Audio cue 要求(brief 級,per #262 Q4c)[SETTLED — #263 Q10]

- **Opening**:爐邊 soundscape + 出發轉場 cue。
- **開封場**:rubric 的 unique sting **新做一條**——`sealedDoor` 今日
  每次門儀式都響(`main.gd` overlay 開關切 track),留佢做門 theme,
  sting 另做先滿足 "heard nowhere else"。
- **Act IV**:「倒轉爐光」soundscape 方向(細節歸 #221)。
- **Finale**:勝/敗各一 cue。

## 7. 資產範圍 [SETTLED — #263,見 02-cast 修訂]

Additive-zero 上限已解除(02-cast「藝術範圍」修訂):scripted scenes
與對白演出可按 blueprint 需要新增資產,逐件由 blueprint/batch brief
開列,行 `docs/art-ledger.md` 契約 + James review。**Shipped 資產永不
修改**(skill §6 照舊)。每場 asset bill 見 §8。

## 8. Staging:Hybrid [SETTLED — #263 Q13,James 2026-08-16]

Bake-off record(四張 mock + trade-offs):
`docs/design/2026-08-16-scene-staging-bakeoff/`。

**定案**:Hybrid——**A 的機器、文法同 staging 做骨幹**(對白、節點
interstitial、short beats 行 §1 嘅 scene player),**peak shots 用
B 級 full-bleed plate**。兩條 binding 品味判斷(James,睇圖拍板):

- **Plates 的視覺 bar = Route B 的電影感處理**(環境縱深、非對稱
  構圖、raking light)——James 對 B 的偏好強烈,plate 寧多勿縮。
- **否決:A-unsealing 的逐格重複處理**(六格各自一群兜帽的萬花筒讀法,
  James:creepy)。開封場的鏡中隊伍必須係**一條隊橫貫全窗**——
  正正係 00 §2.6「窗中站滿一排『你』」的字面;永不逐格複製人群。

**每場 asset bill(9 張新 plate,全行 art-ledger 契約 + James review;
生產路由 image tiers)**:

| 場 | 新 plate | 用 shipped |
|---|---|---|
| 開場 | 爐邊 wide shot ×1(route-b-opening 為 reference;承載拍①③④) | #283 坐像疊演拍②對白 |
| 開封 full | 「鏡中一條隊」×1(單隊橫貫,禁逐格複製)+「碑起身推門」×1 | 亮格 beat 用 mural + masks + frame 現有機件 |
| 開封 short | 無(推門 plate 的門開 crop) | ThresholdScreen 位 |
| Act IV | 五節點 establishing plate ×5(motif 池按 03-acts 對應表) | — |
| 終戰 | 換位 plate ×1(你走,它留;互動 beat 疊其上) | `ascended.png` / `fallen.png` 兩結局 |
