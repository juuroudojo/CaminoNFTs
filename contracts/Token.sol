// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "";
import "";

contract Token is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol){
        
    }
}


