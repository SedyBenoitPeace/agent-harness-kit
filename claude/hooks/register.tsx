import type { EngineInterface, Register } from 'claude-code'

import {
  addUsage,
  appendLine,
  budgetLine,
  chooseModel,
  costLine,
  modelsLine,
  DEFAULT_FEATURE_USD,
  DEFAULT_RUN_USD,
  DECISION_TOOL,
  decisionSpec,
  harnessFacts,
  harnessReport,
  type LineState,
  decisionsPath,
  parseDecision,
  parseSessionLine,
  parseVerdict,
  PLUGIN,
  RUN_DIR,
  runCostText,
  type RunSpend,
  PARALLEL_LANE,
  skippedFile,
  skippedPath,
  type Tokens,
  statusLineText,
  supervisorPrompt,
  transcriptText,
  usageLine,
  usd,
  verdictStatus,
  verifyOf,
} from './lib'

// agent-harness-kit-claude: Claude Code-only additions to the harness.
// Every feature stays inert outside a harnessed repo (no FEATURES.json).
// All hooks live in this file: the engine follows `$` only within it.

// M30-003 — the plugin's own status line (beside the person's own one):
// feature, passing/total, dollars against the feature budget, model,
// features waiting on a human, and the last notice.
async function showStatus($: EngineInterface, shown: LineState, featureBase: number | undefined, budget: number) {
  const facts = harnessFacts(await $.fs.read('FEATURES.json').catch(() => ''))
  if (!facts) return
  const cost = await $.session.usage().then(u => u.cost?.usd).catch(() => undefined)
  const spent = cost !== undefined && featureBase !== undefined ? cost - featureBase : undefined
  $.ui.status(statusLineText(facts, { ...shown, spent, budget }))
}

// M31-001 — credit the session cost since the last event to whoever was
// running through it (any subagent, or the orchestrator alone), and keep the
// run's split in .harness-run/run-cost for run-report.sh.
type Ledger = { running: Set<string>; spend: RunSpend; lastCost?: number }
const sessionCost = ($: EngineInterface) => $.session.usage().then(u => u.cost?.usd).catch(() => undefined)
async function runStart($: EngineInterface) {
  return (await $.fs.exists(`${RUN_DIR}/start`)) ? await $.fs.read(`${RUN_DIR}/start`) : undefined
}
async function tally($: EngineInterface, l: Ledger) {
  const cost = await $.session.usage().then(u => u.cost?.usd).catch(() => undefined)
  if (cost === undefined) return
  if (l.lastCost !== undefined && cost > l.lastCost) l.spend[l.running.size > 0 ? 'agents' : 'orchestration'] += cost - l.lastCost
  l.lastCost = cost
  if (await $.fs.exists(`${RUN_DIR}/start`)) await $.fs.write(`${RUN_DIR}/run-cost`, runCostText(l.spend))
}

