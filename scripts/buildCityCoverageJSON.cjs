#!/usr/bin/env node
/**
 * buildCityCoverageJSON.cjs
 *
 * Modified version of buildCityCoverage.cjs to output pure JSON.
 */

const fs = require('fs');
const path = require('path');
// Import logic from existing script if possible, but verifyCitiesCompleteness is CJS.
const { runCityCoverage } = require('./verifyCitiesCompleteness.cjs');

const args = parseArgs(process.argv.slice(2));
const outFile = args.out || 'assets/data/city_coverage.json';
const options = {
    overlay: args.overlay,
    source: args.source || args.input || args.tiger,
    minPop: args.minpop !== undefined ? Number(args.minpop) : 0,
    funcstat: args.funcstat || args.status || 'A',
    popcsv: args.popcsv,
    silent: true,
};

try {
    const summary = runCityCoverage(options);
    const payload = buildPayload(summary);
    writeJSON(outFile, payload);
    console.log(`City coverage JSON written to ${outFile}`);
} catch (err) {
    console.error('[buildCityCoverageJSON] Failed:', err?.message || err);
    process.exit(1);
}

function parseArgs(list) {
    const parsed = {};
    for (let i = 0; i < list.length; i++) {
        const token = list[i];
        if (!token.startsWith('--')) continue;
        const key = token.slice(2);
        const next = list[i + 1];
        if (next && !next.startsWith('--')) {
            parsed[key] = next;
            i++;
        } else {
            parsed[key] = true;
        }
    }
    return parsed;
}

function buildPayload(summary) {
    const perState = summary.perState.reduce((acc, state) => {
        acc[state.state] = {
            state: state.state,
            stateName: state.stateName,
            source: state.source,
            covered: state.covered,
            coverage: Number(state.coverage || 0),
            missingExamples: state.missingExamples,
        };
        return acc;
    }, {});

    const meta = {
        generatedAt: new Date().toISOString(),
        overlayPath: summary.overlayPath,
        sourcePath: summary.sourcePath,
        minPopulation: summary.minPopulation,
        funcstatFilter: summary.funcstatFilter,
        overlayFeatureCount: summary.overlayFeatureCount,
        sourceFeatureCount: summary.sourceFeatureCount,
        coverageRatio: summary.coverageRatio,
        topMissing: summary.topMissing.map(item => ({
            id: item.id || null,
            name: item.name,
            stateAbbr: item.stateAbbr || null,
            stateName: item.stateName || null,
            population: typeof item.population === 'number' ? item.population : null,
        })),
    };

    return { meta, coverage: perState };
}

function writeJSON(outFile, payload) {
    fs.mkdirSync(path.dirname(outFile), { recursive: true });
    fs.writeFileSync(outFile, JSON.stringify(payload, null, 2));
}
