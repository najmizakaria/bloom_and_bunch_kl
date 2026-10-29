'use strict';
const {readFileSync,existsSync}=require('node:fs');
const policy=require('../functions/store-policy');
const errors=[];
try { policy.validate(policy.configured); } catch(e) { errors.push(e.message); }
if(policy.configured.mode==='demo')errors.push('Store policy is still demo. Configure approved payment and delivery rules before public ordering.');
if(!process.argv.includes('--web')) {
 if(!existsSync('android/key.properties'))errors.push('Provide android/key.properties and the release keystore.');
 if(readFileSync('android/app/build.gradle.kts','utf8').includes('applicationId = "com.example.'))errors.push('Confirm a permanent application ID and coordinate its Firebase/OAuth registration.');
}
if(errors.length){console.error(errors.join('\n'));process.exit(1);}
console.log('Configuration checks passed. Device validation and business approval are still required.');
