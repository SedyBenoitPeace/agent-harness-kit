import { describe, expect, test } from 'claude-code/testing'

import { BAND, FEATURES, models, PLUGIN, START, turn, world } from './world'

const PASSED = 'Done.\nSESSION: M1-001 · passing · gate green · c1'
const VERDICT = '{"done": true, "blocked": false, "skipped_work": []}'
const SURFACES = ['terminal', 'desktop'] as const

describe('next-steps band (M25-004)', () => {
  test('after a passing supervised session it offers next feature, explain and quiz', async ($, on) => {
    const w = world(on, { 'FEATURES.json': FEATURES })
    models(on, VERDICT)
    await $.session.start(START)
    await $.turn.complete(turn(PASSED))
    for (const surface of SURFACES) {
      const ui = await $.ui.mount({ plugin: PLUGIN, surface, ...BAND })
      expect(await ui.find({ text: /M1-001/ })).toBeDefined()
      for (const key of ['next', 'explain', 'quiz', 'hide']) expect(await ui.find({ key })).toBeDefined()
      await ui.press({ key: 'quiz' })
      await ui.unmount()
    }
    expect(w.fills.length).toBe(SURFACES.length)
    expect(w.fills[0]).toContain('Quiz me')
    expect(w.fills[0]).toContain('M1-001')
  })

  test('the explain button asks for the big picture in few words', async ($, on) => {
    const w = world(on, { 'FEATURES.json': FEATURES })
    models(on, VERDICT)
    await $.session.start(START)
    await $.turn.complete(turn(PASSED))
    const ui = await $.ui.mount({ plugin: PLUGIN, surface: 'terminal', ...BAND })
    await ui.press({ key: 'explain' })
    expect(w.fills[0]).toContain('big picture, few words')
    await ui.unmount()
  })

  test('hide removes the band', async ($, on) => {
    world(on, { 'FEATURES.json': FEATURES })
    models(on, VERDICT)
    await $.session.start(START)
    await $.turn.complete(turn(PASSED))
    const ui = await $.ui.mount({ plugin: PLUGIN, surface: 'terminal', ...BAND })
    await ui.press({ key: 'hide' })
    expect(await ui.find({ key: 'quiz' })).toBeUndefined()
    await ui.unmount()
  })

  test('nothing during an unattended run', async ($, on) => {
    world(on, { 'FEATURES.json': FEATURES, '.harness-run/start': 'c0\n' })
    models(on, VERDICT)
    await $.session.start(START)
    await $.turn.complete(turn(PASSED))
    const ui = await $.ui.mount({ plugin: PLUGIN, surface: 'terminal', ...BAND })
    expect(await ui.find({ key: 'quiz' })).toBeUndefined()
    await ui.unmount()
  })

  test('nothing for a blocked session or a builder subagent', async ($, on) => {
    world(on, { 'FEATURES.json': FEATURES })
    models(on, VERDICT)
    await $.session.start(START)
    await $.turn.complete(turn('SESSION: M1-001 · blocked · gate green · needs a human'))
    await $.turn.complete(turn(PASSED, 'agent-5'))
    const ui = await $.ui.mount({ plugin: PLUGIN, surface: 'terminal', ...BAND })
    expect(await ui.find({ key: 'quiz' })).toBeUndefined()
    await ui.unmount()
  })
})
