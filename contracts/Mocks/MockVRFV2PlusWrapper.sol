// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IVRFV2PlusWrapper} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol";
import {VRFV2PlusWrapperConsumerBase} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";

contract MockVRFV2PlusWrapper is IVRFV2PlusWrapper {
    uint256 public constant CALLBACK_PRICE = 1e16;

    uint256 public requestId;
    address public treasureHunt;

    event WrapperFulfillmentFailed(uint256 indexed requestId, address indexed consumer);

    function calculateRequestPriceNative(uint32 _callbackGasLimit, uint32 _numWords)
        external
        view
        override
        returns (uint256)
    {
        return CALLBACK_PRICE;
    }

    function setTreasureHunt(address _treasureHunt) external {
        require(treasureHunt == address(0), "TreasureHunt Already Exists");
        treasureHunt = _treasureHunt;
    }

    function requestRandomWordsInNative(
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations,
        uint32 _numWords,
        bytes calldata extraArgs
    ) external payable override returns (uint256 _requestId) {
        require(msg.value >= CALLBACK_PRICE, "fee too low");
        _requestId = requestId + 1;
        requestId++;
        return _requestId;
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] calldata _randomWords) external {
        VRFV2PlusWrapperConsumerBase c;
        bytes memory resp = abi.encodeWithSelector(c.rawFulfillRandomWords.selector, _requestId, _randomWords);
        (bool success,) = treasureHunt.call{gas: 100000}(resp);
        require(success, "Call to TreasureHunt contract failed");

        if (!success) {
            emit WrapperFulfillmentFailed(_requestId, treasureHunt);
        }
    }

    function lastRequestId() external view returns (uint256) {
        return requestId;
    }

    function depositAmount() external payable {}

    function estimateRequestPrice(uint32, uint32, uint256) external view returns (uint256) {
        return CALLBACK_PRICE;
    }

    function estimateRequestPriceNative(uint32, uint32, uint256) external view returns (uint256) {
        return CALLBACK_PRICE;
    }

    function calculateRequestPrice(uint32, uint32) external view returns (uint256) {
        return CALLBACK_PRICE;
    }

    function link() external view returns (address) {
        return address(0);
    }

    function linkNativeFeed() external view returns (address) {
        return address(0);
    }
}
