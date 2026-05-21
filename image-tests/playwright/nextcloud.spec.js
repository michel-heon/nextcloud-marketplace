// image-tests/playwright/nextcloud.spec.js
// Tests E2E Nextcloud — Niveau 2 (Qualification Fonctionnelle)
// Référence: ADR-701 — T-BROWSER-00 à T-BROWSER-03
//
// Vérifie :
//   - HTTP → HTTPS redirect
//   - Page de login Nextcloud accessible
//   - Connexion administrateur fonctionnelle
//   - Navigation dans l'application (Files)
//   - API OCS disponible
//   - Liens CalDAV/CardDAV opérationnels
//   - status.php cohérent (installed=true, maintenance=false)

import { test, expect } from '@playwright/test';
import { vmIp, adminUser, adminPass } from './playwright.config.js';

const BASE_URL_HTTPS = `https://${vmIp}`;
const BASE_URL_HTTP  = `http://${vmIp}`;

// ============================================================
// T-BROWSER-00 : HTTP → HTTPS Redirect
// ============================================================
test('T-BROWSER-00 : HTTP redirige vers HTTPS', async ({ page }) => {
    await page.goto(BASE_URL_HTTP, { waitUntil: 'domcontentloaded' });
    expect(page.url()).toMatch(/^https:\/\//);
});

// ============================================================
// T-BROWSER-01 : Page de login accessible
// ============================================================
test('T-BROWSER-01 : Page login accessible et formulaire présent', async ({ page }) => {
    const response = await page.goto(`${BASE_URL_HTTPS}/login`, {
        waitUntil: 'domcontentloaded',
    });
    expect(response?.status()).toBeLessThan(400);

    // Champs du formulaire de connexion Nextcloud
    await expect(page.locator('#user')).toBeVisible({ timeout: 15_000 });
    await expect(page.locator('#password')).toBeVisible({ timeout: 5_000 });
});

// ============================================================
// T-BROWSER-01b : status.php — installed=true, maintenance=false
// ============================================================
test('T-BROWSER-01b : status.php — installé et hors maintenance', async ({ request }) => {
    const response = await request.get(`${BASE_URL_HTTPS}/status.php`, {
        ignoreHTTPSErrors: true,
    });
    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.installed).toBe(true);
    expect(body.maintenance).toBe(false);
    // La version doit correspondre au pattern SemVer
    expect(body.version).toMatch(/^\d+\.\d+\.\d+/);
});

// ============================================================
// T-BROWSER-02 : Connexion admin + navigation Files
// ============================================================
test('T-BROWSER-02 : Connexion admin et accès à Files', async ({ page }) => {
    await page.goto(`${BASE_URL_HTTPS}/login`, { waitUntil: 'domcontentloaded' });

    await page.locator('#user').fill(adminUser);
    await page.locator('#password').fill(adminPass);
    await page.locator('[type="submit"], button[type="submit"], .login-form__submit').first().click();

    // Attendre le dashboard ou la page files
    await page.waitForURL(/\/(dashboard|apps\/dashboard|apps\/files|index\.php)/, {
        timeout: 20_000,
    });
    expect(page.url()).toMatch(/https:\/\//);

    // Naviguer vers Files
    await page.goto(`${BASE_URL_HTTPS}/apps/files`, { waitUntil: 'domcontentloaded' });
    // Le conteneur principal de Files doit être visible
    await expect(
        page.locator('#app-content, [data-cy-files-content], .files-list, #files-list')
            .first()
    ).toBeVisible({ timeout: 20_000 });
});

// ============================================================
// T-BROWSER-03 : API OCS disponible
// ============================================================
test('T-BROWSER-03 : API OCS opérationnelle', async ({ request }) => {
    const response = await request.get(
        `${BASE_URL_HTTPS}/ocs/v1.php/config`,
        {
            headers: { 'OCS-APIRequest': 'true' },
            ignoreHTTPSErrors: true,
        }
    );
    expect(response.status()).toBeLessThan(400);
    const text = await response.text();
    expect(text).toMatch(/<ocs>/i);
});

// ============================================================
// T-BROWSER-04 : Redirections CalDAV / CardDAV
// ============================================================
test('T-BROWSER-04 : .well-known/carddav redirige (301/302)', async ({ request }) => {
    const response = await request.get(
        `${BASE_URL_HTTPS}/.well-known/carddav`,
        { ignoreHTTPSErrors: true, maxRedirects: 0 }
    );
    expect([301, 302, 307, 308]).toContain(response.status());
});

test('T-BROWSER-04b : .well-known/caldav redirige (301/302)', async ({ request }) => {
    const response = await request.get(
        `${BASE_URL_HTTPS}/.well-known/caldav`,
        { ignoreHTTPSErrors: true, maxRedirects: 0 }
    );
    expect([301, 302, 307, 308]).toContain(response.status());
});
