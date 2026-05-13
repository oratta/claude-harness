// PoC sandbox: greet.ts
//
// This file is intentionally left UNIMPLEMENTED so that the sandbox
// starts in the RED state. Task #6 (codex orchestrator) will let the
// Codex agent fill in the body via TDD.
//
// The type signature is provided so that `tsc --noEmit` passes even
// before the implementation is written.

export function greet(name: string): string {
  return `Hello, ${name || 'stranger'}!`;
}
