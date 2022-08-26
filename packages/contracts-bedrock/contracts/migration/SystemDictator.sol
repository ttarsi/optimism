// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { L1CrossDomainMessenger } from "../L1/L1CrossDomainMessenger.sol";
import { L1StandardBridge } from "../L1/L1StandardBridge.sol";
import { OptimismPortal } from "../L1/OptimismPortal.sol";
import { L2OutputOracle } from "../L1/L2OutputOracle.sol";
import { Proxy } from "../universal/Proxy.sol";
import { ProxyAdmin } from "../universal/ProxyAdmin.sol";
import { OptimismMintableERC20Factory } from "../universal/OptimismMintableERC20Factory.sol";
import { AddressManager } from "../legacy/AddressManager.sol";
import { L1ChugSplashProxy } from "../legacy/L1ChugSplashProxy.sol";

contract SystemDictator is Ownable {
    struct L2OutputOracleConfig {
        bytes32 genesisL2Output;
        uint256 startingBlockNumber;
        address proposer;
        address owner;
    }

    struct Config {
        address owner;
        address multisig;
        bytes32[] zeroslots;

        // Existing contracts
        L1CrossDomainMessenger l1CrossDomainMessenger;
        L1StandardBridge l1StandardBridge;
        AddressManager addressManager;
        ProxyAdmin proxyAdmin;

        // New proxies
        Proxy proxyOptimismMintableERC20Factory;
        Proxy proxyL2OutputOracle;
        Proxy proxyOptimismPortal;

        // New implementations
        L1CrossDomainMessenger implL1CrossDomainMessenger;
        L1StandardBridge implL1StandardBridge;
        OptimismMintableERC20 implOptimismMintableERC20Factory;
        L2OutputOracle implL2OutputOracle;
        OptimismPortal implOptimismPortal;

        // Initialization config
        L2OutputOracleConfig l2OutputOracleConfig;
    }

    Config public config;

    constructor(Config memory _config) Ownable() {
        transferOwnership(_config.owner);
    }

    function step1() public onlyOwner() {
        // Pause the L1CrossDomainMessenger
        config.l1CrossDomainMessenger.pause();

        // Remove all dead addresses from the AddressManager
        string[] memory deads = [
            "Proxy__OVM_L1CrossDomainMessenger",
            "Proxy__OVM_L1StandardBridge",
            "OVM_CanonicalTransactionChain",
            "OVM_L2CrossDomainMessenger",
            "OVM_DecompressionPrecompileAddress",
            "OVM_Sequencer",
            "OVM_Proposer",
            "OVM_ChainStorageContainer-CTC-batches",
            "OVM_ChainStorageContainer-CTC-queue",
            "OVM_CanonicalTransactionChain",
            "OVM_StateCommitmentChain",
            "OVM_BondManager",
            "OVM_ExecutionManager",
            "OVM_FraudVerifier",
            "OVM_StateManagerFactory",
            "OVM_StateTransitionerFactory",
            "OVM_SafetyChecker",
            "OVM_L1MultiMessageRelayer"
        ];

        for (uint256 i = 0; i < deads.length; i++) {
            config.addressManager.setAddress(deads[i], address(0));
        }
    }

    function step2() public onlyOwner {
        // TODO: Zero out storage by upgrading contracts to temporary impls
        for (uint256 i = 0; i < zeroslots.length; i++) {

        }
    }

    function step3() public onlyOwner {
        // Configure ProxyAdmin
        config.proxyAdmin.setAddressManager(config.addressManager);
        config.proxyAdmin.setProxyType(address(config.l1CrossDomainMessenger), ProxyAdmin.ProxyType.RESOLVED);
        config.proxyAdmin.setProxyType(address(config.l1StandardBridge), ProxyAdmin.ProxyType.CHUGSPLASH);
        config.proxyAdmin.setImplementationName(address(config.l1CrossDomainMessenger), "OVM_L1CrossDomainMessenger");

        // Transfer ownership of AddressManager to ProxyAdmin
        config.addressManager.transferOwnership(address(config.proxyAdmin));

        // Transfer ownership of L1StandardBridge to ProxyAdmin
        L1ChugSplashProxy(config.l1StandardBridge).setOwner(address(config.proxyAdmin));
    }

    function step4() public onlyOwner {
        // Upgrade the OptimismMintableERC20Factory
        config.proxyAdmin.upgrade(
            address(config.proxyOptimismMintableERC20Factory),
            address(config.implOptimismMintableERC20Factory)
        );

        // Upgrade the L2OutputOracle and call initialize()
        config.proxyAdmin.upgradeAndCall(
            address(config.proxyL2OutputOracle),
            address(config.implL2OutputOracle),
            abi.encodeCall(
                L2OutputOracle.initialize,
                config.l2OutputOracleConfig.genesisL2Output,
                config.l2OutputOracleConfig.startingBlockNumber,
                config.l2OutputOracleConfig.proposer,
                config.l2OutputOracleConfig.owner
            )
        );

        // Upgrade the OptimismPortal and call initialize()
        config.proxyAdmin.upgradeAndCall(
            address(config.proxyOptimismPortal),
            address(config.implOptimismPortal),
            abi.encodeCall(OptimismPortal.initialize)
        );

        // TODO: Transfer ETH from L1StandardBridge to OptimismPortal

        // Upgrade the L1StandardBridge and call initialize()
        config.proxyAdmin.upgradeAndCall(
            address(config.l1StandardBridge),
            address(config.implL1StandardBridge),
            abi.encodeCall(
                L1StandardBridge.initialize,
                address(config.l1CrossDomainMessenger)
            )
        );

        // Upgrade the L1CrossDomainMessenger and call initialize()
        config.proxyAdmin.upgradeAndCall(
            address(config.l1CrossDomainMessenger),
            address(config.implL1CrossDomainMessenger),
            abi.encodeCall(L1CrossDomainMessenger.initialize)
        );
    }

    function step5() public onlyOwner {
        // Unpause the L1CrossDomainMessenger
        config.l1CrossDomainMessenger.unpause();
    }

    function step6() public onlyOwner {
        // Transfer ownership of the L1CrossDomainMessenger to multisig
        config.l1CrossDomainMessenger.transferOwnership(address(config.multisig));

        // Transfer ownership of the ProxyAdmin to multisig
        config.proxyAdmin.setOwner(address(config.multisig));
    }
}
