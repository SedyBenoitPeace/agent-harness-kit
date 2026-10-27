import { describe, expect, test } from 'claude-code/testing'

import { START, world } from './world'

const feature = (id: string, extra: Record<string, unknown> = {}) => ({ id, milestone: 1, title: id, status: 'failing', verify: 'x', ...extra })
const featuresOf = (...fs: Record<string, unknown>[]) => JSON.stringify({ milestones: { '1': 'One' }, features: fs })
const builder = (id: string) => ({ prompt: `Use harness-session for ${id}, inline. End with its SESSION line.`, subagentType: 'harness-builder' })

describe('model choice (M30-001)', () => {
  test('effort low, medium, high start on haiku, sonnet, opus', async ($, on) => {
    const w = world(on, { 'FEATURES.json': featuresOf(feature('M1-001', { effort: 'low' }), feature('M1-002', { effort: 'medium' }), feature('M1-003', { effort: 'high' })) })
    await $.session.start(START)
    for (const id of ['M1-001', 'M1-002', 'M1-003']) await $.agent.spawn(builder(id))
    expect(w.spawns.map(s => s.model)).toEqual(['haiku', 'sonnet', 'opus'])
    expect(w.files['.harness-run/models.log']).toContain('M1-001 haiku effort low')
  })

  test('the M38 brief prompt names its feature, not the depends_on ids pasted below it', async ($, on) => {
    const w = world(on, { 'FEATURES.json': featuresOf(feature('M1-001', { effort: 'high' }), feature('M1-002', { effort: 'low', depends_on: ['M1-001'] })) })
    await $.session.start(START)
    const brief = 'Run one harness session for M1-002, inline. Start with `bash ../harness-session/scripts/context.sh --brief`. End with the SESSION line.\n== Feature M1-002 ==\n{ "id": "M1-002", "depends_on": ["M1-001"] }'
    await $.agent.spawn({ prompt: brief, subagentType: 'general-purpose' })
    expect(w.spawns[0]!.model).toBe('haiku')
  })

  test('a feature with no effort starts on sonnet', async ($, on) => {
    const w = world(on, { 'FEATURES.json': featuresOf(feature('M1-001')) })
    await $.session.start(START)
    await $.agent.spawn(builder('M1-001'))
    expect(w.spawns[0]!.model).toBe('sonnet')
  })

  test('a retry steps up one tier, an evaluator rejection too, capped at opus', async ($, on) => {
    const w = world(on, { 'FEATURES.json': featuresOf(feature('M1-001', { effort: 'low' }), feature('M1-002', { effort: 'low', eval_attempts: 1 })) })
    await $.session.start(START)
    await $.agent.spawn(builder('M1-001'))
    await $.agent.spawn(builder('M1-001'))
    await $.agent.spawn(builder('M1-001'))
    await $.agent.spawn(builder('M1-001'))
    await $.agent.spawn(builder('M1-002'))
    expect(w.spawns.map(s => s.model)).toEqual(['haiku', 'sonnet', 'opus', 'opus', 'sonnet'])
  })

  test('sensitive paths never start below sonnet', async ($, on) => {
    const w = world(on, { 'FEATURES.json': featuresOf(feature('M1-001', { effort: 'low', paths: ['src/auth/'] })) })
    await $.session.start(START)
    await $.agent.spawn(builder('M1-001'))
    expect(w.spawns[0]!.model).toBe('sonnet')
    expect(w.files['.harness-run/models.log']).toContain('sensitive paths')
  })

  test('the evaluator never runs below sonnet, and is left alone above it', async ($, on) => {
    const w = world(on, { 'FEATURES.json': featuresOf(feature('M1-001')) })
    await $.session.start(START)
    await $.agent.spawn({ prompt: 'judge M1-001', subagentType: 'harness-evaluator', model: 'haiku' })
    await $.agent.spawn({ prompt: 'judge M1-001', subagentType: 'harness-evaluator', model: 'opus' })
    expect(w.spawns.map(s => s.model)).toEqual(['sonnet', 'opus'])
  })

  test('model_floor raises the minimum', { options: { model_floor: 'sonnet' } }, async ($, on) => {
    const w = world(on, { 'FEATURES.json': featuresOf(feature('M1-001', { effort: 'low' })) })
    await $.session.start(START)
    await $.agent.spawn(builder('M1-001'))
    expect(w.spawns[0]!.model).toBe('sonnet')
  })

  test('route_models false leaves every model alone', { options: { route_models: false } }, async ($, on) => {
    const w = world(on, { 'FEATURES.json': featuresOf(feature('M1-001', { effort: 'low' })) })
    await $.session.start(START)
    await $.agent.spawn(builder('M1-001'))
    expect(w.spawns[0]!.model).toBeUndefined()
  })

  test('other subagents and repos without a harness are untouched', async ($, on) => {
    const w = world(on, {})
    await $.session.start(START)
    await $.agent.spawn(builder('M1-001'))
    await $.agent.spawn({ prompt: 'look around', subagentType: 'Explore' })
    expect(w.spawns.map(s => s.model)).toEqual([undefined, undefined])
    expect(w.files['.harness-run/models.log']).toBeUndefined()
  })

  test('model small, medium, large start haiku, sonnet, opus, effort ignored', async ($, on) => {
    const w = world(on, { 'FEATURES.json': featuresOf(feature('M1-001', { model: 'small', effort: 'high' }), feature('M1-002', { model: 'medium', effort: 'low' }), feature('M1-003', { model: 'large', effort: 'low' })) })
    await $.session.start(START)
    for (const id of ['M1-001', 'M1-002', 'M1-003']) await $.agent.spawn(builder(id))
    expect(w.spawns.map(s => s.model)).toEqual(['haiku', 'sonnet', 'opus'])
    expect(w.files['.harness-run/models.log']).toContain('M1-001 haiku model small')
  })

  test('a Claude alias is used as given, a foreign alias counts as medium', async ($, on) => {
    const w = world(on, { 'FEATURES.json': featuresOf(feature('M1-001', { model: 'haiku' }), feature('M1-002', { model: 'opus', effort: 'low' }), feature('M1-003', { model: 'gpt-mini', effort: 'low' })) })
    await $.session.start(START)
    for (const id of ['M1-001', 'M1-002', 'M1-003']) await $.agent.spawn(builder(id))
    expect(w.spawns.map(s => s.model)).toEqual(['haiku', 'opus', 'sonnet'])
  })

  test('a retry steps up from the size', async ($, on) => {
    const w = world(on, { 'FEATURES.json': featuresOf(feature('M1-001', { model: 'small' }), feature('M1-002', { model: 'small', eval_attempts: 1 })) })
    await $.session.start(START)
    await $.agent.spawn(builder('M1-001'))
    await $.agent.spawn(builder('M1-001'))
    await $.agent.spawn(builder('M1-002'))
    expect(w.spawns.map(s => s.model)).toEqual(['haiku', 'sonnet', 'sonnet'])
  })

  test('sensitive paths floor a small feature at sonnet', async ($, on) => {
    const w = world(on, { 'FEATURES.json': featuresOf(feature('M1-001', { model: 'small', paths: ['src/billing/'] })) })
    await $.session.start(START)
    await $.agent.spawn(builder('M1-001'))
    expect(w.spawns[0]!.model).toBe('sonnet')
  })

  test('model_floor raises a small feature', { options: { model_floor: 'sonnet' } }, async ($, on) => {
    const w = world(on, { 'FEATURES.json': featuresOf(feature('M1-001', { model: 'small' })) })
    await $.session.start(START)
    await $.agent.spawn(builder('M1-001'))
    expect(w.spawns[0]!.model).toBe('sonnet')
  })
})
