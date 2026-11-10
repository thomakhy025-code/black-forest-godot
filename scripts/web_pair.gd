extends RefCounted
## Pairs two website players through the public PeerJS broker.
## The first browser to claim a free room is the host. The next one joins it.
## No address is typed. Desktop builds never call the JavaScript bridge.

static var _booted := false

const BOOT := """
window.__bf = window.__bf || {role:'', status:'search', inbox:[], open:false, peer:null, conn:null, fast:null, fastOpen:false, pendingSnap:'', roomPeer:'', busy:false, gen:0, passes:0, waitTimer:0, helloTimer:0, paired:false, down:0, blocked:0, badBrowser:false};
window.bfCloud = {secure:true, host:'0.peerjs.com', port:443};
window.bfStop = function(silent) {
  var box = window.__bf;
  box.gen += 1;
  if (box.waitTimer) { clearTimeout(box.waitTimer); box.waitTimer = 0; }
  if (box.helloTimer) { clearInterval(box.helloTimer); box.helloTimer = 0; }
  box.open = false;
  box.busy = false;
  box.paired = false;
  box.role = '';
  box.pendingSnap = '';
  box.roomPeer = '';
  box.fastOpen = false;
  if (box.fast) { try { box.fast.close(); } catch (e0) {} }
  box.fast = null;
  if (box.conn) { try { box.conn.close(); } catch (e) {} }
  if (box.peer) { try { box.peer.destroy(); } catch (e) {} }
  box.conn = null;
  box.peer = null;
  box.inbox = [];
  if (!silent) box.status = 'closed';
};
window.bfSend = function(s) {
  var box = window.__bf;
  if (!box || !box.conn || !box.open) return;
  var payload = s;
  try { payload = JSON.parse(s); } catch (e) {}
  try { box.conn.send(payload); } catch (e2) {}
};
window.bfState = function() {
  window.bfFlush();
  var box = window.__bf;
  if (!box) return 'missing<<S>><<S>>0<<S>>';
  var lines = box.inbox;
  box.inbox = [];
  return box.status + '<<S>>' + box.role + '<<S>>' + (box.open ? '1' : '0') + '<<S>>' + lines.join('<<NL>>');
};
window.bfIsSnap = function(line) {
  return line.indexOf('"t":"snap"') !== -1 || line.indexOf('"t": "snap"') !== -1;
};
window.bfPush = function(d) {
  var line = typeof d === 'string' ? d : JSON.stringify(d);
  if (!line) return;
  var box = window.__bf;
  if (window.bfIsSnap(line)) {
    var kept = [];
    for (var i = 0; i < box.inbox.length; i++) {
      if (!window.bfIsSnap(box.inbox[i])) kept.push(box.inbox[i]);
    }
    kept.push(line);
    box.inbox = kept;
    return;
  }
  box.inbox.push(line);
};
window.bfWaiting = function(conn) {
  if (!conn) return 999999;
  try {
    var dc = conn.dataChannel || conn._dc;
    if (dc && typeof dc.bufferedAmount === 'number') return dc.bufferedAmount;
  } catch (e) {}
  if (typeof conn.bufferSize === 'number') return conn.bufferSize;
  return 0;
};
window.bfSendFast = function(s) {
  var box = window.__bf;
  var conn = (box && box.fast && box.fastOpen) ? box.fast : null;
  if (!conn) { window.bfSend(s); return; }
  var payload = s;
  try { payload = JSON.parse(s); } catch (e) {}
  try { conn.send(payload); } catch (e2) { window.bfSend(s); }
};
window.bfNoteSnap = function(b64) {
  if (!window.__bf) return;
  window.__bf.pendingSnap = b64;
  window.bfFlush();
};
window.bfFlush = function() {
  var box = window.__bf;
  if (!box || !box.pendingSnap) return;
  var conn = (box.fast && box.fastOpen) ? box.fast : box.conn;
  if (!conn) return;
  if (conn === box.conn && !box.open) return;
  if (conn === box.fast && !box.fastOpen) return;
  if (window.bfWaiting(conn) > 1200) return;
  var body = box.pendingSnap;
  box.pendingSnap = '';
  try { conn.send({t:'snap', b:body}); }
  catch (e) { box.pendingSnap = body; }
};
window.bfTakeFast = function(conn) {
  var box = window.__bf;
  if (box.fast && box.fast !== conn) { try { box.fast.close(); } catch (e) {} }
  box.fast = conn;
  box.fastOpen = false;
  conn.on('data', function(d) { window.bfPush(d); });
  conn.on('open', function() { if (window.__bf.fast === conn) window.__bf.fastOpen = true; });
  conn.on('close', function() {
    if (window.__bf.fast !== conn) return;
    window.__bf.fast = null;
    window.__bf.fastOpen = false;
  });
  conn.on('error', function() { if (window.__bf.fast === conn) window.__bf.fastOpen = false; });
  if (conn.open) box.fastOpen = true;
};
window.bfOpenFast = function() {
  var box = window.__bf;
  if (!box.peer || !box.roomPeer || box.fast) return;
  var conn = box.peer.connect(box.roomPeer, {reliable:false, serialization:'json', label:'fast', metadata:{ch:'fast'}});
  window.bfTakeFast(conn);
};
window.bfEnsure = function(done) {
  if (typeof Peer !== 'undefined') { done(); return; }
  if (window.__bfFailed) { window.__bf.status = 'missing'; return; }
  if (window.__bfLoading) {
    var wait = setInterval(function() {
      if (typeof Peer !== 'undefined') { clearInterval(wait); done(); }
      else if (window.__bfFailed) { clearInterval(wait); window.__bf.status = 'missing'; }
    }, 100);
    return;
  }
  window.__bfLoading = true;
  var tag = document.createElement('script');
  tag.src = 'https://unpkg.com/peerjs@1.5.4/dist/peerjs.min.js';
  tag.onload = function() { done(); };
  tag.onerror = function() { window.__bfFailed = true; window.__bf.status = 'missing'; };
  document.head.appendChild(tag);
};
window.bfRelease = function() {
  var box = window.__bf;
  if (box.waitTimer) { clearTimeout(box.waitTimer); box.waitTimer = 0; }
  box.open = false;
  box.role = '';
  if (box.conn) { try { box.conn.close(); } catch (e) {} }
  if (box.peer) { try { box.peer.destroy(); } catch (e2) {} }
  box.conn = null;
  box.peer = null;
};
window.bfWire = function(conn, gen, asHost) {
  var box = window.__bf;
  if (box.conn) { try { conn.close(); } catch (e) {} return false; }
  box.conn = conn;
  conn.on('data', function(d) {
    if (gen !== window.__bf.gen) return;
    window.__bf.paired = true;
    if (window.__bf.helloTimer) { clearInterval(window.__bf.helloTimer); window.__bf.helloTimer = 0; }
    window.bfPush(d);
  });
  conn.on('close', function() {
    if (gen !== window.__bf.gen || window.__bf.conn !== conn) return;
    var paired = window.__bf.paired;
    window.__bf.conn = null;
    window.__bf.open = false;
    if (window.__bf.helloTimer) { clearInterval(window.__bf.helloTimer); window.__bf.helloTimer = 0; }
    if (paired) window.__bf.status = 'closed';
  });
  conn.on('error', function() {
    if (gen !== window.__bf.gen) return;
    if (!window.__bf.open) window.__bf.blocked += 1;
  });
  if (asHost) {
    var greet = function() {
      if (gen !== window.__bf.gen || window.__bf.conn !== conn) return;
      window.__bf.open = true;
      if (window.__bf.waitTimer) { clearTimeout(window.__bf.waitTimer); window.__bf.waitTimer = 0; }
      if (window.__bf.helloTimer) clearInterval(window.__bf.helloTimer);
      window.__bf.helloTimer = setInterval(function() {
        if (gen !== window.__bf.gen || window.__bf.paired || window.__bf.conn !== conn) {
          clearInterval(window.__bf.helloTimer);
          window.__bf.helloTimer = 0;
          return;
        }
        try { conn.send({t:'hello'}); } catch (e) {}
      }, 400);
      try { conn.send({t:'hello'}); } catch (e2) {}
    };
    conn.on('open', greet);
    if (conn.open) greet();
  }
  return true;
};
window.bfGuest = function(gen, room, waitMs, done) {
  if (gen !== window.__bf.gen) return;
  var peer = new Peer(window.bfCloud);
  var settled = false;
  var timer = setTimeout(function() { finish('fail'); }, 8000);
  function finish(result) {
    if (settled || gen !== window.__bf.gen) return;
    settled = true;
    clearTimeout(timer);
    if (result !== 'joined') {
      try { peer.destroy(); } catch (e) {}
    }
    done(result);
  }
  peer.on('open', function() {
    if (settled || gen !== window.__bf.gen) return;
    clearTimeout(timer);
    var conn = peer.connect('blackforest' + room, {reliable:true, serialization:'json'});
    timer = setTimeout(function() { finish('fail'); }, waitMs);
    conn.on('data', function(d) {
      if (settled || gen !== window.__bf.gen) return;
      if (!window.bfWire(conn, gen, false)) { finish('fail'); return; }
      window.__bf.peer = peer;
      window.__bf.roomPeer = conn.peer;
      window.__bf.open = true;
      window.__bf.role = 'guest';
      window.__bf.status = 'guest';
      window.__bf.paired = true;
      window.bfPush(d);
      window.bfOpenFast();
      finish('joined');
    });
    conn.on('close', function() { finish('fail'); });
    conn.on('error', function() { finish('fail'); });
  });
  peer.on('error', function(err) {
    if (settled || gen !== window.__bf.gen) return;
    var kind = err && err.type ? err.type : '';
    if (kind === 'browser-incompatible') { window.__bf.status = 'error'; window.__bf.badBrowser = true; finish('fail'); return; }
    if (kind === 'peer-unavailable') { finish('empty'); return; }
    window.__bf.down += 1;
    finish('fail');
  });
};
window.bfHost = function(gen, room, done) {
  if (gen !== window.__bf.gen) return;
  var peer = new Peer('blackforest' + room, window.bfCloud);
  var settled = false;
  function finish(ok) {
    if (settled || gen !== window.__bf.gen) return;
    settled = true;
    clearTimeout(timer);
    if (!ok) {
      try { peer.destroy(); } catch (e) {}
    }
    done(ok);
  }
  var timer = setTimeout(function() { finish(false); }, 5000);
  peer.on('open', function() {
    if (settled || gen !== window.__bf.gen) { try { peer.destroy(); } catch (e) {} return; }
    settled = true;
    clearTimeout(timer);
    window.__bf.peer = peer;
    window.__bf.role = 'host';
    window.__bf.status = 'host';
    peer.on('connection', function(conn) {
      if (gen !== window.__bf.gen) { try { conn.close(); } catch (e) {} return; }
      var meta = conn.metadata || {};
      if (conn.label === 'fast' || meta.ch === 'fast') { window.bfTakeFast(conn); return; }
      if (window.__bf.busy || window.__bf.conn) { try { conn.close(); } catch (e2) {} return; }
      window.bfWire(conn, gen, true);
    });
    peer.on('disconnected', function() {
      if (gen !== window.__bf.gen || window.__bf.conn) return;
      try { peer.reconnect(); } catch (e) { window.__bf.status = 'error'; }
    });
    done(true);
  });
  peer.on('error', function(err) {
    if (settled || gen !== window.__bf.gen) return;
    var kind = err && err.type ? err.type : '';
    if (kind === 'browser-incompatible') { window.__bf.status = 'error'; window.__bf.badBrowser = true; }
    else if (kind === 'unavailable-id' || kind === 'peer-unavailable') window.__bf.blocked += 1;
    else window.__bf.down += 1;
    finish(false);
  });
};
window.bfSeek = function(gen, room) {
  if (gen !== window.__bf.gen || window.__bf.badBrowser) return;
  if (room > 4) {
    window.__bf.passes += 1;
    if (window.__bf.passes < 3) { window.bfSeek(gen, 1); return; }
    window.__bf.status = (window.__bf.down > 0 && window.__bf.blocked === 0) ? 'error' : 'busy';
    return;
  }
  window.bfGuest(gen, room, 10000, function(result) {
    if (result === 'joined' || gen !== window.__bf.gen || window.__bf.badBrowser) return;
    window.bfHost(gen, room, function(hosted) {
      if (hosted || gen !== window.__bf.gen || window.__bf.badBrowser) return;
      window.bfGuest(gen, room, 15000, function(again) {
        if (again === 'joined' || gen !== window.__bf.gen || window.__bf.badBrowser) return;
        window.bfSeek(gen, room + 1);
      });
    });
  });
};
window.bfFind = function() {
  window.bfStop(true);
  var gen = window.__bf.gen;
  window.__bf.status = 'search';
  window.__bf.role = '';
  window.__bf.open = false;
  window.__bf.busy = false;
  window.__bf.passes = 0;
  window.__bf.down = 0;
  window.__bf.blocked = 0;
  window.__bf.badBrowser = false;
  window.__bf.paired = false;
  window.__bf.pendingSnap = '';
  window.__bf.roomPeer = '';
  window.__bf.fastOpen = false;
  if (window.__bf.fast) { try { window.__bf.fast.close(); } catch (e3) {} }
  window.__bf.fast = null;
  if (window.__bf.helloTimer) { clearInterval(window.__bf.helloTimer); window.__bf.helloTimer = 0; }
  window.__bf.inbox = [];
  window.bfEnsure(function() {
    if (gen !== window.__bf.gen) return;
    if (typeof Peer === 'undefined') { window.__bf.status = 'missing'; return; }
    window.bfSeek(gen, 1);
  });
};
window.bfFind();
"""


