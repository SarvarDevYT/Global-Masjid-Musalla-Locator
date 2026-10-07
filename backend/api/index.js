const app = require('../src/app');
const { dbManager } = require('../src/db/database');

let initialized = false;

module.exports = async (req, res) => {
  if (!initialized) {
    try {
      await dbManager.initialize();
      initialized = true;
    } catch (err) {
      console.error('Database initialization warning:', err);
    }
  }
  return app(req, res);
};
