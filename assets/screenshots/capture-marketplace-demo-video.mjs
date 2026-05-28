import { firefox } from '@playwright/test';
import { mkdir, rename } from 'node:fs/promises';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);
const ROOT = process.cwd();
const STATE_FILE = resolve(ROOT, '.image-test-state');
const OUT_DIR = resolve(ROOT, 'assets/screenshots');
const RAW_DIR = resolve(OUT_DIR, 'video-raw');
const OUTPUT_WEBM = resolve(OUT_DIR, 'nextcloud-demo.webm');
const OUTPUT_MP4 = resolve(OUT_DIR, 'nextcloud-demo.mp4');

function readState(filePath) {
  const state = {};
  if (!existsSync(filePath)) return state;
  const lines = readFileSync(filePath, 'utf8').split('\n');
  for (const line of lines) {
    const idx = line.indexOf('=');
    if (idx > 0) {
      const key = line.slice(0, idx).trim();
      const value = line.slice(idx + 1).trim();
      if (key) state[key] = value;
    }
  }
  return state;
}

async function transcodeToMp4(inputFile, outputFile) {
  await execFileAsync('ffmpeg', [
    '-y',
    '-i', inputFile,
    '-vf', 'fps=30,scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2',
    '-c:v', 'libx264',
    '-preset', 'fast',
    '-pix_fmt', 'yuv420p',
    '-movflags', '+faststart',
    '-an',
    outputFile,
  ]);
}

async function smoothPause(page, ms) {
  await page.waitForTimeout(ms);
}

async function highlightAndPause(page, selector, ms = 1800) {
  const locator = page.locator(selector).first();
  if (await locator.count()) {
    await locator.scrollIntoViewIfNeeded().catch(() => {});
  }
  await smoothPause(page, ms);
}

async function main() {
  const state = readState(STATE_FILE);
  const host = process.env.TEST_VM_FQDN || process.env.TEST_VM_IP || state.TEST_VM_FQDN || state.TEST_VM_IP;
  const adminUser = process.env.TEST_NC_ADMIN_USER || state.TEST_NC_ADMIN_USER || 'ncadmin';
  const adminPass = process.env.TEST_NC_ADMIN_PASS || state.TEST_NC_ADMIN_PASS || 'changeme123!';

  if (!host) {
    throw new Error('Missing TEST_VM_IP/TEST_VM_FQDN (.image-test-state incomplete).');
  }

  const base = `https://${host}`;

  await mkdir(OUT_DIR, { recursive: true });
  await mkdir(RAW_DIR, { recursive: true });

  const browser = await firefox.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
    ignoreHTTPSErrors: true,
    recordVideo: {
      dir: RAW_DIR,
      size: { width: 1280, height: 720 },
    },
  });

  const page = await context.newPage();
  const video = page.video();

  await page.goto(`${base}/login`, { waitUntil: 'domcontentloaded' });
  await smoothPause(page, 1500);

  await page.locator('#user').fill(adminUser);
  await smoothPause(page, 700);
  await page.locator('#password').fill(adminPass);
  await smoothPause(page, 700);
  await page.locator('button[type="submit"], input[type="submit"], .login-form__submit').first().click();
  await page.waitForLoadState('networkidle');
  await smoothPause(page, 2200);

  await page.goto(`${base}/index.php/apps/files/`, { waitUntil: 'domcontentloaded' });
  await highlightAndPause(page, '#app-content-files, #files-list, [data-cy-files-content], .files-list', 2600);

  await page.goto(`${base}/index.php/settings/admin/overview`, { waitUntil: 'domcontentloaded' });
  await highlightAndPause(page, '#security-warning-state, .settings-section, #app-content', 2600);

  await page.goto(`${base}/index.php/settings/admin/serverinfo`, { waitUntil: 'domcontentloaded' });
  await highlightAndPause(page, '#server, #app-content', 2600);

  await page.goto(`${base}/index.php/settings/users`, { waitUntil: 'domcontentloaded' });
  await highlightAndPause(page, '#users, #app-content-vue, #app-content', 2600);

  await page.goto(`${base}/index.php/settings/user/security`, { waitUntil: 'domcontentloaded' });
  await highlightAndPause(page, '#security-password, #security, #app-content', 2600);

  await smoothPause(page, 1500);
  await context.close();
  await browser.close();

  const rawVideoPath = await video.path();
  await rename(rawVideoPath, OUTPUT_WEBM).catch(async () => {
    // If already in target dir/name, keep original path.
  });

  const webmInput = existsSync(OUTPUT_WEBM) ? OUTPUT_WEBM : rawVideoPath;
  await transcodeToMp4(webmInput, OUTPUT_MP4);

  console.log(`WEBM: ${webmInput}`);
  console.log(`MP4: ${OUTPUT_MP4}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
