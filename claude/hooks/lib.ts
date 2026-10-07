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
