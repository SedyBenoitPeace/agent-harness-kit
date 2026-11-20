import { test } from "@playwright/test";

test(
  "M1-001.1 user's future session",
  { tag: "@critical" },
  async ({ page }) => {
    await page.goto("/book");
  },
);

test("M1-001.2 Booked screen looks right", async () => {});
