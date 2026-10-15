// Pure logic shared by the hooks in register.ts. Nothing here touches `$`:
// the engine only follows `$` within the file that registers the hooks.

export const PLUGIN = 'agent-harness-kit-claude'
export const RUN_DIR = '.harness-run'
export const FEATURE_ID = /^M\d+-\d{3}$/

const oneLine = (v: unknown) => String(v ?? '').replace(/\s+/g, ' ').trim()

// --- M25-001 decision register -------------------------------------------

export const DECISION_TOOL = 'register_decision'

export const decisionSpec = {
  name: DECISION_TOOL,
  description:
    'Record a decision while building a harness feature (FEATURES.json id like M3-002): ' +
    'call it each time you pick one option over another or assume something the brief ' +
    'did not say. One call per decision; it is folded into the PROGRESS.md Decisions line.',
  inputSchema: {
    type: 'object',
    properties: {
      feature: { type: 'string', description: 'Feature id, e.g. M3-002' },
      chose: { type: 'string', description: 'What you chose, or the assumption you made' },
      over: { type: 'string', description: 'The option you rejected (or "nothing" for an assumption)' },
      why: { type: 'string', description: 'Why, in a few words' },
    },
    required: ['feature', 'chose', 'over', 'why'],
  },
}

export const decisionsPath = (feature: string) => `${RUN_DIR}/decisions/${feature}.md`

export type Decision = { feature: string; line: string } | { error: string }

export function parseDecision(input: Record<string, unknown>): Decision {
  const feature = oneLine(input.feature)
  if (!FEATURE_ID.test(feature)) {
    return { error: `register_decision: feature must be a FEATURES.json id like M3-002, got "${feature}"` }
  }
  return { feature, line: `- chose ${oneLine(input.chose)} over ${oneLine(input.over)}: ${oneLine(input.why)}` }
}

export function appendLine(before: string | undefined, feature: string, line: string) {
  const head = before ?? `# Decisions for ${feature}\n\n`
  return `${head.endsWith('\n') ? head : `${head}\n`}${line}\n`
}

// --- M25-002 done-check supervisor ---------------------------------------

export type SessionLine = { feature: string; outcome: string; gate: string }

// The protocol's last line of a session: `SESSION: <id> · <outcome> · gate <g> · ...`
export function parseSessionLine(answer: string): SessionLine | undefined {
  const m = /SESSION: (M\d+-\d{3}) · (passing|review|blocked) · gate (green|red)/.exec(answer)
  return m ? { feature: m[1]!, outcome: m[2]!, gate: m[3]! } : undefined
}

export function verifyOf(featuresJson: string, feature: string): string | undefined {
  try {
    const data = JSON.parse(featuresJson) as { features?: { id?: string; verify?: string }[] }
    return data.features?.find(f => f.id === feature)?.verify
  } catch {
    return undefined
  }
}

export const SUPERVISOR_RULES =
  'You check a finished harness coding session against its acceptance criterion. ' +
  'Answer with one JSON object and nothing else: ' +
  '{"done": boolean, "blocked": boolean, "skipped_work": string[]}. ' +
  'done = the verify criterion is demonstrably met by what the session did. ' +
  'blocked = the session stopped for something only a human can decide. ' +
  'skipped_work = parts of the verify criterion, edge cases or checks the session ' +
  'considered or needed and did not do, each in a few words; [] when none. ' +
  'Judge only from the session; do not assume work you cannot see.'

export function supervisorPrompt(line: SessionLine, verify: string, transcript?: string) {
  return (
    `${SUPERVISOR_RULES}\n\nFeature ${line.feature}, reported ${line.outcome}, gate ${line.gate}.\n` +
    `Verify criterion: ${verify}\n` +
    (transcript === undefined ? 'The session is the conversation above.' : `The session:\n${transcript}`)
  )
}

export type Verdict = { done: boolean; blocked: boolean; skipped: string[] }

