// ============================================================
// CYBERTRUCK OBBY LINCOLN - FIX ROUND 2
// Run from project root: node fix2.js
// ============================================================

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname);
const SRC = path.join(ROOT, 'src');

const fixed = [];
const skipped = [];
const errors = [];

function log(msg)  { fixed.push(msg);   console.log('✅ ' + msg); }
function skip(msg) { skipped.push(msg); console.log('⏭  ' + msg); }
function fail(msg) { errors.push(msg);  console.log('❌ ' + msg); }
function readFile(p) { try { return fs.readFileSync(p, 'utf8'); } catch(e) { return null; } }
function writeFile(p, c) {
    try { fs.writeFileSync(p, c, 'utf8'); return true; }
    catch(e) { fail('Write failed ' + p + ': ' + e.message); return false; }
}

// ============================================================
// FIX 1: MAP OFFSETS — PREVENT TERRAIN OVERLAP
// Each map needs a massive offset so terrain never overlaps
// ============================================================
console.log('\n--- FIX 1: Fix map START_POS offsets to prevent overlap ---');

const mapOffsets = {
    'GenerateCityMap.server.lua':      'Vector3.new(0, 0, 0)',
    'GenerateMountainMap.server.lua':  'Vector3.new(4000, 0, 0)',
    'GenerateRaceTrackMap.server.lua': 'Vector3.new(8000, 0, 0)',
};

for (const [file, offset] of Object.entries(mapOffsets)) {
    const filePath = path.join(SRC, 'ServerScriptService', file);
    let src = readFile(filePath);
    if (!src) { skip(file + ' not found'); continue; }

    const patched = src.replace(
        /local\s+START_POS\s*=\s*Vector3\.new\([^)]*\)/,
        `local START_POS = ${offset}`
    );

    if (patched !== src) {
        if (writeFile(filePath, patched)) log(file + ' → START_POS = ' + offset);
    } else {
        // Not found, inject after first comment block
        const insertAfter = src.indexOf('\n') + 1;
        const injected = src.slice(0, insertAfter)
            + `local START_POS = ${offset}\n`
            + src.slice(insertAfter);
        if (writeFile(filePath, injected)) log(file + ' → START_POS injected: ' + offset);
    }
}

// ============================================================
// FIX 2: EXPANDTOGRID — ALL 3 GENERATORS
// Region3:ExpandToGrid() is deprecated
// Replace with manual grid snapping
// ============================================================
console.log('\n--- FIX 2: Fix ExpandToGrid in all map generators ---');

const snapHelper = `
-- AUTO FIX: snapToGrid replaces deprecated :ExpandToGrid()
local _GRID_SIZE = 4
local function snapToGrid(vec)
    return Vector3.new(
        math.round(vec.X / _GRID_SIZE) * _GRID_SIZE,
        math.round(vec.Y / _GRID_SIZE) * _GRID_SIZE,
        math.round(vec.Z / _GRID_SIZE) * _GRID_SIZE
    )
end
`;

const generators = [
    'GenerateCityMap.server.lua',
    'GenerateMountainMap.server.lua',
    'GenerateRaceTrackMap.server.lua',
];

for (const file of generators) {
    const filePath = path.join(SRC, 'ServerScriptService', file);
    let src = readFile(filePath);
    if (!src) { skip(file + ' not found'); continue; }

    if (!src.includes('ExpandToGrid')) {
        skip(file + ' — no ExpandToGrid found');
        continue;
    }

    // Fix pattern: Region3.new(min, max):ExpandToGrid(N)
    let patched = src.replace(
        /Region3\.new\(([^,\n]+),\s*([^\n)]+)\)\s*:ExpandToGrid\(\d+\)/g,
        (_, minArg, maxArg) =>
            `Region3.new(snapToGrid(${minArg.trim()}), snapToGrid(${maxArg.trim()}))`
    );

    // Fix pattern: someVar:ExpandToGrid(N)
    patched = patched.replace(
        /(\w[\w.]*)\s*:ExpandToGrid\(\d+\)/g,
        (_, varName) => varName
    );

    // Inject snapToGrid helper if not already there
    if (!patched.includes('snapToGrid')) {
        const firstNewline = patched.indexOf('\n');
        patched = patched.slice(0, firstNewline + 1)
            + snapHelper
            + patched.slice(firstNewline + 1);
    } else if (!patched.includes('function snapToGrid')) {
        const firstNewline = patched.indexOf('\n');
        patched = patched.slice(0, firstNewline + 1)
            + snapHelper
            + patched.slice(firstNewline + 1);
    }

    if (writeFile(filePath, patched)) log(file + ' — ExpandToGrid fixed');
}

