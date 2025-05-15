// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Testing utilities
import { Test } from "forge-std/Test.sol";

// Libraries
import { Predeploys } from "src/libraries/Predeploys.sol";

// Target contract
import { SuperchainERC721 } from "src/L2/SuperchainERC721.sol";
import { IERC7802NFT, IERC165 } from "interfaces/L2/IERC7802NFT.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ISuperchainERC721 } from "interfaces/L2/ISuperchainERC721.sol";
import { MockSuperchainERC721Implementation } from "test/mocks/SuperchainERC721Implementation.sol";

/// @title SuperchainERC721Test
/// @notice Contract for testing the SuperchainERC721 contract.
contract SuperchainERC721Test is Test {
    address internal constant ZERO_ADDRESS = address(0);
    address internal constant SUPERCHAIN_NFT_BRIDGE = Predeploys.SUPERCHAIN_NFT_BRIDGE;
    address internal constant MESSENGER = Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER;

    SuperchainERC721 public superchainERC721;

    /// @notice Sets up the test suite.
    function setUp() public {
        superchainERC721 = new MockSuperchainERC721Implementation();
    }

    /// @notice Helper function to setup a mock and expect a call to it.
    function _mockAndExpect(address _receiver, bytes memory _calldata, bytes memory _returned) internal {
        vm.mockCall(_receiver, _calldata, _returned);
        vm.expectCall(_receiver, _calldata);
    }

    /// @notice Tests the `mint` function reverts when the caller is not the bridge.
    function testFuzz_crosschainMint_callerNotBridge_reverts(address _caller, address _to, uint256 _tokenId) public {
        // Ensure the caller is not the bridge
        vm.assume(_caller != SUPERCHAIN_NFT_BRIDGE);

        // Expect the revert with `Unauthorized` selector
        vm.expectRevert(ISuperchainERC721.Unauthorized.selector);

        // Call the `mint` function with the non-bridge caller
        vm.prank(_caller);
        superchainERC721.crosschainMint(_to, _tokenId);
    }

    /// @notice Tests the `mint` succeeds and emits the `Mint` event.
    function testFuzz_crosschainMint_succeeds(address _to, uint256 _tokenId) public {
        // Ensure `_to` is not the zero address
        vm.assume(_to != ZERO_ADDRESS);

        // Get the total supply and balance of `_to` before the mint to compare later on the assertions
        vm.expectRevert("ERC721: invalid token ID");
        superchainERC721.ownerOf(_tokenId);
        uint256 _toBalanceBefore = superchainERC721.balanceOf(_to);

        // Look for the emit of the `Transfer` event
        vm.expectEmit(address(superchainERC721));
        emit IERC721.Transfer(ZERO_ADDRESS, _to, _tokenId);

        // Look for the emit of the `CrosschainMint` event
        vm.expectEmit(address(superchainERC721));
        emit IERC7802NFT.CrosschainMint(_to, _tokenId, SUPERCHAIN_NFT_BRIDGE);

        // Call the `mint` function with the bridge caller
        vm.prank(SUPERCHAIN_NFT_BRIDGE);
        superchainERC721.crosschainMint(_to, _tokenId);

        // Check the total supply and balance of `_to` after the mint were updated correctly
        assertEq(superchainERC721.ownerOf(_tokenId), _to);
        assertEq(superchainERC721.balanceOf(_to), _toBalanceBefore + 1);
    }

    /// @notice Tests the `burn` function reverts when the caller is not the bridge.
    function testFuzz_crosschainBurn_callerNotBridge_reverts(address _caller, uint256 _tokenId) public {
        // Ensure the caller is not the bridge
        vm.assume(_caller != SUPERCHAIN_NFT_BRIDGE);

        // Expect the revert with `Unauthorized` selector
        vm.expectRevert(ISuperchainERC721.Unauthorized.selector);

        // Call the `burn` function with the non-bridge caller
        vm.prank(_caller);
        superchainERC721.crosschainBurn(_tokenId);
    }

    /// @notice Tests the `burn` burns the amount and emits the `CrosschainBurn` event.
    function testFuzz_crosschainBurn_succeeds(address _owner, uint256 _tokenId) public {
        // Ensure `_owner` is not the zero address
        vm.assume(_owner != ZERO_ADDRESS);

        // Mint some tokens to `_owner` so then they can be burned
        vm.prank(SUPERCHAIN_NFT_BRIDGE);
        superchainERC721.crosschainMint(_owner, _tokenId);
        address _ownerBefore = superchainERC721.ownerOf(_tokenId);
        assertEq(_ownerBefore, _owner);

        // Get the balance of `_owner` before the burn to compare later on the assertions
        uint256 _ownerBalanceBefore = superchainERC721.balanceOf(_owner);

        // // Look for the emit of the `Transfer` event
        vm.expectEmit(address(superchainERC721));
        emit IERC721.Transfer(_owner, ZERO_ADDRESS, _tokenId);

        // Look for the emit of the `CrosschainBurn` event
        vm.expectEmit(address(superchainERC721));
        emit IERC7802NFT.CrosschainBurn(_tokenId, SUPERCHAIN_NFT_BRIDGE);

        // Call the `burn` function with the bridge caller
        vm.prank(SUPERCHAIN_NFT_BRIDGE);
        superchainERC721.crosschainBurn(_tokenId);

        // Check the total supply and balance of `_owner` after the burn were updated correctly
        vm.expectRevert("ERC721: invalid token ID");
        superchainERC721.ownerOf(_tokenId);
        assertEq(superchainERC721.balanceOf(_owner), _ownerBalanceBefore - 1);
    }

    /// @notice Tests that the `supportsInterface` function returns true for the `IERC7802NFT` interface.
    function test_supportInterface_succeeds() public view {
        assertTrue(superchainERC721.supportsInterface(type(IERC165).interfaceId));
        assertTrue(superchainERC721.supportsInterface(type(IERC7802NFT).interfaceId));
        assertTrue(superchainERC721.supportsInterface(type(IERC721).interfaceId));
    }

    /// @notice Tests that the `supportsInterface` function returns false for any other interface than the
    /// `IERC7802NFT` one.
    function testFuzz_supportInterface_works(bytes4 _interfaceId) public view {
        vm.assume(_interfaceId != type(IERC165).interfaceId);
        vm.assume(_interfaceId != type(IERC7802NFT).interfaceId);
        vm.assume(_interfaceId != type(IERC721).interfaceId);
        assertFalse(superchainERC721.supportsInterface(_interfaceId));
    }
}
