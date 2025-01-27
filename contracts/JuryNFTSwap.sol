// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MelonNFT.sol";
import "./Proposal.sol";

contract JuryNFTSwap is IERC721Receiver, Ownable {
    struct NFTListInfo {
        uint tokenId;
        uint price;
        string uri;
        uint gainTime;
    }

    struct ApplyStartUpNFTInfo {
        uint pledgeAmount;
        address user;
        uint applyTime;
    }

    uint public immutable COMMON_NFT_LIMIT_PER_USER;
    uint public immutable START_UP_NFT_LIMIT;

    MelonNFT public melonNFT;
    NFTListInfo[] public startUpNFTs;
    NFTListInfo[] public commonNFTs;
    ApplyStartUpNFTInfo[] public applyStartUpNFTInfos;

    mapping(address => NFTListInfo) public userStartUpNFTs;
    mapping(address => NFTListInfo[]) public userCommonNFTs;
    mapping(address => ApplyStartUpNFTInfo) public userApplyStartUpNFT;

    mapping(address => uint) public nftLock;
    mapping(uint => NFTListInfo) public infoByTokenId;

    event HangOut(uint indexed tokenId, uint price);
    event StartUpNFTSending(address indexed buyer, uint tokenId, uint price);
    event BuyNFT(address indexed buyer, uint tokenId, uint price);
    event Redeem(address indexed redeemer, uint tokenId, uint redeemPrice);
    event ApplyStartUpNFT(address indexed user, uint pledgeAmount);

    error NotListed(uint tokenId);
    error AlreadyListed(uint tokenId);
    error RedemptionTimeNotReached(
        address NFTAddr,
        uint tokenId,
        uint redemptionTime
    );
    error NotNFTOwner(address user, uint tokenId);
    error MaximumNumberOfHoldings(address user, uint holdAmount);
    error NFTTransferFailed(uint tokenId);

    modifier isListed(uint tokenId) {
        if (bytes(infoByTokenId[tokenId].uri).length == 0) {
            revert NotListed(tokenId);
        }
        _;
    }

    modifier isUnListed(uint tokenId) {
        if (bytes(infoByTokenId[tokenId].uri).length > 0) {
            revert AlreadyListed(tokenId);
        }
        _;
    }

    modifier isOwner(address user, uint tokenId) {
        if (melonNFT.ownerOf(tokenId) != user) {
            revert NotNFTOwner(user, tokenId);
        }
        _;
    }

    constructor(
        address _melonNFTAddr,
        uint _commonNFTsLimitPerUser,
        uint _startUpNFTsLimit
    ) Ownable() {
        melonNFT = MelonNFT(_melonNFTAddr);
        COMMON_NFT_LIMIT_PER_USER = _commonNFTsLimitPerUser;
        START_UP_NFT_LIMIT = _startUpNFTsLimit;
    }

    function getTotalApplyInfo()
        external
        view
        returns (uint totalApplicants, uint totalPledgedAmount)
    {
        totalApplicants = applyStartUpNFTInfos.length;
        for (uint i = 0; i < totalApplicants; i++) {
            totalPledgedAmount += applyStartUpNFTInfos[i].pledgeAmount;
        }
    }

    function getApplyStartUpNFTInfos()
        external
        view
        returns (ApplyStartUpNFTInfo[] memory)
    {
        return applyStartUpNFTInfos;
    }

    function getAllStartUpNFTs() external view returns (NFTListInfo[] memory) {
        return startUpNFTs;
    }

    function getAllCommonNFTs() external view returns (NFTListInfo[] memory) {
        return commonNFTs;
    }

    function getCommonNFTHolding(
        address user
    ) external view returns (NFTListInfo[] memory) {
        return userCommonNFTs[user];
    }

    function distributeStartUpNFT(
        address[] memory users,
        uint[] memory tokenIds
    ) external onlyOwner {
        require(
            users.length == tokenIds.length,
            "Users and tokenIds array lengths must match"
        );
        clearApplyLock();
        for (uint i = 0; i < users.length; i++) {
            address user = users[i];
            uint tokenId = tokenIds[i];
            NFTListInfo storage info = infoByTokenId[tokenId];
            if (bytes(info.uri).length == 0) {
                revert NotListed(tokenId);
            }
            melonNFT.safeTransferFrom(address(this), user, tokenId);
            info.gainTime = block.timestamp;
            userStartUpNFTs[user] = info;

            delete infoByTokenId[tokenId];
            handleNFTListRemove(startUpNFTs, tokenId);
            emit StartUpNFTSending(user, tokenId, info.price);
        }
    }

    function applyStartUpNFT(uint pledgeAmount) external {
        ApplyStartUpNFTInfo memory info = ApplyStartUpNFTInfo({
            pledgeAmount: pledgeAmount,
            user: msg.sender,
            applyTime: block.timestamp
        });
        applyStartUpNFTInfos.push(info);
        userApplyStartUpNFT[msg.sender] = info;
        nftLock[msg.sender] += pledgeAmount;
        emit ApplyStartUpNFT(msg.sender, pledgeAmount);
    }

    function getUserApplyStartUpNFTInfos(
        address user
    )
        external
        view
        returns (
            uint tokenId,
            string memory uri,
            uint pledgeAmount,
            uint applyTime
        )
    {
        NFTListInfo memory info = userStartUpNFTs[user];
        ApplyStartUpNFTInfo memory applyInfo = userApplyStartUpNFT[user];
        tokenId = info.tokenId;
        uri = info.uri;
        pledgeAmount = applyInfo.pledgeAmount;
        applyTime = applyInfo.applyTime;
    }

    function initialNFTHangOut(
        uint tokenId,
        uint price
    ) public isOwner(msg.sender, tokenId) isUnListed(tokenId) onlyOwner {
        bool isStartUp = price == 0;
        melonNFT.safeTransferFrom(msg.sender, address(this), tokenId);
        string memory uri = melonNFT.tokenURI(tokenId);
        NFTListInfo memory newListing = NFTListInfo({
            tokenId: tokenId,
            price: price,
            uri: uri,
            gainTime: 0
        });
        if (isStartUp) {
            startUpNFTs.push(newListing);
        } else {
            commonNFTs.push(newListing);
        }
        infoByTokenId[tokenId] = newListing;
        emit HangOut(tokenId, price);
    }

    function purchaseCommonNFT(
        uint tokenId,
        Proposal proposal
    ) external isListed(tokenId) {
        uint balance = userCommonNFTs[msg.sender].length;

        if (balance >= COMMON_NFT_LIMIT_PER_USER) {
            revert MaximumNumberOfHoldings(msg.sender, balance);
        }

        NFTListInfo memory info = infoByTokenId[tokenId];

        require(
            proposal.getAvailableBalance(msg.sender) >= info.price,
            "Insufficient balance"
        );

        try melonNFT.safeTransferFrom(address(this), msg.sender, tokenId) {
            nftLock[msg.sender] += info.price;

            info.gainTime = block.timestamp;

            userCommonNFTs[msg.sender].push(info);

            handleNFTListRemove(commonNFTs, tokenId);
            delete infoByTokenId[tokenId];

            emit BuyNFT(msg.sender, tokenId, info.price);
        } catch {
            revert NFTTransferFailed(tokenId);
        }
    }

    function redeem(
        uint tokenId,
        uint price,
        Proposal proposal
    ) external isOwner(msg.sender, tokenId) isUnListed(tokenId) {
        bool isStartUp = tokenId < START_UP_NFT_LIMIT;

        melonNFT.safeTransferFrom(msg.sender, address(this), tokenId);

        string memory uri = melonNFT.tokenURI(tokenId);

        NFTListInfo memory newListing = NFTListInfo({
            tokenId: tokenId,
            price: price,
            uri: uri,
            gainTime: 0
        });

        if (isStartUp) {
            startUpNFTs.push(newListing);
            delete userStartUpNFTs[msg.sender];
        } else {
            commonNFTs.push(newListing);
            handleNFTListRemove(userCommonNFTs[msg.sender], tokenId);
        }

        infoByTokenId[tokenId] = newListing;

        uint curLock = nftLock[msg.sender];

        if (price >= curLock) {
            nftLock[msg.sender] = 0;
            proposal.addInterest(msg.sender, price - curLock);
        } else {
            nftLock[msg.sender] -= price;
        }

        emit Redeem(msg.sender, tokenId, price);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function handleNFTListRemove(
        NFTListInfo[] storage listInfos,
        uint tokenId
    ) internal {
        for (uint i = 0; i < listInfos.length; i++) {
            if (listInfos[i].tokenId == tokenId) {
                listInfos[i] = listInfos[listInfos.length - 1];
                listInfos.pop();
                break;
            }
        }
    }

    function clearApplyLock() internal {
        uint applyCount = applyStartUpNFTInfos.length;
        for (uint i = 0; i < applyCount; i++) {
            ApplyStartUpNFTInfo storage applyInfo = applyStartUpNFTInfos[i];
            nftLock[applyInfo.user] -= applyInfo.pledgeAmount;
        }
        // Clear the entire array after unlocking the NFTs
        delete applyStartUpNFTInfos;
    }
}
