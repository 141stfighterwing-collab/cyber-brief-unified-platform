import { chromium } from '@playwright/test';

async function main() {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-gpu'] });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await ctx.newPage();
  
  // 1. Go to landing
  await page.goto('http://localhost:3000/', { waitUntil: 'networkidle' });
  await new Promise(r => setTimeout(r, 2000));
  
  // 2. Check what buttons we have
  const allBtns = await page.locator('button').allTextContents();
  console.log('Buttons on page:', allBtns.filter(b => b.trim()));
  
  // 3. Try clicking Get Started using text selector (not role)
  const gsBtn = page.locator('text=Get Started');
  console.log('Get Started visible:', await gsBtn.isVisible().catch(() => 'NO'));
  const gsBtn2 = page.locator('button >> text=Get Started');
  console.log('button >> text=Get Started visible:', await gsBtn2.isVisible().catch(() => 'NO'));
  
  // 4. Try clicking
  if (await gsBtn.isVisible().catch(() => false)) {
    await gsBtn.click();
    await new Promise(r => setTimeout(r, 2000));
    console.log('Clicked Get Started');
  } else if (await gsBtn2.isVisible().catch(() => false)) {
    await gsBtn2.click();
    await new Promise(r => setTimeout(r, 2000));
    console.log('Clicked Get Started v2');
  } else {
    console.log('Could not find Get Started');
  }
  
  // 5. Check page state
  const body = await page.textContent('body');
  console.log('Has name field:', body.includes('name') || body.includes('Name'));
  console.log('Has Create Account:', body.includes('Create Account'));
  
  const hasForm = await page.locator('#name').isVisible().catch(() => false);
  console.log('Name input visible:', hasForm);
  
  // 6. Check if we're on auth view by looking for form
  if (hasForm) {
    console.log('Filling form...');
    await page.locator('#name').fill('Test Admin');
    await page.locator('#email').fill('test-v5@cbup.local');
    await page.locator('#company').fill('CBUP');
    await page.locator('#password').fill('Test2025!');
    await page.locator('button[type="submit"]').click();
    await new Promise(r => setTimeout(r, 4000));
    
    // Check dashboard
    const btnsAfter = await page.locator('button').allTextContents();
    console.log('Buttons after signup:', btnsAfter.filter(b => b.trim()));
  }
  
  await browser.close();
}
main().catch(console.error);