export function parseVerdict(text: string): Verdict | undefined {
  const m = /\{[\s\S]*\}/.exec(text)
  if (!m) return undefined
  try {
    const v = JSON.parse(m[0]) as { done?: unknown; blocked?: unknown; skipped_work?: unknown }
    if (typeof v.done !== 'boolean' || typeof v.blocked !== 'boolean' || !Array.isArray(v.skipped_work)) return undefined
    return { done: v.done, blocked: v.blocked, skipped: v.skipped_work.map(x => String(x)).filter(x => x.trim() !== '') }
  } catch {
    return undefined
  }
}

export const skippedPath = (feature: string) => `${RUN_DIR}/decisions/${feature}.skipped.md`

export function skippedFile(feature: string, skipped: string[]) {
  return `# Supervisor: work ${feature} may have skipped\n\n${skipped.map(s => `- ${s}`).join('\n')}\n`
}

export function verdictStatus(feature: string, v: Verdict | undefined) {
  if (!v) return `supervisor ${feature}: no verdict`
  const state = v.blocked ? 'blocked' : v.done ? 'done' : 'not done'
  return v.skipped.length > 0 ? `supervisor ${feature}: ${state}, skipped ${v.skipped.length}` : `supervisor ${feature}: ${state}`
}

// A subagent's conversation as plain text, newest last, capped for a cheap call.
export function transcriptText(messages: { role: string; text: string; toolUses?: { tool?: string }[] }[], max = 12000) {
  const text = messages
    .map(m => `${m.role}: ${m.text}${m.toolUses?.length ? ` [tools: ${m.toolUses.map(t => t.tool ?? '?').join(', ')}]` : ''}`)
    .join('\n')
  return text.length > max ? text.slice(text.length - max) : text
}

// --- M25-003 / M30-002 budget guard, in dollars ----------------------------
// Measured from the session's own cost figure (subagents included), so the
// kit keeps no price table. 0 turns a budget off.

export const DEFAULT_FEATURE_USD = 5
export const DEFAULT_RUN_USD = 50
export const DEFAULT_SESSION_TOKENS = 150_000 // M34-011: a builder's context before it wraps up

export const usd = (n: number) => `$${n.toFixed(2)}`

export function budgetLine(when: string, scope: string, spent: number, budget: number) {
  return `${when} ${scope}: ${usd(spent)} over the ${usd(budget)} budget; run asked to stop after this feature\n`
}

// One line per builder session in .harness-run/cost.log, read by run-report.sh
export function costLine(feature: string, spent: number) {
  return `${feature} ${spent.toFixed(4)}\n`
}

// --- M32-002 tokens in .harness-run/usage.log ---------------------------------
// `<scope> claude <model> <input> <cached> <output>`, scope a feature id or
// `orchestration`; input includes the cache share, cached is the cache read.

export type TurnUsage = {
  input_tokens: number
  output_tokens: number
  cache_creation_input_tokens: number
  cache_read_input_tokens: number
  model?: string
}
export type Tokens = { input: number; cached: number; output: number; model: string }

export function addUsage(sum: Tokens | undefined, u: TurnUsage): Tokens {
  const cached = u.cache_read_input_tokens
  return {
    input: (sum?.input ?? 0) + u.input_tokens + u.cache_creation_input_tokens + cached,
    cached: (sum?.cached ?? 0) + cached,
    output: (sum?.output ?? 0) + u.output_tokens,
    model: u.model || sum?.model || '-',
  }
}

export const usageLine = (scope: string, t: Tokens) => `${scope} claude ${t.model} ${t.input} ${t.cached} ${t.output}\n`

// --- M31-001 where a run's dollars go ------------------------------------------
// Each slice of the session's cost goes to `agents` when at least one subagent
// (builder or evaluator) was running through it, else to `orchestration`. Lanes
// running together share one slice, so nothing is counted twice. Read by
// run-report.sh from .harness-run/run-cost.

export type RunSpend = { agents: number; orchestration: number }

export function runCostText(s: RunSpend) {
  return `agents ${s.agents.toFixed(4)}\norchestration ${s.orchestration.toFixed(4)}\n`
}

// --- M30-001 model choice -----------------------------------------------------
// Aliases only: each resolves to its family's newest model, so a release
// (Haiku 5.5, say) is picked up with nothing to maintain.

export const TIERS = ['haiku', 'sonnet', 'opus'] as const
const SENSITIVE = /auth|payment|billing|migration|secret|credential|personal/i
export const BUILDER_PROMPT = /harness-session for (M\d+-\d{3})/
export const PARALLEL_LANE = /as a parallel lane in /

