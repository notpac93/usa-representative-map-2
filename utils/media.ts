export function getOfficialImagePath(stateId: string, officialId: string, ext: string = 'jpg') {
  return `/officials/${stateId}/${officialId}.${ext}`.toLowerCase();
}

// Future enhancement: load a JSON manifest listing which images exist, fallback to placeholder if missing.
