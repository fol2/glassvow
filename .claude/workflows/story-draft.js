export const meta = {
  name: 'story-draft',
  description: 'Story batch pipeline steps 3-4: canon-lint + twist-safety over a batch line table',
  whenToUse:
    'After drafting a story batch file under docs/story/batches/ (pipeline per docs/story/04-delivery.md). Pass args {batchFile, chunks?}: batchFile is the batch markdown path; chunks optionally names sections for the twist-safety fan-out (defaults to one whole-file pass).',
  phases: [
    { title: 'Canon lint', detail: 'four lenses: truth+matrix / vocabulary+orthography / voice / ladder+ledger' },
    { title: 'Twist safety', detail: 'per-chunk dual-reading and leak check' },
    { title: 'Verify', detail: 'adversarial refutation of block-severity findings' },
  ],
}

const batchFile = args && args.batchFile
if (!batchFile) throw new Error('args.batchFile required: path to the batch line-table markdown')
const chunks = (args && args.chunks && args.chunks.length) ? args.chunks : ['the entire batch file']

const BIBLE =
  'docs/story/00-truth.md (canon root: §3 fission rules, §4 information matrix, §5 reveal ladder, §7 quest readings), ' +
  'docs/story/01-world.md (surface fiction, channel discipline, geography west-to-east, fire physics), ' +
  'docs/story/02-cast.md (voice sheets; the Shade accusation line is the L1 weight ceiling), ' +
  'docs/story/03-acts.md (act backgrounds/motifs), ' +
  'docs/story/04-delivery.md (per-channel spoiler ceilings, line table schema), ' +
  'docs/story/05-foreshadow-ledger.md (every line must have a row: surface/post-twist/level), ' +
  'docs/story/06-glossary.md (canonical terms; Tier A bans; register rules)'

const FINDINGS = {
  type: 'object', required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object', required: ['line_id', 'rule', 'severity', 'detail'],
        properties: {
          line_id: { type: 'string', description: 'content key or whisper number the finding is about' },
          rule: { type: 'string', description: 'which bible rule is violated, with file+section citation' },
          severity: { type: 'string', enum: ['block', 'warn'] },
          detail: { type: 'string' },
          suggested_fix: { type: 'string' },
        },
      },
    },
  },
}

const VERDICT = {
  type: 'object', required: ['refuted', 'why'],
  properties: {
    refuted: { type: 'boolean', description: 'true = the line actually passes; the finding is wrong' },
    why: { type: 'string' },
  },
}

const COMMON =
  `Read ${batchFile} in full, then the bible files you need: ${BIBLE}. ` +
  'The batch file is the draft under review; the bible is the authority. ' +
  'Report ONLY defects (empty findings = clean). Every finding must cite the bible rule it violates ' +
  '(file + section). severity=block for a canon/leak/ban violation; warn for judgment calls worth ' +
  "James's attention. Do not propose stylistic rewrites of lines that pass."

// ---- Phase 1: canon lint (pipeline step 3), four independent lenses ----
const LENSES = [
  {
    key: 'truth',
    prompt:
      'Canon-lint lens TRUTH+MATRIX: check every zh and en line (and every walker mini-bio) against ' +
      '00-truth: fission rules (§3), the information-control matrix (§4 — no speaker may voice knowledge ' +
      'above their row; the matrix outranks cast sheets), settled history (§2), and the fair-play decalogue ' +
      'in .claude/skills/glassvow-story/SKILL.md §9 (esp. rules 1, 3, 4, 6, 7). Flag any line that ' +
      'contradicts canon, invents metaphysics, or has a speaker knowing too much.',
  },
  {
    key: 'vocab',
    prompt:
      'Canon-lint lens VOCABULARY+ORTHOGRAPHY: (a) Tier A bans in BOTH languages — 尖塔/Spire, 爬/攀/climb, ' +
      '登臨/ascend, 頂點/summit, 之上-as-place/above-as-place, 向上/upward, 階梯-as-road/stair (Tier B keeps: ' +
      '王冠/crown, 破曉/dawn, 朝聖/pilgrimage, 層 as stack measure, literal in-scene up/down). ' +
      '(b) 06-glossary discipline: canonical terms only, correct zh/en pairings, unlocked names in 【brackets】. ' +
      '(c) zh orthography: 着 never 著 (verb suffix), 裏 never 裡; HK 書面語 register, no 口語 (no 喺/嗰/咗/係 ' +
      'in player-facing zh). Check ONLY the zh/en table cells destined for locale files, plus quoted new names.',
  },
  {
    key: 'voice',
    prompt:
      'Canon-lint lens VOICE: 02-cast voice sheets. Lamplighter lines: old-fashioned, concrete, only visible ' +
      'things (lamps, oil, roads, faces); ambiguity from facts, never rhetoric. Shade lines: broken sentences, ' +
      'present-perfect memory, second person only. Pages: written-record register. Whispers: dying words — may ' +
      'unsettle, never explain. Apply the test: could ONLY this speaker say this line?',
  },
  {
    key: 'ladder',
    prompt:
      'Canon-lint lens LADDER+LEDGER: (a) per-channel ceilings from 04-delivery — whispers ≤L1, quest bodies ≤L1, ' +
      'quest closers ≤L2; check each line’s declared 級 against its channel AND against its content. ' +
      '(b) The L1 weight anchor: no L1 line may be more explicit about the truth than the Shade accusation line ' +
      '(ledger row 3). (c) Every zh/en line in the batch must have a matching row in 05-foreshadow-ledger.md ' +
      '(main table update or Batch 1 rows 27-82) — list any line missing from the ledger.',
  },
]

