"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
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

  return (
    <main className="flex-1 max-w-2xl mx-auto w-full p-6">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-semibold">Your walks</h1>
        <button onClick={handleSignOut} className="text-sm underline">
          Sign out
        </button>
      </div>

      {error && <p className="text-red-600">{error}</p>}
      {walks === null && !error && <p>Loading…</p>}
      {walks?.length === 0 && <p>No walks yet. Go for one!</p>}

      <ul className="divide-y">
        {walks?.map((walk) => (
          <li key={walk.id}>
            <Link
              href={`/walks/${walk.id}`}
              className="flex items-center justify-between py-3 hover:bg-gray-50"
            >
              <div>
                <p className="font-medium">
                  {(walk.distance_meters / 1000).toFixed(2)} km
                </p>
                <p className="text-sm text-gray-600">
                  {new Date(walk.started_at).toLocaleString()}
                </p>
              </div>
              <span className="text-gray-700">
                {formatDuration(walk.duration_seconds)}
              </span>
            </Link>
          </li>
        ))}
      </ul>
    </main>
  );
}
