## STORMBIT : A DECENTRALIZED CONSUMER BASED LENDING PROTOCOL 


  <img src="./docs/Logo.png" alt="Stormbit Logo" width="200" class="logo">


  THIS IS AN AVALANCHE CONSUMER BASED APPLICATION PROJECT BUILT DURING AVALANCHE FRONTIER HACKATHON 
  
## DOCUMENTATION 


You can find the documentation here : [StormBit Documentation](https://app.gitbook.com/o/6Ba9JCvQ5qAfdGJBr4ud/s/85Jk3acx3jKwt2N6IWnB/)

## TL;DR:

StormBit is a Lending Marketplace trageting the micro lending market.
It is offering different types of agreements to allow the lenders and the borrowers to interact in a more real way and connect decentralized world to the real world. 


## Architecture 

### Actors 

- **Lender** : a lender is a KYC-ed person who is willing to stake an amount in a shared pool and vote for giving or no a loan to a borrower. Lenders are able to manage all functionalities of their pools. 
- **Borrower** : a borrower is a KYC-ed person who wants or has an active loan on a pool. Borrowers are able to manage all functionalities of their loans (such as repaying them). 
- **User** : a user is non KYC-ed account who can visualize data on the app but cannot interact with the most of the pools. 
- **Pool Manager** : a pool manager is a KYC-ed user who holds voting power inside a pool. Managers are only able to approve/reject loans on the pool they have voting power at. 

### Governance & Loans Allocation 

- Loans allocations goes through a voting process. Each loan request is a loan proposal that is on Avalanche Fuji Testnet. The StormBitLending contract implementing the lending is inheriting from Openzeppelin necessary contracts for governance. Please refer to this official Openzeppelin documentation for any details. 

- On-chain transactions include : 
1. **Proposal creation** : a proposal is created when a borrower requests a loan after depositing a collateral (NFT or ERC-20 tokens) or without collateral (Simple Agreement). 
2. **Casting vote** : voting on a loan allocation is reserved to the stakers only. 
3. **Voting cool down period** : sets a delay before a voter's votes are considered valid for proposal consideration. Defined to mitigate potential manipulation or abrupt changes in voting power.


### Agreements 

There are 3 types of agreements : 

#### FTAgreement 

  <img src="./docs/FTAgreement.png" alt="FTAgreement Logo" >


## How it is made 

StormBit protocol aims to facilitate the access of credit allocation to the 99%. By providing different types of agreements, any KYC-ed user can request a loan and receive a fair answer from the owners of a shared pool. 



## Technologies Used

StormBit protocol contracts are deployed on Avalanche and all the interactions are on the Avalanche blockchain. 

We have abstracted the way for users to connect without the need of a wallet, for scability and to attract web2 players also : 

#### Particle Auth 

Particle Auth is used to allow lenders and borrowers to use their email or mobile number to be able to login. StormBit by using Particle Auth is opening the door to web2 users to participate to DeFi. 

#### Chainlink 



## Tech Stack 






## Deployed Contracts






## Contact 


@Build by Q3Labs with Love during Avalanche Frontier Hackathon. 




