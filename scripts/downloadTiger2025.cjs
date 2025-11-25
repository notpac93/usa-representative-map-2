#!/usr/bin/env node

const fs = require('node:fs/promises');
const path = require('node:path');
const { pipeline } = require('node:stream/promises');
const { createWriteStream } = require('node:fs');
const AdmZip = require('adm-zip');

const BASE_URL = 'https://www2.census.gov/geo/tiger/TIGER2025/';
const OUTPUT_ROOT = path.resolve(__dirname, '..', 'data', 'raw', 'tiger2025');
const MARKER_NAME = '.download-complete';
const visitedDirectories = new Set();

const allowedTopFolders = process.env.TIGER_FOLDERS
  ? new Set(process.env.TIGER_FOLDERS.split(',').map((segment) => segment.trim()).filter(Boolean))
  : null;

const onlyPrefix = process.env.TIGER_ONLY?.trim();

const summary = {
  downloaded: 0,
  skipped: 0,
  failed: 0,
};

async function ensureDir(dirPath) {
  await fs.mkdir(dirPath, { recursive: true });
}

async function fileExists(filePath) {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function downloadFile(url, destination) {
  const response = await fetch(url);
  if (!response.ok || !response.body) {
    throw new Error(`Failed to download ${url}: ${response.status} ${response.statusText}`);
  }
  await ensureDir(path.dirname(destination));
  const fileStream = createWriteStream(destination);
  await pipeline(response.body, fileStream);
}

async function extractZip(zipPath, destination) {
  await ensureDir(destination);
  const zip = new AdmZip(zipPath);
  zip.extractAllTo(destination, true);
}

async function processZip(url, segments, fileName) {
  const folderName = fileName.replace(/\.zip$/i, '');
  const targetDir = path.join(OUTPUT_ROOT, ...segments, folderName);
  const markerPath = path.join(targetDir, MARKER_NAME);
  if (await fileExists(markerPath)) {
    summary.skipped += 1;
    console.log(`✓ Skipping ${fileName} (already downloaded)`);
    return;
  }

  if (await fileExists(targetDir)) {
    await fs.rm(targetDir, { recursive: true, force: true });
  }

  console.log(`↓ Downloading ${fileName}`);
  const tempZipPath = path.join(targetDir, fileName);
  try {
    await downloadFile(url + fileName, tempZipPath);
    console.log(`⇢ Extracting ${fileName}`);
    await extractZip(tempZipPath, targetDir);
    await fs.rm(tempZipPath, { force: true });
    await fs.writeFile(markerPath, new Date().toISOString());
    summary.downloaded += 1;
  } catch (error) {
    summary.failed += 1;
    await fs.rm(targetDir, { recursive: true, force: true }).catch(() => {});
    await fs.rm(tempZipPath, { force: true }).catch(() => {});
    console.error(`✗ Failed ${fileName}:`, error.message || error);
  }
}

function parseLinks(html) {
  const links = [];
  const regex = /href="([^"]+)"/gi;
  let match;
  while ((match = regex.exec(html)) !== null) {
    links.push(match[1]);
  }
  return links;
}

async function crawlDirectory(url, segments = []) {
  const normalizedUrl = url.endsWith('/') ? url : `${url}/`;
  if (visitedDirectories.has(normalizedUrl)) {
    return;
  }
  visitedDirectories.add(normalizedUrl);
  console.log(`Listing ${url}`);
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to fetch directory ${url}: ${response.status}`);
  }
  const html = await response.text();
  const links = parseLinks(html)
    .filter((href) => href && href !== '../' && !href.startsWith('?'));

  for (const href of links) {
    const resolved = new URL(href, url);
    const normalized = resolved.href;
    if (!normalized.startsWith(BASE_URL)) {
      continue;
    }
    const relativePath = normalized.slice(BASE_URL.length);
    if (!relativePath) {
      continue;
    }

    if (normalized.endsWith('/')) {
      const folderName = relativePath.replace(/\/$/, '').split('/').pop();
      if (!folderName) continue;
      if (segments.length === 0 && allowedTopFolders && !allowedTopFolders.has(folderName)) {
        continue;
      }
      await crawlDirectory(normalized, [...segments, folderName]);
    } else if (normalized.toLowerCase().endsWith('.zip')) {
      const fileName = relativePath.split('/').pop();
      if (!fileName) continue;
      if (onlyPrefix && !fileName.startsWith(onlyPrefix)) {
        continue;
      }
      await processZip(url, segments, fileName);
    }
  }
}

async function main() {
  await ensureDir(OUTPUT_ROOT);
  await crawlDirectory(BASE_URL);
  console.log('All TIGER files processed.');
  console.log(`Summary: downloaded ${summary.downloaded}, skipped ${summary.skipped}, failed ${summary.failed}.`);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
