import assert from 'node:assert/strict'
import { test } from 'node:test'
import { createRequire } from 'node:module'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { runInNewContext } from 'node:vm'
import { build } from 'esbuild'

const requireHarness = createRequire(join(process.env.DSH_HARNESS, 'package.json'))
const { JSDOM } = requireHarness('jsdom')
const bundle = await build({
  entryPoints: [fileURLToPath(new URL('../src/client/source-card.js', import.meta.url))],
  bundle: true, format: 'cjs', platform: 'node', write: false, external: ['react'],
})
const module = { exports: {} }
runInNewContext(bundle.outputFiles[0].text, {
  module, exports: module.exports, URL,
  require: name => { if (name === 'react') return {}; throw new Error(`unexpected module ${name}`) },
})

test('sources retain authored web links once, excluding mentions, unsafe URLs and image-only links', () => {
  const { document } = new JSDOM(`<main>
    <a href="https://EXAMPLE.com/news?q=one#release"> Release <strong>notes</strong> </a>
    <a href="https://example.com/news?q=one#release">Repeated citation</a>
    <a href="http://other.example.org/">Another source</a>
    <a href="https://bots.local/chief">Chief</a>
    <a href="mailto:team@example.com">Email</a>
    <a href="javascript:alert(1)">Unsafe</a>
    <a href="data:text/html,bad">Data</a>
    <a href="file:///tmp/report">File</a>
    <a href="/api/private">Relative</a>
    <a href="#footnote">Footnote</a>
    <a href="https://user:password@example.com/private">Credentials</a>
    <a href="https://example.com/picture"><img alt="Picture"></a>
    <a href="https://example.com/empty"> </a>
    <code>https://not-a-link.example.com/</code>
  </main>`).window
  assert.deepEqual(JSON.parse(JSON.stringify(module.exports.messageSources(document.querySelector('main')))), [
    { href: 'https://example.com/news?q=one#release', host: 'example.com', title: 'Release notes' },
    { href: 'http://other.example.org/', host: 'other.example.org', title: 'Another source' },
  ])
})
