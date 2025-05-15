// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Interfaces
import { IERC7802NFT } from "interfaces/L2/IERC7802NFT.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ISemver } from "interfaces/universal/ISemver.sol";

/// @title ISuperchainERC721
/// @notice This interface is available on the ISuperchainERC721 contract.
/// @dev This interface is needed for the abstract ISuperchainERC721 implementation but is not part of the standard
interface ISuperchainERC721 is IERC7802NFT, IERC721, ISemver {
    error Unauthorized();

    function supportsInterface(bytes4 _interfaceId) external view returns (bool);

    function __constructor__() external;  // TODO what is this for?
}
