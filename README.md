### Dev:
- `$ git clone https://github.com/DOSNetwork/eth-contracts`
- `$ npm install`
- `$ npm -g install truffle`
- `$ npm install -g ganache-cli` or installing its [graphic interface](https://truffleframework.com/ganache)
- Required truffle/solcjs version: >= 0.5

### Compile:
- `$ truffle compile`

### Deploy to local development network:
- `$ ganache-cli`
- `$ truffle migrate --reset`


### Deploy to rinkeby testnet:
- `$ truffle compile --all`
- `$ truffle migrate --reset --network rinkeby`


### Deploy to mainnet:
- `$ truffle compile --all`
- `$ truffle migrate --reset --network live`


### Test:
- `$ ganache-cli -a 20`; // Config more than 10 test accounts 
- `$ truffle test`
