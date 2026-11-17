#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"
PORT="${PORT:-3000}"
DIST_DIR="$PROJECT_DIR/dist"
export PORT PROJECT_DIR DIST_DIR
export OPENCODE_WEB_DIR="${OPENCODE_WEB_DIR:-/home/runner/work/_temp/omgithub-web}"

run_timed() { /usr/bin/time -p "$@"; }

# This dependency-free static project uses a copy as its build step.
run_timed mkdir -p "$DIST_DIR" "$OPENCODE_WEB_DIR"
run_timed cp "$PROJECT_DIR/index.html" "$DIST_DIR/index.html"
run_timed node -e 'const fs=require("node:fs"),path=require("node:path");const out=path.join(process.env.OPENCODE_WEB_DIR,"deployment-output.json");fs.mkdirSync(path.dirname(out),{recursive:true});fs.writeFileSync(out,JSON.stringify({project:process.env.PROJECT_DIR,directory:process.env.DIST_DIR}))'

# Keep the server in the foreground so the controller owns its lifecycle.
run_timed node -e '
const http=require("node:http"),fs=require("node:fs"),path=require("node:path");
const root=path.resolve(process.env.DIST_DIR),mime={".html":"text/html; charset=utf-8",".js":"text/javascript; charset=utf-8",".css":"text/css; charset=utf-8",".png":"image/png",".jpg":"image/jpeg",".svg":"image/svg+xml"};
http.createServer((req,res)=>{try{const pathname=decodeURIComponent(new URL(req.url,"http://localhost").pathname);let file=path.resolve(root,"."+pathname);if(!file.startsWith(root+path.sep)&&file!==root){res.writeHead(403);return res.end("Forbidden")}if(fs.statSync(file).isDirectory())file=path.join(file,"index.html");res.setHeader("Content-Type",mime[path.extname(file)]||"application/octet-stream");res.setHeader("Cache-Control","no-store");fs.createReadStream(file).on("error",()=>{res.writeHead(404);res.end("Not found")}).pipe(res)}catch{res.writeHead(404);res.end("Not found")}}).listen(Number(process.env.PORT),"0.0.0.0",()=>console.log("Ruínas de Umbra ready on port "+process.env.PORT));
'