"use client";

import { useEffect, useRef, useState } from "react";
import { setThemePreference, useThemePreference, type ThemePreference } from "@/lib/theme";

const CHOICES: { value: ThemePreference; label: string }[] = [
  { value: "light", label: "Light" },
  { value: "dark", label: "Dark" },
  { value: "system", label: "Match my device" },
];

/** An Options link that opens a small panel for choosing the theme. */
export function OptionsMenu() {
  const [open, setOpen] = useState(false);
  const pref = useThemePreference();
  const root = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onPointer = (e: PointerEvent) => {
      if (root.current && !root.current.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    document.addEventListener("pointerdown", onPointer);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("pointerdown", onPointer);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  return (
    <div ref={root} className="relative">
      <button
        type="button"
        className="tc-link"
        aria-haspopup="true"
        aria-expanded={open}
        onClick={() => setOpen(!open)}
      >
        Options
      </button>
      {open && (
        <div className="tc-panel absolute right-0 top-full z-20 mt-2 flex w-60 flex-col gap-1 p-3">
          <p className="tc-label px-3 pb-1">Appearance</p>
          <div role="radiogroup" aria-label="Appearance" className="flex flex-col gap-1">
            {CHOICES.map((c) => (
              <button
                key={c.value}
                type="button"
                role="radio"
                aria-checked={pref === c.value}
                className="tc-choice"
                onClick={() => setThemePreference(c.value)}
              >
                <i aria-hidden="true" />
                {c.label}
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
