const http = require('http');

function req(method, path, token, body, contentType) {
  return new Promise((resolve, reject) => {
    const headers = {};
    if (token) headers.Authorization = 'Bearer ' + token;
    if (contentType) headers['Content-Type'] = contentType;
    if (body) headers['Content-Length'] = Buffer.byteLength(body);
    const r = http.request({ hostname: 'localhost', port: 5144, path, method, headers }, (res) => {
      let d = '';
      res.on('data', (c) => (d += c));
      res.on('end', () => resolve({ status: res.statusCode, body: d }));
    });
    r.on('error', reject);
    if (body) r.write(body);
    r.end();
  });
}

(async () => {
  const loginBody = JSON.stringify({
    username: 'chattest_sara',
    password: 'Test@12345',
    deviceInfo: { deviceID: 'test', deviceName: 'test', deviceVersion: '16', appVersion: '2.113.0', platform: 'android' },
  });
  const login = await req('POST', '/Auth/Login', null, loginBody, 'application/json');
  const token = JSON.parse(login.body).accessToken;

  for (const targetId of [2747, 2748, 2749]) {
    const block = await req('POST', `/chat/users/${targetId}/block`, token);
    console.log(`BLOCK ${targetId}`, block.status, block.body.slice(0, 200));
  }

  const unblock2747 = await req('POST', '/chat/users/2747/unblock', token);
  console.log('UNBLOCK 2747', unblock2747.status, unblock2747.body.slice(0, 200));

  const block2747Again = await req('POST', '/chat/users/2747/block', token);
  console.log('BLOCK 2747 AGAIN', block2747Again.status, block2747Again.body.slice(0, 200));
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
