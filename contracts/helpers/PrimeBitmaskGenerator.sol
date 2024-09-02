// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

contract PrimeBitmaskGenerator {
    // In Hex: 0x20208828828208a20a08a28ac
    uint256 public primeBitmask;

    constructor() {
        // Dynamically generate the bitmask for prime numbers between 0 and 100
        primeBitmask = generatePrimeBitmask();
    }

    /// @notice Generates the bitmask for prime numbers between 0 and 100
    /// @return The bitmask with bits set for prime numbers
    function generatePrimeBitmask() internal pure returns (uint256) {
        uint256 bitmap = 0;
        uint8[25] memory primes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97];

        for (uint8 i = 0; i < primes.length; i++) {
            bitmap |= (uint256(1) << primes[i]); // Set the bit for each prime
        }
        return bitmap;
    }

    /// @notice Checks if a number is a prime number between 0 and 100
    /// @param number The number to check
    /// @return isPrime Returns true if the number is a prime number between 0 and 100, otherwise false
    function isPrime(uint256 number) public view returns (bool) {
        require(number <= 100, "Number must be between 0 and 100 inclusive"); // Bounds check
        // Check if the bit corresponding to the number is set in the bitmask
        return (primeBitmask & (1 << number)) != 0;
    }
}