export const register: Register = (on, options) => {
  let isHarnessed = false
  const checked = new Set<string>()
  const num = (v: unknown, d: number) => (typeof v === 'number' && v >= 0 ? v : d)
  const featureBudget = num(options.feature_budget_usd, DEFAULT_FEATURE_USD)
  const runBudget = num(options.run_budget_usd, DEFAULT_RUN_USD)
  let featureBase: number | undefined // session cost when the current feature began
  let runBase: number | undefined // session cost when this session first saw the run
  let isFeatureFlagged = false
  let isRunFlagged = false
  const builderTokens = new Map<string, Tokens>() // per builder subagent, summed over its turns (M32-002)
  const measured = new Set<string>() // features whose cost is logged since their builder started
  const shown: { feature?: string; model?: string; notice?: string } = {} // what the status line shows (M30-003)
  const route = options.route_models !== false
  const supervisor = options.supervisor === true // M34-004: off by default
  const lanes = new Set<string>() // parallel-lane builders, never judged
  const floor = typeof options.model_floor === 'string' ? options.model_floor : 'haiku'
  // M31-001 — the run's cost split: agents running vs the orchestrator alone
  const ledger: Ledger = { running: new Set(), spend: { agents: 0, orchestration: 0 } }


  // M34-004 — a new .harness-run/start is a new run: its dollars, budgets and
  // pending builder usage count from here, not from the run before it.
  let seenStart: string | undefined
  const applyStart = (start: string | undefined, cost: number | undefined) => {
    if (start === seenStart) return
    seenStart = start
    if (start === undefined) return
    ledger.spend = { agents: 0, orchestration: 0 }
    ledger.lastCost = cost
    runBase = cost
    featureBase = cost
    isRunFlagged = false
    isFeatureFlagged = false
    builderTokens.clear()
    measured.clear()
  }

  on('session.start', async ($, e, next) => {
    const started = await next(e)
    isHarnessed = await $.fs.exists('FEATURES.json').catch(() => false)
    if (isHarnessed) {
      await $.tool.register(decisionSpec)
      // budgets count from here (M30-002)
      featureBase = await $.session.usage().then(u => u.cost?.usd).catch(() => undefined)
      ledger.lastCost = featureBase
      if (await $.fs.exists(`${RUN_DIR}/start`)) runBase = featureBase
      seenStart = await runStart($)
      await showStatus($, shown, featureBase, featureBudget)
    }
    await $.command.register({ name: 'harness', description: 'Harness status: milestones, next feature, what waits on you, cost (no model call)' })
    return started
  })

  // M30-003 — /harness: the status from FEATURES.json, no model call
  on('command.run', { command: 'harness' }, async $ => {
    const facts = harnessFacts(await $.fs.read('FEATURES.json').catch(() => ''))
    if (!facts) return { text: 'No harness here: FEATURES.json is missing or not valid JSON.' }
    const cost = await $.session.usage().then(u => u.cost?.usd).catch(() => undefined)
    return { text: harnessReport(facts, cost) }
  })

  // M30-001 — model choice: a harness builder starts on the model its
  // feature's effort asks for, one tier up per earlier start or evaluator
  // rejection; the evaluator and sensitive features never below sonnet.
  // The main session, forks, teammates and workflow agents are left alone.
  on('agent.spawn', async ($, e, next) => {
    if (isHarnessed && !e.fork) {
      applyStart(await runStart($), await sessionCost($))
      await tally($, ledger)
    }
    const track = <T,>(started: T) => {
      const id = (started as { agentId?: unknown } | undefined)?.agentId
      if (isHarnessed && !e.fork && typeof id === 'string') ledger.running.add(id)
      return started
    }
    if (!isHarnessed || !route || e.fork || e.isTeammate || e.workflow) return track(await next(e))
    const features = await $.fs.read('FEATURES.json').catch(() => '')
    const logPath = `${RUN_DIR}/models.log`
    const log = (await $.fs.exists(logPath)) ? await $.fs.read(logPath) : ''
    const choice = chooseModel(e, features, log, floor)
    if (!choice) return track(await next(e))
    const started = track(await next({ ...e, model: choice.model }))
    const laneId = (started as { agentId?: unknown } | undefined)?.agentId
    if (PARALLEL_LANE.test(e.prompt) && typeof laneId === 'string') lanes.add(laneId)
    if (choice.feature) {
      shown.feature = choice.feature
      shown.model = choice.model
      await showStatus($, shown, featureBase, featureBudget)
      measured.delete(choice.feature)
      await $.fs.write(logPath, log + modelsLine(choice, features))
      if (!(await $.fs.exists(`${RUN_DIR}/.gitignore`))) await $.fs.write(`${RUN_DIR}/.gitignore`, '*\n')
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
    applyStart(await runStart($), await sessionCost($))
    await tally($, ledger)
    if (e.agentId !== undefined) ledger.running.delete(e.agentId)
    const line = parseSessionLine(e.answer)

    // M32-002 — tokens for the run report: a builder's turns sum on its
    // feature at its SESSION line; the orchestrator's own turns are
    // orchestration. Each subagent has its own usage, so lanes count once.
    if (e.usage && (await $.fs.exists(`${RUN_DIR}/start`))) {
      const logUsage = async (scope: string, t: Tokens) => {
        const path = `${RUN_DIR}/usage.log`
        const before = (await $.fs.exists(path)) ? await $.fs.read(path) : ''
        await $.fs.write(path, before + usageLine(scope, t))
      }
      if (e.agentId === undefined) await logUsage('orchestration', addUsage(undefined, e.usage))
      else {
        const t = addUsage(builderTokens.get(e.agentId), e.usage)
        builderTokens.set(e.agentId, t)
        if (line) {
          builderTokens.delete(e.agentId)
          await logUsage(line.feature, t)
        }
      }
    }

    // M30-002 — budget guard in dollars: what the feature (since the last
    // SESSION line) and the run (since this session saw it) have cost.
    const cost = await $.session.usage().then(u => u.cost?.usd).catch(() => undefined)
    if (cost !== undefined) {
      featureBase ??= cost
      const isRun = await $.fs.exists(`${RUN_DIR}/start`)
      if (isRun) runBase ??= cost
      const stop = async (scope: string, spent: number, budget: number) => {
        shown.notice = `budget: ${scope} ${usd(spent)} of ${usd(budget)}`
        if (!isRun) return
        const log = `${RUN_DIR}/budget.log`
        const before = (await $.fs.exists(log)) ? await $.fs.read(log) : ''
        await $.fs.write(log, before + budgetLine(new Date().toISOString(), scope, spent, budget))
        await $.fs.write(`${RUN_DIR}/STOP`, `budget: ${scope} ${usd(spent)} of ${usd(budget)}\n`)
      }
      const spent = cost - featureBase
      if (featureBudget > 0 && spent > featureBudget && !isFeatureFlagged) {
        isFeatureFlagged = true
        await stop(`feature ${line?.feature ?? 'in progress'}`, spent, featureBudget)
      }
      if (isRun && runBase !== undefined && runBudget > 0 && cost - runBase > runBudget && !isRunFlagged) {
        isRunFlagged = true
        await stop('run', cost - runBase, runBudget)
      }
      // each builder session's cost, once (an orchestrator echoing its
      // SESSION line is not a second session)
      if (line && !measured.has(line.feature)) {
        measured.add(line.feature)
        if (isRun) {
          const log = `${RUN_DIR}/cost.log`
          const before = (await $.fs.exists(log)) ? await $.fs.read(log) : ''
          await $.fs.write(log, before + costLine(line.feature, spent))
        }
      }
      if (line) {
        featureBase = cost
        isFeatureFlagged = false
      }
    }

    await showStatus($, shown, featureBase, featureBudget)
    if (!line || !supervisor || (e.agentId !== undefined && lanes.has(e.agentId))) return result
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
    shown.notice = verdictStatus(line.feature, verdict)
    await showStatus($, shown, featureBase, featureBudget)
    return result
  })
}
