import { describe, expect, test } from 'claude-code/testing'

import { PLUGIN, START, world } from './world'

const TOOL = `mcp__${PLUGIN}__register_decision`

describe('decision register (M25-001)', () => {
  test('registers the tool only in a harnessed repo', async ($, on) => {
    const w = world(on, { 'FEATURES.json': '{}' })
    await $.session.start(START)
    expect(w.registered).toEqual(['register_decision'])
  })

  test('stays out of a repo without FEATURES.json', async ($, on) => {
    const w = world(on, {})
    await $.session.start(START)
    expect(w.registered).toEqual([])
  })

  test('appends one decision per call and keeps the folder out of git', async ($, on) => {
    const { files } = world(on, { 'FEATURES.json': '{}' })
    await $.session.start(START)
    const first = await $.tool.call({ tool: TOOL, feature: 'M3-002', chose: 'jq', over: 'python', why: 'already a dependency' })
    const second = await $.tool.call({ tool: TOOL, feature: 'M3-002', chose: 'one file', over: 'two', why: 'simpler' })
    expect(first.deny).toBeUndefined()
    expect(second.deny).toBeUndefined()
    const log = files['.harness-run/decisions/M3-002.md'] ?? ''
    expect(log).toContain('- chose jq over python: already a dependency')
    expect(log).toContain('- chose one file over two: simpler')
    expect(log.split('\n').filter(l => l.startsWith('- ')).length).toBe(2)
    expect(files['.harness-run/.gitignore']).toBe('*\n')
  })

  test('refuses a feature id that could leave .harness-run/', async ($, on) => {
    const { files } = world(on, { 'FEATURES.json': '{}' })
    await $.session.start(START)
    for (const feature of ['../../etc/passwd', 'M1-001/../../x', 'notes', '']) {
      const r = await $.tool.call({ tool: TOOL, feature, chose: 'a', over: 'b', why: 'c' })
      expect(r.deny).toBeDefined()
    }
    expect(Object.keys(files)).toEqual(['FEATURES.json'])
  })
})
