"use client";

import { useSyncExternalStore } from "react";

export type DistanceUnit = "km" | "mi";

const KEY = "trail-units";
const METERS_PER_MILE = 1609.344;
const FEET_PER_METER = 3.28084;
const listeners = new Set<() => void>();

function readUnits(): DistanceUnit {
  try {
    return localStorage.getItem(KEY) === "mi" ? "mi" : "km";
  } catch {
    return "km";
  }
}

export function setUnits(units: DistanceUnit) {
  try {
    localStorage.setItem(KEY, units);
  } catch {
    // Storage can be blocked; the choice then lasts until the page reloads.
  }
  listeners.forEach((l) => l());
}

function subscribe(onChange: () => void) {
  listeners.add(onChange);
  return () => {
    listeners.delete(onChange);
  };
}

export function useUnits(): DistanceUnit {
  return useSyncExternalStore(subscribe, readUnits, () => "km");
}

/** A walk's length: "3.20 km" or "1.99 mi". */
export function formatDistance(meters: number, units: DistanceUnit) {
  return units === "km"
    ? `${(meters / 1000).toFixed(2)} km`
    : `${(meters / METERS_PER_MILE).toFixed(2)} mi`;
}

/** A short length such as a marked stretch: "140 m" or "460 ft". */
export function formatShortDistance(meters: number, units: DistanceUnit) {
  return units === "km"
    ? `${Math.round(meters)} m`
    : `${Math.round(meters * FEET_PER_METER)} ft`;
}
