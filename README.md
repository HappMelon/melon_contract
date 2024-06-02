# test account
0xc0ee714715108b1a6795391f7e05a044d795ba70   
secret key: 641943fa6c3fab18fed274c2b3194f0d71383ecfb9a58b2d70188e693c245510  
0xb9d47c289b8dacff0b894e385464f51e5eabdd86  
secret key: a39de0eaa34cd3be35a7a200989437b9f672a4056298a51f086db9b634683fec

# faucets guide
1. 获取0.05 sepolia ETH  
https://www.infura.io/faucet/sepolia?_ga=2.191463465.2049402864.1717224083-318271395.1717224083
2. 通过跨链桥转化成zk test ETH  
https://app.txsync.io/bridge

# deployed info
## zksync testnet
- melonToken  
0xDf77D063Cf7BdBf2D8167B18e511c82b6cE6d1DD
- proposalAddr  
0x68386FaD40442a9D0C189FB087b8633dde79AF5a
- melonNft  
0x027da933c821D112A1b97EB1e5cE653cfb28768F
- assessor   
0xD5F5aBbafdC0c31F0747A50Df3F05F30494eFb0C
- juryNftSwap  
0xB7e4a92BE506A89d8E3Ef11d1F71472372f2c257

# Architecture diagram
![alt text](image-2.png)

# Test contract
`npx hardhat test ${path} --network hardhat`

# Steps for deploying ZkSync test network
> `npx  hardhat deploy-zksync --script index.js --network zkSyncTestnet` （Error reporting： `Error in plugin @matterlabs/hardhat-zksync-deploy: Deploy function does not exist or exported invalidly.`，Temporarily abandoned）
1. First initialization `npx hardhat run deploy/index.js` 
2. [view contract](https://sepolia.explorer.zksync.io/)
3. [verify](https://docs.zksync.io/build/tooling/hardhat/hardhat-zksync-verify.html#commands)
`npx  hardhat verify --network zkSyncTestnet  ${Contract address}  ${Construction parameters}`
# Replace logical contract
[Subsequent replacement of logical contracts](https://docs.zksync.io/build/tooling/hardhat/hardhat-zksync-upgradable.html#upgradable-examples)



# Sample Hardhat Project
This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.js
```
