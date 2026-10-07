import { describe, expect, test } from 'claude-code/testing'

import { FEATURES, models, START, turn, world } from './world'

const BUDGET = { options: { feature_token_budget: 1000 } }
const RUN = { 'FEATURES.json': FEATURES, '.harness-run/start': 'abc123\n' }
const written = (files: Record<string, string>) => Object.keys(files).filter(p => !(p in RUN))

describe('budget guard (M25-003)', () => {
  test('a builder over budget during a run writes STOP and a reason', BUDGET, async ($, on) => {
    const w = world(on, { ...RUN })
    models(on, '{}')
    await $.session.start(START)
    await $.turn.complete(turn('working', 'agent-1', 600))
    expect(w.files['.harness-run/STOP']).toBeUndefined()
    await $.turn.complete(turn('still working', 'agent-1', 600))
    expect(w.files['.harness-run/STOP']).toBeDefined()
    expect(w.files['.harness-run/budget.log']).toContain('agent-1')
    expect(w.files['.harness-run/budget.log']).toContain('1200')
    expect(w.statuses.at(-1)).toContain('budget')
  })

  test('staying under budget writes nothing', BUDGET, async ($, on) => {
    const w = world(on, { ...RUN })
    models(on, '{}')
    await $.session.start(START)
    await $.turn.complete(turn('a', 'agent-1', 400))
    await $.turn.complete(turn('b', 'agent-2', 900))
    expect(written(w.files)).toEqual([])
  })

  test('cache reads do not count toward the budget', BUDGET, async ($, on) => {
    const w = world(on, { ...RUN })
    models(on, '{}')
    await $.session.start(START)
    await $.turn.complete(turn('a', 'agent-1', 900))
    expect(written(w.files)).toEqual([])
  })

  test('outside a run it warns but never writes STOP', BUDGET, async ($, on) => {
    const w = world(on, { 'FEATURES.json': FEATURES })
    models(on, '{}')
    await $.session.start(START)
    await $.turn.complete(turn('a', 'agent-1', 1500))
    expect(w.files['.harness-run/STOP']).toBeUndefined()
    expect(w.statuses.at(-1)).toContain('budget')
  })

  test('the main loop count restarts after each SESSION line', BUDGET, async ($, on) => {
    const w = world(on, { ...RUN })
    models(on, '{"done": true, "blocked": false, "skipped_work": []}')
    await $.session.start(START)
    await $.turn.complete(turn('a', undefined, 600))
    await $.turn.complete(turn('SESSION: M1-001 · passing · gate green · c1', undefined, 300))
    await $.turn.complete(turn('b', undefined, 600))
    expect(w.files['.harness-run/STOP']).toBeUndefined()
  })

  test('logs each feature\'s tokens once, from its builder, during a run (M29-003)', BUDGET, async ($, on) => {
    const w = world(on, { ...RUN })
    models(on, '{"done": true, "blocked": false, "skipped_work": []}')
    await $.session.start(START)
    await $.turn.complete(turn('building', 'agent-1', 300))
    await $.turn.complete(turn('SESSION: M1-001 · passing · gate green · c1', 'agent-1', 200))
    await $.turn.complete(turn('SESSION: M1-001 · passing · gate green · c1', undefined, 50))
    expect(w.files['.harness-run/tokens.log']).toBe('M1-001 500\n')
  })

  test('no tokens log outside a run', BUDGET, async ($, on) => {
    const w = world(on, { 'FEATURES.json': FEATURES })
    models(on, '{"done": true, "blocked": false, "skipped_work": []}')
    await $.session.start(START)
    await $.turn.complete(turn('SESSION: M1-001 · passing · gate green · c1', 'agent-1', 200))
    expect(w.files['.harness-run/tokens.log']).toBeUndefined()
  })

  test('does nothing outside a harnessed repo', BUDGET, async ($, on) => {
    const w = world(on, {})
    models(on, '{}')
    await $.session.start(START)
    await $.turn.complete(turn('a', 'agent-1', 5000))
    expect(Object.keys(w.files)).toEqual([])
    expect(w.statuses).toEqual([])
  })
})
