import { firefox } from '@playwright/test';
import { mkdir } from 'node:fs/promises';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const ROOT = process.cwd();
const STATE_FILE = resolve(ROOT, '.image-test-state');
const OUT_DIR = resolve(ROOT, 'assets/screenshots');

function readState(filePath) {
  const state = {};
  if (!existsSync(filePath)) return state;
  const lines = readFileSync(filePath, 'utf8').split('\n');
  for (const line of lines) {
    const idx = line.indexOf('=');
    if (idx > 0) {
      const k = line.slice(0, idx).trim();
      const v = line.slice(idx + 1).trim();
      if (k) state[k] = v;
    }
  }
  return state;
}

const state = readState(STATE_FILE);
const host = process.env.TEST_VM_FQDN || process.env.TEST_VM_IP || state.TEST_VM_FQDN || state.TEST_VM_IP;
const adminUser = process.env.TEST_NC_ADMIN_USER || state.TEST_NC_ADMIN_USER || 'ncadmin';
const adminPass = process.env.TEST_NC_ADMIN_PASS || state.TEST_NC_ADMIN_PASS || 'changeme123!';

if (!host) {
  throw new Error('Missing TEST_VM_IP/TEST_VM_FQDN (.image-test-state not found or incomplete).');
}

const base = `https://${host}`;

const shots = [
  {
    file: 'screenshot-01-files-overview.png',
    url: `${base}/index.php/apps/files/`,
    waitFor: '#app-content-files, #files-list, [data-cy-files-content], .files-list',
  },
  {
    file: 'screenshot-02-admin-overview.png',
    url: `${base}/index.php/settings/admin/overview`,
    waitFor: '#security-warning-state, #app-content, main, .settings-section',
  },
  {
    file: 'screenshot-03-admin-serverinfo.png',
    url: `${base}/index.php/settings/admin/serverinfo`,
    waitFor: '#server',
  },
  {
    file: 'screenshot-04-user-management.png',
    url: `${base}/index.php/settings/users`,
    waitFor: '#app-content-vue, #app-content, #users, .users-list',
  },
  {
    file: 'screenshot-05-user-security.png',
    url: `${base}/index.php/settings/user/security`,
    waitFor: '#security-password, #security-password-list, #security, .settings-section, #app-content',
  },
];

async function login(page) {
  await page.goto(`${base}/login`, { waitUntil: 'domcontentloaded' });
  const user = page.locator('#user');
  const pass = page.locator('#password');
  if (await user.count()) {
    await user.fill(adminUser);
  }
  if (await pass.count()) {
    await pass.fill(adminPass);
  }
  await page.locator('button[type="submit"], input[type="submit"], .login-form__submit').first().click();
  await page.waitForLoadState('networkidle');
}

async function capture() {
  await mkdir(OUT_DIR, { recursive: true });

  const browser = await firefox.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
    ignoreHTTPSErrors: true,
  });

  const page = await context.newPage();
  await login(page);

  for (const shot of shots) {
    await page.goto(shot.url, { waitUntil: 'domcontentloaded' });
    try {
      await page.locator(shot.waitFor).first().waitFor({ timeout: 15000 });
    } catch {
      // fallback: capture anyway if selector differs in this Nextcloud build
    }
    await page.waitForTimeout(1200);
    await page.screenshot({ path: resolve(OUT_DIR, shot.file), fullPage: false });
    console.log(`${shot.file} <= ${shot.url}`);
  }

  await browser.close();
}

capture().catch((err) => {
  console.error(err);
  process.exit(1);
});
