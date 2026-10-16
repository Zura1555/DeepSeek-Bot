import { useEffect, useLayoutEffect, useRef, useState } from "react";

// -------------------------------------------------------------------------
// Overlays: new chat, bot exchange, details drawer, context menu

// Escape closes only the newest open layer, so a dialog over the details pane does
// not take the pane down with it.
const escapeLayers = [];
const onEscapeKey = (event) => {
  if (event.key === "Escape") escapeLayers.at(-1)?.current();
};
export function useEscape(onClose, enabled = true) {
  const ref = useRef(onClose);
  ref.current = onClose;
  useEffect(() => {
    if (!enabled) return undefined;
    if (escapeLayers.length === 0)
      window.addEventListener("keydown", onEscapeKey);
    escapeLayers.push(ref);
    return () => {
      escapeLayers.splice(escapeLayers.indexOf(ref), 1);
      if (escapeLayers.length === 0)
        window.removeEventListener("keydown", onEscapeKey);
    };
  }, [enabled]);
}

export function useMobile() {
  const [mobile, setMobile] = useState(
    () => window.matchMedia("(max-width: 768px)").matches,
  );
  useEffect(() => {
    const query = window.matchMedia("(max-width: 768px)");
    const update = () => setMobile(query.matches);
    update();
    query.addEventListener("change", update);
    return () => query.removeEventListener("change", update);
  }, []);
  return mobile;
}

const mobileModals = [];
export function useMobileModal(root, active, label, covered = false) {
  const blocked = useRef(covered);
  blocked.current = covered;
  useLayoutEffect(() => {
    const node = root.current;
    if (!active || !node) return undefined;
    const previous = document.activeElement;
    const attributes = ["role", "aria-modal", "aria-label"].map((key) => [
      key,
      node.getAttribute(key),
    ]);
    node.setAttribute("role", "dialog");
    node.setAttribute("aria-modal", "true");
    if (label) node.setAttribute("aria-label", label);
    const focusable = () =>
      [
        ...node.querySelectorAll(
          'button:not(:disabled),a[href],input:not(:disabled),textarea:not(:disabled),select:not(:disabled),[tabindex="0"]',
        ),
      ].filter(
        (element) =>
          element.getClientRects().length > 0 &&
          getComputedStyle(element).visibility === "visible" &&
          !element.closest("[hidden],[inert]"),
      );
    mobileModals.push(node);
    const focus = () => {
      if (
        !blocked.current &&
        mobileModals.at(-1) === node &&
        !node.contains(document.activeElement)
      )
        focusable()[0]?.focus({ preventScroll: true });
    };
    const frame = requestAnimationFrame(focus);
    node.addEventListener("transitionend", focus);
    node.addEventListener("animationend", focus);
    const trap = (event) => {
      if (
        blocked.current ||
        event.defaultPrevented ||
        event.key !== "Tab" ||
        mobileModals.at(-1) !== node
      )
        return;
      const items = focusable();
      const first = items[0];
      const last = items.at(-1);
      if (!first) {
        event.preventDefault();
        return;
      }
      if (
        !node.contains(document.activeElement) ||
        (event.shiftKey
          ? document.activeElement === first
          : document.activeElement === last)
      ) {
        event.preventDefault();
        const target = event.shiftKey ? last : first;
        target.focus();
      }
    };
    window.addEventListener("keydown", trap);
    return () => {
      mobileModals.splice(mobileModals.lastIndexOf(node), 1);
      cancelAnimationFrame(frame);
      node.removeEventListener("transitionend", focus);
      node.removeEventListener("animationend", focus);
      window.removeEventListener("keydown", trap);
      for (const [key, value] of attributes) {
        if (value === null) node.removeAttribute(key);
        else node.setAttribute(key, value);
      }
      if (
        node.contains(document.activeElement) ||
        document.activeElement === document.body
      ) {
        const target = previous?.isConnected
          ? previous
          : document.querySelector(".bt-mobile-menu");
        requestAnimationFrame(() => {
          if (
            target?.isConnected &&
            (mobileModals.length === 0 || mobileModals.at(-1).contains(target))
          )
            target.focus({ preventScroll: true });
        });
      }
    };
  }, [active, label]);
}

// New chat and Bot exchanges show in place of the conversation, right of the sidebar.
export function usePaneLeft() {
  const [paneLeft, setPaneLeft] = useState(280);
  useLayoutEffect(() => {
    const column = document.querySelector(
      '[class*="_footArea"]',
    )?.parentElement;
    if (column) setPaneLeft(Math.round(column.getBoundingClientRect().right));
  }, []);
  return paneLeft;
}
