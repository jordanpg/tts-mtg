// @ts-check
import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';
import nxeslint from '@nx/eslint-plugin';

export default tseslint.config(
  eslint.configs.recommended,
  tseslint.configs.recommended,
  { plugins: { '@nx': nxeslint } },
  {
    ignores: ['node_modules', 'tmp', 'dist'],
  },
);
