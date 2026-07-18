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

  for (const path of [
    '/chat/users/2747/unblock',
    '/chat/users/2747/block',
    '/chat/users/2747/unblock',
    '/chat/users/2747/block',
  ]) {
    const method = path.endsWith('unblock') ? 'DELETE' : 'POST';
    const res = await req(method, path, token);
    console.log(method, path, res.status, res.body.slice(0, 250));
  }
})();
