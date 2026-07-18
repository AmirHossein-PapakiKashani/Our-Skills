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

function multipart(fields) {
  const boundary = '----diag' + Date.now();
  let body = '';
  for (const [k, v] of Object.entries(fields)) {
    body += `--${boundary}\r\nContent-Disposition: form-data; name="${k}"\r\n\r\n${v}\r\n`;
  }
  body += `--${boundary}--\r\n`;
  return { body, type: `multipart/form-data; boundary=${boundary}` };
}

(async () => {
  const loginBody = JSON.stringify({
    username: 'chattest_sara',
    password: 'Test@12345',
    deviceInfo: {
      deviceID: 'test',
      deviceName: 'test',
      deviceVersion: '16',
      appVersion: '2.113.0',
      platform: 'android',
    },
  });
  const login = await req('POST', '/Auth/Login', null, loginBody, 'application/json');
  console.log('LOGIN', login.status, login.body.slice(0, 200));
  const token = JSON.parse(login.body).accessToken;

  const p02 = await req('POST', '/chat/conversations/pv/0', token);
  console.log('P02', p02.status, p02.body);

  const b01 = await req('POST', '/chat/users/2747/block', token);
  console.log('B01', b01.status, b01.body);

  const g02 = multipart({ name: '', memberUserIds: '2748' });
  const g02r = await req('POST', '/chat/groups', token, g02.body, g02.type);
  console.log('G02', g02r.status, g02r.body);

  const g03 = multipart({ name: 'TestGroup', memberUserIds: '' });
  const g03r = await req('POST', '/chat/groups', token, g03.body, g03.type);
  console.log('G03', g03r.status, g03r.body);

  const c03 = multipart({ name: 'TestChannel', handle: 'BAD-HANDLE!', description: '', memberUserIds: '2748' });
  const c03r = await req('POST', '/chat/channels', token, c03.body, c03.type);
  console.log('C03', c03r.status, c03r.body);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
