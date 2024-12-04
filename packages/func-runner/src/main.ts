import { bootstrapRunner } from '@nx-extend/gcp-functions/runner';

/* eslint-disable @nx/enforce-module-boundaries */
bootstrapRunner(new Map([['mtg-api', import('../../mtg-api/src/main')]]));
