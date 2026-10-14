import { describe, expect, test } from 'claude-code/testing'

import { FEATURES, models, START, turn, world } from './world'

const BUDGET = { options: { feature_budget_usd: 2, run_budget_usd: 5 } }
const RUN = { 'FEATURES.json': FEATURES, '.harness-run/start': 'abc123\n' }
const DONE = '{"done": true, "blocked": false, "skipped_work": []}'
const session = (id: string) => `SESSION: ${id} · passing · gate green · c1`
const written = (files: Record<string, string>) => Object.keys(files).filter(p => !(p in RUN))

describe('budget guard in dollars (M30-002)', () => {
  test('a feature over its budget during a run writes STOP and a reason', BUDGET, async ($, on) => {
    const w = world(on, { ...RUN })
    models(on, '{}')
    w.cost.usd = 0.1
    await $.session.start(START)
    await $.turn.complete(turn('working', 'agent-1'))
    w.cost.usd = 1.5
    await $.turn.complete(turn('still working', 'agent-1'))
    expect(w.files['.harness-run/STOP']).toBeUndefined()
    w.cost.usd = 2.4
    await $.turn.complete(turn('and more', 'agent-1'))
    expect(w.files['.harness-run/STOP']).toBeDefined()
    expect(w.files['.harness-run/budget.log']).toContain('$2.30 over the $2.00 budget')
    expect(w.statuses.at(-1)).toContain('budget')
  })

  test('the run over its budget writes STOP even when each feature stays under', BUDGET, async ($, on) => {
    const w = world(on, { ...RUN })
    models(on, DONE)
    w.cost.usd = 0
    await $.session.start(START)
    for (const [i, id] of ['M1-001', 'M1-002', 'M1-003'].entries()) {
      w.cost.usd = 1.8 * (i + 1)
      await $.turn.complete(turn(session(id), `agent-${i}`))
    }
    expect(w.files['.harness-run/budget.log']).toContain('run: $5.40 over the $5.00 budget')
    expect(w.files['.harness-run/STOP']).toBeDefined()
  })

  test('each builder session logs its cost once; an orchestrator echo does not', BUDGET, async ($, on) => {
    const w = world(on, { ...RUN })
    models(on, DONE)
    w.cost.usd = 0.5
    await $.session.start(START)
    w.cost.usd = 1.25
    await $.turn.complete(turn(session('M1-001'), 'agent-1'))
    w.cost.usd = 1.3
    await $.turn.complete(turn(session('M1-001')))
    expect(w.files['.harness-run/cost.log']).toBe('M1-001 0.7500\n')
  })

  test("staying under budget writes no STOP or budget log, only the run's cost split", BUDGET, async ($, on) => {
    const w = world(on, { ...RUN })
    models(on, '{}')
    w.cost.usd = 0
    await $.session.start(START)
    w.cost.usd = 1
    await $.turn.complete(turn('a', 'agent-1'))
    expect(written(w.files)).toEqual(['.harness-run/run-cost'])
  })

  test('outside a run it warns but never writes STOP', BUDGET, async ($, on) => {
    const w = world(on, { 'FEATURES.json': FEATURES })
    models(on, '{}')
    w.cost.usd = 0
    await $.session.start(START)
    await $.turn.complete(turn('a'))
    w.cost.usd = 3
    await $.turn.complete(turn('b'))
    expect(w.files['.harness-run/STOP']).toBeUndefined()
    expect(w.statuses.at(-1)).toContain('budget')
  })

  test('a host without a cost ledger takes no budget action', BUDGET, async ($, on) => {
    const w = world(on, { ...RUN })
    models(on, '{}')
    await $.session.start(START)
    await $.turn.complete(turn('a', 'agent-1'))
    expect(written(w.files)).toEqual([])
  })

  test('0 turns a budget off', { options: { feature_budget_usd: 0, run_budget_usd: 0 } }, async ($, on) => {
    const w = world(on, { ...RUN })
    models(on, '{}')
    w.cost.usd = 0
    await $.session.start(START)
    await $.turn.complete(turn('a', 'agent-1'))
    w.cost.usd = 500
    await $.turn.complete(turn('b', 'agent-1'))
    expect(w.files['.harness-run/STOP']).toBeUndefined()
  })

  test('a run splits its cost into feature agents and orchestration (M31-001)', BUDGET, async ($, on) => {
    const w = world(on, { ...RUN })
    models(on, DONE)
    const spawn = (id: string) => $.agent.spawn({ prompt: `Use harness-session for ${id}, inline.`, subagentType: 'harness-builder' })
    w.cost.usd = 0
    await $.session.start(START)
    w.cost.usd = 0.5 // orchestrator: context, status
    await spawn('M1-001')
    w.cost.usd = 3.5 // builder agent-1 at work
    await $.turn.complete(turn(session('M1-001'), 'agent-1'))
    w.cost.usd = 4 // orchestrator: verify, next dispatch
    await spawn('M1-002')
    w.cost.usd = 6
    await $.turn.complete(turn(session('M1-002'), 'agent-2'))
    w.cost.usd = 6.25 // orchestrator: report
    await $.turn.complete(turn('run complete'))
    expect(w.files['.harness-run/run-cost']).toBe('agents 5.0000\norchestration 1.2500\n')
  })

  test('parallel lanes are counted once, not once per lane (M31-001)', BUDGET, async ($, on) => {
    const w = world(on, { ...RUN })
    models(on, DONE)
    const spawn = (id: string) => $.agent.spawn({ prompt: `Use harness-session for ${id}, inline, as a parallel lane.`, subagentType: 'harness-builder' })
    w.cost.usd = 0
    await $.session.start(START)
    w.cost.usd = 1
    await spawn('M1-001')
    await spawn('M1-002')
    w.cost.usd = 5
    await $.turn.complete(turn(session('M1-001'), 'agent-1'))
    w.cost.usd = 7
    await $.turn.complete(turn(session('M1-002'), 'agent-2'))
    w.cost.usd = 7.5 // merges and the full gate
    await $.turn.complete(turn('batch merged'))
    expect(w.files['.harness-run/run-cost']).toBe('agents 6.0000\norchestration 1.5000\n')
  })

  test('outside a run no run cost is written (M31-001)', BUDGET, async ($, on) => {
    const w = world(on, { 'FEATURES.json': FEATURES })
    models(on, '{}')
    w.cost.usd = 0
    await $.session.start(START)
    w.cost.usd = 1
    await $.turn.complete(turn('a'))
    expect(w.files['.harness-run/run-cost']).toBeUndefined()
  })

  test('does nothing outside a harnessed repo', BUDGET, async ($, on) => {
    const w = world(on, {})
    models(on, '{}')
    w.cost.usd = 0
    await $.session.start(START)
    w.cost.usd = 50
    await $.turn.complete(turn('a', 'agent-1'))
    expect(Object.keys(w.files)).toEqual([])
    expect(w.statuses).toEqual([])
  })
})
