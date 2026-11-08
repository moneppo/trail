"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { OptionsMenu } from "@/components/OptionsMenu";
import { supabase } from "@/lib/supabaseClient";
import type { Walk } from "@/lib/types";

function formatDuration(seconds: number) {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  return [h, m, s].map((n) => n.toString().padStart(2, "0")).join(":");
}

export default function WalksPage() {
  const router = useRouter();
  const [walks, setWalks] = useState<Walk[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      if (!data.session) {
        router.replace("/login");
        return;
      }
      supabase
        .from("walks")
        .select("*")
        .order("started_at", { ascending: false })
        .then(({ data, error }) => {
          if (error) setError(error.message);
          else setWalks(data as Walk[]);
        });
    });
  }, [router]);

  async function handleSignOut() {
    await supabase.auth.signOut();
    router.replace("/login");
  }

  const totalKm = (walks ?? []).reduce((sum, w) => sum + w.distance_meters, 0) / 1000;

  return (
    <main className="flex-1 max-w-2xl mx-auto w-full px-4 pb-12">
      <header className="tc-rule-bold flex items-end justify-between gap-4 pt-12 pb-4">
        <div>
          <p className="tc-label">
            {walks ? `${walks.length} ${walks.length === 1 ? "walk" : "walks"} · ${totalKm.toFixed(1)} km` : " "}
          </p>
          <h1 className="tc-title-xl">Your walks</h1>
        </div>
        <div className="flex items-center gap-5">
          <OptionsMenu />
          <button onClick={handleSignOut} className="tc-link">
            Sign out
          </button>
        </div>
      </header>
      <div className="tc-rule-hair h-1" />

      {error && <p className="tc-error mt-4">{error}</p>}
      {walks === null && !error && <p className="tc-caption mt-4">Loading walks…</p>}
      {walks?.length === 0 && <p className="tc-caption mt-4">No walks yet. Go for one.</p>}

      <ul>
        {walks?.map((walk) => (
          <li key={walk.id} className="tc-rule-row">
            <Link
              href={`/walks/${walk.id}`}
              className="flex items-center justify-between gap-4 py-4 hover:underline decoration-dashed underline-offset-4"
            >
              <div>
                <p className="tc-label">{new Date(walk.started_at).toLocaleString()}</p>
                <p className="tc-title-md">{(walk.distance_meters / 1000).toFixed(2)} km</p>
              </div>
              <span className="tc-data">{formatDuration(walk.duration_seconds)}</span>
            </Link>
          </li>
        ))}
      </ul>
    </main>
  );
}
