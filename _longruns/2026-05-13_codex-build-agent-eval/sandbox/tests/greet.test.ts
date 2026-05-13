import { describe, it, expect } from 'vitest';
import { greet } from '../src/greet.js';

describe('greet', () => {
  it('returns "Hello, <name>!" for a plain name', () => {
    expect(greet('world')).toBe('Hello, world!');
  });

  it('handles empty string by greeting "stranger"', () => {
    expect(greet('')).toBe('Hello, stranger!');
  });
});
