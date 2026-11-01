// Headless previews of game art (no Roblox Studio needed). Run from tools/preview after
// `npm install three@0.160.0` (Playwright + Chromium are preinstalled in Claude Code cloud).
//
//   node render.js models out/relics.json out/relics.png   # tools/relic_art_check out/relics.json
//   node render.js models out/suits.json  out/suits.png    # lune run tools/preview/suit_dump
//   node render.js world  '{"pos":[300,-80,-200],"at":[520,-140,-320],"fog":"#2a8aa8","fogStart":40,"fogEnd":420}' out/world.png
//   node render.js icons  out/icons.html  out/icons.png    # lune run tools/preview/icon_sheet
const { chromium } = require('playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');

const [mode, arg, outFile] = process.argv.slice(2);
const root = __dirname;
const server = http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split('?')[0].split('#')[0]);
  fs.readFile(path.join(root, url), (err, data) => {
    if (err) { res.writeHead(404); res.end(); } else res.end(data);
  });
}).listen(0, async () => {
  const port = server.address().port;
  const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  let page;
  if (mode === 'icons') {
    page = await browser.newPage({ viewport: { width: 1200, height: 600 } });
    await page.goto(`http://localhost:${port}/${arg}`);
  } else if (mode === 'world') {
    const view = Object.assign({ w: 900, h: 500, fov: 60, fog: '#2a8aa8', fogStart: 40, fogEnd: 420 }, JSON.parse(arg));
    page = await browser.newPage({ viewport: { width: view.w, height: view.h } });
    await page.goto(`http://localhost:${port}/world.html#` + encodeURIComponent(JSON.stringify(view)));
    await page.waitForFunction(() => document.title === 'done', null, { timeout: 120000 });
  } else {
    page = await browser.newPage({ viewport: { width: 1110, height: 1300 } });
    await page.goto(`http://localhost:${port}/models.html?data=${encodeURIComponent(arg)}`);
    await page.waitForFunction(() => document.title === 'done', null, { timeout: 120000 });
  }
  await page.screenshot({ path: path.join(root, outFile), fullPage: true });
  await browser.close();
  server.close();
  console.log('wrote', outFile);
});
