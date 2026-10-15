import { describe, expect, test } from 'claude-code/testing'

import { FEATURES, models, START, turn, world } from './world'

const SESSION_OK = 'Done.\nSESSION: M1-001 · passing · gate green · abc123'
const CLEAN = '{"done": true, "blocked": false, "skipped_work": []}'
const feature = (extra: Record<string, unknown> = {}) => ({ id: 'M1-001', milestone: 1, title: 'x', status: 'failing', verify: 'x', effort: 'low', ...extra })
const featuresOf = (extra: Record<string, unknown> = {}) => JSON.stringify({ milestones: { '1': 'One' }, features: [feature(extra)] })
const builder = { prompt: 'Use harness-session for M1-001, inline. End with its SESSION line.', subagentType: 'harness-builder' }
// harness-run's Parallel lanes step, verbatim
const lane = { prompt: 'Use harness-session for M1-001, inline, as a parallel lane in ../repo-M1-001. End with its SESSION line.', subagentType: 'general-purpose' }

describe('run-scoped ledger (M34-004)', () => {
  test('a new .harness-run/start resets cost split, budgets and pending usage', { options: { run_budget_usd: 5 } }, async ($, on) => {
    const w = world(on, { 'FEATURES.json': FEATURES, '.harness-run/start': 'run1\n' })
    models(on, CLEAN)
    w.cost.usd = 0
    await $.session.start(START)
    w.cost.usd = 4
    await $.turn.complete(turn('orchestrating', undefined, 1000))
    await $.turn.complete(turn('half a builder', 'agent-1', 1000))
    expect(w.files['.harness-run/run-cost']).toBe('agents 0.0000\norchestration 4.0000\n')
    w.files['.harness-run/start'] = 'run2\n'
    w.cost.usd = 6
    await $.turn.complete(turn('new run', undefined, 1000))
    w.cost.usd = 8
    await $.turn.complete(turn('more', undefined, 1000))
    // run 1's dollars are gone from run 2: no STOP, split holds only the 2 spent since
    expect(w.files['.harness-run/run-cost']).toBe('agents 0.0000\norchestration 2.0000\n')
    expect(w.files['.harness-run/STOP']).toBeUndefined()
    // pending builder usage of run 1 is dropped: only run 2's turn is summed
    await $.turn.complete(turn(SESSION_OK, 'agent-1', 500))
    expect(w.files['.harness-run/usage.log']!.split('\n').at(-2)).toBe('M1-001 claude claude-sonnet-5-5 50400 50000 100')
  })
})

describe('models.log for lanes (M34-004)', () => {
  test('the exact parallel-lane prompt writes a models.log line', async ($, on) => {
    const w = world(on, { 'FEATURES.json': featuresOf() })
    await $.session.start(START)
    await $.agent.spawn(lane)
    expect(w.spawns[0]!.model).toBe('haiku')
    expect(w.files['.harness-run/models.log']).toMatch(/^M1-001 haiku effort low/)
  })
})

describe('step-up after a notes change (M34-004)', () => {
  test('same notes step up, changed notes start fresh', async ($, on) => {
    const w = world(on, { 'FEATURES.json': featuresOf({ notes: 'Needs a human: which db?' }) })
    await $.session.start(START)
    await $.agent.spawn(builder)
    await $.agent.spawn(builder)
    w.files['FEATURES.json'] = featuresOf({ notes: 'Answer: sqlite' })
    await $.agent.spawn(builder)
    await $.agent.spawn(builder)
    expect(w.spawns.map(s => s.model)).toEqual(['haiku', 'sonnet', 'haiku', 'sonnet'])
  })
})

describe('supervisor default (M34-004)', () => {
  test('off by default: no model call', async ($, on) => {
    world(on, { 'FEATURES.json': FEATURES })
    const m = models(on, CLEAN)
    await $.session.start(START)
    await $.turn.complete(turn(SESSION_OK))
    await $.turn.complete(turn(SESSION_OK.replace('M1-001', 'M1-002'), 'agent-1'))
    expect(m.fork.length + m.complete.length).toBe(0)
  })

  test('supervisor true turns it on', { options: { supervisor: true } }, async ($, on) => {
    world(on, { 'FEATURES.json': FEATURES })
    const m = models(on, CLEAN)
    await $.session.start(START)
    await $.turn.complete(turn(SESSION_OK))
    expect(m.fork.length).toBe(1)
  })

  test('never judges a parallel-lane builder, even when on', { options: { supervisor: true } }, async ($, on) => {
    world(on, { 'FEATURES.json': JSON.stringify({ features: [{ id: 'M1-001', milestone: 1, status: 'failing', verify: 'x' }] }) })
    const m = models(on, CLEAN)
    await $.session.start(START)
    const started = await $.agent.spawn(lane)
    await $.turn.complete(turn(SESSION_OK, (started as { agentId: string }).agentId))
    expect(m.fork.length + m.complete.length).toBe(0)
  })
})
