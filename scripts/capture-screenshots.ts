/**
 * CBUP Screenshot Capture Script — FINAL VERSION
 * Captures all platform views: landing, auth, dashboard, alerts, briefs, monitoring, workflow, APIs
 */
import { chromium, type Page } from '@playwright/test';
import * as fs from 'fs';

const BASE_URL = process.env.BASE_URL || 'http://localhost:3000';
const DIR = process.env.SCREENSHOT_DIR || '/home/z/my-project/download/screenshots';

const wait = (ms: number) => new Promise(r => setTimeout(r, ms));

async function shot(page: Page, name: string, ms = 2000): Promise<boolean> {
  const p = `${DIR}/${name}.png`;
  try {
    await wait(ms);
    await page.screenshot({ path: p, fullPage: true, animations: 'disabled' });
    console.log(`  ${(fs.statSync(p).size / 1024).toFixed(0).padStart(5)}KB  ${name}.png`);
    return true;
  } catch (e: any) { console.log(`  FAIL  ${name}: ${e.message}`); return false; }
}

async function apiShot(page: Page, name: string, endpoint: string, title: string, color: string): Promise<boolean> {
  const p = `${DIR}/${name}.png`;
  try {
    const res = await page.goto(`${BASE_URL}${endpoint}`, { waitUntil: 'networkidle' });
    const status = res?.status() || 0;
    const body = await page.textContent('body') || '{}';
    
    await page.setContent(`<!DOCTYPE html><html><head><style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'SF Mono',monospace;background:linear-gradient(135deg,#0a0f0d,#0d1117);color:#c9d1d9;padding:48px;min-height:100vh}
.tag{display:inline-block;padding:4px 12px;border-radius:6px;font-size:13px;font-weight:700;margin-right:10px}
.endpoint{color:#8b949e;font-size:14px;margin-bottom:8px}
h1{color:#e6edf3;font-size:22px;margin:12px 0 20px;font-weight:600}
pre{background:#161b22;padding:28px;border-radius:12px;border:1px solid #30363d;overflow-x:auto;white-space:pre-wrap;font-size:14px;line-height:1.7;color:#e6edf3}
.foot{margin-top:32px;padding-top:16px;border-top:1px solid #21262d;color:#484f58;font-size:12px}
.sm{display:inline-block;padding:2px 8px;border-radius:4px;font-size:11px;font-weight:600;margin-right:6px}
</style></head><body>
<div class="tag" style="background:${color};color:#fff">GET</div>
<div class="endpoint">${endpoint}</div>
<h1>${title}</h1>
<div style="margin-bottom:20px">
  <span class="sm" style="background:#1f2937;color:#9ca3af">CBUP v0.3.0</span>
  <span class="sm" style="background:#064e3b;color:#6ee7b7">SQLite</span>
  <span class="sm" style="background:${status < 400 ? '#064e3b' : '#450a0a'};color:${status < 400 ? '#6ee7b7' : '#fca5a5'}">HTTP ${status}</span>
</div>
<pre>${body}</pre>
<div class="foot">Cyber Brief Unified Platform | ${new Date().toISOString()}</div>
</body></html>`);
    await page.screenshot({ path: p, fullPage: true });
    console.log(`  ${(fs.statSync(p).size / 1024).toFixed(0).padStart(5)}KB  ${name}.png`);
    return true;
  } catch (e: any) { console.log(`  FAIL  ${name}: ${e.message}`); return false; }
}

