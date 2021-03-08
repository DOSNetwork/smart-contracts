### Compile
* `cd .. && npm install`
* `truffle compile --all`

### Config
* Change `httpProvider` for supported chains.
* Change `MetaSource` for guardian node to check data changes and notify on-chain systems.

### Execute
* `export PK=xxxxx` ()
* `pm2 start guardian.js`