// A model name's tier: haiku 0, sonnet 1, opus 2, above opus 3; -1 unknown.
export function tierOf(model: string | undefined) {
  const m = (model ?? '').toLowerCase()
  if (m.includes('haiku')) return 0
  if (m.includes('sonnet')) return 1
  if (m.includes('opus')) return 2
  if (m.includes('fable') || m.includes('mythos')) return 3
  return -1
}

type FeatureEntry = { id?: string; model?: unknown; effort?: unknown; paths?: unknown; eval_attempts?: unknown }

export function featureOf(featuresJson: string, id: string): FeatureEntry | undefined {
  try {
    return (JSON.parse(featuresJson) as { features?: FeatureEntry[] }).features?.find(f => f.id === id)
  } catch {
    return undefined
  }
}

export type SpawnFacts = { subagentType: string; prompt: string; model?: string; parentModel: string }
export type ModelChoice = { model: string; feature?: string; reason: string }

const floorTier = (floor: string) => Math.max(0, (TIERS as readonly string[]).indexOf(floor))

// The model a harness subagent should start on, or undefined to leave it be.
export function chooseModel(spawn: SpawnFacts, featuresJson: string, modelsLog: string, floor: string): ModelChoice | undefined {
  const min = floorTier(floor)
  if (spawn.subagentType === 'harness-evaluator') {
    const asked = tierOf(spawn.model ?? spawn.parentModel)
    const want = Math.max(1, min)
    return asked >= 0 && asked < want ? { model: TIERS[want]!, reason: 'evaluator never below sonnet' } : undefined
  }
  const id = BUILDER_PROMPT.exec(spawn.prompt)?.[1] ?? (spawn.subagentType === 'harness-builder' ? /M\d+-\d{3}/.exec(spawn.prompt)?.[0] : undefined)
  if (!id) return undefined
  const f = featureOf(featuresJson, id)
  if (!f) return undefined
  const effort = typeof f.effort === 'string' ? f.effort : 'none'
  // M33-002: a size (or a Claude alias) picks the model; effort only when `model` is absent.
  // Any other value (another CLI's alias) counts as medium.
  const size = typeof f.model === 'string' ? f.model.toLowerCase() : ''
  const sized = size ? { small: 0, medium: 1, large: 2 }[size] ?? (tierOf(size) < 0 ? 1 : Math.min(2, tierOf(size))) : undefined
  const reasons = [sized !== undefined ? `model ${size}` : `effort ${effort}`]
  let tier = sized ?? (effort === 'low' ? 0 : effort === 'high' || effort === 'max' ? 2 : 1)
  const starts = modelsLog.split('\n').filter(l => l.startsWith(`${id} `) && l.endsWith(` notes:${notesKey(featuresJson, id)}`)).length
  const attempts = Number(f.eval_attempts) > 0 ? Number(f.eval_attempts) : 0
  if (starts + attempts > 0) {
    tier += starts + attempts
    reasons.push(`+${starts + attempts} after ${starts} earlier start(s), ${attempts} evaluator rejection(s)`)
  }
  tier = Math.min(2, tier)
  const paths = Array.isArray(f.paths) ? f.paths.map(String) : []
  if (tier < 1 && paths.some(p => SENSITIVE.test(p))) {
    tier = 1
    reasons.push('sensitive paths')
  }
  if (tier < min) {
    tier = min
    reasons.push(`floor ${floor}`)
  }
  return { model: TIERS[tier]!, feature: id, reason: reasons.join(', ') }
}

// Short hash of a feature's notes (M34-004): an owner's answer changes the notes.
export function notesKey(featuresJson: string, id: string) {
  const n = String(featureOf(featuresJson, id)?.notes ?? '')
  let h = 5381
  for (const c of n) h = ((h * 33) ^ c.charCodeAt(0)) >>> 0
  return h.toString(16)
}

export function modelsLine(choice: ModelChoice, featuresJson = '') {
  return `${choice.feature} ${choice.model} ${choice.reason} notes:${notesKey(featuresJson, choice.feature!)}\n`
}

