// image-tests/playwright/playwright.config.js
// Configuration Playwright pour les tests Nextcloud Marketplace
// node_modules installés à la racine du projet (ADR-602, package.json à la racine)
//
// Variables d'environnement lues :
//   TEST_VM_IP              - IP publique de la VM de test
//   TEST_VM_FQDN            - FQDN DNS de la VM (défini après vm-test-dns-assign)
//                             Si présent, les tests utilisent le FQDN plutôt que l'IP.
//   TEST_NC_ADMIN_USER      - Administrateur Nextcloud (défaut: ncadmin)
//   TEST_NC_ADMIN_PASS      - Mot de passe admin Nextcloud

import { defineConfig, devices } from '@playwright/test';
import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Lecture du state file .image-test-state pour récupérer IP et credentials
const STATE_FILE = resolve(__dirname, '../../.image-test-state');
const state = {};
try {
    const lines = readFileSync(STATE_FILE, 'utf-8').split('\n');
    for (const line of lines) {
        const eqIdx = line.indexOf('=');
        if (eqIdx > 0) {
            const key = line.substring(0, eqIdx).trim();
            const val = line.substring(eqIdx + 1).trim();
            if (key) state[key] = val;
        }
    }
} catch {
    // State file absent — on se rabat sur les variables d'environnement
}

export const vmIp      = process.env.TEST_VM_IP         || state.TEST_VM_IP         || 'localhost';
// vmFqdn : utilise le FQDN DNS si disponible (après vm-test-dns-assign), sinon l'IP.
// Permet d'exécuter les mêmes specs contre l'IP (phase 1) puis contre le nom DNS (phase 6).
export const vmFqdn    = process.env.TEST_VM_FQDN       || state.TEST_VM_FQDN       || vmIp;
export const adminUser = process.env.TEST_NC_ADMIN_USER || state.TEST_NC_ADMIN_USER || 'ncadmin';
export const adminPass = process.env.TEST_NC_ADMIN_PASS  || state.TEST_NC_ADMIN_PASS  || 'changeme123!';

export default defineConfig({
    testDir: '.',
    timeout: 30_000,
    retries: 1,
    fullyParallel: false, // tests séquentiels (état de session partagé)
    reporter: [
        ['list'],
        ['html', {
            outputFolder: resolve(__dirname, '../../.test-reports/playwright'),
            open: 'never',
        }],
    ],

    use: {
        baseURL: `https://${vmFqdn}`,
        ignoreHTTPSErrors: true, // certificat auto-signé en environnement de test
        screenshot: 'only-on-failure',
        video: 'retain-on-failure',
        trace: 'on-first-retry',
    },

    projects: [
        {
            name: 'firefox',
            use: {
                ...devices['Desktop Firefox'],
                ignoreHTTPSErrors: true,
            },
        },
    ],
});
