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

// --- M25-003 budget guard -------------------------------------------------

export const DEFAULT_BUDGET = 1_500_000

// Tokens that cost real money: input, output and cache writes. Cache reads are
// a tenth of the price and dominate long sessions, so they are left out.
export function countedTokens(usage: { input_tokens: number; output_tokens: number; cache_creation_input_tokens: number } | undefined) {
  return usage ? usage.input_tokens + usage.output_tokens + usage.cache_creation_input_tokens : 0
}

export function budgetLine(when: string, who: string, used: number, budget: number) {
  return `${when} ${who}: ${used} tokens over the ${budget} budget; run asked to stop after this feature\n`
}

// --- M25-004 next-steps band ------------------------------------------------

export const nextStepPrompts = (feature: string) => ({
  next: 'Implement the next feature in this repo, following the harness.',
  explain: `Explain what ${feature} changed: big picture, few words. A diagram if it helps.`,
  quiz: `Quiz me with three multiple-choice questions on what ${feature} shipped, one at a time, so I know I understand it.`,
})
