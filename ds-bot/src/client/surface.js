import { STORAGE } from './storage.js'

// The plugin's surface mode: 'bot' paints the whole team interface over the shell,
// 'agent' withdraws every replacement so the shell's own interface comes back.
// `plain` marks a Bot-mode view whose main view is a plain session — only the
// conversation replacements come off then, the shell stays.
export function groupsFor({ mode, plain = false }) {
  return { shell: mode === 'bot', conversation: mode === 'bot' && !plain }
}

const GROUPS = ['shell', 'conversation']

// Runs every disposer even when one throws, last installed first: later entries
// lean on earlier ones (the theme's styles and tokens), never the other way round.
function disposeAll(disposers, label) {
  for (const dispose of [...disposers].reverse()) {
    try { dispose?.() } catch (error) { console.warn(`[ds-bot] ${label}`, error) }
  }
}

// Keeps the mounted groups in step with `groupsFor`. The conversation group sits on
// the shell's styles and tokens, so it comes off before the shell and goes on after.
// A group's list is cleared before it is disposed, and a failed install leaves it
// empty, so a throw never makes a later reconcile believe the group is mounted.
export function surfaceGroups(install) {
  const mounted = { shell: [], conversation: [] }
  const withdraw = (group) => {
    const disposers = mounted[group]
    mounted[group] = []
    disposeAll(disposers, `withdraw ${group}`)
  }
  return {
    reconcile(wanted) {
      for (const group of [...GROUPS].reverse()) if (!wanted[group]) withdraw(group)
      for (const group of GROUPS) {
        if (!wanted[group] || mounted[group].length > 0) continue
        try { mounted[group] = install[group]() } catch (error) { console.warn(`[ds-bot] install ${group}`, error) }
      }
    },
    dispose() { for (const group of [...GROUPS].reverse()) withdraw(group) },
  }
}

export function readMode(storage = globalThis.localStorage) {
  try { return storage.getItem(STORAGE.surface) === 'agent' ? 'agent' : 'bot' } catch { return 'bot' }
}

export function writeMode(mode, storage = globalThis.localStorage) {
  try { storage.setItem(STORAGE.surface, mode) } catch { /* storage unavailable */ }
}

// iOS's keyboard resizes the visual viewport, not the layout viewport or dvh.
// Keep these writes scoped to Bot mode and restore the host's viewport on withdrawal.
export function installMobileViewport() {
  const mobile = window.matchMedia('(max-width: 768px)')
  const viewport = window.visualViewport
  const meta = document.querySelector('meta[name="viewport"]')
  const original = meta?.getAttribute('content')
  const update = () => {
    if (mobile.matches) {
      if (meta) {
        const content = (original ?? 'width=device-width, initial-scale=1').split(',')
          .filter(part => !/^\s*(viewport-fit|interactive-widget)\s*=/.test(part))
        meta.setAttribute('content', [...content, 'viewport-fit=cover', 'interactive-widget=resizes-content'].join(','))
      }
      // Pinch zoom must remain free to pan and scale the page.
      if (!viewport || viewport.scale === 1) {
        document.body.style.setProperty('--bt-viewport-height', `${viewport?.height ?? window.innerHeight}px`)
        document.body.style.setProperty('--bt-viewport-top', `${viewport?.offsetTop ?? 0}px`)
      }
    } else {
      if (meta) {
        if (original === null) meta.removeAttribute('content')
        else meta.setAttribute('content', original)
      }
      document.body.style.removeProperty('--bt-viewport-height')
      document.body.style.removeProperty('--bt-viewport-top')
    }
  }
  update()
  mobile.addEventListener('change', update)
  window.addEventListener('resize', update)
  viewport?.addEventListener('resize', update)
  viewport?.addEventListener('scroll', update)
  return () => {
    mobile.removeEventListener('change', update)
    window.removeEventListener('resize', update)
    viewport?.removeEventListener('resize', update)
    viewport?.removeEventListener('scroll', update)
    if (meta) {
      if (original === null) meta.removeAttribute('content')
      else meta.setAttribute('content', original)
    }
    document.body.style.removeProperty('--bt-viewport-height')
    document.body.style.removeProperty('--bt-viewport-top')
  }
}
