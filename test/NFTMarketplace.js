const NFTMarket = artifacts.require('NFTMarketplace');

contract('NFTMarketplace', (accounts) => {
	let nftMarketInstance;

	before(async () => {
		nftMarketInstance = await NFTMarket.deployed();
	});

	// Test NFT creation
	it("should create a new NFT with correct details", async () => {
		const tokenId = 1;
		const tokenName = 'NFT1';
		const tokenDescription = 'Description for NFT1';

		await nftMarketInstance.createNFT(tokenId, tokenName, tokenDescription);

		const createdToken = await nftMarketInstance.getNFT(tokenId);

		assert.equal(createdToken.id, tokenId);
		assert.equal(createdToken.name, tokenName);
		assert.equal(createdToken.description, tokenDescription);
		assert.equal(createdToken.owner, accounts[0]);
	});

	// Test NFT transfer
	it("should transfer NFT ownership successfully", async () => {
		const sender = accounts[1];
		const receiver = accounts[2];
		const tokenId = 2;
		const tokenName = "NFT2";
		const tokenDescription = "Description for NFT2";
		await nftMarketInstance.createNFT(tokenId, tokenName, tokenDescription, { from: sender });

		await nftMarketInstance.transferNFT(tokenId, receiver, { from: sender });

		const newOwner = await nftMarketInstance.ownerOf(tokenId);
		assert.equal(newOwner, receiver, "Ownership transfer failed");
	});

	// Test NFT listing for sale
	it("should list NFT for sale correctly", async () => {
		const tokenOwner = accounts[3];
		const tokenId = 3;
		const tokenName = "NFT3";
		const tokenDescription = "Description for NFT3";
		const salePrice = web3.utils.toWei("1", "ether");
		await nftMarketInstance.createNFT(tokenId, tokenName, tokenDescription, { from: tokenOwner });

		await nftMarketInstance.listNFTForSale(tokenId, salePrice, { from: tokenOwner });

		const updatedToken = await nftMarketInstance.getNFT(tokenId);
		assert.equal(updatedToken.forSale, true, "NFT not listed for sale");
		assert.equal(updatedToken.price, salePrice, "Incorrect sale price");
	});

	// Test NFT removal from sale
	it("should remove NFT from sale", async () => {
		const tokenOwner = accounts[4];
		const tokenId = 4;
		const tokenName = "NFT4";
		const tokenDescription = "Description for NFT4";
		const salePrice = web3.utils.toWei("1", "ether");
		await nftMarketInstance.createNFT(tokenId, tokenName, tokenDescription, { from: tokenOwner });

		await nftMarketInstance.listNFTForSale(tokenId, salePrice, { from: tokenOwner });

		await nftMarketInstance.removeNFTFromSale(tokenId, { from: tokenOwner });

		const updatedToken = await nftMarketInstance.getNFT(tokenId);
		assert.equal(updatedToken.forSale, false, "NFT still listed for sale");
	});

	// Test successful NFT purchase
	it("should execute a successful NFT purchase", async () => {
		const seller = accounts[5];
		const buyer = accounts[6];
		const tokenId = 5;
		const tokenName = "NFT5";
		const tokenDescription = "Description for NFT5";
		const salePrice = web3.utils.toWei("1", "ether");
		await nftMarketInstance.createNFT(tokenId, tokenName, tokenDescription, { from: seller });
		await nftMarketInstance.listNFTForSale(tokenId, salePrice, { from: seller });

		const buyerInitialBalance = await web3.eth.getBalance(buyer);
		const sellerInitialBalance = await web3.eth.getBalance(seller);
	
		const transactionReceipt = await nftMarketInstance.purchaseNFT(tokenId, { from: buyer, value: web3.utils.toWei("1", "ether") });
	
		const newOwner = await nftMarketInstance.ownerOf(tokenId);
		assert.equal(newOwner, buyer, "Ownership not transferred to buyer");
	
		const updatedToken = await nftMarketInstance.getNFT(tokenId);
		assert.equal(updatedToken.forSale, false, "NFT still listed for sale");
	
		const sellerUpdatedBalance = await web3.eth.getBalance(seller);
		const amount = web3.utils.toWei("1", "ether");
		assert.equal(sellerUpdatedBalance - sellerInitialBalance, amount, "Incorrect amount received by seller");
	
		const marginOfError = BigInt(web3.utils.toWei("0.001", "ether"));
	
		const gasUsed = transactionReceipt.receipt.gasUsed;
		const txDetails = await web3.eth.getTransaction(transactionReceipt.tx);
		const gasFee = web3.utils.toBN(gasUsed).mul(web3.utils.toBN(txDetails.gasPrice));
	
		const buyerUpdatedBalance = await web3.eth.getBalance(buyer);
		const difference = BigInt(Math.abs(buyerInitialBalance - buyerUpdatedBalance - gasFee - amount));
		assert.isTrue(difference <= marginOfError, "Incorrect deduction from buyer's balance");
	});
	
	// Test unsuccessful NFT purchase
	it("should fail an NFT purchase with insufficient funds", async () => {
		const seller = accounts[7];
		const buyer = accounts[8];
		const tokenId = 6;
		const tokenName = "NFT6";
		const tokenDescription = "Description for NFT6";
		const salePrice = web3.utils.toWei("2", "ether");
	
		await nftMarketInstance.createNFT(tokenId, tokenName, tokenDescription, { from: seller });
	
		await nftMarketInstance.listNFTForSale(tokenId, salePrice, { from: seller });
	
		const buyerInitialBalance = await web3.eth.getBalance(buyer);
	
		try {
			await nftMarketInstance.purchaseNFT(tokenId, { from: buyer, value: salePrice - web3.utils.toWei("1", "ether") });
			assert.fail("Purchase should have failed due to insufficient Ether amount");
		} catch (error) {
			assert(error.message.includes("Insufficient funds."), "Unexpected error occurred");
	
			const nft = await nftMarketInstance.getNFT(tokenId);
			assert.equal(nft.owner, seller, "NFT should still be owned by the seller");
	
			const buyerUpdatedBalance = await web3.eth.getBalance(buyer);
			assert.equal(buyerInitialBalance, buyerUpdatedBalance, "Incorrect deduction from buyer's balance");
		}
	});
});	
