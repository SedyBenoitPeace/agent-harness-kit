import { describe, expect, test } from 'claude-code/testing'

import { models, START, turn, world } from './world'

const FEATURES = JSON.stringify({
  milestones: { '1': 'Core', '2': 'Ship' },
  features: [
    { id: 'M1-001', milestone: 1, title: 'boot', status: 'passing', verify: 'x' },
    { id: 'M1-002', milestone: 1, title: 'parser', status: 'failing', verify: 'x', effort: 'low', paths: ['src/parser/'] },
    { id: 'M2-001', milestone: 2, title: 'deploy', status: 'deferred', verify: 'x', notes: 'Needs a human: who approves the deploy?' },
    { id: 'M2-002', milestone: 2, title: 'smoke', status: 'failing', verify: 'x', depends_on: ['M2-001'] },
  ],
})
const BUDGET = { options: { feature_budget_usd: 5 } }

describe('status line and /harness (M30-003)', () => {
  test('shows feature, passing/total, dollars against budget, model and what waits on you', BUDGET, async ($, on) => {
    const w = world(on, { 'FEATURES.json': FEATURES })
    models(on, '{}')
    w.cost.usd = 1
    await $.session.start(START)
    expect(w.statuses.at(-1)).toBe('harness M1-002 · 1/4 passing · $0.00/$5.00 · 1 waiting on you')
    await $.agent.spawn({ prompt: 'Use harness-session for M1-002, inline.', subagentType: 'harness-builder' })
    w.cost.usd = 2.4
    await $.turn.complete(turn('working', 'agent-1'))
    expect(w.statuses.at(-1)).toBe('harness M1-002 · 1/4 passing · $1.40/$5.00 · haiku · 1 waiting on you')
  })

  test('a budget notice stays on the line', { options: { feature_budget_usd: 1 } }, async ($, on) => {
    const w = world(on, { 'FEATURES.json': FEATURES })
    models(on, '{}')
    w.cost.usd = 0
    await $.session.start(START)
    w.cost.usd = 1.5
    await $.turn.complete(turn('working'))
    await $.turn.complete(turn('more'))
    expect(w.statuses.at(-1)).toContain('budget: feature in progress $1.50 of $1.00')
  })

  test('/harness reports milestones, next (held ones skipped), what waits and cost, with no model call', async ($, on) => {
    const w = world(on, { 'FEATURES.json': FEATURES })
    const m = models(on, '{}')
    w.cost.usd = 0.75
    await $.session.start(START)
    const out = await $.command.run({ command: 'harness', args: '' })
    expect(out.text).toContain('M1: 1/2 passing — Core')
    expect(out.text).toContain('Next: M1-002 — parser')
    expect(out.text).toContain('paths: src/parser/')
    expect(out.text).toContain('M2-001 — who approves the deploy?')
    expect(out.text).toContain('held: M2-002 (depends on M2-001)')
    expect(out.text).toContain('$0.75')
    expect(m.fork.length + m.complete.length).toBe(0)
  })

  test('/harness outside a harnessed repo says so', async ($, on) => {
    world(on, {})
    await $.session.start(START)
    const out = await $.command.run({ command: 'harness', args: '' })
    expect(out.text).toContain('No harness here')
  })
})
