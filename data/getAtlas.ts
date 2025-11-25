// Dynamic atlas loader: prefers generated atlas (atlas.generated.ts) if present, else falls back to placeholder statesAtlas.
import { Atlas } from '../types';
import { atlas as manualAtlas } from './statesAtlas';

export async function loadAtlas(): Promise<Atlas> {
  try {
    // Use dynamic path fragment to prevent Vite from trying to statically resolve when file absent.
    const candidate = './atlas.generated';
    const mod: any = await import(/* @vite-ignore */ candidate + '.ts');
    if (mod && mod.atlas) return mod.atlas as Atlas;
  } catch (_) { /* fallthrough */ }
  return manualAtlas;
}