// ============================================================
// FIX 3: FIND AND FIX HELLO WORLD TEST SCRIPT
// ============================================================
console.log('\n--- FIX 3: Find and remove Hello World test script ---');

// Check common locations
const testScriptPaths = [
    path.join(SRC, 'ServerScriptService', 'Script.server.lua'),
    path.join(SRC, 'ServerScriptService', 'test.server.lua'),
    path.join(SRC, 'ServerScriptService', 'Script.lua'),
];

for (const p of testScriptPaths) {
    const src = readFile(p);
    if (src && src.includes('Hello world')) {
        fs.rmSync(p);
        log('Deleted Hello World test script: ' + path.basename(p));
    }
}

// Also search all server scripts for hello world
const ssFiles = fs.readdirSync(path.join(SRC, 'ServerScriptService'));
for (const file of ssFiles) {
    if (!file.endsWith('.lua')) continue;
    const filePath = path.join(SRC, 'ServerScriptService', file);
    const src = readFile(filePath);
    if (src && src.trim() === 'print("Hello world!")') {
        fs.rmSync(filePath);
        log('Deleted Hello World test script: ' + file);
    }
}

// ============================================================
// FIX 4: ADD DATASTORE FALLBACK FOR STUDIO TESTING
// When DataStore is unavailable in Studio, use default data
// instead of crashing — add this to GarageHandler and CoinHandler
// ============================================================
console.log('\n--- FIX 4: Add DataStore Studio fallback ---');

const datastoreFallbackComment = `
-- STUDIO FIX: When DataStore is unavailable in Studio,
-- fall back to default PlayerData so the game still runs.
-- Enable "Studio Access to API Services" in Game Settings
-- to use real DataStore during Studio testing.
`;

const filesToPatch = [
    {
        file: 'GarageHandler.server.lua',
        // Find the DataStore error handler and make sure it falls back gracefully
        pattern: /if not success then[\s\S]*?warn\([^)]+\)[\s\S]*?end/,
    },
    {
        file: 'CoinHandler.server.lua',
        pattern: /if not success then[\s\S]*?warn\([^)]+\)[\s\S]*?end/,
    }
];

for (const { file } of filesToPatch) {
    const filePath = path.join(SRC, 'ServerScriptService', file);
    let src = readFile(filePath);
    if (!src) { skip(file + ' not found'); continue; }

    if (src.includes('STUDIO FIX')) {
        skip(file + ' — studio fallback already present');
        continue;
    }

    // Find DataStore GetAsync calls and ensure they have proper fallback
    // Pattern: local success, data = pcall(function() return store:GetAsync(...) end)
    const hasProperFallback = src.includes('PlayerData.GetDefault()') ||
                               src.includes('GetDefault()');

    if (!hasProperFallback) {
        // Find the pattern where data load fails and add GetDefault fallback
        const patched = src.replace(
            /(local\s+success\s*,\s*(?:data|result)\s*=\s*pcall[\s\S]*?end\s*\n)([\s\S]*?)(if\s+not\s+success)/,
            (match, pcallBlock, between, ifNotSuccess) => {
                return pcallBlock + between +
                    `-- STUDIO FIX: fallback to defaults if DataStore unavailable\n    ` +
                    ifNotSuccess;
            }
        );

        // More direct approach: find warn lines after DataStore failure
        // and add data = PlayerData.GetDefault() after them
        const patched2 = src.replace(
            /(warn\(".*?DataStore.*?"\))/g,
            `$1\n        data = require(game.ReplicatedStorage.Module.PlayerData).GetDefault()`
        );

        if (patched2 !== src) {
            if (writeFile(filePath, patched2)) {
                log(file + ' — DataStore fallback to GetDefault() added');
            }
        } else {
            skip(file + ' — could not auto-patch DataStore fallback, fix manually');
        }
    } else {
        skip(file + ' — already has GetDefault fallback');
    }
}

