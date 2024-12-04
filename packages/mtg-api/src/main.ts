import type { HttpFunction } from '@google-cloud/functions-framework';

const { foo = 'testBar' } = process.env;

// Note: When changing "MtgApi" to something else
// make sure to also update the "entryPoint" inside the "project.json"
export const MtgApi: HttpFunction = async (req, res) => {
  res.status(200).send(foo);
};
