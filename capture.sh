#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAPTURE_URL="${CAPTURE_URL:?Set CAPTURE_URL to the exact preview URL}"
CAPTURE_DIR="${CAPTURE_DIR:?Set CAPTURE_DIR to an evidence directory}"
export PROJECT_DIR CAPTURE_URL CAPTURE_DIR

run_timed() { /usr/bin/time -p "$@"; }
run_timed mkdir -p "$CAPTURE_DIR"

# Use the worker's configured headed Chromium and close this capture's browser.
run_timed node --input-type=module -e '
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { join } from "node:path";
const runtime=join(process.env.HOME,".local/share/omgithub-playwright");
const require=createRequire(join(runtime,"package.json"));
const {chromium}=require("playwright");
const config=JSON.parse(readFileSync(join(runtime,process.platform==="darwin"?"metal.json":"linux.json"),"utf8"));
if(process.platform==="linux")process.env.DISPLAY||=":"+readFileSync(join(runtime,"display"),"utf8").trim();
const transient=error=>Object.assign(error,{exitCode:75});
let browser;
try {
  browser=await chromium.launch({...config.browser.launchOptions,timeout:30000}).catch(transient);
  for(const [name,width,height] of [["desktop",1280,900],["mobile",390,844]]){
    const page=await browser.newPage({viewport:{width,height},deviceScaleFactor:1}).catch(transient);
    page.setDefaultTimeout(30000);
    const errors=[];
    page.on("pageerror",e=>errors.push(e.message));
    const response=await page.goto(process.env.CAPTURE_URL,{waitUntil:"load",timeout:45000}).catch(transient);
    if(!response?.ok())throw Object.assign(new Error(`Navigation failed: HTTP ${response?.status()}`),{exitCode:!response||[408,429,500,502,503,504].includes(response.status())?75:1});
    try {
      await page.locator("canvas#game").waitFor({state:"visible",timeout:15000});
      await page.waitForFunction(()=>{const c=document.querySelector("canvas#game");return c&&c.width>0&&c.height>0&&document.fonts.status==="loaded"},{timeout:15000});
      await page.waitForTimeout(1200);
      if(errors.length)throw new Error(`Rendering JavaScript error: ${errors.join("; ")}`);
      await page.screenshot({path:join(process.env.CAPTURE_DIR,`final-${name}.png`),timeout:30000}).catch(e=>{if(e.name==="TimeoutError"||!browser.isConnected())throw transient(e);throw e});
    } catch(e) { if(e.exitCode)throw e; throw new Error(`Rendering defect in ${name}: ${e.message}`); }
    await page.close();
  }
} catch(error) {console.error(error);process.exitCode=error.exitCode||1}
finally {await browser?.close().catch(error=>{console.error(error);process.exitCode||=75})}
'