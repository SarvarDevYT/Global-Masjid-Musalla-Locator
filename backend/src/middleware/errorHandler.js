const config = require('../config');

function notFoundHandler(req, res, next) {
  res.status(404).json({
    success: false,
    error: 'Endpoint not found'
  });
}

function errorHandler(err, req, res, next) {
  console.error('[Error]', err);

  // Per secure coding guidelines: Generic errors to users, detail to logs.
  const statusCode = err.status || err.statusCode || 500;
  const isDev = config.nodeEnv === 'development';

  res.status(statusCode).json({
    success: false,
    error: statusCode === 500 ? 'Internal Server Error' : err.message,
    ...(isDev && { debug: err.message })
  });
}

module.exports = {
  notFoundHandler,
  errorHandler
};
