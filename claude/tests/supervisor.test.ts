import { describe, expect, test } from 'claude-code/testing'

import { FEATURES, models, START, turn, world } from './world'

const SESSION_OK = 'Done.\nSESSION: M1-001 · passing · gate green · abc123'
const SKIPPED = '{"done": true, "blocked": false, "skipped_work": ["no test for the empty-name case"]}'
const CLEAN = '{"done": true, "blocked": false, "skipped_work": []}'

describe('done-check supervisor (M25-002)', () => {
  test('main loop: forks once against verify, writes skipped work, sets a status', async ($, on) => {
    const w = world(on, { 'FEATURES.json': FEATURES })
    const m = models(on, SKIPPED)
    await $.session.start(START)
    await $.turn.complete(turn(SESSION_OK))
    expect(m.fork.length).toBe(1)
    expect(m.complete.length).toBe(0)
    expect(m.fork[0]).toContain('greet.sh Ada prints Hello, Ada!')
    expect(w.files['.harness-run/decisions/M1-001.skipped.md']).toContain('no test for the empty-name case')
    expect(w.statuses.at(-1)).toContain('M1-001')
    expect(w.statuses.at(-1)).toContain('skipped 1')
  })

  test('builder subagent: reads its own messages and completes, not forks', async ($, on) => {
    const w = world(on, { 'FEATURES.json': FEATURES })
    const m = models(on, CLEAN)
    await $.session.start(START)
    await $.turn.complete(turn(SESSION_OK, 'agent-7'))
    expect(m.messages).toEqual(['agent-7'])
    expect(m.fork.length).toBe(0)
    expect(m.complete.length).toBe(1)
    expect(m.complete[0]).toContain('skipped the usage check')
    expect(w.files['.harness-run/decisions/M1-001.skipped.md']).toBeUndefined()
    expect(w.statuses.at(-1)).toContain('done')
  })

  test('does nothing for a turn without a SESSION line', async ($, on) => {
    const w = world(on, { 'FEATURES.json': FEATURES })
    const m = models(on, CLEAN)
    await $.session.start(START)
    await $.turn.complete(turn('Just chatting.'))
    expect(m.fork.length + m.complete.length).toBe(0)
    expect(w.statuses.length).toBe(0)
  })

  test('does nothing outside a harnessed repo', async ($, on) => {
    world(on, {})
    const m = models(on, CLEAN)
    await $.session.start(START)
    await $.turn.complete(turn(SESSION_OK))
    expect(m.fork.length + m.complete.length).toBe(0)
  })

  test('an unparseable verdict writes nothing and says so', async ($, on) => {
    const w = world(on, { 'FEATURES.json': FEATURES })
    models(on, 'I think it is fine')
    await $.session.start(START)
    await $.turn.complete(turn(SESSION_OK))
    expect(Object.keys(w.files).filter(p => p !== 'FEATURES.json')).toEqual([])
    expect(w.statuses.at(-1)).toContain('no verdict')
  })

  test('never writes outside .harness-run/', async ($, on) => {
    const w = world(on, { 'FEATURES.json': FEATURES })
    models(on, SKIPPED)
    await $.session.start(START)
    await $.turn.complete(turn(SESSION_OK))
    await $.turn.complete(turn(SESSION_OK, 'agent-2'))
    expect(Object.keys(w.files).filter(p => p !== 'FEATURES.json').every(p => p.startsWith('.harness-run/'))).toBe(true)
  })

  test('checks a feature once even when the orchestrator echoes its SESSION line', async ($, on) => {
    world(on, { 'FEATURES.json': FEATURES })
    const m = models(on, CLEAN)
    await $.session.start(START)
    await $.turn.complete(turn(SESSION_OK, 'agent-3'))
    await $.turn.complete(turn(`Relaying: ${SESSION_OK}`))
    expect(m.fork.length + m.complete.length).toBe(1)
  })
})
