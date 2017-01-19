module.exports = {
  entry: './src/scapula-jquery',

  output: {
    path: './lib',
    filename: 'scapula-jquery.js',
    libraryTarget: 'umd'
  },

  module: {
    loaders: [
      {
        test: /\.coffee$/,
        loader: "coffee"
      }
    ]
  },

  resolve: {
    extensions: [ '', '.coffee', '.js' ],
    modulesDirectories: [ 'node_modules' ]
  },

  externals: {
    'scapula-utils': {
      root: 'scapula-utils',
      amd: 'scapula-utils',
      commonjs: 'scapula-utils',
      commonjs2: 'scapula-utils'
    }
  }
};
