# 05 — Foreshadow Ledger(伏筆賬簿)

> 反轉故事在 100K 字規模下不穿崩,靠的就是這本賬。**每一句文案(已 shipped
> 或新寫)都要入賬**:表面讀法 / 揭後讀法 / 揭示階梯等級(見 00 §5)/
> 洩露風險。規則:
>
> 1. 一句只有表面讀法而揭後讀不通 → 改到讀通為止。
> 2. 一句在其等級之前就洩露 → 降寫或改期。
> 3. climb/垂直語彙 → 標 `[REWRITE:climb]`,逐句清洗。

| # | 句子(shipped 原文) | 出處 | 級 | 表面讀法 | 揭後讀法 | 狀態 |
|---|---|---|---|---|---|---|
| 1 | Your monument does not always lie down. | whisper 10 | L1 | 詩意的悼詞 | 碑是站着死去的行者本人;他們沒躺下,因為仍在排隊等門開 | 保留,核心伏筆 |
| 2 | The dead climb twice: once in flesh, once in memory. | whisper | L1 | 詩句 | 機制說明書:行者以肉身走一次(真死),留者以記憶再走一次 | `[REWRITE:climb]` 改「行」語彙,語義保留 |
| 3 | I remember the stone. You walked away before I stopped calling. | Own Shade 碎句 | L1 | 影在追憶 | 控訴對象反轉:死者臨終叫住的 you 就是玩家——行開了沒回頭的是留者 | 保留,全 cast 最重一句 |
| 4 | Each climber leaves a shape behind. | quest 文本 | L1 | 路上留影 | 留下的 shape 是坐回爐邊那個——遊戲主角本人 | `[REWRITE:climb]` |
| 5 | We were never climbing out. We were carrying light to the lock. | Own Shade 收束 | L2 | 朝聖目的自白 | 字面為真:行者是送火的隊伍;lock 就是門 | `[REWRITE:climb]` 語義照舊 |
| 6 | Five pages make a chapter; five prices make a confession. | Lamplighter | L1 | 老人的怪話 | 五個代價合起來是一場認人/自白——他在確認你是不是同一個 | 保留 |
| 7 | The first keeper gave you a boon. | keeper/掌燈 文本 | L1 | 世界觀擺設 | 「first keeper」=留低嗰個;boon 是歷代行者遺物 | 保留;keeper 稱謂待 06 定名 |
| 8 | A pale hand has touched the dark side of the glass. | thinGlass omen | L1 | 不祥之兆 | 玻璃另一面一直有人——鏡中那側是留者/隊伍 | 保留 |
| 9 | (有個朝聖者站着死去) | Unreadable Page 頁文 | L2 | 怪談 | 碑的成因,一直明文寫在紙上 | 保留 |
| 10 | (mirror.png:鏡中淺笑黑影) | 事件美術 | L0 | 詭異鏡像 | 鏡中人是留者=你;淺笑因為它認得你 | 資產不改,文案圍繞它寫 |

## 新寫文案入賬區

(開稿後逐批 append;canon-lint workflow 會校驗每批新行都已入賬。)

## `[REWRITE:climb]` 清單狀態

尚未全文掃描 `content/full-content.json` 的 climb/tower/ascend 語彙——
開稿第一批前先跑一次全量 grep 入賬。[TODO]
