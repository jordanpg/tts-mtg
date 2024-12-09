import baseConfig from '../../eslint.config.js';
import jsonPlugin from 'jsonc-eslint-parser';

/** @type import('eslint').Linter.Config[] */
export default [
  ...baseConfig,
  {
    files: ['**/*.json'],
    rules: {
      '@nx/dependency-checks': [
        'error',
        {
          ignoredFiles: [
            '{projectRoot}/eslint.config.{js,cjs,mjs}',
            '{projectRoot}/vite.config.{js,ts,mjs,mts}',
          ],
        },
      ],
    },
    languageOptions: {
      parser: jsonPlugin,
    },
  },
];
