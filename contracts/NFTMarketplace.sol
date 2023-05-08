// SPDX-License-Identifier: MIT
pragma solidity^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is ERC721, Ownable {
	using SafeMath for uint256;

	struct NFT {
		uint256 id;
		string name;
		string description;
		address owner;
		uint256 price;
		bool forSale;
	}

	struct Auction {
		uint256 id;
		uint256 nftId;
		uint256 startPrice;
		uint256 endTime;
		uint256 highestBid;
		address highestBidder;
		bool active;
	}

	mapping (uint256 => NFT) public nfts;
	mapping (uint256 => Auction) public auctions;

	uint256 public nftCounter;
	uint256 public auctionCounter;

	constructor(string memory name, string memory symbol) ERC721(name, symbol) {
	}

	function createNFT(uint256 id, string memory name, string memory description) public {
		nftCounter++;
		_safeMint(msg.sender, id);
		nfts[nftCounter] = NFT(id, name, description, msg.sender, 0, false);
	}

	function getNFT(uint256 id) public view returns (NFT memory) {
		return nfts[id];
	}

	function transferNFT(uint256 id, address receiver) public {
		require(_exists(id), "This NFT does not exist.");
		require(ownerOf(id) == msg.sender, "You are not the owner of this NFT.");
		require(!isInActiveAuction(id), "NFT is in an active auction.");

		safeTransferFrom(msg.sender, receiver, id);
		nfts[id].owner = receiver;
	}

	function listNFTForSale(uint256 id, uint256 price) public {
		require(_exists(id), "This NFT does not exist.");
		require(ownerOf(id) == msg.sender, "You are not the owner of this NFT.");
		require(!isInActiveAuction(id), "NFT is in an active auction.");

		nfts[id].price = price;
		nfts[id].forSale = true;
	}

	function removeNFTFromSale(uint256 id) public {
		require(_exists(id), "This NFT does not exist.");
		require(ownerOf(id) == msg.sender, "You are not the owner of this NFT.");
		require(!isInActiveAuction(id), "NFT is in an active auction.");
		require(nfts[id].forSale == true, "This NFT is not currently for sale.");

		nfts[id].price = 0;
		nfts[id].forSale = false;
	}

	function purchaseNFT(uint256 id) public payable {
		require(_exists(id), "This NFT does not exist.");
		require(nfts[id].forSale == true, "This NFT is not currently for sale.");
		require(!isInActiveAuction(id), "NFT is in an active auction.");
		require(msg.value == nfts[id].price, "Insufficient funds.");
		require(nfts[id].owner != msg.sender, "You are the owner of this NFT.");

		address payable seller = payable(nfts[id].owner);
		seller.transfer(nfts[id].price);
		_transfer(seller, msg.sender, id);
		nfts[id].owner = msg.sender;
		nfts[id].price = 0;
		nfts[id].forSale = false;
	}

	function listNFTForAuction(uint256 id, uint256 startPrice, uint256 duration) public {
		require(_exists(id), "This NFT does not exist.");
		require(nfts[id].forSale == false, "This NFT is  currently for sale.");
		require(ownerOf(id) == msg.sender, "You do not own this NFT.");

		auctionCounter++;
		uint256 endTime = block.timestamp.add(duration);
		auctions[auctionCounter] = Auction(auctionCounter, id, startPrice, endTime, 0, address(0), true);
	}

	function bid(uint256 auctionId) public payable {
		require(auctions[auctionId].active, "Auction is not active.");
		require(block.timestamp <= auctions[auctionId].endTime, "Auction has ended.");
		require(msg.value > auctions[auctionId].highestBid, "Bid is not higher than the current highest bid.");

		if (auctions[auctionId].highestBidder != address(0)) {
			payable(auctions[auctionId].highestBidder).transfer(auctions[auctionId].highestBid);
		}

		auctions[auctionId].highestBid = msg.value;
		auctions[auctionId].highestBidder = msg.sender;
	}

	function endAuction(uint256 auctionId) public {
		require(auctions[auctionId].active, "Auction is not active.");
		require(block.timestamp > auctions[auctionId].endTime, "Auction has not ended yet.");

		auctions[auctionId].active = false;
		uint256 nftId = auctions[auctionId].nftId;
		address seller = nfts[nftId].owner;
		payable(seller).transfer(auctions[auctionId].highestBid);

		_transfer(seller, auctions[auctionId].highestBidder, nftId);
		nfts[nftId].owner = auctions[auctionId].highestBidder;
		nfts[nftId].price = 0;
		nfts[nftId].forSale = false;
	}

	function getRemainingTime(uint256 auctionId) public view returns (uint256) {
		if (block.timestamp >= auctions[auctionId].endTime) {
			return 0;
		}
		return auctions[auctionId].endTime - block.timestamp;
	}

	function isInActiveAuction(uint256 nftId) private view returns (bool) {
		for (uint256 i = 1; i <= auctionCounter; i++) {
			if (auctions[i].nftId == nftId && auctions[i].active) {
				return true;
			}
		}
		return false;
	}

	function getNFTsByKeyword(string memory keyword) public view returns (NFT[] memory) {
		uint256 count = 0;
		for (uint256 i = 1; i <= nftCounter; i++) {
			if (contains(nfts[i].name, keyword) || contains(nfts[i].description, keyword)) {
				count++;
			}
		}
		NFT[] memory result = new NFT[](count);
		uint256 index = 0;
		for (uint256 i = 1; i <= nftCounter; i++) {
			if (contains(nfts[i].name, keyword) || contains(nfts[i].description, keyword)) {
				result[index] = nfts[i];
				index++;
			}
		}
		return result;
	}

	function contains(string memory str, string memory substr) private pure returns (bool) {
		bytes memory strBytes = bytes(str);
		bytes memory substrBytes = bytes(substr);

		if (substrBytes.length == 0) {
			return true;
		}

		for (uint256 i = 0; i <= strBytes.length - substrBytes.length; i++) {
			bool found = true;
			for (uint256 j = 0; j < substrBytes.length; j++) {
				if (strBytes[i + j] != substrBytes[j]) {
					found = false;
					break;
				}
			}
			if (found) {
				return true;
			}
		}
		return false;
	}
}
