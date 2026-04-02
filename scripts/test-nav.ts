import { chromium } from '@playwright/test';

async function main() {
  const browser = await chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-gpu'],
  });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await ctx.newPage();
  
  // Signup first
  await page.goto('http://localhost:3000/', { waitUntil: 'networkidle' });
  await page.locator('button:has-text("Get Started")').first().click();
  await page.waitForTimeout(2000);
  
  const nameField = page.locator('input#name');
  if (await nameField.isVisible({ timeout: 5000 }).catch(() => false)) {
    await nameField.fill('Admin User');
    await page.locator('input#email').fill('admin2@cbup.local');
    await page.locator('input#company').fill('CBUP Security');
    await page.locator('input#password').fill('SecurePass2025!');
    await page.locator('button[type="submit"]').click();
    await page.waitForTimeout(4000);
  }
  
  // Check all buttons
  const buttons = await page.locator('button').allTextContents();
  console.log('ALL BUTTONS:', buttons.filter(b => b.trim()));
  
  // Try getting text from page
  const bodyText = await page.textContent('body');
  const hasDashboard = bodyText.includes('Security Operations') || bodyText.includes('Dashboard');
  const hasAlerts = bodyText.includes('Alerts');
  console.log('Has Dashboard content:', hasDashboard);
  console.log('Has Alerts text:', hasAlerts);
  
  await browser.close();
}
main().catch(console.error);
