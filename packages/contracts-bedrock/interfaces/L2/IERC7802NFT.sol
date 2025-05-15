// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";

/// @title IERC7802NFT
/// @notice Defines the interface for crosschain ERC721 transfers.
interface IERC7802NFT is IERC165 {
    /// @notice Emitted when a crosschain transfer mints tokens.
    /// @param to       Address of the account tokens are being minted for.
    /// @param tokenId  TokenId of token minted.
    /// @param sender   Address of the account that finilized the crosschain transfer.
    event CrosschainMint(address indexed to, uint256 tokenId, address indexed sender);

    /// @notice Emitted when a crosschain transfer burns tokens.
    /// @param tokenId  TokenId of token minted.
    /// @param sender   Address of the account that initiated the crosschain transfer.
    event CrosschainBurn(uint256 tokenId, address indexed sender);

    /// @notice Mint tokens through a crosschain transfer.
    /// @param _to       Address to mint tokens to.
    /// @param _tokenId  TokenId of token minted.
    function crosschainMint(address _to, uint256 _tokenId) external;

    /// @notice Burn tokens through a crosschain transfer.
    /// @param _tokenId  TokenId of token minted.
    function crosschainBurn(uint256 _tokenId) external;
}
