// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Testing utilities
import { Test } from "forge-std/Test.sol";

// Libraries
import { Predeploys } from "src/libraries/Predeploys.sol";
import { IL2ToL2CrossDomainMessenger } from "interfaces/L2/IL2ToL2CrossDomainMessenger.sol";

// Target contract
import { SuperchainNFTBridge } from "src/L2/SuperchainNFTBridge.sol";
import { ISuperchainNFTBridge } from "interfaces/L2/ISuperchainNFTBridge.sol";
import { ISuperchainERC721 } from "interfaces/L2/ISuperchainERC721.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC7802NFT } from "interfaces/L2/IERC7802NFT.sol";
import { MockSuperchainERC721Implementation } from "test/mocks/SuperchainERC721Implementation.sol";

/// @title SuperchainNFTBridgeTest
/// @notice Contract for testing the SuperchainNFTBridge contract.
contract SuperchainNFTBridgeTest is Test {
    address internal constant ZERO_ADDRESS = address(0);
    string internal constant NAME = "SuperchainERC721";
    string internal constant SYMBOL = "OSE";
    address internal constant REMOTE_TOKEN = address(0x123);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event SendERC721(address indexed token, address indexed to, uint256 tokenId, uint256 destination);

    event RelayERC721(address indexed token, address indexed to, uint256 tokenId, uint256 source);

    ISuperchainERC721 public superchainERC721;
    ISuperchainNFTBridge public superchainNFTBridge;

    /// @notice Sets up the test suite.
    function setUp() public {
        vm.etch(Predeploys.SUPERCHAIN_NFT_BRIDGE, address(new SuperchainNFTBridge()).code);
        superchainNFTBridge = ISuperchainNFTBridge(Predeploys.SUPERCHAIN_NFT_BRIDGE);
        superchainERC721 = ISuperchainERC721(address(new MockSuperchainERC721Implementation()));

        // Skip the initialization until OptimismSuperchainERC721Factory is integrated again
        // superchainERC721 = ISuperchainERC721(
        //     IOptimismSuperchainERC721Factory(Predeploys.OPTIMISM_SUPERCHAIN_ERC721_FACTORY).deploy(
        //         REMOTE_TOKEN, NAME, SYMBOL
        //     )
        // );
    }

    /// @notice Helper function to setup a mock and expect a call to it.
    function _mockAndExpect(address _receiver, bytes memory _calldata, bytes memory _returned) internal {
        vm.mockCall(_receiver, _calldata, _returned);
        vm.expectCall(_receiver, _calldata);
    }

    /// @notice Tests the `sendERC721` function reverts when the address `_to` is zero.
    function testFuzz_sendERC721_zeroAddressTo_reverts(address _sender, uint256 _tokenId, uint256 _chainId) public {
        // Expect the revert with `ZeroAddress` selector
        vm.expectRevert(ISuperchainNFTBridge.ZeroAddress.selector);

        // Call the `sendERC721` function with the zero address as `_to`
        vm.prank(_sender);
        superchainNFTBridge.sendERC721(address(superchainERC721), ZERO_ADDRESS, _tokenId, _chainId);
    }

    /// @notice Tests the `sendERC721` function reverts when the `token` does not support the IERC7802NFT interface.
    function testFuzz_sendERC721_notSupportedIERC7802NFT_reverts(
        address _token,
        address _sender,
        address _to,
        uint256 _tokenId,
        uint256 _chainId
    )
        public
    {
        vm.assume(_to != ZERO_ADDRESS);
        assumeAddressIsNot(_token, AddressType.Precompile, AddressType.ForgeAddress);

        // Mock the call over the `supportsInterface` function to return false
        vm.mockCall(
            _token,
            abi.encodeCall(ISuperchainERC721.supportsInterface, (type(IERC7802NFT).interfaceId)),
            abi.encode(false)
        );

        // Expect the revert with `InvalidERC7802` selector
        vm.expectRevert(ISuperchainNFTBridge.InvalidERC7802.selector);

        // Call the `sendERC721` function
        vm.prank(_sender);
        superchainNFTBridge.sendERC721(_token, _to, _tokenId, _chainId);
    }

    /// @notice Tests the `sendERC721` function burns the sender tokens, sends the message, and emits the `SendERC721`
    /// event.
    function testFuzz_sendERC721_succeeds(
        address _sender,
        address _to,
        uint256 _tokenId,
        uint256 _chainId,
        bytes32 _msgHash
    )
        external
    {
        // Ensure `_sender` and `_to` is not the zero address
        vm.assume(_sender != ZERO_ADDRESS);
        vm.assume(_to != ZERO_ADDRESS);

        // Mint some tokens to the sender so then they can be sent
        vm.prank(Predeploys.SUPERCHAIN_NFT_BRIDGE);
        superchainERC721.crosschainMint(_sender, _tokenId);
        assertEq(superchainERC721.ownerOf(_tokenId), _sender);

        // Get the balance of `_sender` before the send to compare later on the assertions
        uint256 _senderBalanceBefore = IERC721(address(superchainERC721)).balanceOf(_sender);

        // Look for the emit of the `Transfer` event
        vm.expectEmit(address(superchainERC721));
        emit IERC721.Transfer(_sender, ZERO_ADDRESS, _tokenId);

        // Look for the emit of the `SendERC721` event
        vm.expectEmit(address(superchainNFTBridge));
        emit SendERC721(address(superchainERC721), _to, _tokenId, _chainId);

        // Mock the call over the `sendMessage` function and expect it to be called properly
        bytes memory _message =
            abi.encodeCall(superchainNFTBridge.relayERC721, (address(superchainERC721), _to, _tokenId));
        _mockAndExpect(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER,
            abi.encodeCall(IL2ToL2CrossDomainMessenger.sendMessage, (_chainId, address(superchainNFTBridge), _message)),
            abi.encode(_msgHash)
        );

        // Call the `sendERC721` function
        vm.prank(_sender);
        bytes32 _returnedMsgHash = superchainNFTBridge.sendERC721(address(superchainERC721), _to, _tokenId, _chainId);

        // Check the message hash was generated correctly
        assertEq(_msgHash, _returnedMsgHash);

        // Check the total supply and balance of `_sender` after the send were updated correctly
        vm.expectRevert("ERC721: invalid token ID");
        IERC721(address(superchainERC721)).ownerOf(_tokenId);
        assertEq(IERC721(address(superchainERC721)).balanceOf(_sender), _senderBalanceBefore - 1);
    }

    /// @notice Tests the `relayERC721` function reverts when the caller is not the L2ToL2CrossDomainMessenger.
    function testFuzz_relayERC721_notMessenger_reverts(
        address _token,
        address _caller,
        address _to,
        uint256 _tokenId
    )
        public
    {
        // Ensure the caller is not the messenger
        vm.assume(_caller != Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER);

        // Expect the revert with `Unauthorized` selector
        vm.expectRevert(ISuperchainNFTBridge.Unauthorized.selector);

        // Call the `relayERC721` function with the non-messenger caller
        vm.prank(_caller);
        superchainNFTBridge.relayERC721(_token, _to, _tokenId);
    }

    /// @notice Tests the `relayERC721` function reverts when the `crossDomainMessageSender` that sent the message is
    /// not
    /// the same SuperchainNFTBridge.
    function testFuzz_relayERC721_notCrossDomainSender_reverts(
        address _crossDomainMessageSender,
        uint256 _source,
        address _to,
        uint256 _tokenId
    )
        public
    {
        vm.assume(_crossDomainMessageSender != address(superchainNFTBridge));

        // Mock the call over the `crossDomainMessageContext` function setting a wrong sender
        vm.mockCall(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER,
            abi.encodeCall(IL2ToL2CrossDomainMessenger.crossDomainMessageContext, ()),
            abi.encode(_crossDomainMessageSender, _source)
        );

        // Expect the revert with `InvalidCrossDomainSender` selector
        vm.expectRevert(ISuperchainNFTBridge.InvalidCrossDomainSender.selector);

        // Call the `relayERC721` function with the sender caller
        vm.prank(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER);
        superchainNFTBridge.relayERC721(address(superchainERC721), _to, _tokenId);
    }

    /// @notice Tests the `relayERC721` mints the proper amount and emits the `RelayERC721` event.
    function testFuzz_relayERC721_succeeds(address _to, uint256 _tokenId, uint256 _source) public {
        vm.assume(_to != ZERO_ADDRESS);

        // Mock the call over the `crossDomainMessageContext` function setting the same address as value
        _mockAndExpect(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER,
            abi.encodeCall(IL2ToL2CrossDomainMessenger.crossDomainMessageContext, ()),
            abi.encode(address(superchainNFTBridge), _source)
        );

        // Get the total supply and balance of `_to` before the relay to compare later on the assertions
        vm.expectRevert("ERC721: invalid token ID");
        IERC721(address(superchainERC721)).ownerOf(_tokenId);
        uint256 _toBalanceBefore = IERC721(address(superchainERC721)).balanceOf(_to);

        // Look for the emit of the `Transfer` event
        vm.expectEmit(address(superchainERC721));
        emit IERC721.Transfer(ZERO_ADDRESS, _to, _tokenId);

        vm.expectEmit(address(superchainERC721));
        emit IERC7802NFT.CrosschainMint(_to, _tokenId, address(superchainNFTBridge));

        // Look for the emit of the `RelayERC721` event
        vm.expectEmit(address(superchainNFTBridge));
        emit RelayERC721(address(superchainERC721), _to, _tokenId, _source);

        // Call the `relayERC721` function with the messenger caller
        vm.prank(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER);
        superchainNFTBridge.relayERC721(address(superchainERC721), _to, _tokenId);

        // Check the total supply and balance of `_to` after the relay were updated correctly
        assertEq(superchainERC721.ownerOf(_tokenId), _to);
        assertEq(IERC721(address(superchainERC721)).balanceOf(_to), _toBalanceBefore + 1);
    }
}
