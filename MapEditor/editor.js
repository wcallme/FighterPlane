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
        this.buildings = []; // decorative buildings: { type, x, z, rotation }
        this.enemies = [];
        this.planes = [];    // air trigger points: { type, x, z, count }
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

// --- Color utility ---

function hexToRgb(hex) {
    const r = parseInt(hex.slice(1, 3), 16);
    const g = parseInt(hex.slice(3, 5), 16);
    const b = parseInt(hex.slice(5, 7), 16);
    return [r, g, b];
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

const PLANE_STYLES = {
    fighter:    { color: '#f39c12', label: 'FTR' },
    aiFighter:  { color: '#e74c3c', label: 'AI' },
};

const BUILDING_STYLES = {
    house:      { color: '#d4a574', border: '#a0784c', label: 'HSE' },
    office:     { color: '#7f8fa6', border: '#5a6a80', label: 'OFC' },
    skyscraper: { color: '#546e8a', border: '#3a5068', label: 'SKY' },
    warehouse:  { color: '#a09080', border: '#786858', label: 'WRH' },
    tower:      { color: '#6c7a7a', border: '#4a5858', label: 'TWR' },
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
        this.rotationAngle = 0;
        this._cosA = 1;
        this._sinA = 0;

        this.tool = 'raise';
        this.brushSize = 3;
        this.brushStrength = 0.5;
        this.selectedEnemy = 'tank';
        this.selectedPlane = 'fighter';
        this.planeCount = 1;
        this.selectedBuilding = 'house';
        this.buildingRotation = 0;
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
        // Center the isometric map view
        const tw = this.cellSize * this.zoom;
        const th = tw / 2;
        const midIX = this.map.segmentsX / 2;
        const midIZ = this.map.segmentsZ / 2;
        const mapCenterX = (midIZ - midIX) * tw / 2;
        const mapCenterY = (midIZ + midIX) * th / 2;
        this.panX = w / 2 - mapCenterX;
        this.panY = h / 2 - mapCenterY;
    }

    // --- Isometric projection ---

    isoProject(ix, iz, h = 0) {
        const tw = this.cellSize * this.zoom;
        const th = tw / 2;
        const hScale = tw * 0.2;
        // Rotate around map center
        const mcx = this.map.segmentsX / 2;
        const mcz = this.map.segmentsZ / 2;
        const dx = ix - mcx;
        const dz = iz - mcz;
        const rix = dx * this._cosA - dz * this._sinA + mcx;
        const riz = dx * this._sinA + dz * this._cosA + mcz;
        return {
            x: (riz - rix) * tw / 2 + this.panX,
            y: (riz + rix) * th / 2 + this.panY - h * hScale,
        };
    }

    // --- Coordinate conversion ---

    canvasToGrid(cx, cy) {
        const tw = this.cellSize * this.zoom;
        const th = tw / 2;
        const hScale = tw * 0.2;
        const sx = cx - this.panX;
        const sy = cy - this.panY;
        const a = tw / 2;
        const b = th / 2;
        const mcx = this.map.segmentsX / 2;
        const mcz = this.map.segmentsZ / 2;
        // Reverse isometric → rotated grid coordinates
        let riz = (sx / a + sy / b) / 2;
        let rix = (sy / b - sx / a) / 2;
        // Inverse rotation → actual grid coordinates
        let drx = rix - mcx;
        let drz = riz - mcz;
        let ix = drx * this._cosA + drz * this._sinA + mcx;
        let iz = -drx * this._sinA + drz * this._cosA + mcz;
        // Height correction
        const ixR = Math.max(0, Math.min(Math.round(ix), this.map.segmentsX));
        const izR = Math.max(0, Math.min(Math.round(iz), this.map.segmentsZ));
        const hAdj = this.map.getHeight(ixR, izR);
        const syAdj = sy + hAdj * hScale;
        riz = (sx / a + syAdj / b) / 2;
        rix = (syAdj / b - sx / a) / 2;
        drx = rix - mcx;
        drz = riz - mcz;
        ix = drx * this._cosA + drz * this._sinA + mcx;
        iz = -drx * this._sinA + drz * this._cosA + mcz;
        return { ix: Math.round(ix), iz: Math.round(iz) };
    }

    gridToCanvas(ix, iz) {
        const h = this.map.getHeight(
            Math.max(0, Math.min(ix, this.map.segmentsX)),
            Math.max(0, Math.min(iz, this.map.segmentsZ))
        );
        return this.isoProject(ix, iz, h);
    }

    worldToCanvas(wx, wz) {
        const ix = this.map.indexX(wx);
        const iz = this.map.indexZ(wz);
        const h = this.map.getHeight(ix, iz);
        return this.isoProject(ix, iz, h);
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
                document.getElementById('planePanel').style.display = this.tool === 'plane' ? '' : 'none';
                document.getElementById('buildingPanel').style.display = this.tool === 'building' ? '' : 'none';
            });
        });

        // Building type buttons
        document.querySelectorAll('.building-type-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('.building-type-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                this.selectedBuilding = btn.dataset.building;
            });
        });

        // Building rotation slider
        const buildRotEl = document.getElementById('buildingRotation');
        buildRotEl.addEventListener('input', () => {
            this.buildingRotation = parseInt(buildRotEl.value);
            document.getElementById('buildingRotationVal').textContent = this.buildingRotation + '°';
        });

        // Enemy type buttons
        document.querySelectorAll('.enemy-type-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('.enemy-type-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                this.selectedEnemy = btn.dataset.enemy;
            });
        });

        // Plane type buttons
        document.querySelectorAll('.plane-type-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('.plane-type-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                this.selectedPlane = btn.dataset.plane;
            });
        });

        // Plane count slider
        const planeCountEl = document.getElementById('planeCount');
        planeCountEl.addEventListener('input', () => {
            this.planeCount = parseInt(planeCountEl.value);
            document.getElementById('planeCountVal').textContent = this.planeCount;
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

        // Rotation slider
        const rotSlider = document.getElementById('rotationSlider');
        rotSlider.addEventListener('input', () => {
            this.rotationAngle = parseFloat(rotSlider.value) * Math.PI / 180;
            this._cosA = Math.cos(this.rotationAngle);
            this._sinA = Math.sin(this.rotationAngle);
            document.getElementById('rotationVal').textContent = rotSlider.value + '\u00b0';
            this.render();
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
        if (e.deltaY < 0) this.zoom = Math.min(16, this.zoom * 1.05);
        else this.zoom = Math.max(0.5, this.zoom / 1.05);

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
        const toolMap = { '1': 'raise', '2': 'lower', '3': 'smooth', '4': 'tree', '5': 'rock', '6': 'enemy', '7': 'plane', '8': 'building', '9': 'eraser' };
        if (toolMap[e.key]) {
            document.querySelectorAll('.tool-btn[data-tool]').forEach(b => b.classList.remove('active'));
            document.querySelector(`.tool-btn[data-tool="${toolMap[e.key]}"]`).classList.add('active');
            this.tool = toolMap[e.key];
            document.getElementById('enemyPanel').style.display = this.tool === 'enemy' ? '' : 'none';
            document.getElementById('planePanel').style.display = this.tool === 'plane' ? '' : 'none';
            document.getElementById('buildingPanel').style.display = this.tool === 'building' ? '' : 'none';
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
            buildings: JSON.parse(JSON.stringify(this.map.buildings)),
            enemies: JSON.parse(JSON.stringify(this.map.enemies)),
            planes: JSON.parse(JSON.stringify(this.map.planes)),
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
        this.map.buildings = snapshot.buildings;
        this.map.enemies = snapshot.enemies;
        this.map.planes = snapshot.planes;
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
            case 'plane':
                this.placePlane(ix, iz);
                break;
            case 'building':
                this.placeBuilding(ix, iz);
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

    placePlane(ix, iz) {
        const wx = this.map.worldX(ix);
        const wz = this.map.worldZ(iz);
        // Don't place too close to existing plane trigger
        const minDist = 8.0;
        for (const p of this.map.planes) {
            const d = Math.sqrt((p.x - wx) ** 2 + (p.z - wz) ** 2);
            if (d < minDist) return;
        }
        this.map.planes.push({
            type: this.selectedPlane,
            x: wx,
            z: wz,
            count: this.planeCount,
        });
    }

    placeBuilding(ix, iz) {
        const wx = this.map.worldX(ix);
        const wz = this.map.worldZ(iz);
        const h = this.map.getHeight(ix, iz);
        if (h <= this.map.waterLevel) return;
        const minDist = 4.0;
        for (const b of this.map.buildings) {
            const d = Math.sqrt((b.x - wx) ** 2 + (b.z - wz) ** 2);
            if (d < minDist) return;
        }
        this.map.buildings.push({
            type: this.selectedBuilding,
            x: wx,
            z: wz,
            rotation: this.buildingRotation,
        });
    }

    applyEraser(cx, cy, gx, gz) {
        // Try to remove objects near cursor first
        const world = this.canvasToWorld(cx, cy);
        const eraseDist = 4.0;

        // Remove nearest plane trigger
        let minIdx = -1, minDist = eraseDist;
        for (let i = 0; i < this.map.planes.length; i++) {
            const p = this.map.planes[i];
            const d = Math.sqrt((p.x - world.x) ** 2 + (p.z - world.z) ** 2);
            if (d < minDist) { minDist = d; minIdx = i; }
        }
        if (minIdx >= 0) { this.map.planes.splice(minIdx, 1); return; }

        // Remove nearest building
        minIdx = -1; minDist = eraseDist;
        for (let i = 0; i < this.map.buildings.length; i++) {
            const b = this.map.buildings[i];
            const d = Math.sqrt((b.x - world.x) ** 2 + (b.z - world.z) ** 2);
            if (d < minDist) { minDist = d; minIdx = i; }
        }
        if (minIdx >= 0) { this.map.buildings.splice(minIdx, 1); return; }

        // Remove nearest enemy
        minIdx = -1; minDist = eraseDist;
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

    // --- Isometric 3D drawing helpers ---

    worldToFGrid(wx, wz) {
        const upc = this.map.widthX / this.map.segmentsX; // 2.5 game units per cell
        return {
            fx: (wx - this.map.originX) / upc,
            fz: (wz - this.map.originZ) / upc,
        };
    }

    drawIsoBox(fx, fz, gameW, gameH, gameD, color, baseH) {
        const upc = this.map.widthX / this.map.segmentsX;
        const hw = gameW / upc / 2;
        const hd = gameD / upc / 2;
        const hTop = baseH + gameH;
        const ctx = this.ctx;

        const [cr, cg, cb] = hexToRgb(color);
        const t00 = this.isoProject(fx - hw, fz - hd, hTop);
        const t01 = this.isoProject(fx - hw, fz + hd, hTop);
        const t10 = this.isoProject(fx + hw, fz - hd, hTop);
        const t11 = this.isoProject(fx + hw, fz + hd, hTop);
        const b00 = this.isoProject(fx - hw, fz - hd, baseH);
        const b01 = this.isoProject(fx - hw, fz + hd, baseH);
        const b10 = this.isoProject(fx + hw, fz - hd, baseH);
        const b11 = this.isoProject(fx + hw, fz + hd, baseH);

        const drawS = (this._cosA + this._sinA) >= 0;
        const drawE = (this._cosA - this._sinA) >= 0;

        // Face perpendicular to ix (darker)
        ctx.fillStyle = `rgb(${Math.round(cr * 0.55)},${Math.round(cg * 0.55)},${Math.round(cb * 0.55)})`;
        if (drawS) {
            ctx.beginPath();
            ctx.moveTo(t10.x, t10.y); ctx.lineTo(t11.x, t11.y);
            ctx.lineTo(b11.x, b11.y); ctx.lineTo(b10.x, b10.y);
            ctx.closePath(); ctx.fill();
        } else {
            ctx.beginPath();
            ctx.moveTo(t00.x, t00.y); ctx.lineTo(t01.x, t01.y);
            ctx.lineTo(b01.x, b01.y); ctx.lineTo(b00.x, b00.y);
            ctx.closePath(); ctx.fill();
        }

        // Face perpendicular to iz (medium)
        ctx.fillStyle = `rgb(${Math.round(cr * 0.72)},${Math.round(cg * 0.72)},${Math.round(cb * 0.72)})`;
        if (drawE) {
            ctx.beginPath();
            ctx.moveTo(t01.x, t01.y); ctx.lineTo(t11.x, t11.y);
            ctx.lineTo(b11.x, b11.y); ctx.lineTo(b01.x, b01.y);
            ctx.closePath(); ctx.fill();
        } else {
            ctx.beginPath();
            ctx.moveTo(t00.x, t00.y); ctx.lineTo(t10.x, t10.y);
            ctx.lineTo(b10.x, b10.y); ctx.lineTo(b00.x, b00.y);
            ctx.closePath(); ctx.fill();
        }

        // Top face
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.moveTo(t00.x, t00.y); ctx.lineTo(t01.x, t01.y);
        ctx.lineTo(t11.x, t11.y); ctx.lineTo(t10.x, t10.y);
        ctx.closePath(); ctx.fill();
    }

    drawIsoLabel(wx, wz, gameH, label, color) {
        const ix = this.map.indexX(wx);
        const iz = this.map.indexZ(wz);
        const bH = Math.max(this.map.getHeight(ix, iz), this.map.waterLevel);
        const { fx, fz } = this.worldToFGrid(wx, wz);
        const top = this.isoProject(fx, fz, bH + gameH + 0.5);
        const cs = this.cellSize * this.zoom;
        const ctx = this.ctx;
        ctx.fillStyle = color;
        ctx.font = `bold ${Math.max(7, cs * 0.45)}px monospace`;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'bottom';
        ctx.fillText(label, top.x, top.y);
    }

    // --- Rendering ---

    render() {
        const ctx = this.ctx;
        const w = this.canvas.width;
        const h = this.canvas.height;
        const cs = this.cellSize * this.zoom;

        ctx.clearRect(0, 0, w, h);
        ctx.fillStyle = '#0a0a18';
        ctx.fillRect(0, 0, w, h);

        const map = this.map;
        const terrainType = map.terrainType || 'temperate';
        const baseLevel = map.waterLevel - 0.3;

        // Determine visible cell range from screen corners (isometric reverse)
        const corners = [
            this.canvasToGrid(0, 0),
            this.canvasToGrid(w, 0),
            this.canvasToGrid(0, h),
            this.canvasToGrid(w, h),
        ];
        let minIX = Infinity, maxIX = -Infinity, minIZ = Infinity, maxIZ = -Infinity;
        for (const c of corners) {
            minIX = Math.min(minIX, c.ix);
            maxIX = Math.max(maxIX, c.ix);
            minIZ = Math.min(minIZ, c.iz);
            maxIZ = Math.max(maxIZ, c.iz);
        }
        const pad = 10;
        const startIX = Math.max(0, Math.floor(minIX) - pad);
        const endIX = Math.min(map.segmentsX - 1, Math.ceil(maxIX) + pad);
        const startIZ = Math.max(0, Math.floor(minIZ) - pad);
        const endIZ = Math.min(map.segmentsZ - 1, Math.ceil(maxIZ) + pad);

        // Determine draw order and visible side faces based on rotation
        const drawSouth = (this._cosA + this._sinA) >= 0;
        const drawEast = (this._cosA - this._sinA) >= 0;
        const ixStep = drawSouth ? 1 : -1;
        const izStep = drawEast ? 1 : -1;
        const ixFrom = drawSouth ? startIX : endIX;
        const ixTo = drawSouth ? endIX : startIX;
        const izFrom = drawEast ? startIZ : endIZ;
        const izTo = drawEast ? endIZ : startIZ;

        // Draw terrain cells from back to front (isometric painter's algorithm)
        for (let ix = ixFrom; drawSouth ? (ix <= ixTo) : (ix >= ixTo); ix += ixStep) {
            for (let iz = izFrom; drawEast ? (iz <= izTo) : (iz >= izTo); iz += izStep) {
                // Get heights at 4 corners of this cell
                const h00 = map.getHeight(ix, iz);
                const h10 = map.getHeight(ix + 1, iz);
                const h01 = map.getHeight(ix, iz + 1);
                const h11 = map.getHeight(ix + 1, iz + 1);
                const avgH = (h00 + h10 + h01 + h11) / 4;

                // Display heights: clamp to water level so water is flat
                const d00 = Math.max(h00, map.waterLevel);
                const d10 = Math.max(h10, map.waterLevel);
                const d01 = Math.max(h01, map.waterLevel);
                const d11 = Math.max(h11, map.waterLevel);

                // Color from actual height (so underwater = water color)
                const [cr, cg, cb] = heightColor(avgH, map.waterLevel, terrainType);
                const noise = cellHash(ix, iz);
                const vary = 1.0 + (noise - 0.5) * 0.1;
                const r = Math.min(255, Math.round(cr * vary));
                const g = Math.min(255, Math.round(cg * vary));
                const b = Math.min(255, Math.round(cb * vary));

                // Project 4 corners with display heights
                const p00 = this.isoProject(ix, iz, d00);
                const p01 = this.isoProject(ix, iz + 1, d01);
                const p11 = this.isoProject(ix + 1, iz + 1, d11);
                const p10 = this.isoProject(ix + 1, iz, d10);

                // Face perpendicular to ix axis (darkest shade)
                ctx.fillStyle = `rgb(${Math.round(r * 0.45)},${Math.round(g * 0.45)},${Math.round(b * 0.45)})`;
                if (drawSouth) {
                    const pb10 = this.isoProject(ix + 1, iz, baseLevel);
                    const pb11s = this.isoProject(ix + 1, iz + 1, baseLevel);
                    ctx.beginPath();
                    ctx.moveTo(p10.x, p10.y);
                    ctx.lineTo(p11.x, p11.y);
                    ctx.lineTo(pb11s.x, pb11s.y);
                    ctx.lineTo(pb10.x, pb10.y);
                    ctx.closePath();
                    ctx.fill();
                } else {
                    const pb00n = this.isoProject(ix, iz, baseLevel);
                    const pb01n = this.isoProject(ix, iz + 1, baseLevel);
                    ctx.beginPath();
                    ctx.moveTo(p00.x, p00.y);
                    ctx.lineTo(p01.x, p01.y);
                    ctx.lineTo(pb01n.x, pb01n.y);
                    ctx.lineTo(pb00n.x, pb00n.y);
                    ctx.closePath();
                    ctx.fill();
                }

                // Face perpendicular to iz axis (medium shade)
                ctx.fillStyle = `rgb(${Math.round(r * 0.62)},${Math.round(g * 0.62)},${Math.round(b * 0.62)})`;
                if (drawEast) {
                    const pb01e = this.isoProject(ix, iz + 1, baseLevel);
                    const pb11e = this.isoProject(ix + 1, iz + 1, baseLevel);
                    ctx.beginPath();
                    ctx.moveTo(p01.x, p01.y);
                    ctx.lineTo(p11.x, p11.y);
                    ctx.lineTo(pb11e.x, pb11e.y);
                    ctx.lineTo(pb01e.x, pb01e.y);
                    ctx.closePath();
                    ctx.fill();
                } else {
                    const pb00w = this.isoProject(ix, iz, baseLevel);
                    const pb10w = this.isoProject(ix + 1, iz, baseLevel);
                    ctx.beginPath();
                    ctx.moveTo(p00.x, p00.y);
                    ctx.lineTo(p10.x, p10.y);
                    ctx.lineTo(pb10w.x, pb10w.y);
                    ctx.lineTo(pb00w.x, pb00w.y);
                    ctx.closePath();
                    ctx.fill();
                }

                // Top face
                ctx.fillStyle = `rgb(${r},${g},${b})`;
                ctx.beginPath();
                ctx.moveTo(p00.x, p00.y);
                ctx.lineTo(p01.x, p01.y);
                ctx.lineTo(p11.x, p11.y);
                ctx.lineTo(p10.x, p10.y);
                ctx.closePath();
                ctx.fill();

                // Grid lines on top face
                if (this.showGrid && this.zoom >= 3) {
                    ctx.strokeStyle = 'rgba(255,255,255,0.07)';
                    ctx.lineWidth = 0.5;
                    ctx.stroke();
                }
            }
        }

        // Highlight middle row (player flight path)
        const midIX = Math.floor(map.segmentsX / 2);
        ctx.save();
        ctx.strokeStyle = 'rgba(255, 255, 100, 0.4)';
        ctx.lineWidth = 2;
        ctx.setLineDash([8, 6]);
        for (const rowIX of [midIX, midIX + 1]) {
            ctx.beginPath();
            for (let iz = startIZ; iz <= endIZ + 1; iz++) {
                const izC = Math.min(iz, map.segmentsZ);
                const hh = Math.max(map.getHeight(rowIX, izC), map.waterLevel);
                const p = this.isoProject(rowIX, iz, hh);
                if (iz === startIZ) ctx.moveTo(p.x, p.y);
                else ctx.lineTo(p.x, p.y);
            }
            ctx.stroke();
        }
        ctx.setLineDash([]);
        ctx.restore();

        // Spawn arrow at map start (iz = 0)
        const spawnH = Math.max(map.getHeight(midIX, 0), map.waterLevel);
        const spawnP = this.isoProject(midIX + 0.5, 0, spawnH);
        const spawnDir = this.isoProject(midIX + 0.5, 5, spawnH);
        const sDx = spawnDir.x - spawnP.x;
        const sDy = spawnDir.y - spawnP.y;
        const sLen = Math.sqrt(sDx * sDx + sDy * sDy);
        if (sLen > 0) {
            const snx = sDx / sLen, sny = sDy / sLen;
            const arrowLen = Math.max(30, cs * 4);
            const headSize = Math.max(8, cs * 1.2);
            const spx = -sny, spy = snx;
            ctx.save();
            ctx.strokeStyle = 'rgba(255, 200, 50, 0.85)';
            ctx.fillStyle = 'rgba(255, 200, 50, 0.85)';
            ctx.lineWidth = Math.max(2, cs * 0.3);
            ctx.beginPath();
            ctx.moveTo(spawnP.x - snx * arrowLen, spawnP.y - sny * arrowLen);
            ctx.lineTo(spawnP.x, spawnP.y);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(spawnP.x, spawnP.y);
            ctx.lineTo(spawnP.x - snx * headSize + spx * headSize * 0.6, spawnP.y - sny * headSize + spy * headSize * 0.6);
            ctx.lineTo(spawnP.x - snx * headSize - spx * headSize * 0.6, spawnP.y - sny * headSize - spy * headSize * 0.6);
            ctx.closePath();
            ctx.fill();
            ctx.font = `bold ${Math.max(10, cs * 1.2)}px sans-serif`;
            ctx.textAlign = 'center';
            ctx.textBaseline = 'bottom';
            ctx.fillText('SPAWN', spawnP.x - snx * arrowLen * 0.5, spawnP.y - sny * arrowLen * 0.5 - headSize);
            ctx.restore();
        }

        // Draw objects sorted by isometric depth (back to front)
        if (this.showObjects) {
            const allObjs = [];
            for (const tree of map.trees) {
                allObjs.push({ type: 'tree', data: tree, depth: map.indexX(tree.x) + map.indexZ(tree.z) });
            }
            for (const rock of map.rocks) {
                allObjs.push({ type: 'rock', data: rock, depth: map.indexX(rock.x) + map.indexZ(rock.z) });
            }
            for (const bld of map.buildings) {
                allObjs.push({ type: 'building', data: bld, depth: map.indexX(bld.x) + map.indexZ(bld.z) });
            }
            for (const enemy of map.enemies) {
                allObjs.push({ type: 'enemy', data: enemy, depth: map.indexX(enemy.x) + map.indexZ(enemy.z) });
            }
            for (const plane of map.planes) {
                allObjs.push({ type: 'plane', data: plane, depth: map.indexX(plane.x) + map.indexZ(plane.z) });
            }
            allObjs.sort((a, b) => a.depth - b.depth);

            // Biome-dependent tree/rock colors
            const treeColors = {
                temperate: { trunk: '#5D4037', canopy: '#27AE60' },
                snow:      { trunk: '#3E2723', canopy: '#1A6B3A' },
                desert:    { trunk: '#2D8B3E', canopy: '#2D8B3E' },
                rocky:     { trunk: '#4E342E', canopy: '#5D4037' },
            };
            const rockColors = {
                temperate: '#7f8c8d', snow: '#6B7B8D', desert: '#B8886B', rocky: '#3D3835',
            };
            const tc = treeColors[terrainType] || treeColors.temperate;
            const rc = rockColors[terrainType] || rockColors.temperate;

            for (const obj of allObjs) {
                const d = obj.data;
                const oix = map.indexX(d.x);
                const oiz = map.indexZ(d.z);
                const bH = Math.max(map.getHeight(oix, oiz), map.waterLevel);
                const { fx, fz } = this.worldToFGrid(d.x, d.z);

                switch (obj.type) {
                    case 'tree': {
                        const h = d.height || 2.5;
                        if (terrainType === 'desert') {
                            // Cactus — single tall column
                            this.drawIsoBox(fx, fz, 0.4, h, 0.4, tc.trunk, bH);
                        } else if (terrainType === 'rocky') {
                            // Dead tree — thin trunk only
                            this.drawIsoBox(fx, fz, 0.2, h * 0.7, 0.2, tc.trunk, bH);
                        } else {
                            // Trunk
                            this.drawIsoBox(fx, fz, 0.3, h * 0.35, 0.3, tc.trunk, bH);
                            // Canopy
                            const cw = h * 0.55;
                            this.drawIsoBox(fx, fz, cw, h * 0.55, cw, tc.canopy, bH + h * 0.35);
                        }
                        break;
                    }

                    case 'rock': {
                        const s = d.scale || 1.0;
                        this.drawIsoBox(fx, fz, s * 1.0, s * 0.35, s * 0.85, rc, bH);
                        break;
                    }

                    case 'building': {
                        const style = BUILDING_STYLES[d.type] || BUILDING_STYLES.house;
                        switch (d.type) {
                            case 'house':
                                this.drawIsoBox(fx, fz, 2.0, 1.6, 2.4, '#c4a882', bH);
                                this.drawIsoBox(fx, fz, 2.2, 0.7, 2.6, '#8B4513', bH + 1.6);
                                break;
                            case 'office':
                                this.drawIsoBox(fx, fz, 3.0, 4.0, 2.5, '#7f8fa6', bH);
                                // Windows
                                this.drawIsoBox(fx, fz, 3.05, 0.3, 2.55, '#4a6080', bH + 1.5);
                                this.drawIsoBox(fx, fz, 3.05, 0.3, 2.55, '#4a6080', bH + 2.8);
                                break;
                            case 'skyscraper':
                                this.drawIsoBox(fx, fz, 3.0, 2.5, 3.0, '#546e8a', bH);
                                this.drawIsoBox(fx, fz, 2.5, 7.5, 2.5, '#6888a8', bH + 2.5);
                                // Antenna
                                this.drawIsoBox(fx, fz, 0.2, 1.0, 0.2, '#aaa', bH + 10.0);
                                break;
                            case 'warehouse':
                                this.drawIsoBox(fx, fz, 4.0, 2.0, 3.0, '#a09080', bH);
                                // Roof ridge
                                this.drawIsoBox(fx, fz, 1.0, 0.5, 3.2, '#887868', bH + 2.0);
                                break;
                            case 'tower':
                                this.drawIsoBox(fx, fz, 1.6, 1.2, 1.6, '#6c7a7a', bH);
                                this.drawIsoBox(fx, fz, 1.1, 4.0, 1.1, '#5a6868', bH + 1.2);
                                this.drawIsoBox(fx, fz, 2.0, 0.2, 2.0, '#8a9a9a', bH + 5.2);
                                break;
                        }
                        if (this.zoom >= 2) this.drawIsoLabel(d.x, d.z, {
                            house: 2.3, office: 4.0, skyscraper: 11.0, warehouse: 2.5, tower: 5.4
                        }[d.type] || 3, style.label, '#fff');
                        break;
                    }

                    case 'enemy': {
                        const style = ENEMY_STYLES[d.type] || ENEMY_STYLES.tank;
                        switch (d.type) {
                            case 'tank':
                                this.drawIsoBox(fx, fz, 0.9, 0.25, 1.4, '#4a5e3a', bH);
                                this.drawIsoBox(fx, fz, 0.55, 0.2, 0.55, '#3a4e2a', bH + 0.25);
                                // Barrel
                                this.drawIsoBox(fx, fz, 0.1, 0.1, 0.8, '#333', bH + 0.35);
                                break;
                            case 'aaGun':
                                // Sandbag base
                                this.drawIsoBox(fx, fz, 1.2, 0.3, 1.2, '#8a7a60', bH);
                                // Gun mount
                                this.drawIsoBox(fx, fz, 0.3, 0.4, 0.3, '#555', bH + 0.3);
                                // Twin barrels pointing up
                                this.drawIsoBox(fx, fz, 0.3, 0.6, 0.08, '#444', bH + 0.5);
                                break;
                            case 'samLauncher':
                                // Truck body (2x scale)
                                this.drawIsoBox(fx, fz, 2.4, 0.5, 4.0, '#4a5540', bH);
                                // Launch rail
                                this.drawIsoBox(fx, fz, 0.3, 0.15, 3.2, '#666', bH + 0.5);
                                // Missile
                                this.drawIsoBox(fx, fz, 0.15, 0.15, 1.4, '#ddd', bH + 0.65);
                                break;
                            case 'truck':
                                // Cargo bed
                                this.drawIsoBox(fx, fz, 1.0, 0.15, 1.4, '#3a5a3a', bH + 0.15);
                                // Cab
                                this.drawIsoBox(fx, fz, 0.9, 0.5, 0.7, '#3a5a8a', bH + 0.15);
                                // Cargo tarp
                                this.drawIsoBox(fx, fz, 0.85, 0.45, 1.2, '#5a7a4a', bH + 0.3);
                                break;
                            case 'radioTower':
                                this.drawIsoBox(fx, fz, 0.15, 3.5, 0.15, '#888', bH);
                                // Dish
                                this.drawIsoBox(fx, fz, 0.5, 0.08, 0.5, '#bbb', bH + 3.0);
                                // Antenna spike
                                this.drawIsoBox(fx, fz, 0.06, 0.6, 0.06, '#999', bH + 3.5);
                                break;
                            case 'building':
                                this.drawIsoBox(fx, fz, 2.0, 1.8, 2.0, '#95a5a6', bH);
                                break;
                            default:
                                this.drawIsoBox(fx, fz, 1.0, 0.5, 1.0, style.color, bH);
                                break;
                        }
                        if (this.zoom >= 2) {
                            const labelH = { tank: 0.6, aaGun: 1.0, samLauncher: 1.0, truck: 0.9, radioTower: 4.2, building: 2.0 };
                            this.drawIsoLabel(d.x, d.z, labelH[d.type] || 1.0, style.label, style.color);
                        }
                        break;
                    }

                    case 'plane': {
                        const pos = this.worldToCanvas(d.x, d.z);
                        const style = PLANE_STYLES[d.type] || PLANE_STYLES.fighter;
                        const sz = Math.max(6, cs * 0.8);

                        // Dashed trigger line across map width in isometric
                        ctx.save();
                        ctx.strokeStyle = style.color + '40';
                        ctx.lineWidth = 1;
                        ctx.setLineDash([4, 4]);
                        const pIZ = map.indexZ(d.z);
                        const tl0 = this.isoProject(0, pIZ, 0);
                        const tl1 = this.isoProject(map.segmentsX, pIZ, 0);
                        ctx.beginPath();
                        ctx.moveTo(tl0.x, tl0.y);
                        ctx.lineTo(tl1.x, tl1.y);
                        ctx.stroke();
                        ctx.setLineDash([]);
                        ctx.restore();

                        // Triangle pointing in flight direction (along iz)
                        const izD0 = this.isoProject(0, 0, 0);
                        const izD1 = this.isoProject(0, 1, 0);
                        const dxx = izD1.x - izD0.x;
                        const dyy = izD1.y - izD0.y;
                        const dLen = Math.sqrt(dxx * dxx + dyy * dyy);
                        const nx = dxx / dLen, ny = dyy / dLen;
                        const perpX = -ny, perpY = nx;
                        ctx.fillStyle = style.color;
                        ctx.beginPath();
                        ctx.moveTo(pos.x + nx * sz * 0.6, pos.y + ny * sz * 0.6);
                        ctx.lineTo(pos.x - nx * sz * 0.5 + perpX * sz * 0.5, pos.y - ny * sz * 0.5 + perpY * sz * 0.5);
                        ctx.lineTo(pos.x - nx * sz * 0.5 - perpX * sz * 0.5, pos.y - ny * sz * 0.5 - perpY * sz * 0.5);
                        ctx.closePath();
                        ctx.fill();
                        ctx.strokeStyle = '#fff';
                        ctx.lineWidth = 1;
                        ctx.stroke();

                        if (d.count > 1) {
                            ctx.fillStyle = '#fff';
                            ctx.font = `bold ${Math.max(7, cs * 0.4)}px monospace`;
                            ctx.textAlign = 'left';
                            ctx.textBaseline = 'middle';
                            ctx.fillText('\u00d7' + d.count, pos.x + sz * 0.7, pos.y);
                        }
                        if (this.zoom >= 3) {
                            ctx.fillStyle = '#fff';
                            ctx.font = `${Math.max(8, cs * 0.5)}px monospace`;
                            ctx.textAlign = 'center';
                            ctx.textBaseline = 'top';
                            ctx.fillText(style.label, pos.x, pos.y + sz * 0.6 + 1);
                        }
                        break;
                    }
                }
            }
        }

        // Brush preview (isometric diamond)
        if (this.mouseGrid && ['raise', 'lower', 'smooth', 'eraser'].includes(this.tool)) {
            const mg = this.mouseGrid;
            const hHere = map.getHeight(
                Math.max(0, Math.min(mg.ix, map.segmentsX)),
                Math.max(0, Math.min(mg.iz, map.segmentsZ))
            );
            const r = this.brushSize;
            ctx.strokeStyle = 'rgba(233, 69, 96, 0.7)';
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            const bTop = this.isoProject(mg.ix - r, mg.iz, hHere);
            const bRight = this.isoProject(mg.ix, mg.iz + r, hHere);
            const bBottom = this.isoProject(mg.ix + r, mg.iz, hHere);
            const bLeft = this.isoProject(mg.ix, mg.iz - r, hHere);
            ctx.moveTo(bTop.x, bTop.y);
            ctx.lineTo(bRight.x, bRight.y);
            ctx.lineTo(bBottom.x, bBottom.y);
            ctx.lineTo(bLeft.x, bLeft.y);
            ctx.closePath();
            ctx.stroke();
        }

        // Placement cursor preview
        if (this.mouseGrid && ['tree', 'rock', 'enemy', 'plane', 'building'].includes(this.tool)) {
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
            `Buildings: ${this.map.buildings.length}<br>` +
            `Enemies: ${this.map.enemies.length}<br>` +
            `Planes: ${this.map.planes.length}`;
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
        map.planes = map.planes.filter(p => p.z <= map.lengthZ);

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

    clearMap() {
        if (!confirm('Clear the entire map? This will remove all objects and flatten terrain.\n\n(Map settings like name, size, and terrain type are preserved.)')) return;
        this.saveUndo();
        const map = this.map;
        for (let iz = 0; iz <= map.segmentsZ; iz++) {
            map.heightmap[iz].fill(0);
        }
        map.trees = [];
        map.rocks = [];
        map.buildings = [];
        map.enemies = [];
        map.planes = [];
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
                buildings: map.buildings.map(b => ({
                    x: Math.round(b.x * 100) / 100,
                    z: Math.round(b.z * 100) / 100,
                    type: b.type,
                    rotation: b.rotation || 0,
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
            planeTriggers: map.planes.map(p => ({
                type: p.type,
                x: Math.round(p.x * 100) / 100,
                z: Math.round(p.z * 100) / 100,
                count: p.count || 1,
            })),
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
            buildingCount: this.map.buildings.length,
            planeCount: this.map.planes.length,
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
        this.map.buildings = data.objects?.buildings || [];
        this.map.enemies = data.enemies || [];
        this.map.planes = data.planeTriggers || [];

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
