"use client";

import { useSyncExternalStore } from "react";

export type ThemePreference = "system" | "light" | "dark";

const KEY = "trail-theme";
const listeners = new Set<() => void>();

function readPreference(): ThemePreference {
  try {
    const v = localStorage.getItem(KEY);
    return v === "light" || v === "dark" ? v : "system";
  } catch {
    return "system";
  }
}

/** Puts the preference on <html>: "system" leaves the attribute off so the
    stylesheet follows the operating system. */
function applyPreference(pref: ThemePreference) {
  const root = document.documentElement;
  if (pref === "system") root.removeAttribute("data-theme");
  else root.setAttribute("data-theme", pref);
}

export function setThemePreference(pref: ThemePreference) {
  try {
    if (pref === "system") localStorage.removeItem(KEY);
    else localStorage.setItem(KEY, pref);
  } catch {
    // Storage can be blocked; the choice then lasts until the page reloads.
  }
  applyPreference(pref);
  listeners.forEach((l) => l());
}

function subscribe(onChange: () => void) {
  listeners.add(onChange);
  const media = window.matchMedia("(prefers-color-scheme: dark)");
  media.addEventListener("change", onChange);
  return () => {
    listeners.delete(onChange);
    media.removeEventListener("change", onChange);
  };
}

export function useThemePreference(): ThemePreference {
  return useSyncExternalStore(subscribe, readPreference, () => "system");
}

/** Whether the night chart is showing, resolving "system" through the OS. */
export function useIsNight(): boolean {
  return useSyncExternalStore(
    subscribe,
    () => {
      const pref = readPreference();
      if (pref === "system") return window.matchMedia("(prefers-color-scheme: dark)").matches;
      return pref === "dark";
    },
    () => false,
  );
}

/** Runs before first paint so a saved choice doesn't flash the other theme. */
export const themeInitScript = `try{var t=localStorage.getItem("${KEY}");if(t==="light"||t==="dark")document.documentElement.setAttribute("data-theme",t)}catch(e){}`;
