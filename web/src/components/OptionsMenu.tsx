"use client";

import { useEffect, useRef, useState } from "react";
import { setThemePreference, useThemePreference, type ThemePreference } from "@/lib/theme";
import { setUnits, useUnits, type DistanceUnit } from "@/lib/units";
import { DeviceIcon, MoonIcon, PersonIcon, SunIcon } from "@/components/Icons";

const THEMES: { value: ThemePreference; label: string; icon: React.ReactNode }[] = [
  { value: "light", label: "Light", icon: <SunIcon /> },
  { value: "dark", label: "Dark", icon: <MoonIcon /> },
  { value: "system", label: "Match my device", icon: <DeviceIcon /> },
];

const UNITS: { value: DistanceUnit; label: string; text: string }[] = [
  { value: "km", label: "Kilometers", text: "km" },
  { value: "mi", label: "Miles", text: "mi" },
];

/**
 * A person icon that opens the options panel: appearance, distance units and,
 * when someone is signed in, sign out.
 */
export function OptionsMenu({ onSignOut }: { onSignOut?: () => void }) {
  const [open, setOpen] = useState(false);
  const theme = useThemePreference();
  const units = useUnits();
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
        className="tc-icon-btn"
        aria-label="Options"
        aria-haspopup="true"
        aria-expanded={open}
        onClick={() => setOpen(!open)}
      >
        <PersonIcon />
      </button>
      {open && (
        <div className="tc-panel absolute right-0 top-full z-20 mt-2 flex w-64 flex-col gap-5 p-4">
          <div className="flex flex-col gap-2">
            <p className="tc-label">Appearance</p>
            <div role="radiogroup" aria-label="Appearance" className="tc-seg">
              {THEMES.map((t) => (
                <button
                  key={t.value}
                  type="button"
                  role="radio"
                  aria-checked={theme === t.value}
                  aria-label={t.label}
                  title={t.label}
                  onClick={() => setThemePreference(t.value)}
                >
                  {t.icon}
                </button>
              ))}
            </div>
          </div>
          <div className="flex flex-col gap-2">
            <p className="tc-label">Distance</p>
            <div role="radiogroup" aria-label="Distance" className="tc-seg">
              {UNITS.map((u) => (
                <button
                  key={u.value}
                  type="button"
                  role="radio"
                  aria-checked={units === u.value}
                  aria-label={u.label}
                  title={u.label}
                  onClick={() => setUnits(u.value)}
                >
                  {u.text}
                </button>
              ))}
            </div>
          </div>
          {onSignOut && (
            <button type="button" className="tc-btn tc-btn--block" onClick={onSignOut}>
              Sign out
            </button>
          )}
        </div>
      )}
    </div>
  );
}
