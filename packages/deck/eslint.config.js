import baseConfig from '../../eslint.config.js';
import JsonParser from 'jsonc-eslint-parser';

/** @type import("eslint").Linter.Config[] */
const config = [
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
      parser: JsonParser,
    },
  },
];

export default config;
