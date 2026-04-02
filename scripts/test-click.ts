import { chromium } from '@playwright/test';

async function main() {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-gpu'] });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await ctx.newPage();
  
  await page.goto('http://localhost:3000/', { waitUntil: 'networkidle' });
  await new Promise(r => setTimeout(r, 2000));
  
  // Try each "Get Started" variant
  for (const text of ['Get Started', 'Get Started Free', 'Start Free Trial']) {
    const locator = page.locator(`button:has-text("${text}")`).first();
    const visible = await locator.isVisible().catch(() => false);
    console.log(`"${text}" visible: ${visible}`);
    if (visible) {
      await locator.click();
      await new Promise(r => setTimeout(r, 2000));
      console.log(`  Clicked "${text}"`);
      break;
    }
  }
  
  // Now check state
  const hasAuthForm = await page.locator('#name').isVisible().catch(() => false);
  console.log('Auth form visible:', hasAuthForm);
  
  const body = await page.textContent('body');
  console.log('Has "Create your account":', body.includes('Create your account'));
  console.log('Has "Welcome back":', body.includes('Welcome back'));
  
  if (!hasAuthForm) {
    // Maybe we need to click Sign In first to trigger the auth view
    // The SPA uses Zustand state. Let me try clicking Sign In
    const signInBtn = page.locator('button:has-text("Sign In")').first();
    if (await signInBtn.isVisible().catch(() => false)) {
      await signInBtn.click();
      await new Promise(r => setTimeout(r, 2000));
      console.log('Clicked Sign In');
      
      // Now switch to Sign Up tab
      const signUpTab = page.locator('button:has-text("Sign Up")').first();
      if (await signUpTab.isVisible().catch(() => false)) {
        await signUpTab.click();
        await new Promise(r => setTimeout(r, 2000));
        console.log('Clicked Sign Up tab');
      }
    }
    
    const hasAuthFormNow = await page.locator('#name').isVisible().catch(() => false);
    console.log('Auth form visible after Sign In:', hasAuthFormNow);
    
    if (hasAuthFormNow) {
      await page.locator('#name').fill('Playwright Admin');
      await page.locator('#email').fill('pw-admin@cbup.local');
      await page.locator('#company').fill('CBUP Security');
      await page.locator('#password').fill('Secure2025!');
      await page.locator('button[type="submit"]').click();
      console.log('Submitted signup form');
      await new Promise(r => setTimeout(r, 4000));
      
      const btns = await page.locator('button').allTextContents();
      console.log('After signup:', btns.filter(b => b.trim()));
    }
  }
  
  await browser.close();
}
main().catch(console.error);
