import type { Register } from 'claude-code'

import { appendLine, DECISION_TOOL, decisionSpec, decisionsPath, parseDecision, PLUGIN, RUN_DIR } from './lib'

// agent-harness-kit-claude: Claude Code-only additions to the harness.
// Every feature stays inert outside a harnessed repo (no FEATURES.json).
// All hooks live in this file: the engine follows `$` only within it.
export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const started = await next(e)
    const isHarnessed = await $.fs.exists('FEATURES.json').catch(() => false)
    if (isHarnessed) {
      await $.tool.register(decisionSpec)
    }
    return started
  })

  // M25-001 — decision register: one line per call in .harness-run/decisions/<id>.md
  on('tool.call', { tool: `mcp__${PLUGIN}__${DECISION_TOOL}` }, async ($, e) => {
    const parsed = parseDecision(e as unknown as Record<string, unknown>)
    if ('error' in parsed) return { deny: parsed.error }
    const path = decisionsPath(parsed.feature)
    const before = (await $.fs.exists(path)) ? await $.fs.read(path) : undefined
    await $.fs.write(path, appendLine(before, parsed.feature, parsed.line))
    // A self-ignoring run folder keeps the worktree clean for harness-run.
    if (!(await $.fs.exists(`${RUN_DIR}/.gitignore`))) await $.fs.write(`${RUN_DIR}/.gitignore`, '*\n')
    return { result: { recorded: parsed.line, file: path } }
  })
}
