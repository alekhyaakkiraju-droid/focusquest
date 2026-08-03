import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(fileURLToPath(import.meta.url));

test("App component exports default function", () => {
  const source = readFileSync(join(root, "../src/App.jsx"), "utf8");
  assert.match(source, /export default function App/);
  assert.match(source, /Parent Dashboard/);
});
