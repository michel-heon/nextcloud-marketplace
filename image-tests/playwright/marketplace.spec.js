// image-tests/playwright/marketplace.spec.js
// Tests de conformité Azure Marketplace — Niveau 3 (Certifiable)
// Référence: ADR-701, ADR-300, ADR-302, ADR-803
//
// Vérifie (via navigateur Playwright) :
//   - HTTPS port 443 accessible
//   - Headers de sécurité (HSTS, X-Frame-Options / CSP, X-Content-Type-Options)
//   - Server header ne divulgue pas de version
//   - Pages d'erreur sans stack trace ni chemins internes
//   - Fichiers sensibles non exposés
//   - mode maintenance = false
//   - TLS accessible (navigateur moderne)

import { test, expect } from '@playwright/test';
import { vmIp } from './playwright.config.js';

const BASE = `https://${vmIp}`;

// ============================================================
// M-SEC-01 : HTTPS accessible
// ============================================================
test('M-SEC-01 : HTTPS accessible (port 443)', async ({ request }) => {
    const response = await request.get(`${BASE}/status.php`, {
        ignoreHTTPSErrors: true,
    });
    expect(response.status()).toBeLessThan(500);
});

// ============================================================
// M-SEC-02 : Headers de sécurité
// ============================================================
test('M-SEC-02 : HSTS présent (Strict-Transport-Security)', async ({ request }) => {
    const response = await request.get(`${BASE}/login`, { ignoreHTTPSErrors: true });
    const hsts = response.headers()['strict-transport-security'];
    expect(hsts, 'Header HSTS manquant').toBeTruthy();
    expect(hsts).toMatch(/max-age=\d+/);
});

test('M-SEC-02b : Protection clickjacking (X-Frame-Options ou CSP)', async ({ request }) => {
    const response = await request.get(`${BASE}/login`, { ignoreHTTPSErrors: true });
    const headers = response.headers();
    const xfo = headers['x-frame-options'];
    const csp = headers['content-security-policy'];
    const hasCspFrameAncestors = csp && /frame-ancestors/i.test(csp);
    const hasXFO = xfo && /deny|sameorigin/i.test(xfo);
    expect(
        hasXFO || hasCspFrameAncestors,
        'Ni X-Frame-Options ni CSP frame-ancestors présent'
    ).toBe(true);
});

test('M-SEC-02c : X-Content-Type-Options nosniff présent', async ({ request }) => {
    const response = await request.get(`${BASE}/login`, { ignoreHTTPSErrors: true });
    const xcto = response.headers()['x-content-type-options'];
    expect(xcto, 'X-Content-Type-Options manquant').toBeTruthy();
    expect(xcto.toLowerCase()).toContain('nosniff');
});

// ============================================================
// M-SEC-03 : Server header ne divulgue pas la version
// ============================================================
test('M-SEC-03 : Server header sans numéro de version', async ({ request }) => {
    const response = await request.get(`${BASE}/login`, { ignoreHTTPSErrors: true });
    const server = response.headers()['server'] || '';
    // Accepter "nginx" ou vide, rejeter "nginx/1.x.x"
    expect(server).not.toMatch(/nginx\/\d+\.\d+\.\d+/i);
    expect(server).not.toMatch(/php\/\d+\.\d+\.\d+/i);
});

// ============================================================
// M-SEC-04 : Page 404 sans divulgation d'informations internes
// ============================================================
test('M-SEC-04 : Page 404 sans stack trace ni chemin interne', async ({ request }) => {
    const response = await request.get(`${BASE}/this-page-does-not-exist-xyz123`, {
        ignoreHTTPSErrors: true,
    });
    expect(response.status()).not.toBe(500);
    const body = await response.text();
    expect(body).not.toMatch(/\/var\/www/);
    expect(body).not.toMatch(/Exception/);
    expect(body).not.toMatch(/stack trace/i);
    expect(body).not.toMatch(/Fatal error/i);
});

// ============================================================
// M-SEC-05 : Fichiers sensibles non exposés
// ============================================================
const SENSITIVE_ROUTES = [
    '/phpinfo.php',
    '/info.php',
    '/test.php',
    '/.env',
    '/.git/config',
];

for (const route of SENSITIVE_ROUTES) {
    test(`M-SEC-05 : ${route} non accessible publiquement`, async ({ request }) => {
        const response = await request.get(`${BASE}${route}`, {
            ignoreHTTPSErrors: true,
            maxRedirects: 5,
        });
        expect(response.status(), `${route} accessible (HTTP 200) — danger !`).not.toBe(200);
    });
}

// ============================================================
// M-SEC-06 : Mode maintenance désactivé
// ============================================================
test('M-SEC-06 : Nextcloud hors mode maintenance', async ({ request }) => {
    const response = await request.get(`${BASE}/status.php`, {
        ignoreHTTPSErrors: true,
    });
    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.maintenance, 'Mode maintenance activé — désactiver avant publication').toBe(false);
    expect(body.installed, 'Nextcloud non installé').toBe(true);
});

// ============================================================
// M-SEC-07 : TLS moderne (navigateur Playwright — Firefox)
// ============================================================
test('M-SEC-07 : TLS accessible via navigateur moderne', async ({ page }) => {
    // Si TLS était cassé, Playwright échouerait sur ignoreHTTPSErrors=false
    // On teste sans ignoreHTTPSErrors pour une VM avec certificat valide,
    // mais on le maintient activé en config pour les certificats auto-signés.
    const response = await page.goto(`${BASE}/status.php`, {
        waitUntil: 'domcontentloaded',
    });
    expect(response?.status()).toBeLessThan(500);
});

// ============================================================
// M-INFO-01 : robots.txt (informatif uniquement)
// ============================================================
test('M-INFO-01 : robots.txt — vérification présence (informatif)', async ({ request }) => {
    const response = await request.get(`${BASE}/robots.txt`, {
        ignoreHTTPSErrors: true,
    });
    // 200 ou 404 sont acceptables — on logge le contenu pour référence
    const statusOk = [200, 404].includes(response.status());
    expect(statusOk, `robots.txt a répondu HTTP ${response.status()}`).toBe(true);
    if (response.status() === 200) {
        const body = await response.text();
        console.info(`  robots.txt (${body.length} bytes): ${body.substring(0, 120).replace(/\n/g, ' ')}`);
    }
});
