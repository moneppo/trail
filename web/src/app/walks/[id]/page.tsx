"use client";

import { Suspense, useEffect, useRef, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import * as maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";
import rough from "roughjs";
import { supabase } from "@/lib/supabaseClient";
import { antiqueMapStyle } from "@/lib/antiqueMapStyle";
import type { Walk, WalkPoint } from "@/lib/types";

function formatDuration(seconds: number) {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  return [h, m, s].map((n) => n.toString().padStart(2, "0")).join(":");
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

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      if (!data.session) {
        router.replace("/login");
        return;
      }
      Promise.all([
        supabase.from("walks").select("*").eq("id", params.id).single(),
        supabase
          .from("walk_points")
          .select("*")
          .eq("walk_id", params.id)
          .order("sequence", { ascending: true }),
      ]).then(([walkRes, pointsRes]) => {
        if (walkRes.error) setError(walkRes.error.message);
        else setWalk(walkRes.data as Walk);
        if (pointsRes.error) setError(pointsRes.error.message);
        else setPoints(pointsRes.data as WalkPoint[]);
      });
    });
  }, [params.id, router]);

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

    const canvas = sketchCanvas.current;
    const roughCanvas = rough.canvas(canvas);

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

      const screenPoints = coordinates.map((coord) => {
        const p = map.project(coord as [number, number]);
        return [p.x, p.y] as [number, number];
      });

      roughCanvas.linearPath(screenPoints, {
        stroke: "#7a1f1f",
        strokeWidth: 3,
        roughness: 1.8,
        bowing: 1.5,
        seed: 1,
      });
    }

    map.on("load", () => {
      const bounds = coordinates.reduce(
        (b, coord) => b.extend(coord as [number, number]),
        new maplibregl.LngLatBounds(coordinates[0] as [number, number], coordinates[0] as [number, number]),
      );
      map.fitBounds(bounds, { padding: 60, duration: 0 });
    });
    map.on("render", drawRoute);

    return () => {
      map.off("render", drawRoute);
      map.remove();
    };
  }, [points]);

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
      </div>
    </main>
  );
}
