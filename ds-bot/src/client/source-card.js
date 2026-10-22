import { createElement as h, Fragment, useEffect, useRef, useState } from 'react'
import { GlobeIcon } from './icons.js'
import { MENTION_ORIGIN } from './text.js'
import { t } from './i18n.js'

// Read the links Markdown already accepted, rather than parse untrusted Markdown twice.
export function messageSources(element) {
  const links = new Map()
  for (const anchor of element.querySelectorAll('a[href]')) {
    let url
    try { url = new URL(anchor.getAttribute('href')) } catch { continue }
    if (!['https:', 'http:'].includes(url.protocol) || url.href.startsWith(MENTION_ORIGIN) || url.username || url.password) continue
    const title = anchor.textContent.replace(/\s+/g, ' ').trim()
    if (!title || links.has(url.href)) continue
    links.set(url.href, { href: url.href, host: url.hostname, title })
  }
  return [...links.values()]
}

function SourceIcon({ host }) {
  const [state, setState] = useState('loading')
  const publicHost = /^[a-z\d.-]+\.[a-z]{2,}$/i.test(host) && !/\.(local|localhost|internal|test|invalid|example|onion|arpa)$/i.test(host)
  return h('span', { className: 'bt-source-icon', 'aria-hidden': true },
    state === 'loaded' ? null : h(GlobeIcon),
    !publicHost || state === 'failed' ? null : h('img', {
      src: `https://icons.duckduckgo.com/ip3/${encodeURIComponent(host)}.ico`,
      alt: '', width: 16, height: 16, loading: 'lazy', decoding: 'async', referrerPolicy: 'no-referrer',
      'data-loaded': state === 'loaded' || undefined,
      onLoad: () => setState('loaded'), onError: () => setState('failed'),
    }))
}

export function SourceMessage({ children, text, streaming }) {
  const content = useRef(null)
  const [sources, setSources] = useState([])
  useEffect(() => {
    if (!streaming) setSources(messageSources(content.current))
  }, [text, streaming])
  return h(Fragment, null,
    h('div', { ref: content }, children),
    !streaming && sources.length ? h('aside', { className: 'bt-sources', 'aria-label': t('Sources') },
      h('div', { className: 'bt-sources-label' }, t('Sources')),
      h('ul', null, sources.map(source => h('li', { key: source.href },
        h('a', { href: source.href, title: source.href, target: '_blank', rel: 'noopener noreferrer' },
          h(SourceIcon, { key: source.host, host: source.host }),
          h('span', { className: 'bt-source-title' }, source.title)))))) : null)
}
