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
