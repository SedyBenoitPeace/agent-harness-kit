// The values agent-harness-kit-claude keeps in $.state (the session's).
export type NextStep = { feature: string } | null

declare module 'claude-code' {
  interface PluginState {
    'agent-harness-kit-claude': { lastPassing: NextStep; isHidden: boolean }
  }
}
