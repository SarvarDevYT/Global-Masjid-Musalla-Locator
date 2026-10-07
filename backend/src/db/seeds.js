const path = require('path');
const fs = require('fs');

let SEED_MOSQUES = [];

try {
  const jsonPath = path.resolve(__dirname, 'uzbekistan_mosques.json');
  if (fs.existsSync(jsonPath)) {
    const rawData = fs.readFileSync(jsonPath, 'utf8');
    SEED_MOSQUES = JSON.parse(rawData);
  }
} catch (e) {
  console.warn('Could not load uzbekistan_mosques.json:', e.message);
}

module.exports = { SEED_MOSQUES };