static func start() -> void:
	var bridge = _bridge()
	if bridge == null:
		return
	if not _booted:
		_booted = true
		bridge.call("eval", BOOT, true)
		return
	bridge.call("eval", "bfFind()", true)


static func stop() -> void:
	var bridge = _bridge()
	if bridge == null or not _booted:
		return
	bridge.call("eval", "bfStop()", true)


static func mark_busy() -> void:
	var bridge = _bridge()
	if bridge == null or not _booted:
		return
	bridge.call("eval", "if(window.__bf)window.__bf.busy=true;", true)


static func send_text(text: String) -> void:
	var bridge = _bridge()
	if bridge == null or not _booted or text == "":
		return
	bridge.call("eval", "bfSend(" + JSON.stringify(text) + ")", true)


static func send_fast(text: String) -> void:
	var bridge = _bridge()
	if bridge == null or not _booted or text == "":
		return
	bridge.call("eval", "bfSendFast(" + JSON.stringify(text) + ")", true)


static func send_snap(blob: PackedByteArray) -> void:
	var bridge = _bridge()
	if bridge == null or not _booted or blob.is_empty():
		return
	bridge.call("eval", "bfNoteSnap(" + JSON.stringify(Marshalls.raw_to_base64(blob)) + ")", true)


static func poll() -> Dictionary:
	var empty := {"status": "missing", "role": "", "open": false, "lines": []}
	var bridge = _bridge()
	if bridge == null or not _booted:
		return empty
	var raw = bridge.call("eval", "bfState()", true)
	var text := str(raw)
	if text == "" or text == "null" or text == "<null>":
		return empty
	var parts := text.split("<<S>>", true, 3)
	while parts.size() < 4:
		parts.append("")
	var lines: Array = []
	if str(parts[3]) != "":
		for line in str(parts[3]).split("<<NL>>"):
			if line != "":
				lines.append(line)
	return {
		"status": str(parts[0]),
		"role": str(parts[1]),
		"open": str(parts[2]) == "1",
		"lines": lines,
	}


static func _bridge():
	if not OS.has_feature("web"):
		return null
	return Engine.get_singleton("JavaScriptBridge")
