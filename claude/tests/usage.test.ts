import { describe, expect, test } from 'claude-code/testing'

import { FEATURES, models, START, turn, world } from './world'

const RUN = { 'FEATURES.json': FEATURES, '.harness-run/start': 'abc123\n' }
const DONE = '{"done": true, "blocked": false, "skipped_work": []}'
const session = (id: string) => `SESSION: ${id} · passing · gate green · c1`
const LOG = '.harness-run/usage.log'
// turn(..., tokens): input tokens - 100, output 100, cache read 50000, model claude-sonnet-5-5

describe('usage.log (M32-002)', () => {
  test('a builder session logs its tokens on its feature, with the model', async ($, on) => {
    const w = world(on, { ...RUN })
    models(on, DONE)
    await $.session.start(START)
    await $.turn.complete(turn('working', 'agent-1', 1000))
    await $.turn.complete(turn(session('M1-001'), 'agent-1', 500))
    // input = input + cache read; cached = cache read; summed over the agent's turns
    expect(w.files[LOG]).toBe('M1-001 claude claude-sonnet-5-5 101300 100000 200\n')
  })

  test('the orchestrator logs its turns on orchestration; an echoed SESSION line is not a builder', async ($, on) => {
    const w = world(on, { ...RUN })
    models(on, DONE)
    await $.session.start(START)
    await $.turn.complete(turn(session('M1-001'), 'agent-1', 1000))
    await $.turn.complete(turn(`done. ${session('M1-001')}`, undefined, 2000))
    expect(w.files[LOG]).toBe(
      'M1-001 claude claude-sonnet-5-5 50900 50000 100\norchestration claude claude-sonnet-5-5 51900 50000 100\n',
    )
  })

  test('each completed main-loop turn is on disk at once, so a killed run keeps its orchestration tokens', async ($, on) => {
    const w = world(on, { ...RUN })
    models(on, DONE)
    await $.session.start(START)
    await $.turn.complete(turn('dispatching', undefined, 1000))
    expect(w.files[LOG]).toBe('orchestration claude claude-sonnet-5-5 50900 50000 100\n')
    await $.turn.complete(turn('still going', undefined, 2000))
    expect(w.files[LOG]).toBe(
      'orchestration claude claude-sonnet-5-5 50900 50000 100\norchestration claude claude-sonnet-5-5 51900 50000 100\n',
    )
  })

  test('a resumed builder adds another turn on the same feature', async ($, on) => {
    const w = world(on, { ...RUN })
    models(on, DONE)
    await $.session.start(START)
    await $.turn.complete(turn(session('M1-001').replace('passing', 'blocked'), 'agent-1', 1000))
    await $.turn.complete(turn(session('M1-001'), 'agent-1', 2000))
    expect(w.files[LOG]).toBe(
      'M1-001 claude claude-sonnet-5-5 50900 50000 100\nM1-001 claude claude-sonnet-5-5 51900 50000 100\n',
    )
  })

  test('parallel lanes each count once, on their own feature', async ($, on) => {
    const w = world(on, { ...RUN })
    models(on, DONE)
    await $.session.start(START)
    await $.turn.complete(turn(session('M1-001'), 'agent-1', 1000))
    await $.turn.complete(turn(session('M1-002'), 'agent-2', 2000))
    const lines = w.files[LOG]!.trim().split('\n')
    expect(lines).toEqual(['M1-001 claude claude-sonnet-5-5 50900 50000 100', 'M1-002 claude claude-sonnet-5-5 51900 50000 100'])
  })

  test('a usage without a model logs a dash', async ($, on) => {
    const w = world(on, { ...RUN })
    models(on, DONE)
    await $.session.start(START)
    const t = turn(session('M1-001'), 'agent-1', 1000)
    delete (t.usage as { model?: string }).model
    await $.turn.complete(t)
    expect(w.files[LOG]).toBe('M1-001 claude - 50900 50000 100\n')
  })

  test('nothing is written outside a run', async ($, on) => {
    const w = world(on, { 'FEATURES.json': FEATURES })
    models(on, DONE)
    await $.session.start(START)
    await $.turn.complete(turn(session('M1-001'), 'agent-1', 1000))
    await $.turn.complete(turn('x', undefined, 1000))
    expect(w.files[LOG]).toBeUndefined()
  })

  test('nothing is written in a repo without FEATURES.json', async ($, on) => {
    const w = world(on, {})
    await $.session.start(START)
    await $.turn.complete(turn('x', undefined, 1000))
    expect(Object.keys(w.files)).toEqual([])
  })
})
