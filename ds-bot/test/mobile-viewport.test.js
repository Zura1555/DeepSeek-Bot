import assert from "node:assert/strict";
import { test } from "node:test";
import { installMobileViewport } from "../src/client/surface.js";

test("mobile viewport follows the keyboard, leaves zoom free, and restores the host on exit", (t) => {
  const mobile = Object.assign(new EventTarget(), { matches: false });
  const viewport = Object.assign(new EventTarget(), {
    height: 800,
    offsetTop: 0,
    scale: 1,
  });
  const window = Object.assign(new EventTarget(), {
    matchMedia: () => mobile,
    visualViewport: viewport,
  });
  const properties = new Map();
  const style = {
    setProperty: (key, value) => properties.set(key, value),
    removeProperty: (key) => properties.delete(key),
  };
  const original = "width=device-width, initial-scale=1, viewport-fit=contain";
  let content = original;
  const meta = {
    getAttribute: () => content,
    setAttribute: (_key, value) => {
      content = value;
    },
  };
  for (const [key, value] of Object.entries({
    window,
    document: { body: { style }, querySelector: () => meta },
  })) {
    const original = Object.getOwnPropertyDescriptor(globalThis, key);
    Object.defineProperty(globalThis, key, { configurable: true, value });
    t.after(() => {
      if (original) Object.defineProperty(globalThis, key, original);
      else delete globalThis[key];
    });
  }
  const dispose = installMobileViewport();
  assert.equal(content, original);
  assert.equal(properties.size, 0);
  mobile.matches = true;
  mobile.dispatchEvent(new Event("change"));
  assert.equal(properties.get("--bt-viewport-height"), "800px");
  assert.ok(content.includes("viewport-fit=cover"));
  viewport.height = 420;
  viewport.offsetTop = 32;
  viewport.dispatchEvent(new Event("resize"));
  assert.equal(properties.get("--bt-viewport-height"), "420px");
  assert.equal(properties.get("--bt-viewport-top"), "32px");
  viewport.scale = 2;
  viewport.height = 210;
  viewport.dispatchEvent(new Event("resize"));
  assert.equal(properties.get("--bt-viewport-height"), "420px");
  mobile.matches = false;
  mobile.dispatchEvent(new Event("change"));
  assert.equal(content, original);
  assert.equal(properties.size, 0);
  dispose();
  mobile.matches = true;
  viewport.dispatchEvent(new Event("resize"));
  assert.equal(properties.size, 0);
});
