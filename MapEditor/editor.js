// =========================================================
// FighterPlane Map Editor
// =========================================================

// --- Mission Storage (shared with missions.js) ---

const MissionStorage = {
    INDEX_KEY: 'fp_missions',
    DATA_PREFIX: 'fp_mission_',

    getIndex() {
        return JSON.parse(localStorage.getItem(this.INDEX_KEY) || '[]');
    },
    saveIndex(arr) {
        localStorage.setItem(this.INDEX_KEY, JSON.stringify(arr));
    },
    getData(id) {
        const raw = localStorage.getItem(this.DATA_PREFIX + id);
        return raw ? JSON.parse(raw) : null;
    },
    saveData(id, data) {
        localStorage.setItem(this.DATA_PREFIX + id, JSON.stringify(data));
    },
    deleteData(id) {
        localStorage.removeItem(this.DATA_PREFIX + id);
    },
};

// --- Data Model ---

class MapData {
    constructor(segmentsX = 40, segmentsZ = 200) {
        this.segmentsX = segmentsX;
        this.segmentsZ = segmentsZ;
        this.widthX = segmentsX * 2.5;
        this.lengthZ = segmentsZ * 2.5;
        this.originX = -this.widthX / 2;
        this.originZ = 0;
        // heightmap[z][x] — row-major
        this.heightmap = [];
        for (let z = 0; z <= segmentsZ; z++) {
            this.heightmap.push(new Float32Array(segmentsX + 1));
        }
        this.trees = [];
        this.rocks = [];
        this.enemies = [];
        this.waterLevel = -0.2;
        this.terrainType = 'temperate';
        this.name = "Untitled Mission";
    }

    getHeight(ix, iz) {
        if (ix < 0 || ix > this.segmentsX || iz < 0 || iz > this.segmentsZ) return 0;
        return this.heightmap[iz][ix];
    }

    setHeight(ix, iz, val) {
        if (ix < 0 || ix > this.segmentsX || iz < 0 || iz > this.segmentsZ) return;
        this.heightmap[iz][ix] = val;
    }

    worldX(ix) { return this.originX + ix * (this.widthX / this.segmentsX); }
    worldZ(iz) { return this.originZ + iz * (this.lengthZ / this.segmentsZ); }
    indexX(wx) { return Math.round((wx - this.originX) / (this.widthX / this.segmentsX)); }
    indexZ(wz) { return Math.round((wz - this.originZ) / (this.lengthZ / this.segmentsZ)); }
}

// --- Terrain biome palettes ---

const TERRAIN_PALETTES = {
    temperate: {
        name: 'Temperate',
        colors: [
            [30, 100, 210],    // water
            [194, 178, 128],   // shore
            [168, 172, 104],   // low
            [118, 158, 72],    // grass
            [82, 148, 56],     // forest
            [56, 128, 41],     // dense
            [38, 97, 25],      // peak
        ],
    },
    snow: {
        name: 'Arctic',
        colors: [
            [35, 65, 120],     // icy water
            [160, 175, 200],   // frozen shore
            [195, 208, 225],   // snow low
            [215, 225, 238],   // snow
            [230, 238, 248],   // deep snow
            [242, 246, 252],   // snowfield
            [250, 253, 255],   // peak
        ],
    },
    desert: {
        name: 'Desert',
        colors: [
            [40, 155, 168],    // oasis water
            [218, 198, 152],   // wet sand
            [212, 188, 138],   // sand
            [198, 168, 108],   // dune
            [182, 148, 82],    // high dune
            [162, 122, 62],    // mesa
            [138, 98, 42],     // peak
        ],
    },
    rocky: {
        name: 'Volcanic',
        colors: [
            [28, 72, 82],      // dark water
            [88, 80, 74],      // dark shore
            [105, 96, 88],     // low rock
            [82, 76, 70],      // basalt
            [65, 60, 56],      // dark basalt
            [50, 46, 44],      // obsidian
            [36, 33, 31],      // peak
        ],
    },
};

// Deterministic per-cell noise for organic texture
function cellHash(ix, iz) {
    let n = (ix * 374761393 + iz * 668265263) | 0;
    n = ((n ^ (n >> 13)) * 1274126177) | 0;
    return ((n ^ (n >> 16)) & 0xff) / 255.0;
}

function heightColor(h, waterLevel, terrainType) {
    const palette = TERRAIN_PALETTES[terrainType || 'temperate'];
    const c = palette.colors;
    if (h <= waterLevel) return c[0];
    if (h <= 0.0) return c[1];
    if (h <= 0.5) return c[2];
    if (h <= 1.5) return c[3];
    if (h <= 3.0) return c[4];
    if (h <= 5.0) return c[5];
    return c[6];
}

// --- Biome vegetation drawing ---

function drawVegetation(ctx, x, y, cs, zoom, terrainType, variation) {
    switch (terrainType) {
        case 'snow':   drawPineTree(ctx, x, y, cs, zoom, variation); break;
        case 'desert': drawCactus(ctx, x, y, cs, zoom, variation); break;
        case 'rocky':  drawDeadTree(ctx, x, y, cs, zoom, variation); break;
        default:       drawDeciduousTree(ctx, x, y, cs, zoom, variation); break;
    }
}

function drawDeciduousTree(ctx, x, y, s, zoom, variation) {
    const r = Math.max(2, s * 0.45);
    if (zoom < 3) {
        ctx.fillStyle = '#2ecc71';
        ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
        return;
    }
    // Shadow
    ctx.fillStyle = 'rgba(0,0,0,0.18)';
    ctx.beginPath();
    ctx.ellipse(x + s * 0.08, y + s * 0.14, r * 0.85, r * 0.5, 0, 0, Math.PI * 2);
    ctx.fill();
    // Trunk
    ctx.fillStyle = '#5D4037';
    ctx.fillRect(x - s * 0.05, y - s * 0.02, s * 0.1, s * 0.22);
    // Canopy shadow layer
    ctx.fillStyle = '#1B8A3C';
    ctx.beginPath(); ctx.arc(x + s * 0.02, y - s * 0.02, r * 0.95, 0, Math.PI * 2); ctx.fill();
    // Canopy main
    ctx.fillStyle = '#27AE60';
    ctx.beginPath(); ctx.arc(x - s * 0.03, y - s * 0.06, r * 0.88, 0, Math.PI * 2); ctx.fill();
    // Canopy highlight
    ctx.fillStyle = 'rgba(144,238,144,0.35)';
    ctx.beginPath(); ctx.arc(x - s * 0.1, y - s * 0.14, r * 0.38, 0, Math.PI * 2); ctx.fill();
    // Leaf detail specks
    if (zoom >= 5) {
        ctx.fillStyle = 'rgba(34,139,34,0.3)';
        const seed = variation * 17;
        for (let i = 0; i < 4; i++) {
            const angle = (seed + i * 1.7) % 6.28;
            const dist = r * 0.4 * (0.5 + ((seed + i * 31) % 10) / 20);
            ctx.beginPath();
            ctx.arc(x + Math.cos(angle) * dist, y - s * 0.05 + Math.sin(angle) * dist, s * 0.06, 0, Math.PI * 2);
            ctx.fill();
        }
    }
}

