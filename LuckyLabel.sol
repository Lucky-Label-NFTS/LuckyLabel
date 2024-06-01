// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Context.sol";


contract LuckyLabel is ERC721, ERC721Enumerable, ERC721URIStorage, VRFConsumerBaseV2Plus {
    uint256 private _nextTokenId;

    // 新增：积分相关变量
    mapping(address => uint256) private userPoints;
    // 假设每个NFT铸造需要的积分数量
    uint256 private constant POINTS_PER_MINT = 1;
    // Declaration of DAY_LIMIT_POINTS
    uint256 private constant DAY_LIMIT_POINTS = 10;

    // Metadata information for each stage of the NFT on IPFS.
    string[] META_DATA = [
        "https://ipfs.io/ipfs/QmYX9gNKcYnDKYBXm1eXM8jPvtqxvfCRjDs26yqFjVNaCG",
        "https://ipfs.io/ipfs/QmYX9gNKcYnDKYBXm1eXM8jPvtqxvfCRjDs26yqFjVNaCG",
        "https://ipfs.io/ipfs/QmYX9gNKcYnDKYBXm1eXM8jPvtqxvfCRjDs26yqFjVNaCG"
    ];

    ///// USE NEW COORDINATOR /////
    IVRFCoordinatorV2Plus COORDINATOR;

    ///// SUBSCRIPTION ID IS NOW UINT256 /////
    uint256 s_subscriptionId;

    uint16 requestConfirmations = 3;

    ///// USE NEW KEYHASH FOR VRF 2.5 GAS LANE /////
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf/v2-5/supported-networks
    bytes32 keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;

    uint32 callbackGasLimit = 2500000;

    uint32 numWords = 1;

    mapping (uint256 => uint256 ) public requestIdToTokenId;

    constructor(uint256 subscriptionId) ERC721("LuckyLabel", "MTK") VRFConsumerBaseV2Plus(0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B){
        COORDINATOR = IVRFCoordinatorV2Plus(0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B);
        s_subscriptionId = subscriptionId;
    }

    // 新增：映射存储每个用户的最近一次积分增加时间
    mapping(address => uint256) public lastPointAdditionTime;

    // 一天的秒数，用于时间检查
    uint256 public constant DAY_IN_SECONDS = 86400;

    // 修改：允许外部调用来增加用户的积分，但有限制
    function addPoints(address _user, uint256 _points) external {
        // 获取当前时间戳
        uint256 currentTimestamp = block.timestamp;

        // 检查是否距离上次积分增加已经超过一天
        require(currentTimestamp >= lastPointAdditionTime[_user] + DAY_IN_SECONDS, "Daily point limit not reached yet");

        // 更新用户的最近积分增加时间
        lastPointAdditionTime[_user] = currentTimestamp;

        // 确保增加的积分不会超过每日限额
        uint256 pointsToAdd = _points > DAY_LIMIT_POINTS ? DAY_LIMIT_POINTS : _points;
        userPoints[_user] += pointsToAdd;

        // 如果需要，这里可以处理超过限额的部分积分，比如返回给调用者或者忽略
    }
    

    // 公开方法让用户检查是否有足够的积分铸造NFT
    function hasEnoughPointsToMint(address _user) public view returns (bool) {
        return userPoints[_user] >= POINTS_PER_MINT;
    }

    // 修改safeMint，确保调用者有足够积分，直接在铸造时扣除
    function safeMint(address _user) public {
        require(hasEnoughPointsToMint(_user), "Insufficient points to mint NFT");
        
        uint256 tokenId = _nextTokenId++;
        _safeMint(_user, tokenId);
        requestIdToTokenId[requestRandomWords()] = tokenId;

        // 铸造后扣除积分
        userPoints[_user] -= POINTS_PER_MINT;
    }

    // 新增：展示用户的所有tokenId(NFT)
    function tokensOfOwner(address _owner) public view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        for (uint256 i; i < tokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }


    // 新增：允许任何人通过地址查询用户的积分
    function getUserPoints(address user) public view returns (uint256) {
        return userPoints[user];
    }

    // The following functions are overrides required by Solidity.
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override{
        // You can return the value to the requester,
        // but this example simply stores it.
        uint256 index = randomWords[0] % 3;
        uint256 tokenId = requestIdToTokenId[requestId];
        _setTokenURI(tokenId, META_DATA[index]);
    }

    function requestRandomWords() internal returns (uint256 requestId){
        ///// UPDATE TO NEW V2.5 REQUEST FORMAT /////
        // To enable payment in native tokens, set nativePayment to true.
        requestId = COORDINATOR.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

}