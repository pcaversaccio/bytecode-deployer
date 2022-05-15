// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/**
 * @dev Error that occurs when the contract creation failed.
 * @param emitter The contract that emits the error.
 */
error Failed(address emitter);

/**
 * @title CREATE Deployer Smart Contract
 * @author Pascal Marco Caversaccio, pascal.caversaccio@hotmail.ch
 * @notice Helper smart contract to make easier and safer usage of the `CREATE` EVM opcode.
 * @dev Adjusted from here: https://github.com/safe-global/safe-contracts/blob/main/contracts/libraries/CreateCall.sol.
 */

contract DeployBytecode {
    /**
     * @dev Event that is emitted when a contract is successfully created.
     * @param newContract The address of the new contract.
     */
    event ContractCreation(address newContract);

    /**
     * @dev The function `deployBytecode` deploys a new contract via calling
     * the `CREATE` opcode and using the creation bytecode as input.
     * @param amount The value in wei to send to the new account. If `amount` is non-zero,
     * `bytecode` must have a `payable` constructor.
     * @param bytecode The creation bytecode.
     */
    function deployBytecode(uint256 amount, bytes memory bytecode)
        public
        returns (address newContract)
    {
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
    }
}