function drawPineTree(ctx, x, y, s, zoom, variation) {
    const r = Math.max(2, s * 0.4);
    if (zoom < 3) {
        ctx.fillStyle = '#1A6B3A';
        ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = 'rgba(240,248,255,0.55)';
        ctx.beginPath(); ctx.arc(x, y - r * 0.25, r * 0.45, 0, Math.PI * 2); ctx.fill();
        return;
    }
    // Shadow
    ctx.fillStyle = 'rgba(0,0,0,0.14)';
    ctx.beginPath();
    ctx.ellipse(x + s * 0.06, y + s * 0.18, s * 0.18, s * 0.08, 0, 0, Math.PI * 2);
    ctx.fill();
    // Trunk
    ctx.fillStyle = '#3E2723';
    ctx.fillRect(x - s * 0.04, y + s * 0.1, s * 0.08, s * 0.16);
    // Bottom tier
    ctx.fillStyle = '#14582C';
    ctx.beginPath();
    ctx.moveTo(x, y - s * 0.15);
    ctx.lineTo(x - s * 0.38, y + s * 0.2);
    ctx.lineTo(x + s * 0.38, y + s * 0.2);
    ctx.fill();
    // Middle tier
    ctx.fillStyle = '#1A7A3C';
    ctx.beginPath();
    ctx.moveTo(x, y - s * 0.35);
    ctx.lineTo(x - s * 0.28, y + s * 0.0);
    ctx.lineTo(x + s * 0.28, y + s * 0.0);
    ctx.fill();
    // Top tier
    ctx.fillStyle = '#1F8C44';
    ctx.beginPath();
    ctx.moveTo(x, y - s * 0.52);
    ctx.lineTo(x - s * 0.18, y - s * 0.15);
    ctx.lineTo(x + s * 0.18, y - s * 0.15);
    ctx.fill();
    // Snow on tiers
    ctx.fillStyle = 'rgba(235,245,255,0.65)';
    ctx.beginPath();
    ctx.moveTo(x, y - s * 0.52);
    ctx.lineTo(x - s * 0.1, y - s * 0.32);
    ctx.lineTo(x + s * 0.1, y - s * 0.32);
    ctx.fill();
    ctx.beginPath();
    ctx.moveTo(x - s * 0.04, y - s * 0.18);
    ctx.lineTo(x - s * 0.18, y - s * 0.01);
    ctx.lineTo(x + s * 0.06, y - s * 0.1);
    ctx.fill();
    // Snow cap blob on bottom tier
    ctx.fillStyle = 'rgba(240,250,255,0.5)';
    ctx.beginPath();
    ctx.moveTo(x + s * 0.05, y + s * 0.04);
    ctx.lineTo(x - s * 0.22, y + s * 0.18);
    ctx.lineTo(x + s * 0.12, y + s * 0.12);
    ctx.fill();
}

