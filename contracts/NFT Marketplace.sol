// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is ReentrancyGuard, Ownable {
    
    // Structure to represent a marketplace listing
    struct Listing {
        uint256 tokenId;
        address nftContract;
        address seller;
        uint256 price;
        bool active;
    }
    
    // Mapping from listing ID to listing details
    mapping(uint256 => Listing) public listings;
    
    // Counter for listing IDs
    uint256 public listingCounter;
    
    // Marketplace fee percentage (e.g., 250 = 2.5%)
    uint256 public marketplaceFee = 250; // 2.5%
    uint256 public constant FEE_DENOMINATOR = 10000;
    
    // Events
    event ItemListed(
        uint256 indexed listingId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        uint256 price
    );
    
    event ItemSold(
        uint256 indexed listingId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address buyer,
        uint256 price
    );
    
    event ListingCanceled(uint256 indexed listingId);
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Core Function 1: List an NFT for sale
     * @param _nftContract Address of the NFT contract
     * @param _tokenId Token ID of the NFT to list
     * @param _price Price in wei for the NFT
     */
    function listItem(
        address _nftContract,
        uint256 _tokenId,
        uint256 _price
    ) external nonReentrant {
        require(_price > 0, "Price must be greater than zero");
        require(
            IERC721(_nftContract).ownerOf(_tokenId) == msg.sender,
            "You don't own this NFT"
        );
        require(
            IERC721(_nftContract).getApproved(_tokenId) == address(this) ||
            IERC721(_nftContract).isApprovedForAll(msg.sender, address(this)),
            "Marketplace not approved to transfer NFT"
        );
        
        uint256 listingId = listingCounter;
        
        listings[listingId] = Listing({
            tokenId: _tokenId,
            nftContract: _nftContract,
            seller: msg.sender,
            price: _price,
            active: true
        });
        
        listingCounter++;
        
        emit ItemListed(listingId, _nftContract, _tokenId, msg.sender, _price);
    }
    
    /**
     * @dev Core Function 2: Buy an NFT from the marketplace
     * @param _listingId ID of the listing to purchase
     */
    function buyItem(uint256 _listingId) external payable nonReentrant {
        Listing storage listing = listings[_listingId];
        
        require(listing.active, "Listing is not active");
        require(msg.value >= listing.price, "Insufficient payment");
        require(msg.sender != listing.seller, "Cannot buy your own NFT");
        
        // Calculate marketplace fee
        uint256 fee = (listing.price * marketplaceFee) / FEE_DENOMINATOR;
        uint256 sellerAmount = listing.price - fee;
        
        // Mark listing as inactive
        listing.active = false;
        
        // Transfer NFT to buyer
        IERC721(listing.nftContract).safeTransferFrom(
            listing.seller,
            msg.sender,
            listing.tokenId
        );
        
        // Transfer payment to seller
        payable(listing.seller).transfer(sellerAmount);
        
        // Transfer fee to marketplace owner
        if (fee > 0) {
            payable(owner()).transfer(fee);
        }
        
        // Refund excess payment
        if (msg.value > listing.price) {
            payable(msg.sender).transfer(msg.value - listing.price);
        }
        
        emit ItemSold(
            _listingId,
            listing.nftContract,
            listing.tokenId,
            listing.seller,
            msg.sender,
            listing.price
        );
    }
    
    /**
     * @dev Core Function 3: Cancel a listing
     * @param _listingId ID of the listing to cancel
     */
    function cancelListing(uint256 _listingId) external nonReentrant {
        Listing storage listing = listings[_listingId];
        
        require(listing.active, "Listing is not active");
        require(
            listing.seller == msg.sender || msg.sender == owner(),
            "Only seller or owner can cancel listing"
        );
        
        listing.active = false;
        
        emit ListingCanceled(_listingId);
    }
    
    /**
     * @dev Get listing details
     * @param _listingId ID of the listing
     */
    function getListing(uint256 _listingId) external view returns (Listing memory) {
        return listings[_listingId];
    }
    
    /**
     * @dev Update marketplace fee (only owner)
     * @param _newFee New fee percentage (e.g., 300 = 3%)
     */
    function updateMarketplaceFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 1000, "Fee cannot exceed 10%"); // Max 10% fee
        marketplaceFee = _newFee;
    }
    
    /**
     * @dev Withdraw accumulated fees (only owner)
     */
    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(owner()).transfer(balance);
    }
    
    /**
     * @dev Check if a listing is active
     * @param _listingId ID of the listing
     */
    function isListingActive(uint256 _listingId) external view returns (bool) {
        return listings[_listingId].active;
    }
}
