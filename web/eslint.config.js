// ESLint v9 flat config for frontend
import js from '@eslint/js';

export default [
  js.configs.recommended,
  {
    files: [
      'static/**/*.js',
      'test/**/*.js',
      'vitest.config.ts'
    ],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: {
        window: true,
        document: true,
        console: true,
        fetch: true,
        FormData: true,
        module: true
      }
    },
    ignores: [
      'coverage/**',
      'node_modules/**',
      'static/assets/**'
    ],
    rules: {
      'no-unused-vars': ['error', { args: 'none', ignoreRestSiblings: true }],
      'eqeqeq': ['error', 'always'],
      'no-console': ['warn', { allow: ['error', 'warn'] }]
    }
  }
];