function drawCactus(ctx, x, y, s, zoom, variation) {
    if (zoom < 3) {
        ctx.fillStyle = '#2D7A3A';
        ctx.beginPath();
        ctx.arc(x, y, Math.max(2, s * 0.35), 0, Math.PI * 2);
        ctx.fill();
        return;
    }
    // Shadow
    ctx.fillStyle = 'rgba(0,0,0,0.2)';
    ctx.beginPath();
    ctx.ellipse(x + s * 0.06, y + s * 0.2, s * 0.14, s * 0.06, 0.2, 0, Math.PI * 2);
    ctx.fill();

    const tw = s * 0.13;
    const th = s * 0.7;
    const tx = x - tw / 2;
    const ty = y - th * 0.55;
    const armVar = variation % 4;

    // Main trunk
    ctx.fillStyle = '#2D8B3E';
    ctx.beginPath();
    ctx.moveTo(tx + tw * 0.5, ty);
    ctx.bezierCurveTo(tx + tw, ty, tx + tw, ty + th, tx + tw * 0.5, ty + th);
    ctx.bezierCurveTo(tx, ty + th, tx, ty, tx + tw * 0.5, ty);
    ctx.fill();
    // Trunk dark edge
    ctx.fillStyle = '#1E6B2C';
    ctx.beginPath();
    ctx.moveTo(tx + tw, ty + th * 0.15);
    ctx.quadraticCurveTo(tx + tw + s * 0.01, ty + th * 0.5, tx + tw * 0.6, ty + th);
    ctx.lineTo(tx + tw * 0.8, ty + th);
    ctx.quadraticCurveTo(tx + tw - s * 0.01, ty + th * 0.5, tx + tw - s * 0.01, ty + th * 0.15);
    ctx.fill();
    // Rib highlight
    ctx.strokeStyle = 'rgba(100,200,110,0.25)';
    ctx.lineWidth = Math.max(0.5, s * 0.02);
    ctx.beginPath();
    ctx.moveTo(x - s * 0.01, ty + s * 0.06);
    ctx.lineTo(x - s * 0.01, ty + th - s * 0.06);
    ctx.stroke();

    // Arms
    ctx.fillStyle = '#2D8B3E';
    if (armVar === 0 || armVar === 2) {
        // Left arm
        const ay = ty + th * 0.32;
        ctx.beginPath();
        ctx.moveTo(tx, ay);
        ctx.lineTo(tx - s * 0.14, ay + s * 0.02);
        ctx.lineTo(tx - s * 0.14, ay - s * 0.18);
        ctx.quadraticCurveTo(tx - s * 0.14, ay - s * 0.24, tx - s * 0.1, ay - s * 0.24);
        ctx.quadraticCurveTo(tx - s * 0.06, ay - s * 0.24, tx - s * 0.06, ay - s * 0.18);
        ctx.lineTo(tx - s * 0.06, ay);
        ctx.fill();
    }
    if (armVar === 1 || armVar === 2) {
        // Right arm
        const ay = ty + th * 0.24;
        ctx.beginPath();
        ctx.moveTo(tx + tw, ay);
        ctx.lineTo(tx + tw + s * 0.14, ay + s * 0.02);
        ctx.lineTo(tx + tw + s * 0.14, ay - s * 0.15);
        ctx.quadraticCurveTo(tx + tw + s * 0.14, ay - s * 0.21, tx + tw + s * 0.1, ay - s * 0.21);
        ctx.quadraticCurveTo(tx + tw + s * 0.06, ay - s * 0.21, tx + tw + s * 0.06, ay - s * 0.15);
        ctx.lineTo(tx + tw + s * 0.06, ay);
        ctx.fill();
    }
    if (armVar === 3) {
        // Both arms, different heights
        const ayL = ty + th * 0.22;
        ctx.beginPath();
        ctx.moveTo(tx, ayL);
        ctx.lineTo(tx - s * 0.12, ayL + s * 0.01);
        ctx.lineTo(tx - s * 0.12, ayL - s * 0.2);
        ctx.quadraticCurveTo(tx - s * 0.12, ayL - s * 0.26, tx - s * 0.08, ayL - s * 0.26);
        ctx.quadraticCurveTo(tx - s * 0.04, ayL - s * 0.26, tx - s * 0.04, ayL - s * 0.2);
        ctx.lineTo(tx - s * 0.04, ayL);
        ctx.fill();
        const ayR = ty + th * 0.38;
        ctx.beginPath();
        ctx.moveTo(tx + tw, ayR);
        ctx.lineTo(tx + tw + s * 0.12, ayR + s * 0.01);
        ctx.lineTo(tx + tw + s * 0.12, ayR - s * 0.14);
        ctx.quadraticCurveTo(tx + tw + s * 0.12, ayR - s * 0.2, tx + tw + s * 0.08, ayR - s * 0.2);
        ctx.quadraticCurveTo(tx + tw + s * 0.04, ayR - s * 0.2, tx + tw + s * 0.04, ayR - s * 0.14);
        ctx.lineTo(tx + tw + s * 0.04, ayR);
        ctx.fill();
    }

    // Flower on top for some cacti
    if (variation % 3 === 0) {
        ctx.fillStyle = '#E84393';
        ctx.beginPath(); ctx.arc(x, ty + s * 0.02, s * 0.045, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = '#FD79A8';
        ctx.beginPath(); ctx.arc(x - s * 0.015, ty, s * 0.028, 0, Math.PI * 2); ctx.fill();
    }
}

function drawDeadTree(ctx, x, y, s, zoom, variation) {
    if (zoom < 3) {
        ctx.fillStyle = '#5D4037';
        ctx.beginPath();
        ctx.arc(x, y, Math.max(2, s * 0.3), 0, Math.PI * 2);
        ctx.fill();
        return;
    }
    // Shadow
    ctx.fillStyle = 'rgba(0,0,0,0.18)';
    ctx.beginPath();
    ctx.ellipse(x + s * 0.06, y + s * 0.15, s * 0.12, s * 0.05, 0, 0, Math.PI * 2);
    ctx.fill();
    // Trunk
    ctx.strokeStyle = '#3E2723';
    ctx.lineWidth = Math.max(1.5, s * 0.08);
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(x, y + s * 0.22);
    ctx.lineTo(x + s * 0.01, y - s * 0.28);
    ctx.stroke();
    // Branches
    ctx.lineWidth = Math.max(1, s * 0.045);
    ctx.strokeStyle = '#4E342E';
    ctx.beginPath();
    ctx.moveTo(x, y - s * 0.12);
    ctx.lineTo(x - s * 0.22, y - s * 0.34);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(x, y - s * 0.2);
    ctx.lineTo(x + s * 0.2, y - s * 0.38);
    ctx.stroke();
    // Twigs
    ctx.lineWidth = Math.max(0.5, s * 0.025);
    ctx.strokeStyle = '#5D4037';
    ctx.beginPath();
    ctx.moveTo(x - s * 0.15, y - s * 0.27);
    ctx.lineTo(x - s * 0.26, y - s * 0.35);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(x + s * 0.13, y - s * 0.31);
    ctx.lineTo(x + s * 0.24, y - s * 0.28);
    ctx.stroke();
    if (zoom >= 5) {
        ctx.beginPath();
        ctx.moveTo(x - s * 0.2, y - s * 0.33);
        ctx.lineTo(x - s * 0.18, y - s * 0.42);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(x + s * 0.18, y - s * 0.36);
        ctx.lineTo(x + s * 0.25, y - s * 0.42);
        ctx.stroke();
    }
}

// --- Biome rock drawing ---

function drawRockAsset(ctx, x, y, cs, zoom, terrainType, scale) {
    const sz = Math.max(2, cs * (0.28 + scale * 0.12));
    const colors = {
        temperate: { base: '#7f8c8d', dark: '#566573', light: 'rgba(180,190,195,0.4)' },
        snow:      { base: '#6B7B8D', dark: '#4A5568', light: 'rgba(220,235,250,0.5)' },
        desert:    { base: '#B8886B', dark: '#8B6548', light: 'rgba(230,210,175,0.4)' },
        rocky:     { base: '#3D3835', dark: '#252220', light: 'rgba(100,95,90,0.35)' },
    };
    const c = colors[terrainType] || colors.temperate;

    if (zoom < 3) {
        ctx.fillStyle = c.base;
        ctx.beginPath(); ctx.arc(x, y, sz, 0, Math.PI * 2); ctx.fill();
        return;
    }
    // Shadow
    ctx.fillStyle = 'rgba(0,0,0,0.18)';
    ctx.beginPath();
    ctx.ellipse(x + cs * 0.06, y + cs * 0.08, sz * 1.1, sz * 0.6, 0.2, 0, Math.PI * 2);
    ctx.fill();
    // Main rock body (irregular polygon)
    ctx.fillStyle = c.base;
    ctx.beginPath();
    ctx.moveTo(x - sz * 0.8, y + sz * 0.3);
    ctx.lineTo(x - sz * 0.9, y - sz * 0.2);
    ctx.lineTo(x - sz * 0.4, y - sz * 0.7);
    ctx.lineTo(x + sz * 0.3, y - sz * 0.8);
    ctx.lineTo(x + sz * 0.85, y - sz * 0.3);
    ctx.lineTo(x + sz * 0.9, y + sz * 0.2);
    ctx.lineTo(x + sz * 0.4, y + sz * 0.6);
    ctx.lineTo(x - sz * 0.3, y + sz * 0.65);
    ctx.closePath();
    ctx.fill();
    // Dark edge
    ctx.strokeStyle = c.dark;
    ctx.lineWidth = Math.max(0.8, cs * 0.02);
    ctx.stroke();
    // Highlight
    ctx.fillStyle = c.light;
    ctx.beginPath();
    ctx.moveTo(x - sz * 0.5, y - sz * 0.15);
    ctx.lineTo(x - sz * 0.3, y - sz * 0.6);
    ctx.lineTo(x + sz * 0.15, y - sz * 0.65);
    ctx.lineTo(x + sz * 0.1, y - sz * 0.2);
    ctx.closePath();
    ctx.fill();
    // Snow cap for arctic rocks
    if (terrainType === 'snow') {
        ctx.fillStyle = 'rgba(240,248,255,0.7)';
        ctx.beginPath();
        ctx.moveTo(x - sz * 0.35, y - sz * 0.5);
        ctx.quadraticCurveTo(x, y - sz * 1.0, x + sz * 0.3, y - sz * 0.55);
        ctx.lineTo(x + sz * 0.1, y - sz * 0.35);
        ctx.quadraticCurveTo(x - sz * 0.1, y - sz * 0.55, x - sz * 0.25, y - sz * 0.35);
        ctx.closePath();
        ctx.fill();
    }
}

// --- Procedural terrain (matching Swift terrainHeight) ---

function proceduralHeight(x, z, seed) {
    const s = seed || [0, 0, 0, 0, 0];
    let h = 0;
    h += Math.sin(x * 0.055 + z * 0.04 + s[0]) * 5.5;
    h += Math.cos(x * 0.08 - z * 0.06 + s[1]) * 3.5;
    h += Math.sin(x * 0.13 + z * 0.1 + s[2]) * 2.2;
    h += Math.sin(x * 0.22 + z * 0.17 + s[3]) * 1.0;
    const island = (Math.sin(z * 0.025 + x * 0.015 + s[4]) + 0.8) * 0.6;
    h *= Math.max(0, island);
    h += 1.8;
    const stripHalfWidth = 40;
    const xFade = Math.max(0, Math.min(1, (stripHalfWidth - Math.abs(x)) / 10.0));
    h = h * xFade + (1 - xFade) * (-1);
    return h;
}

// --- Gaussian brush weight ---

function gaussianWeight(dist, radius) {
    if (dist > radius) return 0;
    const t = dist / radius;
    return Math.exp(-t * t * 3);
}

// --- Enemy colors/labels ---

const ENEMY_STYLES = {
    tank:        { color: '#e74c3c', label: 'TNK' },
    aaGun:       { color: '#e67e22', label: 'AA' },
    samLauncher: { color: '#9b59b6', label: 'SAM' },
    truck:       { color: '#3498db', label: 'TRK' },
    radioTower:  { color: '#1abc9c', label: 'RAD' },
    building:    { color: '#95a5a6', label: 'BLD' },
};

// --- Main Editor ---

class Editor {
    constructor() {
        this.map = new MapData(40, 200);
        this.canvas = document.getElementById('mapCanvas');
        this.ctx = this.canvas.getContext('2d');
        this.wrap = document.getElementById('canvas-wrap');

        this.cellSize = 4;
        this.zoom = 4;
        this.panX = 0;
        this.panY = 0;

        this.tool = 'raise';
        this.brushSize = 3;
        this.brushStrength = 0.5;
        this.selectedEnemy = 'tank';
        this.showGrid = true;
        this.showObjects = true;

        this.isDrawing = false;
        this.isPanning = false;
        this.spaceHeld = false;
        this.lastMouse = null;
        this.mouseGrid = null;

        this.undoStack = [];
        this.maxUndo = 30;

        this.selectedObject = null;

        this.setupEvents();

        // Load mission from URL params or start fresh
        const params = new URLSearchParams(window.location.search);
        const missionParam = params.get('mission');
        if (missionParam && missionParam !== 'new') {
            this.missionId = missionParam;
            const data = MissionStorage.getData(missionParam);
            if (data) {
                this.loadMissionData(data);
                return; // loadMissionData calls setupCanvas + render
            }
        } else if (missionParam === 'new') {
            this.missionId = 'm_' + Date.now();
        } else {
            this.missionId = null;
        }

        this.setupCanvas();
        this.updateDimensions();
        // Sync map length controls
        document.getElementById('mapLength').value = this.map.lengthZ;
        document.getElementById('mapLengthNum').value = Math.round(this.map.lengthZ);
        this.render();
    }

    setupCanvas() {
        const w = this.wrap.clientWidth;
        const h = this.wrap.clientHeight;
        this.canvas.width = w;
        this.canvas.height = h;
        // Center the map (Z is horizontal, X is vertical after rotation)
        const mapPixelW = (this.map.segmentsZ + 1) * this.cellSize * this.zoom;
        const mapPixelH = (this.map.segmentsX + 1) * this.cellSize * this.zoom;
        this.panX = (w - mapPixelW) / 2;
        this.panY = (h - mapPixelH) / 2;
    }

    // --- Coordinate conversion ---

    canvasToGrid(cx, cy) {
        // Rotated: Z is horizontal (canvas X), X is vertical (canvas Y)
        const mz = (cx - this.panX) / (this.cellSize * this.zoom);
        const mx = (cy - this.panY) / (this.cellSize * this.zoom);
        return { ix: Math.round(mx), iz: Math.round(mz) };
    }

    gridToCanvas(ix, iz) {
        // Rotated: Z maps to canvas X, X maps to canvas Y
        return {
            x: iz * this.cellSize * this.zoom + this.panX,
            y: ix * this.cellSize * this.zoom + this.panY,
        };
    }

    worldToCanvas(wx, wz) {
        // Returns the CENTER of the cell (for object rendering)
        const ix = this.map.indexX(wx);
        const iz = this.map.indexZ(wz);
        const cs = this.cellSize * this.zoom;
        return {
            x: iz * cs + this.panX + cs / 2,
            y: ix * cs + this.panY + cs / 2,
        };
    }

    canvasToWorld(cx, cy) {
        const g = this.canvasToGrid(cx, cy);
        return { x: this.map.worldX(g.ix), z: this.map.worldZ(g.iz) };
    }

    // --- Events ---

    setupEvents() {
        // Tool buttons
        document.querySelectorAll('.tool-btn[data-tool]').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('.tool-btn[data-tool]').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                this.tool = btn.dataset.tool;
                document.getElementById('enemyPanel').style.display = this.tool === 'enemy' ? '' : 'none';
            });
        });

        // Enemy type buttons
        document.querySelectorAll('.enemy-type-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('.enemy-type-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                this.selectedEnemy = btn.dataset.enemy;
            });
        });

        // Brush sliders
        const brushSizeEl = document.getElementById('brushSize');
        const brushStrengthEl = document.getElementById('brushStrength');
        brushSizeEl.addEventListener('input', () => {
            this.brushSize = parseInt(brushSizeEl.value);
            document.getElementById('brushSizeVal').textContent = this.brushSize;
        });
        brushStrengthEl.addEventListener('input', () => {
            this.brushStrength = parseInt(brushStrengthEl.value) / 10;
            document.getElementById('brushStrengthVal').textContent = this.brushStrength.toFixed(1);
        });

        // Terrain type
        document.getElementById('terrainType').addEventListener('change', (e) => {
            this.map.terrainType = e.target.value;
            this.render();
            this.scheduleSave();
        });

        // Water level
        const waterEl = document.getElementById('waterLevel');
        waterEl.addEventListener('input', () => {
            this.map.waterLevel = parseFloat(waterEl.value);
            document.getElementById('waterLevelVal').textContent = this.map.waterLevel.toFixed(1);
            this.render();
        });

        // View toggles
        document.getElementById('showGrid').addEventListener('change', (e) => {
            this.showGrid = e.target.checked;
            this.render();
        });
        document.getElementById('showObjects').addEventListener('change', (e) => {
            this.showObjects = e.target.checked;
            this.render();
        });

        // Map name
        document.getElementById('mapName').addEventListener('input', (e) => {
            this.map.name = e.target.value;
            this.scheduleSave();
        });

        // Map length — slider and number input stay in sync
        const mapLenSlider = document.getElementById('mapLength');
        const mapLenNum = document.getElementById('mapLengthNum');
        const applyMapLength = (val) => {
            const newLen = Math.max(100, Math.min(3000, parseFloat(val)));
            mapLenSlider.value = newLen;
            mapLenNum.value = newLen;
            this.resizeMapLength(newLen);
            this.scheduleSave();
        };
        mapLenSlider.addEventListener('input', () => applyMapLength(mapLenSlider.value));
        mapLenNum.addEventListener('change', () => applyMapLength(mapLenNum.value));

        // Canvas mouse events
        this.canvas.addEventListener('mousedown', (e) => this.onMouseDown(e));
        this.canvas.addEventListener('mousemove', (e) => this.onMouseMove(e));
        this.canvas.addEventListener('mouseup', () => this.onMouseUp());
        this.canvas.addEventListener('mouseleave', () => this.onMouseUp());
        this.canvas.addEventListener('wheel', (e) => this.onWheel(e));
        this.canvas.addEventListener('contextmenu', (e) => e.preventDefault());

        // Keyboard
        document.addEventListener('keydown', (e) => this.onKeyDown(e));
        document.addEventListener('keyup', (e) => this.onKeyUp(e));

        // Resize
        window.addEventListener('resize', () => {
            this.canvas.width = this.wrap.clientWidth;
            this.canvas.height = this.wrap.clientHeight;
            this.render();
        });
    }

    onMouseDown(e) {
        const rect = this.canvas.getBoundingClientRect();
        const cx = e.clientX - rect.left;
        const cy = e.clientY - rect.top;

        // Middle-click, alt+click, or spacebar+click for panning
        if (e.button === 1 || (e.button === 0 && e.altKey) || (e.button === 0 && this.spaceHeld)) {
            this.isPanning = true;
            this.lastMouse = { x: e.clientX, y: e.clientY };
            this.canvas.style.cursor = 'grabbing';
            return;
        }

        if (e.button !== 0) return;

        this.isDrawing = true;
        this.saveUndo();
        this.applyTool(cx, cy);
        this.render();
    }

    onMouseMove(e) {
        const rect = this.canvas.getBoundingClientRect();
        const cx = e.clientX - rect.left;
        const cy = e.clientY - rect.top;

        // Update cursor info
        const grid = this.canvasToGrid(cx, cy);
        this.mouseGrid = grid;
        const world = this.canvasToWorld(cx, cy);
        document.getElementById('cursorPos').textContent = `X: ${world.x.toFixed(1)} Z: ${world.z.toFixed(1)}`;
        const h = this.map.getHeight(grid.ix, grid.iz);
        document.getElementById('cursorHeight').textContent = `Height: ${h.toFixed(2)}`;

        if (this.isPanning) {
            this.panX += e.clientX - this.lastMouse.x;
            this.panY += e.clientY - this.lastMouse.y;
            this.lastMouse = { x: e.clientX, y: e.clientY };
            this.render();
            return;
        }

        if (this.isDrawing) {
            this.applyTool(cx, cy);
        }
        this.render();
    }

    onMouseUp() {
        if (this.isDrawing) this.scheduleSave();
        this.isDrawing = false;
        this.isPanning = false;
        this.lastMouse = null;
        this.canvas.style.cursor = this.spaceHeld ? 'grab' : '';
    }

    onWheel(e) {
        e.preventDefault();
        const rect = this.canvas.getBoundingClientRect();
        const cx = e.clientX - rect.left;
        const cy = e.clientY - rect.top;

        const oldZoom = this.zoom;
        if (e.deltaY < 0) this.zoom = Math.min(16, this.zoom * 1.15);
        else this.zoom = Math.max(0.5, this.zoom / 1.15);

        // Zoom toward cursor
        const scale = this.zoom / oldZoom;
        this.panX = cx - (cx - this.panX) * scale;
        this.panY = cy - (cy - this.panY) * scale;

        document.getElementById('zoomLevel').textContent = `Zoom: ${this.zoom.toFixed(1)}x`;
        this.render();
    }

    onKeyDown(e) {
        // Spacebar for grab/pan
        if (e.code === 'Space' && !e.repeat) {
            e.preventDefault();
            this.spaceHeld = true;
            this.canvas.style.cursor = 'grab';
            return;
        }

        // Number keys for tools
        const toolMap = { '1': 'raise', '2': 'lower', '3': 'smooth', '4': 'tree', '5': 'rock', '6': 'enemy', '7': 'eraser' };
        if (toolMap[e.key]) {
            document.querySelectorAll('.tool-btn[data-tool]').forEach(b => b.classList.remove('active'));
            document.querySelector(`.tool-btn[data-tool="${toolMap[e.key]}"]`).classList.add('active');
            this.tool = toolMap[e.key];
            document.getElementById('enemyPanel').style.display = this.tool === 'enemy' ? '' : 'none';
        }

        // Ctrl+Z undo
        if ((e.ctrlKey || e.metaKey) && e.key === 'z') {
            e.preventDefault();
            this.undo();
        }

        // Bracket keys for brush size
        if (e.key === '[') {
            this.brushSize = Math.max(1, this.brushSize - 1);
            document.getElementById('brushSize').value = this.brushSize;
            document.getElementById('brushSizeVal').textContent = this.brushSize;
            this.render();
        }
        if (e.key === ']') {
            this.brushSize = Math.min(15, this.brushSize + 1);
            document.getElementById('brushSize').value = this.brushSize;
            document.getElementById('brushSizeVal').textContent = this.brushSize;
            this.render();
        }
    }

    onKeyUp(e) {
        if (e.code === 'Space') {
            this.spaceHeld = false;
            this.isPanning = false;
            this.canvas.style.cursor = '';
        }
    }

    // --- Undo ---

    saveUndo() {
        // Deep copy heightmap + objects
        const snapshot = {
            heightmap: this.map.heightmap.map(row => new Float32Array(row)),
            trees: JSON.parse(JSON.stringify(this.map.trees)),
            rocks: JSON.parse(JSON.stringify(this.map.rocks)),
            enemies: JSON.parse(JSON.stringify(this.map.enemies)),
        };
        this.undoStack.push(snapshot);
        if (this.undoStack.length > this.maxUndo) this.undoStack.shift();
    }

    undo() {
        if (this.undoStack.length === 0) return;
        const snapshot = this.undoStack.pop();
        this.map.heightmap = snapshot.heightmap;
        this.map.trees = snapshot.trees;
        this.map.rocks = snapshot.rocks;
        this.map.enemies = snapshot.enemies;
        this.render();
        // Show toast
        const toast = document.getElementById('undoToast');
        toast.classList.add('show');
        setTimeout(() => toast.classList.remove('show'), 800);
    }

    // --- Tools ---

    applyTool(cx, cy) {
        const grid = this.canvasToGrid(cx, cy);
        const ix = grid.ix;
        const iz = grid.iz;

        switch (this.tool) {
            case 'raise':
                this.applyBrush(ix, iz, this.brushStrength);
                break;
            case 'lower':
                this.applyBrush(ix, iz, -this.brushStrength);
                break;
            case 'smooth':
                this.applySmooth(ix, iz);
                break;
            case 'tree':
                this.placeTree(ix, iz);
                break;
            case 'rock':
                this.placeRock(ix, iz);
                break;
            case 'enemy':
                this.placeEnemy(ix, iz);
                break;
            case 'eraser':
                this.applyEraser(cx, cy, ix, iz);
                break;
        }
        this.updateCounts();
    }

    applyBrush(cx, cz, strength) {
        const r = this.brushSize;
        for (let dz = -r; dz <= r; dz++) {
            for (let dx = -r; dx <= r; dx++) {
                const dist = Math.sqrt(dx * dx + dz * dz);
                const w = gaussianWeight(dist, r);
                if (w <= 0) continue;
                const ix = cx + dx;
                const iz = cz + dz;
                const cur = this.map.getHeight(ix, iz);
                this.map.setHeight(ix, iz, cur + strength * w);
            }
        }
    }

    applySmooth(cx, cz) {
        const r = this.brushSize;
        const temp = [];
        for (let dz = -r; dz <= r; dz++) {
            for (let dx = -r; dx <= r; dx++) {
                const dist = Math.sqrt(dx * dx + dz * dz);
                if (dist > r) continue;
                const ix = cx + dx;
                const iz = cz + dz;
                // Average neighbors
                let sum = 0, count = 0;
                for (let nz = -1; nz <= 1; nz++) {
                    for (let nx = -1; nx <= 1; nx++) {
                        sum += this.map.getHeight(ix + nx, iz + nz);
                        count++;
                    }
                }
                const avg = sum / count;
                const cur = this.map.getHeight(ix, iz);
                const w = gaussianWeight(dist, r) * 0.5;
                temp.push({ ix, iz, val: cur + (avg - cur) * w });
            }
        }
        for (const t of temp) {
            this.map.setHeight(t.ix, t.iz, t.val);
        }
    }

    placeTree(ix, iz) {
        const h = this.map.getHeight(ix, iz);
        if (h <= this.map.waterLevel) return;
        const wx = this.map.worldX(ix);
        const wz = this.map.worldZ(iz);
        // Don't place too close to existing tree
        const minDist = 3.0;
        for (const t of this.map.trees) {
            const d = Math.sqrt((t.x - wx) ** 2 + (t.z - wz) ** 2);
            if (d < minDist) return;
        }
        this.map.trees.push({
            x: wx, z: wz,
            height: 1.5 + Math.random() * 2.5,
            variation: Math.floor(Math.random() * 4),
        });
    }

    placeRock(ix, iz) {
        const wx = this.map.worldX(ix);
        const wz = this.map.worldZ(iz);
        const h = this.map.getHeight(ix, iz);
        if (h <= this.map.waterLevel) return;
        const minDist = 4.0;
        for (const r of this.map.rocks) {
            const d = Math.sqrt((r.x - wx) ** 2 + (r.z - wz) ** 2);
            if (d < minDist) return;
        }
        this.map.rocks.push({
            x: wx, z: wz,
            scale: 0.8 + Math.random() * 1.2,
        });
    }

    placeEnemy(ix, iz) {
        // Snap to X=0 (center row) if within 2 cells — bullets only hit at X=0
        const midIX = Math.floor(this.map.segmentsX / 2);
        if (Math.abs(ix - midIX) <= 2) ix = midIX;
        const wx = this.map.worldX(ix);
        const wz = this.map.worldZ(iz);
        const h = this.map.getHeight(ix, iz);
        if (h <= this.map.waterLevel) return;
        const minDist = 5.0;
        for (const e of this.map.enemies) {
            const d = Math.sqrt((e.x - wx) ** 2 + (e.z - wz) ** 2);
            if (d < minDist) return;
        }
        const entry = { type: this.selectedEnemy, x: wx, z: wz };
        if (this.selectedEnemy === 'fighter') entry.altitude = 15;
        this.map.enemies.push(entry);
    }

    applyEraser(cx, cy, gx, gz) {
        // Try to remove objects near cursor first
        const world = this.canvasToWorld(cx, cy);
        const eraseDist = 4.0;

        // Remove nearest enemy
        let minIdx = -1, minDist = eraseDist;
        for (let i = 0; i < this.map.enemies.length; i++) {
            const e = this.map.enemies[i];
            const d = Math.sqrt((e.x - world.x) ** 2 + (e.z - world.z) ** 2);
            if (d < minDist) { minDist = d; minIdx = i; }
        }
        if (minIdx >= 0) { this.map.enemies.splice(minIdx, 1); return; }

        // Remove nearest tree
        minIdx = -1; minDist = eraseDist;
        for (let i = 0; i < this.map.trees.length; i++) {
            const t = this.map.trees[i];
            const d = Math.sqrt((t.x - world.x) ** 2 + (t.z - world.z) ** 2);
            if (d < minDist) { minDist = d; minIdx = i; }
        }
        if (minIdx >= 0) { this.map.trees.splice(minIdx, 1); return; }

        // Remove nearest rock
        minIdx = -1; minDist = eraseDist;
        for (let i = 0; i < this.map.rocks.length; i++) {
            const r = this.map.rocks[i];
            const d = Math.sqrt((r.x - world.x) ** 2 + (r.z - world.z) ** 2);
            if (d < minDist) { minDist = d; minIdx = i; }
        }
        if (minIdx >= 0) { this.map.rocks.splice(minIdx, 1); return; }

        // No object found — flatten terrain toward 0
        this.applyBrush(gx, gz, -this.map.getHeight(gx, gz) * 0.3);
    }

    // --- Rendering ---

    render() {
        const ctx = this.ctx;
        const w = this.canvas.width;
        const h = this.canvas.height;
        const cs = this.cellSize * this.zoom;

        ctx.clearRect(0, 0, w, h);
        ctx.fillStyle = '#111';
        ctx.fillRect(0, 0, w, h);

        const map = this.map;

        // Determine visible range (rotated: Z is horizontal, X is vertical)
        const startIZ = Math.max(0, Math.floor(-this.panX / cs) - 1);
        const startIX = Math.max(0, Math.floor(-this.panY / cs) - 1);
        const endIZ = Math.min(map.segmentsZ, Math.ceil((w - this.panX) / cs) + 1);
        const endIX = Math.min(map.segmentsX, Math.ceil((h - this.panY) / cs) + 1);

        // Draw terrain cells (rotated: iz → canvas X, ix → canvas Y)
        const terrainType = map.terrainType || 'temperate';
        for (let iz = startIZ; iz <= endIZ; iz++) {
            for (let ix = startIX; ix <= endIX; ix++) {
                const height = map.getHeight(ix, iz);
                const [cr, cg, cb] = heightColor(height, map.waterLevel, terrainType);
                // Per-cell noise for organic texture
                const noise = cellHash(ix, iz);
                const vary = 1.0 + (noise - 0.5) * 0.1;
                ctx.fillStyle = `rgb(${Math.min(255, Math.round(cr * vary))},${Math.min(255, Math.round(cg * vary))},${Math.min(255, Math.round(cb * vary))})`;
                const px = iz * cs + this.panX;
                const py = ix * cs + this.panY;
                ctx.fillRect(px, py, cs + 0.5, cs + 0.5);
            }
        }

        // Highlight the plane's middle row (X=0 → ix = segmentsX/2)
        const midIX = Math.floor(map.segmentsX / 2);
        const bandY = midIX * cs + this.panY;
        const bandX0 = startIZ * cs + this.panX;
        const bandX1 = (endIZ + 1) * cs + this.panX;
        ctx.save();
        ctx.strokeStyle = 'rgba(255, 255, 100, 0.5)';
        ctx.lineWidth = Math.max(1, cs);
        ctx.setLineDash([cs * 0.5, cs * 0.3]);
        ctx.beginPath();
        ctx.moveTo(bandX0, bandY + cs / 2);
        ctx.lineTo(bandX1, bandY + cs / 2);
        ctx.stroke();
        ctx.setLineDash([]);
        // Subtle fill band for the middle row
        ctx.fillStyle = 'rgba(255, 255, 100, 0.08)';
        ctx.fillRect(bandX0, bandY, bandX1 - bandX0, cs);
        ctx.restore();

        // Spawn arrow — placed well to the left of the map edge so it doesn't overlap
        const mapLeftEdge = this.panX;
        const arrowLen = Math.max(30, cs * 4);
        const arrowHead = Math.max(8, cs * 1.2);
        const arrowGap = Math.max(20, cs * 3);  // space between arrow tip and map edge
        const spawnTipX = mapLeftEdge - arrowGap;
        const spawnY = bandY + cs / 2;
        ctx.save();
        ctx.strokeStyle = 'rgba(255, 200, 50, 0.85)';
        ctx.fillStyle = 'rgba(255, 200, 50, 0.85)';
        ctx.lineWidth = Math.max(2, cs * 0.3);
        // Arrow shaft
        ctx.beginPath();
        ctx.moveTo(spawnTipX - arrowLen, spawnY);
        ctx.lineTo(spawnTipX, spawnY);
        ctx.stroke();
        // Arrow head
        ctx.beginPath();
        ctx.moveTo(spawnTipX, spawnY);
        ctx.lineTo(spawnTipX - arrowHead, spawnY - arrowHead * 0.6);
        ctx.lineTo(spawnTipX - arrowHead, spawnY + arrowHead * 0.6);
        ctx.closePath();
        ctx.fill();
        // Label
        ctx.font = `bold ${Math.max(10, cs * 1.2)}px sans-serif`;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'bottom';
        ctx.fillText('SPAWN', spawnTipX - arrowLen * 0.4, spawnY - arrowHead * 0.8);
        ctx.restore();

        // Grid overlay (rotated: Z lines are vertical, X lines are horizontal)
        if (this.showGrid && this.zoom >= 2) {
            ctx.strokeStyle = 'rgba(255,255,255,0.15)';
            ctx.lineWidth = 0.5;
            // Horizontal lines (one per X index)
            for (let ix = startIX; ix <= endIX; ix++) {
                const py = ix * cs + this.panY;
                ctx.beginPath();
                ctx.moveTo(startIZ * cs + this.panX, py);
                ctx.lineTo(endIZ * cs + this.panX, py);
                ctx.stroke();
            }
            // Vertical lines (one per Z index)
            for (let iz = startIZ; iz <= endIZ; iz++) {
                const px = iz * cs + this.panX;
                ctx.beginPath();
                ctx.moveTo(px, startIX * cs + this.panY);
                ctx.lineTo(px, endIX * cs + this.panY);
                ctx.stroke();
            }
        }

        // Draw objects
        if (this.showObjects) {
            // Trees / Vegetation (biome-aware)
            for (const tree of map.trees) {
                const pos = this.worldToCanvas(tree.x, tree.z);
                drawVegetation(ctx, pos.x, pos.y, cs, this.zoom, terrainType, tree.variation || 0);
            }

            // Rocks (biome-aware)
            for (const rock of map.rocks) {
                const pos = this.worldToCanvas(rock.x, rock.z);
                drawRockAsset(ctx, pos.x, pos.y, cs, this.zoom, terrainType, rock.scale || 1);
            }

            // Enemies
            for (const enemy of map.enemies) {
                const pos = this.worldToCanvas(enemy.x, enemy.z);
                const style = ENEMY_STYLES[enemy.type] || ENEMY_STYLES.tank;
                const sz = Math.max(4, cs * 0.6);

                ctx.fillStyle = style.color;
                ctx.fillRect(pos.x - sz / 2, pos.y - sz / 2, sz, sz);
                ctx.strokeStyle = '#fff';
                ctx.lineWidth = 1;
                ctx.strokeRect(pos.x - sz / 2, pos.y - sz / 2, sz, sz);

                if (this.zoom >= 3) {
                    ctx.fillStyle = '#fff';
                    ctx.font = `${Math.max(8, cs * 0.5)}px monospace`;
                    ctx.textAlign = 'center';
                    ctx.textBaseline = 'top';
                    ctx.fillText(style.label, pos.x, pos.y + sz / 2 + 1);
                }
            }
        }

        // Brush preview
        if (this.mouseGrid && ['raise', 'lower', 'smooth', 'eraser'].includes(this.tool)) {
            const pos = this.gridToCanvas(this.mouseGrid.ix, this.mouseGrid.iz);
            const r = this.brushSize * cs;
            ctx.strokeStyle = 'rgba(233, 69, 96, 0.7)';
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.arc(pos.x, pos.y, r, 0, Math.PI * 2);
            ctx.stroke();
        }

        // Placement cursor preview
        if (this.mouseGrid && ['tree', 'rock', 'enemy'].includes(this.tool)) {
            const pos = this.gridToCanvas(this.mouseGrid.ix, this.mouseGrid.iz);
            ctx.strokeStyle = 'rgba(233, 69, 96, 0.8)';
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.moveTo(pos.x - 6, pos.y); ctx.lineTo(pos.x + 6, pos.y);
            ctx.moveTo(pos.x, pos.y - 6); ctx.lineTo(pos.x, pos.y + 6);
            ctx.stroke();
        }

        this.updateCounts();
    }

    // --- UI Updates ---

    updateDimensions() {
        document.getElementById('mapDimensions').textContent =
            `${this.map.widthX.toFixed(0)}×${this.map.lengthZ.toFixed(0)} (${this.map.segmentsX + 1}×${this.map.segmentsZ + 1})`;
    }

    updateCounts() {
        document.getElementById('objectCounts').innerHTML =
            `Trees: ${this.map.trees.length}<br>` +
            `Rocks: ${this.map.rocks.length}<br>` +
            `Enemies: ${this.map.enemies.length}`;
    }

    // --- Map Resize ---

    resizeMapLength(newLengthZ) {
        this.saveUndo();
        const map = this.map;
        const newSegZ = Math.round(newLengthZ / 2.5);
        if (newSegZ === map.segmentsZ) return;

        const oldSegZ = map.segmentsZ;
        const newHeightmap = [];
        for (let z = 0; z <= newSegZ; z++) {
            if (z <= oldSegZ) {
                // Copy existing row, padding X if needed
                const oldRow = map.heightmap[z];
                const newRow = new Float32Array(map.segmentsX + 1);
                for (let x = 0; x <= map.segmentsX; x++) {
                    newRow[x] = oldRow ? (oldRow[x] || 0) : 0;
                }
                newHeightmap.push(newRow);
            } else {
                // New rows beyond old extent — flat at 0
                newHeightmap.push(new Float32Array(map.segmentsX + 1));
            }
        }

        map.segmentsZ = newSegZ;
        map.lengthZ = newSegZ * 2.5;
        map.heightmap = newHeightmap;

        // Remove objects/enemies that are now out of bounds
        map.trees = map.trees.filter(t => t.z <= map.lengthZ);
        map.rocks = map.rocks.filter(r => r.z <= map.lengthZ);
        map.enemies = map.enemies.filter(e => e.z <= map.lengthZ);

        this.updateDimensions();
        this.updateCounts();
        this.setupCanvas();
        this.render();
    }

    // --- Actions ---

    generateTerrain() {
        this.saveUndo();
        const map = this.map;
        const seed = Array.from({ length: 5 }, () => Math.random() * Math.PI * 2);
        for (let iz = 0; iz <= map.segmentsZ; iz++) {
            for (let ix = 0; ix <= map.segmentsX; ix++) {
                const wx = map.worldX(ix);
                const wz = map.worldZ(iz);
                map.heightmap[iz][ix] = proceduralHeight(wx, wz, seed);
            }
        }
        this.render();
        this.scheduleSave();
    }

    flattenAll() {
        this.saveUndo();
        const map = this.map;
        for (let iz = 0; iz <= map.segmentsZ; iz++) {
            map.heightmap[iz].fill(0);
        }
        this.render();
        this.scheduleSave();
    }

    buildMissionJSON() {
        const map = this.map;
        const heightmap = [];
        for (let iz = 0; iz <= map.segmentsZ; iz++) {
            const row = [];
            for (let ix = 0; ix <= map.segmentsX; ix++) {
                row.push(Math.round(map.heightmap[iz][ix] * 100) / 100);
            }
            heightmap.push(row);
        }
        return {
            version: 1,
            name: map.name,
            description: null,
            author: null,
            terrain: {
                widthX: map.widthX,
                lengthZ: map.lengthZ,
                originX: map.originX,
                originZ: map.originZ,
                segmentsX: map.segmentsX,
                segmentsZ: map.segmentsZ,
                heightmap: heightmap,
            },
            terrainType: map.terrainType || 'temperate',
            waterLevel: map.waterLevel,
            objects: {
                trees: map.trees.map(t => ({
                    x: Math.round(t.x * 100) / 100,
                    z: Math.round(t.z * 100) / 100,
                    height: Math.round(t.height * 100) / 100,
                    variation: t.variation,
                })),
                rocks: map.rocks.map(r => ({
                    x: Math.round(r.x * 100) / 100,
                    z: Math.round(r.z * 100) / 100,
                    scale: Math.round(r.scale * 100) / 100,
                })),
            },
            enemies: map.enemies.map(e => {
                const obj = {
                    type: e.type,
                    x: Math.round(e.x * 100) / 100,
                    z: Math.round(e.z * 100) / 100,
                };
                if (e.altitude !== undefined) obj.altitude = e.altitude;
                return obj;
            }),
            playerStart: { z: 0, altitude: 12 },
            objectives: { type: "destroyAll", description: "Destroy all enemy installations" },
        };
    }

    exportJSON() {
        const data = this.buildMissionJSON();
        const json = JSON.stringify(data, null, 2);
        const blob = new Blob([json], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = (this.map.name || 'mission').replace(/[^a-zA-Z0-9]/g, '_') + '.json';
        a.click();
        URL.revokeObjectURL(url);
    }

    saveToLocalStorage() {
        if (!this.missionId) {
            this.missionId = 'm_' + Date.now();
        }
        const data = this.buildMissionJSON();
        MissionStorage.saveData(this.missionId, data);

        // Update or create index entry
        const index = MissionStorage.getIndex();
        const existing = index.find(m => m.id === this.missionId);
        const entry = {
            id: this.missionId,
            name: this.map.name,
            terrainType: this.map.terrainType || 'temperate',
            modifiedAt: new Date().toISOString(),
            segmentsX: this.map.segmentsX,
            segmentsZ: this.map.segmentsZ,
            enemyCount: this.map.enemies.length,
            treeCount: this.map.trees.length,
            rockCount: this.map.rocks.length,
        };
        if (existing) {
            Object.assign(existing, entry);
        } else {
            entry.createdAt = new Date().toISOString();
            index.push(entry);
        }
        MissionStorage.saveIndex(index);

        // Show brief save indicator
        const toast = document.getElementById('undoToast');
        toast.textContent = 'Saved';
        toast.classList.add('show');
        setTimeout(() => { toast.classList.remove('show'); toast.textContent = 'Undo'; }, 600);
    }

    scheduleSave() {
        clearTimeout(this._saveTimer);
        this._saveTimer = setTimeout(() => this.saveToLocalStorage(), 500);
    }

    importJSON(event) {
        const file = event.target.files[0];
        if (!file) return;
        const reader = new FileReader();
        reader.onload = (e) => {
            try {
                const data = JSON.parse(e.target.result);
                this.loadMissionData(data);
            } catch (err) {
                alert('Invalid JSON file: ' + err.message);
            }
        };
        reader.readAsText(file);
        event.target.value = '';
    }

    loadMissionData(data) {
        const t = data.terrain;
        this.map = new MapData(t.segmentsX, t.segmentsZ);
        this.map.widthX = t.widthX;
        this.map.lengthZ = t.lengthZ;
        this.map.originX = t.originX;
        this.map.originZ = t.originZ;
        this.map.name = data.name || 'Imported';
        this.map.waterLevel = data.waterLevel ?? -0.2;
        this.map.terrainType = data.terrainType || 'temperate';

        // Load heightmap
        for (let iz = 0; iz <= t.segmentsZ; iz++) {
            for (let ix = 0; ix <= t.segmentsX; ix++) {
                if (data.terrain.heightmap[iz] && data.terrain.heightmap[iz][ix] !== undefined) {
                    this.map.heightmap[iz][ix] = data.terrain.heightmap[iz][ix];
                }
            }
        }

        // Load objects
        this.map.trees = data.objects?.trees || [];
        this.map.rocks = data.objects?.rocks || [];
        this.map.enemies = data.enemies || [];

        // Update UI
        document.getElementById('mapName').value = this.map.name;
        document.getElementById('terrainType').value = this.map.terrainType;
        document.getElementById('waterLevel').value = this.map.waterLevel;
        document.getElementById('waterLevelVal').textContent = this.map.waterLevel.toFixed(1);
        document.getElementById('mapLength').value = this.map.lengthZ;
        document.getElementById('mapLengthNum').value = Math.round(this.map.lengthZ);
        this.updateDimensions();
        this.undoStack = [];
        this.setupCanvas();
        this.render();
    }

    newMap() {
        // Show modal
        const overlay = document.createElement('div');
        overlay.className = 'modal-overlay';
        overlay.innerHTML = `
            <div class="modal">
                <h2>New Map</h2>
                <label>Map Name</label>
                <input type="text" id="newMapName" value="New Mission">
                <label>Width X (game units)</label>
                <input type="number" id="newMapWidth" value="100" min="20" max="400" step="10">
                <label>Length Z (game units)</label>
                <input type="number" id="newMapLength" value="500" min="50" max="5000" step="50">
                <div class="btn-row">
                    <button id="newMapCancel">Cancel</button>
                    <button id="newMapCreate" class="primary">Create</button>
                </div>
            </div>
        `;
        document.body.appendChild(overlay);

        document.getElementById('newMapCancel').onclick = () => overlay.remove();
        document.getElementById('newMapCreate').onclick = () => {
            const name = document.getElementById('newMapName').value;
            const widthX = parseFloat(document.getElementById('newMapWidth').value);
            const lengthZ = parseFloat(document.getElementById('newMapLength').value);
            const segX = Math.round(widthX / 2.5);
            const segZ = Math.round(lengthZ / 2.5);
            this.map = new MapData(segX, segZ);
            this.map.name = name;
            document.getElementById('mapName').value = name;
            document.getElementById('mapLength').value = lengthZ;
            document.getElementById('mapLengthNum').value = Math.round(lengthZ);
            this.updateDimensions();
            this.undoStack = [];
            this.setupCanvas();
            this.render();
            overlay.remove();
        };
    }
}

// --- Init ---
const editor = new Editor();
