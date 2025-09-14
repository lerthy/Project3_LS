// ESLint v9 flat config for Lambda (Node)
import js from '@eslint/js';

export default [
  js.configs.recommended,
  {
    files: ['**/*.js'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: {
        process: true,
        console: true
      }
    },
    ignores: ['node_modules/**', 'coverage/**'],
    rules: {
      'no-console': 'off',
      'no-unused-vars': ['error', { args: 'none', ignoreRestSiblings: true }]
    }
  },
  {
    files: ['**/*.test.js'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: {
        jest: true,
        describe: true,
        it: true,
        expect: true,
        beforeEach: true,
        afterEach: true,
        global: true
      }
    }
  }
];