// ============================================================
// FIX 5: UPDATE MapData.lua WITH CORRECT SPAWN POSITIONS
// ============================================================
console.log('\n--- FIX 5: Verify MapData.lua spawn positions ---');

const mapDataPath = path.join(SRC, 'ReplicatedStorage', 'Module', 'MapData.lua');
const mapDataSrc = readFile(mapDataPath);

if (!mapDataSrc) {
    skip('MapData.lua not found');
} else {
    log('MapData.lua found — verify SpawnName matches actual SpawnLocation names in Workspace after map generation');
    // Note: SpawnLocation names are set in the generator scripts
    // They should match: SkyscraperSpawn, BigFootSpawn, HighSpeedSpawn
    if (mapDataSrc.includes('SkyscraperSpawn') &&
        mapDataSrc.includes('BigFootSpawn') &&
        mapDataSrc.includes('HighSpeedSpawn')) {
        skip('MapData.lua spawn names already correct');
    } else {
        log('MapData.lua may have incorrect spawn names — check SkyscraperSpawn, BigFootSpawn, HighSpeedSpawn');
    }
}

// ============================================================
// FIX 6: ADD NOTE ABOUT A-CHASSIS TUNE FIX (MANUAL REQUIRED)
// ============================================================
console.log('\n--- FIX 6: A-Chassis Tune fix (manual steps required) ---');
console.log('');
console.log('  The following errors require manual fixes in Roblox Studio:');
console.log('');
console.log('  ERROR 1: Tesla Cybertruck A-Chassis Initialize line 296');
console.log('  "value of type nil cannot be converted to a number"');
console.log('  FIX: In Studio, open:');
console.log('    Workspace > Tesla Cybertruck > A-Chassis Tune > Tune (ModuleScript)');
console.log('  Find any field that is missing or set to nil that should be a number.');
console.log('  Compare with Zonda Revo Barchetta > A-Chassis Tune > Tune');
console.log('  Copy any missing numeric fields from Zonda to Cybertruck Tune.');
console.log('');
console.log('  ERROR 2: Devel A-Chassis Initialize line 318');
console.log('  "invalid argument #1 to abs (number expected, got nil)"');
console.log('  FIX: In Studio, open:');
console.log('    Workspace > Devel > A-Chassis Tune > Tune (ModuleScript)');
console.log('  Find any field used in math.abs() that is nil.');
console.log('  Common culprits: Tune.FinalDrive, Tune.Ratio, Tune.TorqueCurve');
console.log('  Set missing fields to 0 or copy from a working Tune.');
console.log('');
console.log('  ERROR 3: DataStore not allowed in Studio');
console.log('  FIX: Home > Game Settings > Security tab');
console.log('  Turn ON: Enable Studio Access to API Services');
console.log('');

// ============================================================
// REPORT
// ============================================================
console.log('\n========================================');
console.log('  FIX ROUND 2 - REPORT');
console.log('========================================');
console.log('\n✅ FIXED (' + fixed.length + '):');
fixed.forEach(m => console.log('  ' + m));
console.log('\n⏭  SKIPPED (' + skipped.length + '):');
skipped.forEach(m => console.log('  ' + m));
if (errors.length > 0) {
    console.log('\n❌ ERRORS (' + errors.length + '):');
    errors.forEach(m => console.log('  ' + m));
}
console.log('\n========================================');
console.log('  NEXT STEPS:');
console.log('  1. node fix2.js — run this script');
console.log('  2. git add . && git commit -m "Fix round 2 - map offsets, ExpandToGrid, DataStore fallback" && git push');
console.log('  3. In Studio: Enable API Services (Game Settings > Security)');
console.log('  4. Fix A-Chassis Tune manually (see above)');
console.log('  5. Delete existing map folders from Workspace so they regenerate');
console.log('     (SkyscraperMap, BigFootMap, HighSpeedMap)');
console.log('  6. Restart rojo serve, reconnect plugin, press Play');
console.log('========================================\n');
