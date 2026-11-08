"use client";

import { Suspense, useEffect, useMemo, useRef, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import * as maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";
import rough from "roughjs";
import { supabase } from "@/lib/supabaseClient";
import { inkMapStyle } from "@/lib/inkMapStyle";
import { Compass } from "@/components/Compass";
import { useIsNight } from "@/lib/theme";
import {
  distanceMeters,
  snapRoute,
  type LngLat,
  type MatchStatus,
} from "@/lib/routeMatcher";
import { findUnmappedRuns, MIN_TRAIL_POINTS } from "@/lib/unmappedRuns";
import { fetchAllByWalk, fetchUntrackedTrails, submitUntrackedTrail } from "@/lib/walkData";
import type { Walk, WalkPoint } from "@/lib/types";

type Range = [number, number];

// Canvas colors come from the design system's CSS variables so the walk drawing
// follows the day or night chart.
function palette() {
  const css = getComputedStyle(document.documentElement);
  const read = (name: string) => css.getPropertyValue(name).trim();
  return {
    paper: read("--paper"),
    ink: read("--ink"),
    route: read("--route"),
    unmapped: read("--unmapped"),
    candidate: read("--candidate"),
  };
}

const ROUTE_WIDTH = 4;
const TRAIL_WIDTH = 6;
const UNMAPPED_DASH = [10, 7];
// How close (in screen pixels) a click must land to a dashed section to open it.
const HIT_PX = 20;

function formatDuration(seconds: number) {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  return [h, m, s].map((n) => n.toString().padStart(2, "0")).join(":");
}

function distanceToSegment(p: [number, number], a: [number, number], b: [number, number]) {
  const dx = b[0] - a[0];
  const dy = b[1] - a[1];
  const lenSq = dx * dx + dy * dy;
  const t = lenSq === 0 ? 0 : Math.max(0, Math.min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / lenSq));
  return Math.hypot(p[0] - (a[0] + t * dx), p[1] - (a[1] + t * dy));
}

export default function WalkDetailPage() {
  return (
    <Suspense>
      <WalkDetailContent />
    </Suspense>
  );
}

