import type { Snapshot } from "./domain/types.js";

export const SAIH_BASE = "https://saihtajo.chtajo.es/";
export const SAIH_DISCOVERY_PATH = "page-datos-tiempo-real";
export const MITECO_ZIP_URL =
  "https://www.miteco.gob.es/content/dam/miteco/es/agua/temas/evaluacion-de-los-recursos-hidricos/boletin-hidrologico/Historico-de-embalses/BD-Embalses.zip";
export const USER_AGENT = "embalse-san-juan/0.1 (personal app; github.com/lucferbux)";

/** Delay between SAIH requests, to stay a polite client. */
export const REQUEST_GAP_MS = 1000;

export interface StationConfig {
  code: string;
  /** Opaque `x` token, stable so far. Rediscovered from the station list if it stops working. */
  path: string;
}

const station = (code: string, x: string): StationConfig => ({
  code,
  path: `index.php?w=get-estacion&x=${x}`,
});

export const MAIN_STATION = station(
  "E_19",
  "%2F4ZGs%2B6M%2BZWfvq6%2FyxpbheTu%2BEYNwNRj98K%2BA%2B5o840%2BuxXinbSE0hNYqU6YGhef2c%2BejPpOBZD7EO8lD2xO6GQfFHTGoMYerlC6AwovtMM%3D",
);

export const NEIGHBOURS: ReadonlyArray<StationConfig & { name: string; position: "upstream" | "downstream" }> = [
  {
    ...station("E_17", "%2F4ZGs%2B6M%2BZWfvq6%2Fyxpbhfug5v6QdmEbnkcbbPUchrAQm17PljU5sk9NrV8SjdgDgOJzq4683U7RnVQ5Yw0xDKUbVFxwN%2BErTEHT6LcELhg%3D"),
    name: "Burguillo",
    position: "upstream",
  },
  {
    ...station("E_20", "%2F4ZGs%2B6M%2BZWfvq6%2FyxpbhUbyiWpBZtAmuCcvf1l5H6GrcF6OPvzzgTo6K05HD4gwfa9kkVw%2BMi%2B8JZ6qbDm0cIPwjhHtpvE447V1rIPQRTM%3D"),
    name: "Picadas",
    position: "downstream",
  },
];

export const RAIN_GAUGES: ReadonlyArray<StationConfig & { name: string }> = [
  {
    ...station("P_37", "%2F4ZGs%2B6M%2BZWfvq6%2FyxpbhWBeNS8wr%2BrkXHYLKBEHXnIG29A9Nea6Ol3FI7N3iDM8R8gs20wWXlRkqnLlm4EeHjmA2znoHEW%2Bhz4zBMDfyPY%3D"),
    name: "Santa Cruz de Pinares",
  },
  {
    ...station("PN38", "%2F4ZGs%2B6M%2BZWfvq6%2FyxpbhUakA6iLF0om8eHYLMb9hAk%2F0C7N%2FANJk6MssxnKGwjei0tc287LNQw64ePXEZZs8L7Pg64b5WJCfq9g26%2BT0YE%3D"),
    name: "Navalperal de Pinares",
  },
  {
    ...station("PN39", "%2F4ZGs%2B6M%2BZWfvq6%2FyxpbhbSocsoMUD%2FdbD0Hj%2BVE%2F4Ewo6uZbYt5N6gGmQlCO3h8qSKWs%2BNe8z8bWIZijLIqgGEDiujzVzJ2AI6Fhher6ps%3D"),
    name: "Peguerinos",
  },
];

/** SAIH signal types (`tiposenal`) that the app reads. */
export const SIGNAL = {
  volume: "VE",
  percent: "PO",
  outflow: "CSR",
  transfer: "CT",
  windSpeed: "VV",
  windDirection: "DV",
  temperature: "TE",
  humidity: "HR",
  pressure: "PA",
  solar: "RS",
  rain1h: "P1",
  rain24h: "P24",
} as const;

/** Elevation and level share type `NE`, so they are told apart by tag. */
export const ELEVATION_TAG = "E_19LICT01";
export const LEVEL_TAG = "E_19LI__01";

export const RESERVOIR: Snapshot["reservoir"] = {
  id: "san-juan",
  name: "San Juan",
  river: "Alberche",
  basin: "Tajo",
  province: "Madrid",
  municipality: "San Martín de Valdeiglesias",
  damType: "Gravedad",
  yearBuilt: 1955,
  surfaceHa: 650,
  uses: ["Abastecimiento", "Riego", "Electricidad", "Pesca", "Navegación", "Baño", "Pícnic"],
};

export const SOURCES: Snapshot["sources"] = [
  {
    name: "SAIH Tajo",
    publisher: "Confederación Hidrográfica del Tajo",
    url: "https://saihtajo.chtajo.es/",
    note: "Datos en tiempo real, provisionales y sin validar.",
  },
  {
    name: "Boletín Hidrológico",
    publisher: "Ministerio para la Transición Ecológica y el Reto Demográfico",
    url: "https://www.miteco.gob.es/es/agua/temas/evaluacion-de-los-recursos-hidricos/boletin-hidrologico.html",
    note: "Dato semanal y serie desde 1988, provisionales y sin validar.",
  },
];

export const MAX_DAILY_POINTS = 90;
