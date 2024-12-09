import type { HttpFunction } from '@google-cloud/functions-framework';
import { bootstrapRunner } from '@nx-extend/gcp-functions/runner/index.js';

bootstrapRunner(
  new Map<string, Promise<{ [exp: string]: HttpFunction }>>([
    ['mtg-api', import('../../mtg-api/src/main.js')],
    ['moxfield-proxy', import('../../moxfield-proxy/src/index.js')],
  ]),
);