function WalkDetailContent() {
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const mapContainer = useRef<HTMLDivElement>(null);
  const sketchCanvas = useRef<HTMLCanvasElement>(null);
  const [walk, setWalk] = useState<Walk | null>(null);
  const [points, setPoints] = useState<WalkPoint[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [userId, setUserId] = useState<string | null>(null);
  const night = useIsNight();
  const [bearing, setBearing] = useState(0);
  const [snapped, setSnapped] = useState<LngLat[] | null>(null);
  const [statuses, setStatuses] = useState<MatchStatus[] | null>(null);
  // Set only when matching to streets failed and the recorded route is shown.
  const [snapNote, setSnapNote] = useState<string | null>(null);
  const [trails, setTrails] = useState<Range[]>([]);
  // The stretch being adjusted in the panel, as point indices.
  const [selection, setSelection] = useState<Range | null>(null);
  const [submitError, setSubmitError] = useState<string | null>(null);

  const mapRef = useRef<maplibregl.Map | null>(null);
  // The theme the map style was last built for, so a theme change restyles it.
  const styleNightRef = useRef(night);
  // What the canvas overlay draws. Kept in refs so that receiving the snapped
  // route or moving a handle only needs a repaint, not a rebuild of the whole
  // map.
  const routeRef = useRef<LngLat[]>([]);
  const gapsRef = useRef<Range[]>([]);
  const trailsRef = useRef<Range[]>([]);
  const selectionRef = useRef<Range | null>(null);
  const openGapRef = useRef<(gap: Range) => void>(() => {});

  const overlapsTrail = (start: number, end: number) =>
    trails.some(([s, e]) => start <= e && end >= s);

  // Unmapped runs that haven't been submitted yet; these are the clickable
  // dashed sections.
  const gaps = useMemo(() => {
    if (!statuses) return [];
    return findUnmappedRuns(statuses).filter(
      ([s, e]) => !trails.some(([ts, te]) => s <= te && e >= ts),
    );
  }, [statuses, trails]);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      if (!data.session) {
        router.replace("/login");
        return;
      }
      setUserId(data.session.user.id);
      Promise.all([
        supabase.from("walks").select("*").eq("id", params.id).single(),
        fetchAllByWalk<WalkPoint>("walk_points", params.id).then(
          (data) => ({ data, error: null }),
          (e: Error) => ({ data: null, error: e }),
        ),
      ]).then(([walkRes, pointsRes]) => {
        if (walkRes.error) setError(walkRes.error.message);
        else setWalk(walkRes.data as Walk);
        if (pointsRes.error) setError(pointsRes.error.message);
        else setPoints(pointsRes.data);
      });
    });
  }, [params.id, router]);

  useEffect(() => {
    if (!points || points.length === 0) return;
    let cancelled = false;
    Promise.all([
      snapRoute(
        params.id,
        points.map((p) => [p.lng, p.lat] as LngLat),
      ),
      fetchUntrackedTrails(params.id).catch(() => [] as Range[]),
    ]).then(([result, submitted]) => {
      if (cancelled) return;
      setSnapped(result.route);
      setStatuses(result.statuses);
      setSnapNote(
        result.errors.length > 0
          ? "Couldn't match this walk to streets, so the recorded route is shown."
          : null,
      );
      setTrails(submitted);
    });
    return () => {
      cancelled = true;
    };
  }, [points, params.id]);

  // Declared before the map effect so the refs are current when the map is
  // first created.
  useEffect(() => {
    if (!points) return;
    routeRef.current = snapped ?? points.map((p) => [p.lng, p.lat] as LngLat);
    gapsRef.current = gaps;
    trailsRef.current = trails;
    selectionRef.current = selection;
    openGapRef.current = ([start, end]) => {
      setSelection([start, end]);
      setSubmitError(null);
    };
    mapRef.current?.triggerRepaint();
  }, [points, snapped, gaps, trails, selection]);

  useEffect(() => {
    if (!mapContainer.current || !sketchCanvas.current || !points || points.length === 0) return;

    // Turbopack's asset pipeline breaks maplibre-gl's internal worker-loading
    // logic even when pointed at the right URL, so the worker script is served
    // as a plain static file from /public instead (copied from
    // node_modules/maplibre-gl/dist/maplibre-gl-worker.mjs — re-copy after
    // upgrading maplibre-gl).
    maplibregl.setWorkerUrl("/maplibre-gl-worker.mjs");

    const coordinates = points.map((p) => [p.lng, p.lat] as [number, number]);
    const map = new maplibregl.Map({
      container: mapContainer.current,
      style: inkMapStyle(styleNightRef.current),
      center: coordinates[0],
      zoom: 14,
    });
    map.addControl(new maplibregl.ScaleControl({ unit: "metric" }), "bottom-left");
    mapRef.current = map;

    const canvas = sketchCanvas.current;
    const roughCanvas = rough.canvas(canvas);

    const project = (coord: LngLat) => {
      const p = map.project(coord);
      return [p.x, p.y] as [number, number];
    };

    // The route is drawn on a plain 2D canvas overlay (via rough.js) rather
    // than as a native MapLibre layer, since rough.js can't hand sketchy
    // linework to MapLibre's WebGL renderer. Redrawn on every map "render"
    // so it stays pinned to the right screen position as the map moves. A
    // fixed seed keeps the sketchy wobble stable across redraws instead of
    // re-randomizing every frame.
    function drawRoute() {
      const dpr = window.devicePixelRatio || 1;
      const { clientWidth, clientHeight } = canvas;
      if (canvas.width !== clientWidth * dpr || canvas.height !== clientHeight * dpr) {
        canvas.width = clientWidth * dpr;
        canvas.height = clientHeight * dpr;
      }
      const ctx = canvas.getContext("2d");
      if (!ctx) return;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, clientWidth, clientHeight);

      const route = routeRef.current;
      const gaps = gapsRef.current;
      const screen = route.map(project);
      const line = (from: number, to: number) =>
        screen.slice(Math.max(0, from), Math.min(screen.length, to + 1));
      const colors = palette();
      // A low roughness keeps the line legible while it still reads as pen.
      const base = { roughness: 1.2, bowing: 1, seed: 1 };

      // A paper halo under a stroke so it separates from roads and the route.
      const traceLine = (pts: [number, number][], width: number) => {
        if (pts.length === 0) return;
        ctx.save();
        ctx.lineWidth = width;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.strokeStyle = colors.paper;
        ctx.beginPath();
        pts.forEach(([x, y], i) => (i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)));
        ctx.stroke();
        ctx.restore();
      };
      traceLine(screen, ROUTE_WIDTH + 6);

      if (gaps.length === 0) {
        roughCanvas.linearPath(screen, { ...base, stroke: colors.route, strokeWidth: ROUTE_WIDTH });
      } else {
        // Mapped stretches solid, unmapped (clickable) sections dashed.
        let from = 0;
        for (const [start, end] of gaps) {
          roughCanvas.linearPath(line(from, start), {
            ...base,
            stroke: colors.route,
            strokeWidth: ROUTE_WIDTH,
          });
          roughCanvas.linearPath(line(start - 1, end + 1), {
            ...base,
            stroke: colors.unmapped,
            strokeWidth: ROUTE_WIDTH,
            strokeLineDash: UNMAPPED_DASH,
          });
          from = end;
        }
        roughCanvas.linearPath(line(from, screen.length), {
          ...base,
          stroke: colors.route,
          strokeWidth: ROUTE_WIDTH,
        });
      }

      for (const [start, end] of trailsRef.current) {
        traceLine(line(start, end), TRAIL_WIDTH + 6);
        roughCanvas.linearPath(line(start, end), {
          ...base,
          stroke: colors.candidate,
          strokeWidth: TRAIL_WIDTH,
        });
      }

      const sel = selectionRef.current;
      if (sel) {
        const part = line(sel[0], sel[1]);
        traceLine(part, TRAIL_WIDTH + 8);
        roughCanvas.linearPath(part, { ...base, stroke: colors.candidate, strokeWidth: TRAIL_WIDTH });
      }

      // Start is an open circle, end a circle with a solid center; the two
      // selection handles are open circles too.
      const marker = ([x, y]: [number, number], filled: boolean, radius = 9) => {
        ctx.save();
        ctx.beginPath();
        ctx.arc(x, y, radius, 0, Math.PI * 2);
        ctx.fillStyle = colors.paper;
        ctx.fill();
        ctx.lineWidth = 2.5;
        ctx.strokeStyle = colors.ink;
        ctx.stroke();
        if (filled) {
          ctx.beginPath();
          ctx.arc(x, y, radius - 4, 0, Math.PI * 2);
          ctx.fillStyle = colors.ink;
          ctx.fill();
        }
        ctx.restore();
      };
      if (screen.length > 1) {
        marker(screen[0], false);
        marker(screen[screen.length - 1], true);
      }
      if (sel) {
        for (const i of sel) if (screen[i]) marker(screen[i], false, 11);
      }
    }

    // The dashed section under a click or hover, if any.
    function gapAt(point: { x: number; y: number }): Range | null {
      const route = routeRef.current;
      let best: Range | null = null;
      let bestDist = HIT_PX;
      for (const gap of gapsRef.current) {
        let prev: [number, number] | null = null;
        for (let i = Math.max(0, gap[0] - 1); i <= Math.min(route.length - 1, gap[1] + 1); i++) {
          const cur = project(route[i]);
          if (prev) {
            const d = distanceToSegment([point.x, point.y], prev, cur);
            if (d < bestDist) {
              bestDist = d;
              best = gap;
            }
          }
          prev = cur;
        }
      }
      return best;
    }

    const onClick = (e: maplibregl.MapMouseEvent) => {
      const gap = gapAt(e.point);
      if (gap) openGapRef.current(gap);
    };
    const onMove = (e: maplibregl.MapMouseEvent) => {
      map.getCanvas().style.cursor = gapAt(e.point) ? "pointer" : "";
    };

    map.on("load", () => {
      const bounds = coordinates.reduce(
        (b, coord) => b.extend(coord as [number, number]),
        new maplibregl.LngLatBounds(coordinates[0] as [number, number], coordinates[0] as [number, number]),
      );
      map.fitBounds(bounds, { padding: 60, duration: 0 });
    });
    // Keep the compass turned with the map.
    const onRotate = () => setBearing(map.getBearing());
    map.on("render", drawRoute);
    map.on("click", onClick);
    map.on("mousemove", onMove);
    map.on("rotate", onRotate);

    return () => {
      map.off("render", drawRoute);
      map.off("click", onClick);
      map.off("mousemove", onMove);
      map.off("rotate", onRotate);
      map.remove();
      mapRef.current = null;
    };
  }, [points]);

  // Restyle the basemap when the theme changes.
  useEffect(() => {
    if (styleNightRef.current === night) return;
    styleNightRef.current = night;
    mapRef.current?.setStyle(inkMapStyle(night));
  }, [night]);

  // Colour strip of the whole walk for the panel: mapped vs unmapped stretches.
  const runs = useMemo(() => {
    if (!statuses) return [];
    const out: { mapped: boolean; length: number }[] = [];
    for (const s of statuses) {
      const mapped = s === "matched";
      const last = out[out.length - 1];
      if (last && last.mapped === mapped) last.length++;
      else out.push({ mapped, length: 1 });
    }
    return out;
  }, [statuses]);

  const lastIndex = (statuses?.length ?? 1) - 1;

  // Length in metres of the stretch being adjusted, along the drawn route.
  const selectionMeters = useMemo(() => {
    const route = snapped ?? (points ?? []).map((p) => [p.lng, p.lat] as LngLat);
    if (!selection) return 0;
    let total = 0;
    for (let i = selection[0] + 1; i <= selection[1] && i < route.length; i++) {
      total += distanceMeters(route[i - 1], route[i]);
    }
    return total;
  }, [selection, snapped, points]);

  function closePanel() {
    setSelection(null);
    setSubmitError(null);
  }

  async function submit() {
    if (!selection || !userId) return;
    const [start, end] = selection;
    if (overlapsTrail(start, end)) {
      setSubmitError("That stretch overlaps one you already submitted.");
      return;
    }
    try {
      await submitUntrackedTrail(params.id, userId, start, end);
      setTrails((prev) => [...prev, [start, end]]);
      closePanel();
    } catch (e) {
      setSubmitError(`Couldn't submit: ${e instanceof Error ? e.message : e}`);
    }
  }

  return (
    <main className="relative h-dvh w-full overflow-hidden">
      <div ref={mapContainer} className="absolute inset-0 h-full w-full" />
      <canvas ref={sketchCanvas} className="pointer-events-none absolute inset-0 h-full w-full" />

      <Compass
        size={72}
        bearing={bearing}
        onReset={() => mapRef.current?.easeTo({ bearing: 0, duration: 300 })}
        className="absolute top-4 right-4 z-10"
      />

      <div className="tc-panel absolute top-4 left-4 z-10 flex w-[min(22rem,calc(100%-7rem))] flex-col gap-3 p-4">
        <div className="flex items-start gap-3">
          <Link href="/walks" aria-label="Back to walks" className="tc-close shrink-0">
            ‹
          </Link>
          <div className="min-w-0">
            {error && <p className="tc-error">{error}</p>}
            {walk && (
              <>
                <h1 className="tc-title-md">{(walk.distance_meters / 1000).toFixed(2)} km</h1>
                <p className="tc-data text-[var(--ink-soft)]">
                  {new Date(walk.started_at).toLocaleString()} · {formatDuration(walk.duration_seconds)}
                </p>
              </>
            )}
          </div>
        </div>

        {snapNote && <p className="tc-caption">{snapNote}</p>}

        {statuses && (
          <div className="flex flex-wrap gap-x-5 gap-y-2">
            <div className="flex items-center gap-2">
              <svg width="36" height="10" viewBox="0 0 36 10" aria-hidden="true">
                <path d="M2 5 H34" stroke="var(--route)" strokeWidth="4" strokeLinecap="round" />
              </svg>
              <span className="tc-label">On the map</span>
            </div>
            <div className="flex items-center gap-2">
              <svg width="36" height="10" viewBox="0 0 36 10" aria-hidden="true">
                <path
                  d="M2 5 H34"
                  stroke="var(--unmapped)"
                  strokeWidth="4"
                  strokeLinecap="round"
                  strokeDasharray="10 7"
                />
              </svg>
              <span className="tc-label">Unmapped</span>
            </div>
          </div>
        )}
        {gaps.length > 0 && !selection && (
          <p className="tc-hint">Click a dashed stretch to mark it as a trail.</p>
        )}
      </div>

      {selection && (
        <div className="tc-panel absolute bottom-10 left-1/2 z-10 flex w-[min(28rem,calc(100%-2rem))] -translate-x-1/2 flex-col gap-4 p-4">
          <div className="flex items-center justify-between gap-4">
            <h2 className="tc-title-md">Mark an untracked trail</h2>
            <button type="button" aria-label="Close" onClick={closePanel} className="tc-close shrink-0">
              ×
            </button>
          </div>

          <div className="dual-range relative h-7">
            <div className="absolute inset-x-[14px] top-[7px]">
              <div className="tc-strip">
                {runs.map((r, i) => (
                  <div
                    key={i}
                    style={{ flexGrow: r.length, background: r.mapped ? "var(--route)" : "var(--unmapped)" }}
                  />
                ))}
                <div
                  className="absolute inset-y-0"
                  style={{
                    left: `${(selection[0] / lastIndex) * 100}%`,
                    width: `${((selection[1] - selection[0]) / lastIndex) * 100}%`,
                    background: "var(--candidate)",
                  }}
                />
              </div>
            </div>
            <input
              type="range"
              aria-label="Trail start"
              min={0}
              max={lastIndex}
              step={1}
              value={selection[0]}
              onChange={(e) => {
                const v = Number(e.target.value);
                setSelection([Math.min(v, selection[1] - MIN_TRAIL_POINTS), selection[1]]);
                setSubmitError(null);
              }}
            />
            <input
              type="range"
              aria-label="Trail end"
              min={0}
              max={lastIndex}
              step={1}
              value={selection[1]}
              onChange={(e) => {
                const v = Number(e.target.value);
                setSelection([selection[0], Math.max(v, selection[0] + MIN_TRAIL_POINTS)]);
                setSubmitError(null);
              }}
            />
          </div>

          <div className="tc-data flex justify-between gap-4">
            <span>Point {selection[0] + 1}</span>
            <span>
              {selection[1] - selection[0] + 1} points · {Math.round(selectionMeters)} m
            </span>
            <span>Point {selection[1] + 1}</span>
          </div>

          {submitError && <p className="tc-error">{submitError}</p>}

          <button type="button" onClick={submit} className="tc-btn tc-btn--primary tc-btn--block">
            Submit
          </button>
        </div>
      )}
    </main>
  );
}