async function main() {
  console.log('CBUP Screenshot Capture — Final');
  console.log(`URL: ${BASE_URL} | Dir: ${DIR}\n`);

  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-gpu'] });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2 });
  let ok = 0, fail = 0;

  // ═══ LANDING ═══
  console.log('── Landing Page ──');
  const lp = await ctx.newPage();
  await lp.goto(`${BASE_URL}/`, { waitUntil: 'networkidle' });
  if (await shot(lp, '01-landing-hero', 3000)) ok++; else fail++;

  await lp.evaluate(() => { document.querySelectorAll('section,div').forEach(e => { if (e.textContent?.includes('Real-Time')) e.scrollIntoView({ behavior: 'instant' }); }); });
  if (await shot(lp, '02-features', 2000)) ok++; else fail++;

  await lp.evaluate(() => { document.querySelectorAll('section,div').forEach(e => { if (e.textContent?.includes('$29/mo')) e.scrollIntoView({ behavior: 'instant' }); }); });
  if (await shot(lp, '03-pricing', 2000)) ok++; else fail++;

  await lp.evaluate(() => window.scrollTo(0, document.body.scrollHeight * 0.72));
  if (await shot(lp, '04-sample-brief', 2000)) ok++; else fail++;

  await lp.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
  if (await shot(lp, '05-testimonials', 2000)) ok++; else fail++;
  await lp.close();

  // ═══ AUTH ═══
  console.log('\n── Auth Pages ──');
  const ap = await ctx.newPage();
  await ap.goto(`${BASE_URL}/`, { waitUntil: 'networkidle' });
  await wait(1000);

  // Use the working selector pattern
  const gsBtn = ap.locator('button:has-text("Get Started")').first();
  await gsBtn.click();
  await wait(2000);
  if (await shot(ap, '06-auth-signup', 2000)) ok++; else fail++;

  // Switch to Sign In
  const siTab = ap.locator('button:has-text("Sign In")').first();
  if (await siTab.isVisible().catch(() => false)) {
    await siTab.click();
    await wait(1500);
  }
  if (await shot(ap, '07-auth-login', 2000)) ok++; else fail++;
  await ap.close();

  // ═══ DASHBOARD (Authenticated) ═══
  console.log('\n── Dashboard Views ──');
  const dp = await ctx.newPage();
  await dp.goto(`${BASE_URL}/`, { waitUntil: 'networkidle' });
  await wait(1000);

  // Click Get Started to go to auth
  await dp.locator('button:has-text("Get Started")').first().click();
  await wait(2000);

  // Ensure we're on signup (not login)
  const suTab = dp.locator('button:has-text("Sign Up")').first();
  if (await suTab.isVisible().catch(() => false)) {
    await suTab.click();
    await wait(1000);
  }

  // Fill the form
  const nameEl = dp.locator('#name');
  if (await nameEl.isVisible({ timeout: 5000 }).catch(() => false)) {
    await nameEl.fill('Playwright Admin');
    await dp.locator('#email').fill(`pw-${Date.now()}@cbup.local`);
    await dp.locator('#company').fill('CBUP Security');
    await dp.locator('#password').fill('Playwright2025!');
    await dp.locator('button[type="submit"]').click();
    console.log('  Signup submitted, waiting for redirect...');
    await wait(5000);
  } else {
    console.log('  WARN: signup form not visible');
  }

  // Dashboard
  if (await shot(dp, '08-dashboard', 3000)) ok++; else fail++;

  // Navigate views
  for (const [label, file] of [['Alerts', '09-alerts'], ['Briefs', '10-briefs'], ['Monitoring', '11-monitoring'], ['Workflow', '12-workflow']]) {
    const btn = dp.locator(`button:has-text("${label}")`).first();
    const vis = await btn.isVisible().catch(() => false);
    if (vis) {
      await btn.click();
      await wait(500);
      if (await shot(dp, file, 3000)) ok++; else fail++;
    } else {
      console.log(`  WARN: "${label}" not found`);
      fail++;
    }
  }
  await dp.close();

  // ═══ APIs ═══
  console.log('\n── API Endpoints ──');
  const ep = await ctx.newPage();
  if (await apiShot(ep, '13-api-db-status', '/api/db-status', 'Database Status', '#10b981')) ok++; else fail++;
  if (await apiShot(ep, '14-api-alerts', '/api/alerts', 'Security Alerts Feed', '#f59e0b')) ok++; else fail++;
  if (await apiShot(ep, '15-api-stats', '/api/dashboard/stats', 'Dashboard Statistics', '#3b82f6')) ok++; else fail++;
  if (await apiShot(ep, '16-api-briefs', '/api/briefs/latest', 'Latest Intelligence Brief', '#8b5cf6')) ok++; else fail++;
  await ep.close();

  await browser.close();

  const files = fs.readdirSync(DIR).filter(f => f.endsWith('.png') && !f.includes('-error'));
  const mb = (files.reduce((s, f) => s + fs.statSync(`${DIR}/${f}`).size, 0) / 1048576).toFixed(1);

  console.log(`\n════════════════════════════════════`);
  console.log(`  ${files.length} screenshots (${mb}MB)`);
  console.log(`  ${ok} passed, ${fail} failed`);
  console.log(`  ${DIR}`);
  console.log(`════════════════════════════════════`);
}

main().catch(e => { console.error(e); process.exit(1); });
