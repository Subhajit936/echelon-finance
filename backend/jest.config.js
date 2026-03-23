module.exports = {
  testEnvironment: 'node',
  // setupFilesAfterFramework is the key given in the spec; the actual working Jest key is setupFilesAfterEnv
  setupFilesAfterEnv: ['./tests/setup.js'],
  testTimeout: 30000
};
