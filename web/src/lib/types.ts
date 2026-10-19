export type Walk = {
  id: string;
  started_at: string;
  ended_at: string;
  distance_meters: number;
  duration_seconds: number;
};

export type WalkPoint = {
  id: number;
  walk_id: string;
  lat: number;
  lng: number;
  altitude: number | null;
  recorded_at: string;
  sequence: number;
};
