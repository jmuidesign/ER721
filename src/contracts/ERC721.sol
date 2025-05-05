// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {ICommonErrors} from "../interfaces/ICommonErrors.sol";
import {IERC721} from "../interfaces/IERC721.sol";
import {IERC165} from "../interfaces/IERC165.sol";
import {IERC721Metadata} from "../interfaces/IERC721Metadata.sol";
import {IERC721Enumerable} from "../interfaces/IERC721Enumerable.sol";
import {IERC721TokenReceiver} from "../interfaces/IERC721TokenReceiver.sol";
import {Crowdsale} from "./utils/Crowdsale.sol";
import {Ownable2Steps} from "./utils/Ownable2Steps.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

contract ERC721 is IERC721, IERC165, IERC721Metadata, IERC721Enumerable, ICommonErrors, Ownable2Steps, Crowdsale {
    using Strings for uint256;

    uint256 private immutable maxTotalSupply;
    uint256 private immutable revealTime;
    bytes32 private immutable ipfsCidCommit;

    string private tokenName;
    string private tokenSymbol;
    string private ipfsCid;
    uint256 private tokensCount;

    mapping(uint256 id => address owner) private owners;
    mapping(uint256 id => address approved) private approvals;
    mapping(address owner => uint256 count) private balances;
    mapping(address owner => mapping(address operator => bool approved)) private operators;
    mapping(address owner => uint256[] tokenIds) private ownerToTokenIds;

    modifier onlyOwnerApprovedOrOperator(uint256 tokenId) {
        if (
            msg.sender != owners[tokenId] && msg.sender != approvals[tokenId] && !operators[owners[tokenId]][msg.sender]
        ) revert NotOwnerApprovedOrOperator();

        _;
    }

    modifier onlyOwnerOrOperator(uint256 tokenId) {
        if (msg.sender != owners[tokenId] && !operators[owners[tokenId]][msg.sender]) revert NotOwnerOrOperator();

        _;
    }

    constructor(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _minimumPrice,
        uint256 _maxTotalSupply,
        uint256 _revealTime,
        uint256 _withdrawGracePeriod,
        bytes32 _ipfsCidCommit
    ) Ownable2Steps(msg.sender) Crowdsale(_minimumPrice, _revealTime, _withdrawGracePeriod) {
        if (_revealTime < block.timestamp) revert InvalidRevealTime();

        tokenName = _tokenName;
        tokenSymbol = _tokenSymbol;
        maxTotalSupply = _maxTotalSupply;
        revealTime = _revealTime;
        ipfsCidCommit = _ipfsCidCommit;
    }

    ///////////////////////////////////
    // Reveal IPFS CID
    ///////////////////////////////////
    function revealIpfsCid(string memory _ipfsCid) external onlyOwner {
        if (block.timestamp < revealTime) revert RevealTimeNotReached();
        if (ipfsCidCommit != keccak256(abi.encodePacked(_ipfsCid))) revert InvalidIpfsCid();

        ipfsCid = _ipfsCid;
    }

    ///////////////////////////////////
    // Crowdsale
    ///////////////////////////////////
    function buyToken(address to) external payable {
        _buyToken(to, msg.value);
        _mint(to);
    }

    function withdraw(address to, uint256 amount) external onlyOwner {
        _withdraw(to, amount);
    }

    ///////////////////////////////////
    // IERC165
    ///////////////////////////////////
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC721).interfaceId
            || interfaceId == type(IERC721Metadata).interfaceId || interfaceId == type(IERC721Enumerable).interfaceId;
    }

    ///////////////////////////////////
    // IERC721Metadata
    ///////////////////////////////////
    function name() external view returns (string memory _name) {
        return tokenName;
    }

    function symbol() external view returns (string memory _symbol) {
        return tokenSymbol;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory uri) {
        if (owners[tokenId] == address(0)) revert NotExist();

        return string(abi.encodePacked("ipfs://", ipfsCid, "/", tokenId.toString(), ".json"));
    }

    ///////////////////////////////////
    // IERC721Enumerable
    ///////////////////////////////////
    function totalSupply() external view returns (uint256) {
        return tokensCount;
    }

    function tokenByIndex(uint256 index) external view returns (uint256) {
        if (index >= tokensCount) revert NotExist();

        return index;
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256) {
        if (owner == address(0)) revert AddressZero();

        uint256[] memory tokenIds = ownerToTokenIds[owner];

        if (index >= tokenIds.length) revert NotExist();

        return tokenIds[index];
    }

    ///////////////////////////////////
    // IERC721
    ///////////////////////////////////
    function balanceOf(address owner) external view returns (uint256) {
        if (owner == address(0)) revert AddressZero();

        return balances[owner];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        if (owners[tokenId] == address(0)) revert NotExist();

        return owners[tokenId];
    }

    function transferFrom(address from, address to, uint256 tokenId) public onlyOwnerApprovedOrOperator(tokenId) {
        if (from != owners[tokenId]) revert NotTokenOwner();
        if (to == address(0)) revert AddressZero();

        owners[tokenId] = to;
        balances[from]--;
        balances[to]++;

        delete approvals[tokenId];

        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public {
        transferFrom(from, to, tokenId);

        if (to.code.length > 0) {
            bytes4 response = IERC721TokenReceiver(to).onERC721Received(msg.sender, from, tokenId, data);

            if (response != IERC721TokenReceiver.onERC721Received.selector) revert NotERC721TokenReceiver();
        }
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        safeTransferFrom(from, to, tokenId, "");
    }

    function approve(address approved, uint256 tokenId) external onlyOwnerOrOperator(tokenId) {
        approvals[tokenId] = approved;
        emit Approval(owners[tokenId], approved, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        operators[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        return approvals[tokenId];
    }

    function isApprovedForAll(address owner, address operator) external view returns (bool) {
        return operators[owner][operator];
    }

    ///////////////////////////////////
    // Minting
    ///////////////////////////////////
    function _mint(address to) private {
        if (tokensCount == maxTotalSupply) revert MaxTotalSupplyReached();

        uint256 tokenId = tokensCount;

        owners[tokenId] = to;
        balances[to]++;
        ownerToTokenIds[to].push(tokenId);

        tokensCount++;

        emit Transfer(address(0), to, tokenId);
    }
}
