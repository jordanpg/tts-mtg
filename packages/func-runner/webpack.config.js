import { composePlugins, withNx } from '@nx/webpack';

// Nx plugins for webpack.
export default composePlugins(withNx(), (config) => {
  return config;
});
