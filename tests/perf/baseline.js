// Small k6 baseline for hello-v1. NON-PRODUCTION ONLY.
// 5 virtual users for 30 s, each pausing 0.5 s between requests (about 10 requests/second).
// This measures a baseline; it does NOT say anything about production capacity.
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 5,
  duration: '30s',
  thresholds: {
    http_req_failed: ['rate<0.01'],     // less than 1% errors
    http_req_duration: ['p(95)<1000'],  // 95% of requests under 1 s
  },
};

const BASE = __ENV.BASE_URL || 'https://35.201.86.122.nip.io';

export default function () {
  const res = http.get(`${BASE}/v1/hello?name=Rizk`);
  check(res, {
    'status is 200': (r) => r.status === 200,
    'greeting is correct': (r) => r.body && r.body.includes('Hello, Rizk!'),
  });
  sleep(0.5);
}
