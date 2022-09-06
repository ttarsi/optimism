// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

contract BypassSender {
    constructor(address _recipient) payable {
        selfdestruct(payable(_recipient));
    }
}

contract StaticSender {
    function send(address _recipient) public {
        new BypassSender{ value: address(this).balance }(_recipient);
    }
}
