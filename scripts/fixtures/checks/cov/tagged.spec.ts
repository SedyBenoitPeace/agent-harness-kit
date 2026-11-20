import { test } from '@playwright/test';

// a comment naming 'M1-001.1 book' is not a test
test("M1-001.1 user's future session", { tag: '@critical' }, async ({ page }) => {
  await page.goto('/book'); // needs Python3.11 or newer: 'Python3.11 or newer'
});

test(`M1-001.2 Booked screen looks right`, async () => {});

const model = "GPT-4.1 mini"; // a dashed version string is not a check
