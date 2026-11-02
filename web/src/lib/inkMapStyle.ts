import type { StyleSpecification } from "maplibre-gl";

// Free, no-API-key vector tiles + glyphs (OpenMapTiles schema). See
// https://openfreemap.org — self-serve, no signup, no rate limit.
const TILES_BASE = "https://tiles.openfreemap.org";

// Trail Cartography basemap: ink linework on paper, quiet washes for water and
// parks. Values are the design system's color tokens for each theme.
const PALETTES = {
  day: {
    paper: "#f8f7f2",
    ink: "#1c1915",
    inkSoft: "#4d463b",
    contour: "#9b9179",
    water: "#d5dde0",
    park: "#e1e6cf",
  },
  night: {
    paper: "#17150f",
    ink: "#ece4d0",
    inkSoft: "#bfb59d",
    contour: "#6b634f",
    water: "#26313a",
    park: "#2a3022",
  },
};

export function inkMapStyle(night: boolean): StyleSpecification {
  const p = night ? PALETTES.night : PALETTES.day;
  return {
    version: 8,
    sources: {
      openmaptiles: {
        type: "vector",
        url: `${TILES_BASE}/planet`,
      },
    },
    glyphs: `${TILES_BASE}/fonts/{fontstack}/{range}.pbf`,
    layers: [
      { id: "background", type: "background", paint: { "background-color": p.paper } },
      {
        id: "landcover_wood",
        type: "fill",
        source: "openmaptiles",
        "source-layer": "landcover",
        filter: ["==", ["get", "class"], "wood"],
        paint: { "fill-color": p.park },
      },
      {
        id: "landcover_grass",
        type: "fill",
        source: "openmaptiles",
        "source-layer": "landcover",
        filter: ["==", ["get", "class"], "grass"],
        paint: { "fill-color": p.park },
      },
      {
        id: "park",
        type: "fill",
        source: "openmaptiles",
        "source-layer": "park",
        paint: { "fill-color": p.park },
      },
      {
        id: "water",
        type: "fill",
        source: "openmaptiles",
        "source-layer": "water",
        paint: { "fill-color": p.water, "fill-outline-color": p.contour },
      },
      {
        id: "waterway",
        type: "line",
        source: "openmaptiles",
        "source-layer": "waterway",
        paint: { "line-color": p.contour, "line-width": 1.5 },
      },
      {
        id: "building",
        type: "fill",
        source: "openmaptiles",
        "source-layer": "building",
        paint: { "fill-color": p.paper, "fill-outline-color": p.contour },
      },
      {
        id: "road_path_pedestrian",
        type: "line",
        source: "openmaptiles",
        "source-layer": "transportation",
        filter: ["match", ["get", "class"], ["path", "pedestrian"], true, false],
        paint: {
          "line-color": p.contour,
          "line-width": 1,
          "line-dasharray": [1, 1.5],
        },
      },
      {
        id: "road_minor",
        type: "line",
        source: "openmaptiles",
        "source-layer": "transportation",
        filter: ["match", ["get", "class"], ["minor", "service", "track"], true, false],
        paint: { "line-color": p.contour, "line-width": 1.5 },
      },
      {
        id: "road_secondary_tertiary",
        type: "line",
        source: "openmaptiles",
        "source-layer": "transportation",
        filter: ["match", ["get", "class"], ["secondary", "tertiary"], true, false],
        paint: { "line-color": p.inkSoft, "line-width": 1.5 },
      },
      {
        id: "road_trunk_primary",
        type: "line",
        source: "openmaptiles",
        "source-layer": "transportation",
        filter: ["match", ["get", "class"], ["trunk", "primary", "motorway"], true, false],
        paint: { "line-color": p.ink, "line-width": 2.5 },
      },
      {
        id: "boundary",
        type: "line",
        source: "openmaptiles",
        "source-layer": "boundary",
        filter: ["<=", ["get", "admin_level"], 6],
        paint: {
          "line-color": p.contour,
          "line-width": 1,
          "line-dasharray": [3, 5],
        },
      },
      {
        id: "place_label",
        type: "symbol",
        source: "openmaptiles",
        "source-layer": "place",
        filter: ["match", ["get", "class"], ["city", "town", "village", "suburb", "neighbourhood"], true, false],
        layout: {
          "text-field": ["coalesce", ["get", "name_en"], ["get", "name"]],
          "text-font": ["Noto Sans Italic"],
          "text-size": ["interpolate", ["linear"], ["zoom"], 8, 11, 16, 15],
        },
        paint: {
          "text-color": p.inkSoft,
          "text-halo-color": p.paper,
          "text-halo-width": 1.5,
        },
      },
    ],
  };
}
