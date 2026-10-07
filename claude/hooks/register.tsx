import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import {
  appendLine,
  budgetLine,
  countedTokens,
  DEFAULT_BUDGET,
  nextStepPrompts,
  DECISION_TOOL,
  decisionSpec,
  decisionsPath,
  parseDecision,
  parseSessionLine,
  parseVerdict,
  PLUGIN,
  RUN_DIR,
  skippedFile,
  skippedPath,
  supervisorPrompt,
  transcriptText,
  verdictStatus,
  verifyOf,
} from './lib'

// agent-harness-kit-claude: Claude Code-only additions to the harness.
// Every feature stays inert outside a harnessed repo (no FEATURES.json).
// All hooks live in this file: the engine follows `$` only within it.
// M25-004 — what the next-steps band draws from (the session's state).
const lastPassing = atom({ plugin: 'agent-harness-kit-claude', key: 'lastPassing' } as const, null)
const isHidden = atom({ plugin: 'agent-harness-kit-claude', key: 'isHidden' } as const, false)

export const register: Register = (on, options) => {
  let isHarnessed = false
  const checked = new Set<string>()
  const budget = typeof options.feature_token_budget === 'number' ? options.feature_token_budget : DEFAULT_BUDGET
  const used = new Map<string, number>() // per builder subagent, or 'main' between SESSION lines
  const flagged = new Set<string>()

  on('session.start', async ($, e, next) => {
    const started = await next(e)
    isHarnessed = await $.fs.exists('FEATURES.json').catch(() => false)
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

  // M25-002 — done-check supervisor: a session that ends with its SESSION line
  // gets one cheap check against the feature's verify. The main loop forks its
  // own (cached) transcript; a builder subagent's messages are read and sent
  // to a small model, since a fork only ever sees the main thread.
  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    if (!isHarnessed) return result
    const line = parseSessionLine(e.answer)

    // M25-003 — budget guard: count what each feature spends. A builder
    // subagent is one feature; the main loop counts between SESSION lines.
    const who = e.agentId ?? 'main'
    const total = (used.get(who) ?? 0) + countedTokens(e.usage)
    used.set(who, total)
    if (total > budget && !flagged.has(who)) {
      flagged.add(who)
      $.ui.status(`budget: ${who} used ${total} tokens (budget ${budget})`)
      if (await $.fs.exists(`${RUN_DIR}/start`)) {
        const log = `${RUN_DIR}/budget.log`
        const before = (await $.fs.exists(log)) ? await $.fs.read(log) : ''
        await $.fs.write(log, before + budgetLine(new Date().toISOString(), who, total, budget))
        await $.fs.write(`${RUN_DIR}/STOP`, `budget: ${who} used ${total} tokens\n`)
      }
    }
    if (line && who === 'main') {
      used.delete('main')
      flagged.delete('main')
    }

    if (!line) return result
    // M25-004 — a supervised (not unattended) main-loop session that passed
    // gets the next-steps band; anything else clears it.
    if (who === 'main') {
      const isRun = await $.fs.exists(`${RUN_DIR}/start`)
      const step = line.outcome === 'passing' && !isRun ? { feature: line.feature } : null
      await update($, lastPassing, () => step)
      await update($, isHidden, () => false)
    }
    // One check per feature outcome: an orchestrator echoing a builder's
    // SESSION line must not pay for a second check.
    const key = `${line.feature} ${line.outcome}`
    if (checked.has(key)) return result
    checked.add(key)
    const verify = verifyOf(await $.fs.read('FEATURES.json').catch(() => ''), line.feature)
    if (verify === undefined) return result

    let reply: string | undefined
    if (e.agentId === undefined) {
      const forked = await $.model.fork({ prompt: supervisorPrompt(line, verify) })
      reply = forked.isAnswered ? forked.text : undefined
    } else {
      const messages = await $.session.messages({ agentId: e.agentId })
      if (Array.isArray(messages)) {
        const done = await $.model.complete({ model: 'haiku', prompt: supervisorPrompt(line, verify, transcriptText(messages)), maxTokens: 400 })
        reply = done.isAnswered ? done.text : undefined
      }
    }

    const verdict = reply === undefined ? undefined : parseVerdict(reply)
    if (verdict && verdict.skipped.length > 0) {
      await $.fs.write(skippedPath(line.feature), skippedFile(line.feature, verdict.skipped))
      if (!(await $.fs.exists(`${RUN_DIR}/.gitignore`))) await $.fs.write(`${RUN_DIR}/.gitignore`, '*\n')
    }
    $.ui.status(verdictStatus(line.feature, verdict))
    return result
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const step = await read($, lastPassing)
    if (step === null || e.props.hasSurvey || (await read($, isHidden))) return next(e)
    const prompts = nextStepPrompts(step.feature)
    const { Box, Button, Text } = $.ui.resolve(e)
    return (
      <Box>
        <Text dimColor>{step.feature} passed. Next: </Text>
        <Button key="next" label="Next feature" variant="primary" onPress={() => $.prompt.fill({ text: prompts.next, mode: 'replace' })} />
        <Button key="explain" label="Explain" onPress={() => $.prompt.fill({ text: prompts.explain, mode: 'replace' })} />
        <Button key="quiz" label="Quiz me" onPress={() => $.prompt.fill({ text: prompts.quiz, mode: 'replace' })} />
        <Button key="hide" label="Hide" role="dismiss" onPress={() => update($, isHidden, () => true)} />
      </Box>
    )
  })
}
