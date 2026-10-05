'use strict';
const {spawnSync}=require('node:child_process');
const seed=spawnSync(process.execPath,['tool/seed_demo.cjs'],{stdio:'inherit'});
if(seed.status!==0)process.exit(seed.status??1);
const args=['drive','--no-pub','--driver=integration_test/driver.dart','--target=integration_test/order_journey_test.dart','-d','web-server','--headless','--browser-name=chrome','--dart-define=APP_ENV=demo'];
for(const [name,key]of [['AUTH','FIREBASE_AUTH_EMULATOR_HOST'],['FIRESTORE','FIRESTORE_EMULATOR_HOST'],['STORAGE','FIREBASE_STORAGE_EMULATOR_HOST']]) {
 const port=process.env[key]?.split(':').at(-1);if(port)args.push(`--dart-define=${name}_EMULATOR_PORT=${port}`);
}
if(process.env.UX_JOURNEY_FILTER)args.push(`--dart-define=JOURNEY_FILTER=${process.env.UX_JOURNEY_FILTER}`);
if(process.env.UX_FUNCTIONS_PORT)args.push(`--dart-define=FUNCTIONS_EMULATOR_PORT=${process.env.UX_FUNCTIONS_PORT}`);
const result=spawnSync(process.platform==='win32'?'flutter.bat':'flutter',args,{stdio:'inherit',shell:process.platform==='win32'});
process.exit(result.status??1);
