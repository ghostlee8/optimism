// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Libraries
import { Predeploys } from "src/libraries/Predeploys.sol";
import { ZeroAddress, Unauthorized } from "src/libraries/errors/CommonErrors.sol";

// Interfaces
import { ISuperchainERC721 } from "interfaces/L2/ISuperchainERC721.sol";
import { IERC7802NFT, IERC165 } from "interfaces/L2/IERC7802NFT.sol";
import { IL2ToL2CrossDomainMessenger } from "interfaces/L2/IL2ToL2CrossDomainMessenger.sol";

/// @custom:proxied true
/// @custom:predeploy 0x4200000000000000000000000000000000000029
/// @title SuperchainNFTBridge
/// @notice The SuperchainNFTBridge allows for the bridging of ERC721 tokens to make them transferrable across the
///         Superchain. It builds on top of the L2ToL2CrossDomainMessenger for both replay protection and domain
///         binding.
contract SuperchainNFTBridge {
    /// @notice Thrown when attempting to relay a message and the cross domain message sender is not the
    /// SuperchainTokenBridge.
    error InvalidCrossDomainSender();

    /// @notice Thrown when attempting to use a token that does not implement the ERC7802 interface.
    error InvalidERC7802();

    /// @notice Emitted when tokens are sent from one chain to another.
    /// @param token         Address of the token sent.
    /// @param to            Address of the recipient.
    /// @param tokenId        Number of tokens sent.
    /// @param destination   Chain ID of the destination chain.
    event SendERC721(address indexed token, address indexed to, uint256 tokenId, uint256 destination);

    /// @notice Emitted whenever tokens are successfully relayed on this chain.
    /// @param token         Address of the token relayed.
    /// @param to            Address of the recipient.
    /// @param tokenId        Amount of tokens relayed.
    /// @param source        Chain ID of the source chain.
    event RelayERC721(address indexed token, address indexed to, uint256 tokenId, uint256 source);

    /// @notice Address of the L2ToL2CrossDomainMessenger Predeploy.
    address internal constant MESSENGER = Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER;

    /// @notice Semantic version.
    /// @custom:semver 1.0.2
    string public constant version = "1.0.2";

    // TODO QUESTION HACK: should this make sure the token is being sent only by the token owner? Or approval fine?
    /// @notice Sends tokens to a target address on another chain.
    /// @dev Tokens are burned on the source chain.
    /// @param _nft      Token to send.
    /// @param _to       Address to send tokens to.
    /// @param _tokenId  tokenId to send.
    /// @param _chainId  Chain ID of the destination chain.
    /// @return msgHash_ Hash of the message sent.
    function sendERC721(
        address _nft,
        address _to,
        uint256 _tokenId,
        uint256 _chainId
    )
        external
        returns (bytes32 msgHash_)
    {
        if (_to == address(0)) revert ZeroAddress();

        if (!IERC165(_nft).supportsInterface(type(IERC7802NFT).interfaceId)) revert InvalidERC7802();

        ISuperchainERC721(_nft).crosschainBurn(_tokenId);

        bytes memory message = abi.encodeCall(this.relayERC721, (_nft, _to, _tokenId));
        msgHash_ = IL2ToL2CrossDomainMessenger(MESSENGER).sendMessage(_chainId, address(this), message);

        emit SendERC721(_nft, _to, _tokenId, _chainId);
    }

    /// @notice Relays tokens received from another chain.
    /// @dev Tokens are minted on the destination chain.
    /// @param _nft      NFT to relay.
    /// @param _to       Address to relay tokens to.
    /// @param _tokenId  Amount of tokens to relay.
    function relayERC721(address _nft, address _to, uint256 _tokenId) external {
        if (msg.sender != MESSENGER) revert Unauthorized();

        (address crossDomainMessageSender, uint256 source) =
            IL2ToL2CrossDomainMessenger(MESSENGER).crossDomainMessageContext();

        if (crossDomainMessageSender != address(this)) revert InvalidCrossDomainSender();

        ISuperchainERC721(_nft).crosschainMint(_to, _tokenId);

        emit RelayERC721(_nft, _to, _tokenId, source);
    }
}
