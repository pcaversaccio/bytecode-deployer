// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/**
 * @dev Error that occurs when the contract creation failed.
 * @param emitter The contract that emits the error.
 */
error Failed(address emitter);

/**
 * @dev Error that occurs when the factory contract has insufficient balance.
 * @param emitter The contract that emits the error.
 */
error InsufficientBalance(address emitter);

/**
 * @dev Error that occurs when the bytecode length is zero.
 * @param emitter The contract that emits the error.
 */
error ZeroBytecodeLength(address emitter);

/**
 * @title CREATE Deployer Smart Contract
 * @author Pascal Marco Caversaccio, pascal.caversaccio@hotmail.ch
 * @notice Helper smart contract to make easier and safer usage of the `CREATE` EVM opcode.
 * @dev Adjusted from here: https://github.com/safe-global/safe-contracts/blob/main/contracts/libraries/CreateCall.sol.
 */

contract Create {
    /**
     * @dev Event that is emitted when a contract is successfully created.
     * @param newContract The address of the new contract.
     */
    event ContractCreation(address newContract);

    /**
     * @dev The function `deploy` deploys a new contract via calling
     * the `CREATE` opcode and using the creation bytecode as input.
     * @param amount The value in wei to send to the new account. If `amount` is non-zero,
     * `bytecode` must have a `payable` constructor.
     * @param bytecode The creation bytecode.
     */
    function deploy(uint256 amount, bytes memory bytecode)
        public
        returns (address newContract)
    {
        if (address(this).balance < amount)
            revert InsufficientBalance(address(this));
        if (bytecode.length == 0) revert ZeroBytecodeLength(address(this));
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            /** @dev `CREATE` opcode
             *
             * Stack input
             * ------------
             * value: value in wei to send to the new account.
             * offset: byte offset in the memory in bytes, the instructions of the new account.
             * size: byte size to copy (size of the instructions).
             *
             * Stack output
             * ------------
             * address: the address of the deployed contract.
             *
             * How are bytes stored in Solidity:
             * In memory the `bytes` is stored by having first the length of the `bytes` and then the data,
             * this results in the following schema: `<32-bytes length><data>` at the location where bytecode points to.
             *
             * Now if we want to use the data with `CREATE`, we first point to the start of the raw data, which is after the length.
             * Therefore, we add 32 (the space required for the length) to the location stored in the bytecode variable.
             * This is the first parameter. For the second parameter, we read the length from memory using `mload`.
             * As the length is the first 32 bytes at the location of `bytecode`, we can read the length by calling `mload(bytecode)`.
             */
            newContract := create(amount, add(bytecode, 0x20), mload(bytecode))
        }
        if (newContract == address(0)) revert Failed(address(this));
        emit ContractCreation(newContract);
        return newContract;
    }

    /**
     * @dev Returns the address where a contract will be stored if deployed via `deploy`.
     * For the specification of the Recursive Length Prefix (RLP) encoding scheme, please
     * refer to p. 19 of the Ethereum Yellow Paper (https://ethereum.github.io/yellowpaper/paper.pdf)
     * and the Ethereum Wiki (https://eth.wiki/fundamentals/rlp). For further insights also, see the
     * following issue: https://github.com/Rari-Capital/solmate/issues/207.
     *
     * Based on the EIP-161 (https://github.com/ethereum/EIPs/blob/master/EIPS/eip-161.md) specification,
     * all contract accounts on the Ethereum mainnet are initiated with `nonce = 1`.
     * Thus, the first contract address created by another contract is calculated with a non-zero nonce.
     */
    // prettier-ignore
    function computeAddress(address addr, uint256 nonce) public pure returns (address) {
        bytes memory data;
        bytes1 len = bytes1(0x94);

        if (nonce == 0x00) data = abi.encodePacked(bytes1(0xd6), len, addr, bytes1(0x80));
        else if (nonce <= 0x7f) data = abi.encodePacked(bytes1(0xd6), len, addr, uint8(nonce));
        else if (nonce <= type(uint8).max) data = abi.encodePacked(bytes1(0xd7), len, addr, bytes1(0x81), uint8(nonce));
        else if (nonce <= type(uint16).max) data = abi.encodePacked(bytes1(0xd8), len, addr, bytes1(0x82), uint16(nonce));
        else if (nonce <= type(uint24).max) data = abi.encodePacked(bytes1(0xd9), len, addr, bytes1(0x83), uint24(nonce));

        /**
         * @dev In the case of `nonce > type(uint24).max`, we have the following encoding scheme:
         * 0xda = 0xc0 (short RLP prefix) + 0x16 (length of: 0x94 ++ address ++ 0x84 ++ nonce),
         * 0x94 = 0x80 + 0x14 (0x14 = the length of an address, 20 bytes, in hex),
         * 0x84 = 0x80 + 0x04 (0x04 = the bytes length of the nonce, 4 bytes, in hex).
         * We assume nobody can have a nonce large enough to require more than 4 bytes.
         */
        else data = abi.encodePacked(bytes1(0xda), len, addr, bytes1(0x84), uint32(nonce));

        return address(uint160(uint256(keccak256(data))));
    }

    /**
     * @dev Receive function to enable deployments of `bytecode` with a `payable` constructor.
     */
    receive() external payable {}
}
