import { supabase } from "@/lib/supabaseClient";

// PostgREST caps a single response (1000 rows by default), and a walk
// recorded every few meters easily exceeds that, so read in pages.
const PAGE_SIZE = 1000;

export async function fetchAllByWalk<T>(
  table: "walk_points" | "snapped_points",
  walkId: string,
): Promise<T[]> {
  const rows: T[] = [];
  for (let from = 0; ; from += PAGE_SIZE) {
    const { data, error } = await supabase
      .from(table)
      .select("*")
      .eq("walk_id", walkId)
      .order("sequence", { ascending: true })
      .range(from, from + PAGE_SIZE - 1);
    if (error) throw new Error(error.message);
    rows.push(...(data as T[]));
    if (data.length < PAGE_SIZE) break;
  }
  return rows;
}

/** A stretch of a walk (inclusive point indices) submitted as an untracked trail. */
export type SubmittedTrail = { start: number; end: number; accepted: boolean };

/** Stretches of a walk submitted as untracked trails, and whether each has been accepted onto the map. */
export async function fetchUntrackedTrails(walkId: string): Promise<SubmittedTrail[]> {
  const { data, error } = await supabase
    .from("untracked_trails")
    .select("start_sequence, end_sequence, type")
    .eq("walk_id", walkId);
  if (error) throw new Error(error.message);
  return data.map((r) => ({
    start: r.start_sequence as number,
    end: r.end_sequence as number,
    accepted: r.type === "accepted",
  }));
}

/** Submits a stretch of a walk as a candidate untracked trail. */
export async function submitUntrackedTrail(
  walkId: string,
  userId: string,
  start: number,
  end: number,
) {
  const { error } = await supabase.from("untracked_trails").insert({
    user_id: userId,
    walk_id: walkId,
    type: "candidate",
    start_sequence: start,
    end_sequence: end,
  });
  if (error) throw new Error(error.message);
}
