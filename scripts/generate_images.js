// Generates a handful of simple flat-design PNG images used as bundled
// jigsaw puzzle pictures, using only Node's built-in zlib (no deps, no
// network access, no external assets/licensing concerns).
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const WIDTH = 800;
const HEIGHT = 600;
const OUT_DIR = path.join(__dirname, '..', 'app', 'assets', 'images');

function crc32(buf) {
  let c;
  const table = crc32.table || (crc32.table = (() => {
    const t = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
      c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      t[n] = c >>> 0;
    }
    return t;
  })());
  let crc = 0xffffffff;
  for (let i = 0; i < buf.length; i++) crc = table[(crc ^ buf[i]) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type, 'ascii');
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
  return Buffer.concat([len, typeBuf, data, crc]);
}

function encodePng(width, height, rgbBuffer) {
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 2; // color type: RGB
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;

  // add filter byte (0 = none) per scanline
  const stride = width * 3;
  const raw = Buffer.alloc((stride + 1) * height);
  for (let y = 0; y < height; y++) {
    raw[y * (stride + 1)] = 0;
    rgbBuffer.copy(raw, y * (stride + 1) + 1, y * stride, y * stride + stride);
  }
  const idat = zlib.deflateSync(raw, { level: 9 });

  return Buffer.concat([
    signature,
    chunk('IHDR', ihdr),
    chunk('IDAT', idat),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

function setPx(buf, w, x, y, r, g, b) {
  if (x < 0 || x >= w || y < 0) return;
  const idx = (y * w + x) * 3;
  buf[idx] = r; buf[idx + 1] = g; buf[idx + 2] = b;
}

function lerp(a, b, t) { return a + (b - a) * t; }

function mixColor(c1, c2, t) {
  return [
    Math.round(lerp(c1[0], c2[0], t)),
    Math.round(lerp(c1[1], c2[1], t)),
    Math.round(lerp(c1[2], c2[2], t)),
  ];
}

function fillCircle(buf, w, h, cx, cy, r, color) {
  const r2 = r * r;
  for (let y = Math.max(0, cy - r); y < Math.min(h, cy + r); y++) {
    for (let x = Math.max(0, cx - r); x < Math.min(w, cx + r); x++) {
      const dx = x - cx; const dy = y - cy;
      if (dx * dx + dy * dy <= r2) setPx(buf, w, x, y, ...color);
    }
  }
}

function fillTriangle(buf, w, h, x1, y1, x2, y2, x3, y3, color) {
  const minY = Math.max(0, Math.min(y1, y2, y3));
  const maxY = Math.min(h, Math.max(y1, y2, y3));
  const sign = (px, py, ax, ay, bx, by) => (px - bx) * (ay - by) - (ax - bx) * (py - by);
  for (let y = minY; y < maxY; y++) {
    for (let x = 0; x < w; x++) {
      const d1 = sign(x, y, x1, y1, x2, y2);
      const d2 = sign(x, y, x2, y2, x3, y3);
      const d3 = sign(x, y, x3, y3, x1, y1);
      const hasNeg = d1 < 0 || d2 < 0 || d3 < 0;
      const hasPos = d1 > 0 || d2 > 0 || d3 > 0;
      if (!(hasNeg && hasPos)) setPx(buf, w, x, y, ...color);
    }
  }
}

function verticalGradient(buf, w, h, topColor, bottomColor) {
  for (let y = 0; y < h; y++) {
    const t = y / (h - 1);
    const [r, g, b] = mixColor(topColor, bottomColor, t);
    for (let x = 0; x < w; x++) setPx(buf, w, x, y, r, g, b);
  }
}

function makeSunset() {
  const buf = Buffer.alloc(WIDTH * HEIGHT * 3);
  verticalGradient(buf, WIDTH, HEIGHT, [255, 145, 95], [120, 45, 110]);
  fillCircle(buf, WIDTH, HEIGHT, 560, 220, 90, [255, 226, 140]);
  // rolling hills silhouette
  fillTriangle(buf, WIDTH, HEIGHT, -50, HEIGHT, 300, 330, 650, HEIGHT, [70, 40, 70]);
  fillTriangle(buf, WIDTH, HEIGHT, 150, HEIGHT, 520, 400, 900, HEIGHT, [40, 20, 50]);
  return buf;
}

function makeOcean() {
  const buf = Buffer.alloc(WIDTH * HEIGHT * 3);
  verticalGradient(buf, WIDTH, HEIGHT, [135, 206, 250], [10, 90, 140]);
  for (let i = 0; i < 6; i++) {
    const y = 260 + i * 45;
    for (let x = 0; x < WIDTH; x++) {
      const wave = Math.sin((x + i * 40) * 0.03) * 8;
      const yy = Math.round(y + wave);
      for (let t = 0; t < 4; t++) setPx(buf, WIDTH, x, yy + t, 255, 255, 255);
    }
  }
  fillCircle(buf, WIDTH, HEIGHT, 120, 110, 70, [255, 250, 210]);
  return buf;
}

function makeForest() {
  const buf = Buffer.alloc(WIDTH * HEIGHT * 3);
  verticalGradient(buf, WIDTH, HEIGHT, [180, 230, 200], [230, 240, 200]);
  const treeColors = [[46, 110, 64], [34, 90, 52], [58, 130, 76]];
  for (let i = 0; i < 9; i++) {
    const cx = 40 + i * 95;
    const baseY = HEIGHT - 60;
    const color = treeColors[i % treeColors.length];
    fillTriangle(buf, WIDTH, HEIGHT, cx - 70, baseY, cx + 70, baseY, cx, baseY - 260, color);
    fillTriangle(buf, WIDTH, HEIGHT, cx - 55, baseY - 90, cx + 55, baseY - 90, cx, baseY - 320, color);
  }
  return buf;
}

function makeMountain() {
  const buf = Buffer.alloc(WIDTH * HEIGHT * 3);
  verticalGradient(buf, WIDTH, HEIGHT, [190, 225, 245], [235, 245, 250]);
  fillTriangle(buf, WIDTH, HEIGHT, -50, HEIGHT, 260, 120, 560, HEIGHT, [120, 130, 150]);
  fillTriangle(buf, WIDTH, HEIGHT, 200, HEIGHT, 470, 60, 820, HEIGHT, [90, 100, 125]);
  // snow caps
  fillTriangle(buf, WIDTH, HEIGHT, 220, 190, 260, 120, 300, 190, [255, 255, 255]);
  fillTriangle(buf, WIDTH, HEIGHT, 430, 140, 470, 60, 510, 140, [255, 255, 255]);
  return buf;
}

const images = {
  sunset: makeSunset,
  ocean: makeOcean,
  forest: makeForest,
  mountain: makeMountain,
};

fs.mkdirSync(OUT_DIR, { recursive: true });
for (const [name, gen] of Object.entries(images)) {
  const buf = gen();
  const png = encodePng(WIDTH, HEIGHT, buf);
  const outPath = path.join(OUT_DIR, `${name}.png`);
  fs.writeFileSync(outPath, png);
  console.log('Wrote', outPath, `(${png.length} bytes)`);
}
