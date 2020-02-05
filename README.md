### Dev:
- `$ git clone https://github.com/DOSNetwork/eth-contracts`
- `$ npm install`
- `$ npm -g install truffle`
- `$ npm install -g ganache-cli` or installing its [graphic interface](https://truffleframework.com/ganache)
- Required truffle/solcjs version: >= 0.5

### Compile:
- `$ truffle compile`

### Deploy:
- `$ ganache-cli`
- `$ truffle migrate --reset`

### Test:
- `$ ganache-cli -a 20`; // Config more than 10 test accounts 
- `$ truffle test`
