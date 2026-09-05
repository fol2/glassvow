const {chromium}=require('playwright');
const fs=require('fs');
(async()=>{
 const browser=await chromium.launch({headless:true});const page=await browser.newPage({viewport:{width:1500,height:1080}});let errors=[];page.on('pageerror',e=>errors.push(String(e)));
 await page.goto('http://127.0.0.1:8766/docs/map/studies/camera-composition/');
 const rows=await page.evaluate(()=>{
  const out=[];
  for(let si=0;si<DATA.samples.length;si++){
   $('sample').value=si;setSample();
   for(const shape of ['844,390','1180,820','1458,820'])for(const pitch of ['40','55']){
    $('shape').value=shape;$('pitch').value=pitch;mode='journey';
    for(const n of sample.nodes){focus=n.id;render();out.push({...window.studyState,roadsDrawn:document.querySelectorAll('[data-edge]').length,nodesDrawn:document.querySelectorAll('[data-node]').length})}
    mode='survey';render();out.push({...window.studyState,roadsDrawn:document.querySelectorAll('[data-edge]').length,nodesDrawn:document.querySelectorAll('[data-node]').length});
   }
  }
  return out;
 });
 await page.selectOption('#sample','0');await page.selectOption('#shape','844,390');await page.selectOption('#pitch','55');await page.click('#return');await page.click('#safety');await page.screenshot({path:'docs/map/studies/camera-composition/phone-journey.png',fullPage:true});
 await page.click('#survey');await page.screenshot({path:'docs/map/studies/camera-composition/phone-survey.png',fullPage:true});
 await page.selectOption('#sample','3');await page.selectOption('#shape','1458,820');await page.screenshot({path:'docs/map/studies/camera-composition/act4-survey.png',fullPage:true});
 await page.setViewportSize({width:390,height:844});await page.screenshot({path:'docs/map/studies/camera-composition/narrow-page.png',fullPage:true});
 const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);
 const summary={cases:rows.length,missingCoverage:rows.filter(r=>r.roadsDrawn!==r.edgeCount||r.nodesDrawn!==r.nodeCount),localFailures:rows.filter(r=>r.mode==='journey'&&(!r.fit||r.overlap)),overviewClipped:rows.filter(r=>r.mode==='survey'&&r.shown!==r.nodeCount),errors,narrowPageOverflow:overflow};
 fs.writeFileSync('docs/map/studies/camera-composition/check-results.json',JSON.stringify({summary,rows},null,2));console.log(JSON.stringify(summary));await browser.close();
 if(errors.length||overflow||summary.missingCoverage.length||summary.overviewClipped.length)process.exitCode=1;
})();
