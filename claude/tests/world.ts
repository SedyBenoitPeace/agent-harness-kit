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
  on('ui.status', async () => ({ value: undefined }))
  return { files, registered }
}