// --- M30-003 status line and /harness ------------------------------------------
// Read from FEATURES.json alone: no model call, no shell.

type Entry = { id: string; milestone?: unknown; title?: string; status?: string; notes?: unknown; depends_on?: unknown; effort?: unknown; paths?: unknown }

export type Facts = {
  passing: number
  total: number
  milestones: { key: string; name: string; passing: number; total: number }[]
  next?: Entry
  waiting: { id: string; question: string }[]
  held: { id: string; on: string }[]
}

const WAITING = /^Needs a human:\s*/

export function harnessFacts(featuresJson: string): Facts | undefined {
  let data: { milestones?: Record<string, string>; features?: Entry[] }
  try {
    data = JSON.parse(featuresJson)
  } catch {
    return undefined
  }
  const fs = (data.features ?? []).filter(f => typeof f?.id === 'string')
  const waiting = fs
    .filter(f => f.status === 'deferred' && WAITING.test(String(f.notes ?? '')))
    .map(f => ({ id: f.id, question: String(f.notes).replace(WAITING, '') }))
  // held: failing features whose depends_on reaches a waiting one, transitively
  const on = new Map<string, string>(waiting.map(w => [w.id, '']))
  const failing = fs.filter(f => f.status === 'failing')
  for (let changed = true; changed; ) {
    changed = false
    for (const f of failing) {
      if (on.has(f.id) || !Array.isArray(f.depends_on)) continue
      const hit = f.depends_on.map(String).find(d => on.has(d))
      if (hit) {
        on.set(f.id, hit)
        changed = true
      }
    }
  }
  const held = [...on].filter(([, v]) => v !== '').map(([id, v]) => ({ id, on: v }))
  const order = (f: Entry) => [Number(f.milestone) || 0, f.id] as const
  const next = failing
    .filter(f => !on.has(f.id))
    .sort((a, b) => order(a)[0] - order(b)[0] || order(a)[1].localeCompare(order(b)[1]))[0]
  const keys = [...new Set(fs.map(f => String(f.milestone)))].sort((a, b) => Number(a) - Number(b))
  return {
    passing: fs.filter(f => f.status === 'passing').length,
    total: fs.length,
    milestones: keys.map(key => {
      const ms = fs.filter(f => String(f.milestone) === key)
      return { key, name: data.milestones?.[key] ?? '?', passing: ms.filter(f => f.status === 'passing').length, total: ms.length }
    }),
    next,
    waiting,
    held,
  }
}

export type LineState = { feature?: string; model?: string; spent?: number; budget?: number; notice?: string }

export function statusLineText(f: Facts, s: LineState) {
  const parts = [`harness ${s.feature ?? f.next?.id ?? 'done'}`, `${f.passing}/${f.total} passing`]
  if (s.spent !== undefined) parts.push(s.budget ? `${usd(s.spent)}/${usd(s.budget)}` : usd(s.spent))
  if (s.model) parts.push(s.model)
  if (f.waiting.length > 0) parts.push(`${f.waiting.length} waiting on you`)
  if (s.notice) parts.push(s.notice)
  return parts.join(' · ')
}

export function harnessReport(f: Facts, runCost?: number) {
  const lines = ['Harness status', '']
  for (const m of f.milestones) lines.push(`M${m.key}: ${m.passing}/${m.total} passing — ${m.name}`)
  lines.push('', `${f.passing}/${f.total} features passing`)
  if (f.next) {
    lines.push('', `Next: ${f.next.id} — ${f.next.title ?? ''}`)
    if (typeof f.next.effort === 'string') lines.push(`  effort: ${f.next.effort}`)
    if (Array.isArray(f.next.paths) && f.next.paths.length > 0) lines.push(`  paths: ${f.next.paths.join(', ')}`)
  } else {
    lines.push('', 'Next: nothing eligible')
  }
  if (f.waiting.length > 0) {
    lines.push('', 'Waiting on you:')
    for (const w of f.waiting) lines.push(`  ${w.id} — ${w.question}`)
    for (const h of f.held) lines.push(`  held: ${h.id} (depends on ${h.on})`)
  }
  if (runCost !== undefined) lines.push('', `This session so far: ${usd(runCost)}`)
  return lines.join('\n')
}
