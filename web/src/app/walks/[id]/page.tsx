"use client";

import { Suspense, useEffect, useRef, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import * as maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";
import { supabase } from "@/lib/supabaseClient";
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
    if (!mapContainer.current || !points || points.length === 0) return;

    // Turbopack's asset pipeline breaks maplibre-gl's internal worker-loading
    // logic even when pointed at the right URL, so the worker script is served
    // as a plain static file from /public instead (copied from
    // node_modules/maplibre-gl/dist/maplibre-gl-worker.mjs — re-copy after
    // upgrading maplibre-gl).
    maplibregl.setWorkerUrl("/maplibre-gl-worker.mjs");

    const coordinates = points.map((p) => [p.lng, p.lat] as [number, number]);
    const map = new maplibregl.Map({
      container: mapContainer.current,
      style: {
        version: 8,
        sources: {
          osm: {
            type: "raster",
            tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
            tileSize: 256,
            attribution: "© OpenStreetMap contributors",
          },
        },
        layers: [{ id: "osm", type: "raster", source: "osm" }],
      },
      center: coordinates[0],
      zoom: 14,
    });
    map.on("load", () => {
      map.addSource("route", {
        type: "geojson",
        data: {
          type: "Feature",
          properties: {},
          geometry: { type: "LineString", coordinates },
        },
      });
      map.addLayer({
        id: "route",
        type: "line",
        source: "route",
        paint: { "line-color": "#16a34a", "line-width": 4 },
      });

      const bounds = coordinates.reduce(
        (b, coord) => b.extend(coord),
        new maplibregl.LngLatBounds(coordinates[0], coordinates[0]),
      );
      map.fitBounds(bounds, { padding: 40, duration: 0 });
    });

    return () => map.remove();
  }, [points]);

  return (
    <main className="relative h-dvh w-full overflow-hidden">
      <div ref={mapContainer} className="absolute inset-0 h-full w-full" />

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
