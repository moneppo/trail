import type { StyleSpecification } from "maplibre-gl";

// Free, no-API-key vector tiles + glyphs (OpenMapTiles schema). See
// https://openfreemap.org — self-serve, no signup, no rate limit.
const TILES_BASE = "https://tiles.openfreemap.org";

const INK = "#4a3522";
const PARCHMENT = "#ede3cb";

export const antiqueMapStyle: StyleSpecification = {
  version: 8,
  sources: {
    openmaptiles: {
      type: "vector",
      url: `${TILES_BASE}/planet`,
    },
  },
  glyphs: `${TILES_BASE}/fonts/{fontstack}/{range}.pbf`,
  layers: [
    { id: "background", type: "background", paint: { "background-color": PARCHMENT } },
    {
      id: "landcover_wood",
      type: "fill",
      source: "openmaptiles",
      "source-layer": "landcover",
      filter: ["==", ["get", "class"], "wood"],
      paint: { "fill-color": "#cdd4a8", "fill-opacity": 0.5 },
    },
    {
      id: "landcover_grass",
      type: "fill",
      source: "openmaptiles",
      "source-layer": "landcover",
      filter: ["==", ["get", "class"], "grass"],
      paint: { "fill-color": "#dde3bd", "fill-opacity": 0.45 },
    },
    {
      id: "park",
      type: "fill",
      source: "openmaptiles",
      "source-layer": "park",
      paint: { "fill-color": "#d9e0bb", "fill-opacity": 0.5 },
    },
    {
      id: "landuse_residential",
      type: "fill",
      source: "openmaptiles",
      "source-layer": "landuse",
      filter: ["==", ["get", "class"], "residential"],
      paint: { "fill-color": "#e4d9b8", "fill-opacity": 0.35 },
    },
    {
      id: "water",
      type: "fill",
      source: "openmaptiles",
      "source-layer": "water",
      paint: { "fill-color": "#b7c3bb", "fill-outline-color": "#7f8f84" },
    },
    {
      id: "waterway",
      type: "line",
      source: "openmaptiles",
      "source-layer": "waterway",
      paint: { "line-color": "#7f8f84", "line-width": 1 },
    },
    {
      id: "building",
      type: "fill",
      source: "openmaptiles",
      "source-layer": "building",
      paint: {
        "fill-color": "#e3d5ab",
        "fill-outline-color": INK,
        "fill-opacity": 0.8,
      },
    },
    {
      id: "road_path_pedestrian",
      type: "line",
      source: "openmaptiles",
      "source-layer": "transportation",
      filter: ["match", ["get", "class"], ["path", "pedestrian"], true, false],
      paint: {
        "line-color": "#8a6d46",
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
      paint: { "line-color": "#8a6d46", "line-width": 1 },
    },
    {
      id: "road_secondary_tertiary",
      type: "line",
      source: "openmaptiles",
      "source-layer": "transportation",
      filter: ["match", ["get", "class"], ["secondary", "tertiary"], true, false],
      paint: { "line-color": INK, "line-width": 1.5 },
    },
    {
      id: "road_trunk_primary",
      type: "line",
      source: "openmaptiles",
      "source-layer": "transportation",
      filter: ["match", ["get", "class"], ["trunk", "primary", "motorway"], true, false],
      paint: { "line-color": INK, "line-width": 2.5 },
    },
    {
      id: "boundary",
      type: "line",
      source: "openmaptiles",
      "source-layer": "boundary",
      filter: ["<=", ["get", "admin_level"], 6],
      paint: {
        "line-color": "#7a3b1e",
        "line-width": 1,
        "line-dasharray": [4, 2],
        "line-opacity": 0.6,
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
        "text-color": INK,
        "text-halo-color": PARCHMENT,
        "text-halo-width": 1.5,
      },
    },
  ],
};
