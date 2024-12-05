import { bootstrapRunner } from '@nx-extend/gcp-functions/runner';

bootstrapRunner(new Map([['mtg-api', import('../../mtg-api/src/main')]]));