phase('Canon lint')
const lintResults = await parallel(
  LENSES.map((l) => () =>
    agent(`${l.prompt}\n\n${COMMON}`, {
      label: `lint:${l.key}`, phase: 'Canon lint', schema: FINDINGS, model: 'sonnet',
    })
  )
)
const lintFindings = lintResults.filter(Boolean).flatMap((r) => r.findings)
log(`canon lint: ${lintFindings.length} finding(s)`)

// ---- Phase 2: twist safety (pipeline step 4) ----
phase('Twist safety')
const twistResults = await parallel(
  chunks.map((c) => () =>
    agent(
      `Twist-safety pass over ${c} in ${batchFile}. For EVERY zh and en line in that scope: ` +
        '(1) the surface reading must fully work on its own — a line that only functions post-twist is a leak ' +
        '(fair-play rule 2); (2) the post-twist rereading must survive, and preferably turn colder; ' +
        '(3) the line must not reveal above its declared reveal-ladder level (00-truth §5), where the truth ' +
        'being guarded is: fission / monuments-are-walkers / Keeper identity / the door’s real condition ' +
        '(surface facts like the destination or the six shards are free at any level, #262 Q3); ' +
        '(4) weight check: any line more explicit about the truth than the Shade accusation line must be L2+ ' +
        'and obey its channel ceiling. Also reread each walker mini-bio: it must not require walker knowledge ' +
        'above the 00 §4 matrix.\n\n' +
        COMMON,
      { label: `twist:${c.slice(0, 30)}`, phase: 'Twist safety', schema: FINDINGS, model: 'sonnet' }
    )
  )
)
const twistFindings = twistResults.filter(Boolean).flatMap((r) => r.findings)
log(`twist safety: ${twistFindings.length} finding(s)`)

// ---- Phase 3: adversarial verify of blockers ----
const all = [...lintFindings, ...twistFindings]
const blocks = all.filter((f) => f.severity === 'block')
const warns = all.filter((f) => f.severity !== 'block')
const CAP = 12
if (blocks.length > CAP) log(`verify capped at ${CAP} of ${blocks.length} blockers — rerun after fixes`)
phase('Verify')
const verified = await parallel(
  blocks.slice(0, CAP).map((f) => () =>
    agent(
      'Adversarially verify this story-batch finding — try to REFUTE it against the bible. ' +
        'It is refuted if the cited rule does not say what the finding claims, if the line actually passes ' +
        'on a careful reading, or if a more recent SETTLED decision supersedes the cited rule. ' +
        `Finding: ${JSON.stringify(f)}\n\nRead ${batchFile} and the bible: ${BIBLE}.`,
      { label: `verify:${f.line_id}`, phase: 'Verify', schema: VERDICT, model: 'sonnet' }
    ).then((v) => ({ ...f, refuted: v ? v.refuted : false, verdict_why: v ? v.why : 'verifier died' }))
  )
)
const confirmed = verified.filter(Boolean).filter((f) => !f.refuted)
const refuted = verified.filter(Boolean).filter((f) => f.refuted)
const unverified = blocks.slice(CAP)

return {
  blockers_confirmed: confirmed,
  blockers_refuted: refuted,
  blockers_unverified: unverified,
  warnings: warns,
}
