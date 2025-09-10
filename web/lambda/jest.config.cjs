// Jest config in CommonJS to work with package.json type=module
/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: 'node',
  transform: {
    '^.+\\.js$': ['babel-jest', {
      presets: [['@babel/preset-env', { targets: { node: 'current' } }]]
    }]
  },
  collectCoverage: true,
  coverageThreshold: {
    global: { branches: 70, functions: 70, lines: 70, statements: 70 }
  },
  coverageReporters: ['text', 'json', 'html']
};
