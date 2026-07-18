const fs = require('fs');
const path = 'd:/Elay_Backend-master/.cursor/calendar-integration-collection.json';
const c = JSON.parse(fs.readFileSync(path, 'utf8'));
// Keep structure; write MCP payload file
const payload = {
  workspace: '8f8205b4-1f6e-4b7b-8b73-1397399bbabc',
  collection: {
    info: {
      name: c.info.name,
      description: c.info.description || 'Calendar A+B integration tests',
      schema: 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'
    },
    variable: (c.variable || []).map(v => ({ key: v.key, value: v.value == null ? '' : String(v.value) })),
    event: c.event || [],
    item: c.item
  }
};
fs.writeFileSync('d:/Elay_Backend-master/.cursor/calendar-postman-create-payload.json', JSON.stringify(payload));
console.log('payload bytes', fs.statSync('d:/Elay_Backend-master/.cursor/calendar-postman-create-payload.json').size);
console.log('folders', payload.collection.item.length);
