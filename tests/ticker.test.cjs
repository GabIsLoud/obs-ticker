const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const repo = path.resolve(__dirname, '..');
const html = fs.readFileSync(path.join(repo, 'index.html'), 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
const manifest = JSON.parse(fs.readFileSync(path.join(repo, 'games.json'), 'utf8'));

function harness(query = '') {
  const css = Object.fromEntries([...html.matchAll(/(--\w+):\s*([^;]+);/g)].map(m => [m[1], m[2]]));
  const frames = new Map();
  const timers = new Map();
  const requests = [];
  let id = 0;
  function element() {
    const classes = new Set();
    return {
      children: [], style: {}, dataset: {}, attributes: {}, hidden: false,
      classList: { add: c => classes.add(c), remove: c => classes.delete(c),
        toggle: (c, enabled) => enabled ? classes.add(c) : classes.delete(c), contains: c => classes.has(c) },
      setAttribute(k, v) { this.attributes[k] = v; },
      appendChild(child) { this.children.push(child); },
      addEventListener() {}, cloneNode: element,
      getBoundingClientRect: () => ({ width: 100 }),
      set innerHTML(value) { this.children = []; }
    };
  }
  const root = element(), track = element(), picker = element();
  const context = {
    URLSearchParams, location: { search: query }, window: {}, console,
    document: {
      getElementById: key => ({ tickerRoot: root, track, presetPicker: picker })[key],
      documentElement: { style: { setProperty: (k, v) => { css[k] = String(v); } } },
      createElement: element, querySelectorAll: () => [], head: element()
    },
    getComputedStyle: () => ({ getPropertyValue: k => css[k] || '' }),
    addEventListener() {},
    requestAnimationFrame: fn => { frames.set(++id, fn); return id; },
    cancelAnimationFrame: key => frames.delete(key),
    setTimeout: fn => { timers.set(++id, fn); return id; },
    clearTimeout: key => timers.delete(key),
    fetch: url => new Promise((resolve, reject) => requests.push({ url, resolve, reject }))
  };
  vm.runInNewContext(script, context);
  return {
    api: context.window.OBSTicker, css, root, track, picker, requests, frames, timers,
    frame(time) { const jobs = [...frames.values()]; frames.clear(); jobs.forEach(fn => fn(time)); },
    respond(index, value, json = false) {
      requests[index].resolve({ ok: true, json: async () => value, text: async () => value });
    }
  };
}

async function flush() { for (let i = 0; i < 12; i++) await Promise.resolve(); }
async function start(query = '') {
  const h = harness(query);
  h.respond(0, manifest, true);
  await flush();
  return h;
}

test('manifest references existing, nonempty assets and unique keys', () => {
  const keys = manifest.games.map(g => g.key.toLowerCase().replace(/[^a-z0-9]+/g, ''));
  assert.equal(new Set(keys).size, keys.length);
  for (const game of manifest.games) {
    assert.ok(game.label);
    for (const file of [game.src, game.logo]) assert.ok(fs.statSync(path.join(repo, file)).size > 0, file);
  }
});

test('picker retains intended defaults and explicit zero padding', async () => {
  const h = await start();
  assert.equal(h.css['--size'], '30');
  assert.equal(h.css['--paddingY'], '6');
  assert.equal(h.css['--paddingX'], '16');
  assert.equal(h.css['--gapX'], '14');
  const overridden = await start('?size=999&px=0&py=&gap=invalid');
  assert.equal(overridden.css['--size'], '200');
  assert.equal(overridden.css['--paddingX'], '0');
  assert.equal(overridden.css['--paddingY'], '6');
  assert.equal(overridden.css['--gapX'], '14');
});

test('direct source uses bundled logo and only schedules one animation', async () => {
  const h = await start('?src=messages.txt');
  h.respond(1, 'One\nTwo'); await flush();
  assert.equal(h.track.children[0].children[0].src, 'justG.png');
  assert.equal(h.frames.size, 1);
  h.api.next();
  assert.equal(h.frames.size, 1);
});

test('switching presets ignores an older message response', async () => {
  const h = await start('?preset=generic');
  h.api.choosePreset('witcher3');
  h.respond(2, 'New preset'); await flush();
  h.respond(1, 'Old preset'); await flush();
  assert.equal(h.track.children[0].children[1].textContent, 'New preset');
  assert.equal(h.frames.size, 1);
});

test('returning to picker ignores failed requests from previous preset', async () => {
  const h = await start('?preset=generic');
  h.api.showPicker();
  h.requests[1].reject(new Error('Old request failed')); await flush();
  assert.equal(h.frames.size, 0);
  assert.equal(h.track.children.length, 0);
  assert.equal(h.picker.hidden, false);
});

test('picker cancels a pending measurement frame', async () => {
  const h = await start('?preset=generic');
  h.respond(1, 'Message'); await flush();
  h.api.showPicker();
  assert.equal(h.frames.size, 0);
});

test('preset switching cancels collapse timer and restores visibility', async () => {
  const h = await start('?preset=generic');
  h.respond(1, 'Message'); await flush();
  h.frame(1); h.frame(2); h.frame(100000); await flush(); h.frame(100001);
  assert.equal(h.timers.size, 1);
  assert.equal(h.root.classList.contains('isHidden'), true);
  h.api.next(); assert.equal(h.frames.size, 0);
  h.api.choosePreset('witcher3');
  assert.equal(h.timers.size, 0);
  assert.equal(h.root.classList.contains('isHidden'), false);
  assert.equal(h.root.attributes['aria-hidden'], 'false');
});

test('in-flight periodic reload cannot repopulate the picker', async () => {
  const h = await start('?preset=generic&reloadEvery=1');
  h.respond(1, 'Initial message'); await flush();
  assert.equal(h.requests.length, 3);
  h.api.showPicker();
  h.respond(2, 'Stale reload'); await flush();
  h.api.next();
  assert.equal(h.frames.size, 0);
  assert.equal(h.track.children.length, 0);
});
