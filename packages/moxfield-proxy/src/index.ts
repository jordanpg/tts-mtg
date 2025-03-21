import type { HttpFunction } from '@google-cloud/functions-framework';

const {
  moxfieldApi = 'api.moxfield.com api2.moxfield.com',
  moxfieldAgent,
  requestFilters = '.*',
} = process.env;
const apis = moxfieldApi.split(/\s+/);
const filters = requestFilters.split(/\s+/);

// Note: When changing function name to something else
// make sure to also update the "entryPoint" inside the "project.json"
export const MoxfieldProxy: HttpFunction = async (req, res) => {
  if (!apis.length) {
    return res.status(503).send('Moxfield unavailable');
  }
  // Validate we have a user agent configured
  if (!moxfieldAgent) {
    return res.status(503).send('Moxfield agent not configured');
  }

  // Validate that this path is whitelisted
  const query = req.query['q'] ?? req.query['query'];
  if (typeof query !== 'string') {
    return res.status(400).send(`Query is required`);
  }
  if (filters.length && !filters.some((f) => new RegExp(f).test(query))) {
    return res.status(400).send(`Path not recognized`);
  }

  const api = apis[Math.floor(Math.random() * apis.length)];
  return fetch(`https://${api}${query}`, {
    headers: {
      'User-Agent': moxfieldAgent,
    },
  })
    .then(async (resp) => res.status(resp.status).send(await resp.json()))
    .catch((err) =>
      res.status(err.status).send(err instanceof Error ? err.message : String(err)),
    );
};
