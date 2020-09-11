pragma solidity ^0.6.0;

import {ERC20} from "./ERC20.sol";

contract NS is ERC20 {
    function decimals() public pure returns (uint8) {
        return 18;
    }

    function rounding() public pure returns (uint8) {
        return 2;
    }

    function name() public pure returns (string memory) {
        return "NetSepio";
    }

    function symbol() public pure returns (string memory) {
        return "NS";
    }
}
