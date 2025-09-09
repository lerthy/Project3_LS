// Test setup file for Vitest
// This file runs before each test suite

// Global test utilities
global.console = {
  ...console,
  // Uncomment to silence console.log during tests
  // log: jest.fn(),
};

// DOM cleanup
afterEach(() => {
  // Clean up DOM after each test
  document.body.innerHTML = '';
});
