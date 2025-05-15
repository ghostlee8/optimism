// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// Contracts
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Libraries
import { Predeploys } from "src/libraries/Predeploys.sol";
import { Unauthorized } from "src/libraries/errors/CommonErrors.sol";

// Interfaces
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ISemver } from "interfaces/universal/ISemver.sol";
import { IERC7802NFT, IERC165 } from "interfaces/L2/IERC7802NFT.sol";

/// @title SuperchainERC721
/// @notice A standard ERC721 extension implementing IERC7802 for unified cross-chain fungibility
///         across the Superchain. Gives the SuperchainNFTBridge mint and burn permissions.
abstract contract SuperchainERC721 is ERC721, IERC7802NFT, ISemver {
    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        // solhint-disable-previous-line no-empty-blocks
    }

    /// @notice Semantic version.
    /// @custom:semver 1.0.2
    function version() external view virtual returns (string memory) {
        return "1.0.2";
    }

    /// @notice Allows the SuperchainNFTBridge to mint tokens.
    /// @param _to      Address to mint tokens to.
    /// @param _tokenId Id of token to mint.
    function crosschainMint(address _to, uint256 _tokenId) external {
        if (msg.sender != Predeploys.SUPERCHAIN_NFT_BRIDGE) revert Unauthorized();

        _mint(_to, _tokenId);

        emit CrosschainMint(_to, _tokenId, msg.sender);
    }

    /// @notice Allows the SuperchainNFTBridge to burn tokens.
    /// @param _tokenId Amount of tokens to burn.
    function crosschainBurn(uint256 _tokenId) external {
        if (msg.sender != Predeploys.SUPERCHAIN_NFT_BRIDGE) revert Unauthorized();

        _burn(_tokenId);

        emit CrosschainBurn(_tokenId, msg.sender);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 _interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return _interfaceId == type(IERC7802NFT).interfaceId || _interfaceId == type(IERC721).interfaceId
            || _interfaceId == type(IERC165).interfaceId;
    }
}
