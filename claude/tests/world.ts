import type { On } from 'claude-code'

export const PLUGIN = 'agent-harness-kit-claude'
export const START = { cwd: '/repo', surface: null, isInteractive: false } as const

// The world beneath the plugin, in memory: session.start, the working
// directory's files, and tool registration.
// The engine resolves fs paths against the plugin folder (claude/); the
// in-memory files are keyed relative to it, as the repo root would be.
export const rel = (p: string) => (p.includes('/claude/') ? p.slice(p.lastIndexOf('/claude/') + 8) : p)

export function world(on: On, files: Record<string, string> = {}) {
  const registered: string[] = []
  on('session.start', async (_$, e) => ({ cwd: e.cwd }))
  on('fs.exists', async (_$, e) => ({ value: rel(e.path) in files }))
  on('fs.read', async (_$, e) => {
    const text = files[rel(e.path)]
    if (text === undefined) throw new Error(`ENOENT: ${rel(e.path)}`)
    return { value: text }
  })
  on('fs.write', async (_$, e) => {
    files[rel(e.path)] = e.text
    return { value: undefined }
  })
  on('tool.register', async (_$, e) => {
    registered.push(e.name)
    return { value: { tool: `mcp__${PLUGIN}__${e.name}` } }
  })
  const statuses: (string | undefined)[] = []
  on('ui.status', async (_$, e) => {
    statuses.push((e as { text?: string }).text)
    return { value: undefined }
  })
  on('turn.complete', async (_$, e) => ({ text: e.answer }))
  return { files, registered, statuses }
}

export const USAGE = { input_tokens: 10, output_tokens: 5, cache_creation_input_tokens: 0, cache_read_input_tokens: 0 }

export const FEATURES = JSON.stringify({
  milestones: { '1': 'One' },
  features: [{ id: 'M1-001', milestone: 1, title: 'greet', status: 'passing', verify: 'greet.sh Ada prints Hello, Ada!' }],
})

// Model calls beneath the plugin: each answers `reply`, and is recorded.
export function models(on: On, reply: string) {
  const calls = { fork: [] as string[], complete: [] as string[], messages: [] as (string | undefined)[] }
  const answer = { value: { isAnswered: true as const, text: reply, usage: USAGE } }
  on('model.fork', async (_$, e) => {
    calls.fork.push(e.prompt)
    return answer
  })
  on('model.complete', async (_$, e) => {
    calls.complete.push(e.prompt)
    return answer
  })
  on('session.messages', async (_$, e) => {
    calls.messages.push(e.agentId)
    return { value: [{ role: 'assistant' as const, text: 'built greet.sh, skipped the usage check', toolUses: [] }] }
  })
  return calls
}

export const turn = (answer: string, agentId?: string) => ({
  answer,
  durationMs: 1000,
  isAborted: false,
  turnId: 't1',
  reason: 'answer' as const,
  ...(agentId ? { agentId } : {}),
})
