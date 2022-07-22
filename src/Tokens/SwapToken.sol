// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract SwapToken is ERC20 {
    constructor() ERC20("SwapToken", "SWT") {
        _mint(msg.sender, 1_000_000_000 * 10 ** decimals());
    }
}