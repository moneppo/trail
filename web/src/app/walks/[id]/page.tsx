"use client";

import { Suspense, useEffect, useMemo, useRef, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import * as maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";
import rough from "roughjs";
import { supabase } from "@/lib/supabaseClient";
import { antiqueMapStyle } from "@/lib/antiqueMapStyle";
import {
  describeResult,
  snapRoute,
  type LngLat,
  type MatchStatus,
} from "@/lib/routeMatcher";
import { findUnmappedRuns, MIN_TRAIL_POINTS } from "@/lib/unmappedRuns";
import { fetchAllByWalk, fetchUntrackedTrails, submitUntrackedTrail } from "@/lib/walkData";
import type { Walk, WalkPoint } from "@/lib/types";

type Range = [number, number];

const INK = "#7a1f1f";
const MATCHED = "#1D9E75";
const UNMAPPED = "#BA7517";
const TRAIL = "#534AB7";
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
  const [snap, setSnap] = useState(true);
  const [snapped, setSnapped] = useState<LngLat[] | null>(null);
  const [statuses, setStatuses] = useState<MatchStatus[] | null>(null);
  const [snapStatus, setSnapStatus] = useState<string | null>(null);
  const [trails, setTrails] = useState<Range[]>([]);
  // The stretch being adjusted in the panel, as point indices.
  const [selection, setSelection] = useState<Range | null>(null);
  const [submitError, setSubmitError] = useState<string | null>(null);

  const mapRef = useRef<maplibregl.Map | null>(null);
  // What the canvas overlay draws. Kept in refs so that toggling snapping,
  // receiving the snapped route or moving a handle only needs a repaint, not
  // a rebuild of the whole map.
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
    if (!snap || !statuses) return [];
    return findUnmappedRuns(statuses).filter(
      ([s, e]) => !trails.some(([ts, te]) => s <= te && e >= ts),
    );
  }, [snap, statuses, trails]);

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
      setSnapStatus(describeResult(result));
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
    routeRef.current =
      snap && snapped ? snapped : points.map((p) => [p.lng, p.lat] as LngLat);
    gapsRef.current = gaps;
    trailsRef.current = snap ? trails : [];
    selectionRef.current = snap ? selection : null;
    openGapRef.current = ([start, end]) => {
      setSelection([start, end]);
      setSubmitError(null);
    };
    mapRef.current?.triggerRepaint();
  }, [points, snapped, snap, gaps, trails, selection]);

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
      style: antiqueMapStyle,
      center: coordinates[0],
      zoom: 14,
    });
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
      const base = { roughness: 1.8, bowing: 1.5, seed: 1 };

      if (gaps.length === 0) {
        roughCanvas.linearPath(screen, { ...base, stroke: INK, strokeWidth: 3 });
      } else {
        // Mapped stretches solid, unmapped (clickable) sections dashed.
        let from = 0;
        for (const [start, end] of gaps) {
          roughCanvas.linearPath(line(from, start), { ...base, stroke: MATCHED, strokeWidth: 3 });
          roughCanvas.linearPath(line(start - 1, end + 1), {
            ...base,
            stroke: UNMAPPED,
            strokeWidth: 3,
            strokeLineDash: [10, 8],
          });
          from = end;
        }
        roughCanvas.linearPath(line(from, screen.length), { ...base, stroke: MATCHED, strokeWidth: 3 });
      }

      for (const [start, end] of trailsRef.current) {
        roughCanvas.linearPath(line(start, end), { ...base, stroke: TRAIL, strokeWidth: 5 });
      }

      const sel = selectionRef.current;
      if (sel) {
        const part = line(sel[0], sel[1]);
        ctx.save();
        ctx.lineWidth = 12;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.strokeStyle = "rgba(127,119,221,0.45)";
        ctx.beginPath();
        part.forEach(([x, y], i) => (i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)));
        ctx.stroke();
        for (const i of sel) {
          if (!screen[i]) continue;
          ctx.beginPath();
          ctx.arc(screen[i][0], screen[i][1], 8, 0, Math.PI * 2);
          ctx.fillStyle = "#fff";
          ctx.fill();
          ctx.lineWidth = 2.5;
          ctx.strokeStyle = TRAIL;
          ctx.stroke();
        }
        ctx.restore();
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
    map.on("render", drawRoute);
    map.on("click", onClick);
    map.on("mousemove", onMove);

    return () => {
      map.off("render", drawRoute);
      map.off("click", onClick);
      map.off("mousemove", onMove);
      map.remove();
      mapRef.current = null;
    };
  }, [points]);

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

      <div className="absolute top-4 left-4 z-10 max-w-xs rounded-lg border border-black/10 bg-white/90 p-4 shadow-lg backdrop-blur-sm dark:border-white/10 dark:bg-black/80">
        <Link href="/walks" className="text-sm underline">
          ← Back to walks
        </Link>

        {error && <p className="mt-2 text-red-600">{error}</p>}

        {walk && (
          <div className="mt-2">
            <h1 className="text-2xl font-semibold">
              {(walk.distance_meters / 1000).toFixed(2)} km
            </h1>
            <p className="text-gray-600 dark:text-gray-400">
              {new Date(walk.started_at).toLocaleString()} ·{" "}
              {formatDuration(walk.duration_seconds)} ·{" "}
              {(
                walk.duration_seconds /
                60 /
                (walk.distance_meters / 1000 || 1)
              ).toFixed(1)}{" "}
              min/km
            </p>
          </div>
        )}

        <label className="mt-3 flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={snap}
            onChange={(e) => {
              setSnap(e.target.checked);
              closePanel();
            }}
          />
          Snap to streets and trails
        </label>
        {snap && (
          <p className="mt-1 text-xs text-gray-500">{snapStatus ?? "Matching…"}</p>
        )}
        {snap && gaps.length > 0 && !selection && (
          <p className="mt-1 text-xs text-gray-500">
            Click a dashed section to mark it as a trail.
          </p>
        )}
      </div>

      {snap && selection && (
        <div className="absolute bottom-4 left-1/2 z-10 w-[min(28rem,calc(100%-2rem))] -translate-x-1/2 rounded-lg border border-black/10 bg-white/95 p-3 shadow-lg backdrop-blur-sm dark:border-white/10 dark:bg-black/85">
          <div className="flex justify-end">
            <button
              type="button"
              aria-label="Close"
              onClick={closePanel}
              className="flex h-7 w-7 items-center justify-center rounded-full text-lg leading-none hover:bg-black/10 dark:hover:bg-white/10"
            >
              ×
            </button>
          </div>

          <div className="dual-range relative mt-1 h-6">
            <div className="absolute inset-x-[9px] top-2 flex h-2 overflow-hidden rounded">
              {runs.map((r, i) => (
                <div
                  key={i}
                  style={{ flexGrow: r.length, background: r.mapped ? MATCHED : UNMAPPED }}
                />
              ))}
              <div
                className="absolute inset-y-0"
                style={{
                  left: `${(selection[0] / lastIndex) * 100}%`,
                  width: `${((selection[1] - selection[0]) / lastIndex) * 100}%`,
                  background: "rgba(127,119,221,0.45)",
                }}
              />
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

          {submitError && <p className="mt-2 text-sm text-red-600">{submitError}</p>}

          <button
            type="button"
            onClick={submit}
            className="mt-3 w-full rounded-md bg-black py-2 text-sm font-medium text-white dark:bg-white dark:text-black"
          >
            Submit
          </button>
        </div>
      )}
    </main>
  );
}
