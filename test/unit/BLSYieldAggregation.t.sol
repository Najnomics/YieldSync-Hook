// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/avs/libraries/BLSYieldAggregation.sol";

contract BLSYieldAggregationUnitTest is Test {
    // Test data structures
    BLSYieldAggregation.YieldSubmission[] yieldSubmissions;
    BLSYieldAggregation.BLSSignature[] blsSignatures;
    
    // Test constants
    uint256 constant BASE_YIELD_RATE = 400; // 4%
    uint256 constant HIGH_YIELD_RATE = 800; // 8%
    address constant OPERATOR1 = address(0x1);
    address constant OPERATOR2 = address(0x2);
    
    function setUp() public {
        // Clear arrays for each test
        delete yieldSubmissions;
        delete blsSignatures;
    }

    // Helper function to create yield submission
    function createYieldSubmission(
        address lstToken,
        uint256 yieldRate,
        uint256 timestamp,
        address operator
    ) internal pure returns (BLSYieldAggregation.YieldSubmission memory) {
        return BLSYieldAggregation.YieldSubmission({
            lstToken: lstToken,
            yieldRate: yieldRate,
            timestamp: timestamp,
            operator: operator,
            proof: abi.encodePacked(keccak256(abi.encodePacked(lstToken, yieldRate, timestamp)))
        });
    }

    // Helper function to create BLS signature
    function createBLSSignature() internal pure returns (BLSYieldAggregation.BLSSignature memory) {
        return BLSYieldAggregation.BLSSignature({
            signature: [uint256(1), uint256(2)],
            pubkey: [uint256(1), uint256(2), uint256(3), uint256(4)]
        });
    }

    // Basic Aggregation Tests (10 tests)
    function test_AggregateYieldData_SingleSubmission() public {
        address token = makeAddr("stETH");
        yieldSubmissions.push(createYieldSubmission(token, BASE_YIELD_RATE, block.timestamp, OPERATOR1));
        blsSignatures.push(createBLSSignature());
        
        BLSYieldAggregation.AggregatedYieldData memory result = 
            BLSYieldAggregation.aggregateYieldData(yieldSubmissions, blsSignatures);
        
        assertEq(result.lstToken, token);
        assertEq(result.submissionCount, 1);
    }

    function test_AggregateYieldData_MultipleSubmissions() public {
        address token = makeAddr("stETH");
        yieldSubmissions.push(createYieldSubmission(token, BASE_YIELD_RATE, block.timestamp, OPERATOR1));
        yieldSubmissions.push(createYieldSubmission(token, HIGH_YIELD_RATE, block.timestamp, OPERATOR2));
        blsSignatures.push(createBLSSignature());
        blsSignatures.push(createBLSSignature());
        
        BLSYieldAggregation.AggregatedYieldData memory result = 
            BLSYieldAggregation.aggregateYieldData(yieldSubmissions, blsSignatures);
        
        assertEq(result.submissionCount, 2);
        assertGt(result.consensusYieldRate, 0);
    }

    function test_AggregateYieldData_EmptyArrays() public {
        vm.expectRevert("BLS: no submissions");
        BLSYieldAggregation.aggregateYieldData(yieldSubmissions, blsSignatures);
    }

    function test_AggregateYieldData_MismatchedLengths() public {
        address token = makeAddr("stETH");
        yieldSubmissions.push(createYieldSubmission(token, BASE_YIELD_RATE, block.timestamp, OPERATOR1));
        // Don't add signature - length mismatch
        
        vm.expectRevert("BLS: length mismatch");
        BLSYieldAggregation.aggregateYieldData(yieldSubmissions, blsSignatures);
    }

    function test_YieldSubmission_StructFields() public {
        address token = makeAddr("stETH");
        BLSYieldAggregation.YieldSubmission memory submission = 
            createYieldSubmission(token, BASE_YIELD_RATE, block.timestamp, OPERATOR1);
        
        assertEq(submission.lstToken, token);
        assertEq(submission.yieldRate, BASE_YIELD_RATE);
        assertEq(submission.operator, OPERATOR1);
        assertGt(submission.proof.length, 0);
    }

    function test_BLSSignature_StructFields() public {
        BLSYieldAggregation.BLSSignature memory sig = createBLSSignature();
        
        assertEq(sig.signature[0], 1);
        assertEq(sig.signature[1], 2);
        assertEq(sig.pubkey[0], 1);
        assertEq(sig.pubkey[3], 4);
    }

    function test_AggregatedYieldData_DefaultValues() public {
        address token = makeAddr("stETH");
        yieldSubmissions.push(createYieldSubmission(token, BASE_YIELD_RATE, block.timestamp, OPERATOR1));
        blsSignatures.push(createBLSSignature());
        
        BLSYieldAggregation.AggregatedYieldData memory result = 
            BLSYieldAggregation.aggregateYieldData(yieldSubmissions, blsSignatures);
        
        assertEq(result.lstToken, token);
        assertGt(result.timestamp, 0);
        assertNotEq(result.dataHash, bytes32(0));
    }

    function test_MultipleOperators_SameToken() public {
        address token = makeAddr("stETH");
        yieldSubmissions.push(createYieldSubmission(token, BASE_YIELD_RATE, block.timestamp, OPERATOR1));
        yieldSubmissions.push(createYieldSubmission(token, BASE_YIELD_RATE, block.timestamp, OPERATOR2));
        blsSignatures.push(createBLSSignature());
        blsSignatures.push(createBLSSignature());
        
        BLSYieldAggregation.AggregatedYieldData memory result = 
            BLSYieldAggregation.aggregateYieldData(yieldSubmissions, blsSignatures);
        
        assertEq(result.submissionCount, 2);
        assertEq(result.lstToken, token);
    }

    function test_YieldSubmission_ProofGeneration() public {
        address token = makeAddr("stETH");
        uint256 yieldRate = BASE_YIELD_RATE;
        uint256 timestamp = block.timestamp;
        
        BLSYieldAggregation.YieldSubmission memory submission = 
            createYieldSubmission(token, yieldRate, timestamp, OPERATOR1);
        
        bytes memory expectedProof = abi.encodePacked(keccak256(abi.encodePacked(token, yieldRate, timestamp)));
        assertEq(submission.proof, expectedProof);
    }

    function test_BLSSignature_ArrayLengths() public {
        BLSYieldAggregation.BLSSignature memory sig = createBLSSignature();
        
        // Signature should be length 2 (G1 point)
        assertEq(sig.signature.length, 2);
        // Pubkey should be length 4 (G2 point)
        assertEq(sig.pubkey.length, 4);
    }
}