import { test, expect } from '@playwright/test';

test('M1-001.1 Book a future session @critical', async ({ page }) => {
  await page.goto('/book');
  await expect(page.getByText('Booking confirmed')).toBeVisible();
});

test("M1-001.2 Booked screen looks right", async ({ page }) => {
  await page.goto('/my-bookings');
});
